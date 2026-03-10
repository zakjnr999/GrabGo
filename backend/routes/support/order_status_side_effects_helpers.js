const RiderStatus = require("../../models/RiderStatus");
const {
  fireDeliverySettlementSideEffects,
} = require("../../services/delivery_settlement_service");
const {
  recordDeliveryCancellation,
} = require("../../services/delivery_analytics_service");

const createOrderStatusSideEffectsHelpers = ({
  creditService,
  releaseInventoryHolds,
  createOrderAudit,
  getIO,
  notifyOrderStatusChange,
  decryptDeliveryCode,
  sendDeliveryCodeSms,
  safeDispatchRetrySideEffect,
  queueDispatchRetryIfNeeded,
  dispatchService,
  dispatchRetryService,
  trackingService,
  shouldTriggerDispatchForOrder,
  ORDER_TO_TRACKING_STATUS_MAP,
  COD_NO_SHOW_REASON,
  logger,
}) => {
  const createOrderAuditSafe = (...args) => createOrderAudit(...args).catch(() => null);

  const sendGiftRecipientCodeIfNeeded = async ({
    orderId,
    order,
    updatedOrder,
    status,
    actorId,
    actorRole,
  }) => {
    if (
      status !== "on_the_way" ||
      order.status === "on_the_way" ||
      !order.isGiftOrder ||
      !order.deliveryVerificationRequired ||
      !order.giftRecipientPhone ||
      !order.deliveryCodeEncrypted
    ) {
      return;
    }

    try {
      const deliveryCode = decryptDeliveryCode(order.deliveryCodeEncrypted);
      const recipientSendResult = await sendDeliveryCodeSms({
        phoneNumber: order.giftRecipientPhone,
        orderNumber: updatedOrder.orderNumber,
        code: deliveryCode,
        audience: "recipient",
        recipientName: order.giftRecipientName,
      });

      await createOrderAuditSafe({
        orderId,
        actorId,
        actorRole,
        action: "gift_code_sent_recipient",
        metadata: {
          trigger: "status_on_the_way",
          success: !!recipientSendResult?.success,
          provider: recipientSendResult?.provider || null,
          errorMessage: recipientSendResult?.success ? null : recipientSendResult?.message || null,
        },
      });
    } catch (error) {
      logger.error({
        event: "gift_recipient_status_notification_failed",
        orderId,
        error: error?.message || String(error),
      });
    }
  };

  const resetRiderDeliveryStatusIfNeeded = async ({ order, status }) => {
    if (!["delivered", "cancelled"].includes(status) || !order.riderId) {
      return;
    }

    try {
      await RiderStatus.findOneAndUpdate(
        { riderId: order.riderId },
        { $set: { isOnDelivery: false, currentOrderId: null } }
      );
      logger.info({
        event: "rider_delivery_status_reset",
        riderId: order.riderId,
        status,
        orderId: order.id,
      });
    } catch (error) {
      logger.error({
        event: "reset_rider_delivery_status_failed",
        riderId: order.riderId,
        status,
        orderId: order.id,
        error: error?.message || String(error),
      });
    }
  };

  const fireDeliveryAnalyticsSideEffects = ({ order, updatedOrder, status, actorRole, normalizedCancellationReason }) => {
    if (status === "delivered" && order.riderId) {
      fireDeliverySettlementSideEffects({
        order: updatedOrder,
        riderId: order.riderId,
        creditAmount: Number(order.riderEarnings) || Number(order.deliveryFee) || 0,
        orderType: order.orderType || "food",
      });
    }

    if (status === "cancelled" && order.riderId) {
      const cancellationFault = actorRole === "rider" ? "rider" : "customer";
      recordDeliveryCancellation({
        riderId: order.riderId,
        orderId: order.id,
        orderType: order.orderType || "food",
        fault: cancellationFault,
        reason: normalizedCancellationReason || "",
      }).catch((error) => {
        logger.error({
          event: "delivery_cancellation_analytics_failed",
          orderId: order.id,
          riderId: order.riderId,
          error: error?.message || String(error),
        });
      });
    }
  };

  const triggerDispatchIfNeeded = async ({ orderId, order, updatedOrder, status }) => {
    if (
      !shouldTriggerDispatchForOrder(updatedOrder, status) ||
      !["paid", "successful"].includes(updatedOrder.paymentStatus || order.paymentStatus) ||
      updatedOrder.riderId ||
      updatedOrder.fulfillmentMode === "pickup"
    ) {
      return;
    }

    logger.info({
      event: "dispatch_triggered_after_order_status_update",
      orderId,
      orderNumber: updatedOrder.orderNumber,
      status,
    });

    dispatchService
      .dispatchOrder(orderId)
      .then(async (result) => {
        if (result.success) {
          logger.info({
            event: "dispatch_succeeded_after_order_status_update",
            orderId,
            orderNumber: updatedOrder.orderNumber,
            riderName: result.riderName,
          });
          await safeDispatchRetrySideEffect(
            `mark retry resolved after status dispatch (${orderId})`,
            () => dispatchRetryService.markRetryResolved(orderId, "dispatch_succeeded")
          );
          return;
        }

        logger.warn({
          event: "dispatch_failed_after_order_status_update",
          orderId,
          orderNumber: updatedOrder.orderNumber,
          error: result.error,
        });
        await safeDispatchRetrySideEffect(
          `enqueue retry after status dispatch failure (${orderId})`,
          () =>
            queueDispatchRetryIfNeeded({
              orderId,
              orderNumber: updatedOrder.orderNumber,
              result,
              source: "orders:status_update",
            })
        );
      })
      .catch(async (error) => {
        logger.error({
          event: "dispatch_exception_after_order_status_update",
          orderId,
          orderNumber: updatedOrder.orderNumber,
          error: error?.message || String(error),
        });
        await safeDispatchRetrySideEffect(
          `enqueue retry after status dispatch exception (${orderId})`,
          () =>
            dispatchRetryService.enqueueDispatchRetry({
              orderId,
              orderNumber: updatedOrder.orderNumber,
              reason: "dispatch_exception",
              source: "orders:status_update",
              delaySeconds: 30,
              metadata: { error: error?.message || String(error) },
            })
        );
      });
  };

  const syncTrackingStatusIfNeeded = ({ orderId, status }) => {
    const trackingStatus = ORDER_TO_TRACKING_STATUS_MAP[status];
    if (!trackingStatus) return;

    trackingService.updateOrderStatus(orderId, trackingStatus).catch((trackingError) => {
      const message = String(trackingError?.message || "");
      if (message.toLowerCase().includes("tracking not found")) {
        logger.warn({
          event: "tracking_status_sync_skipped_missing_tracking",
          orderId,
          trackingStatus,
        });
        return;
      }
      logger.error({
        event: "tracking_status_sync_failed",
        orderId,
        trackingStatus,
        error: trackingError?.message || String(trackingError),
      });
    });
  };

  const runOrderStatusPostUpdateSideEffects = async ({
    orderId,
    order,
    updatedOrder,
    status,
    actorId,
    actorRole,
    normalizedCancellationReason,
    normalizedNoShowEvidence,
    deliveryVerification,
    pickupCodeForNotification,
    isCodNoShowCancellation,
  }) => {
    if (status === "cancelled" && order.creditsApplied > 0) {
      await creditService.releaseHold(order.customerId, order.id);
    }

    if (status === "cancelled" && order.fulfillmentMode === "pickup") {
      await releaseInventoryHolds({ orderId }).catch(() => null);
    }

    await createOrderAuditSafe({
      orderId,
      actorId,
      actorRole,
      action: `status_${status}`,
      reason: status === "cancelled" ? normalizedCancellationReason || null : null,
      metadata: {
        previousStatus: order.status,
        nextStatus: status,
        fulfillmentMode: order.fulfillmentMode,
        deliveryVerificationMethod:
          status === "delivered" && order.deliveryVerificationRequired
            ? deliveryVerification?.method || null
            : null,
      },
    });

    if (isCodNoShowCancellation && normalizedNoShowEvidence) {
      await createOrderAuditSafe({
        orderId,
        actorId,
        actorRole,
        action: "cod_no_show_confirmed",
        reason: COD_NO_SHOW_REASON,
        metadata: {
          ...normalizedNoShowEvidence,
        },
      });
    }

    const io = getIO();
    const pickupReadyMessage =
      status === "ready" && updatedOrder.fulfillmentMode === "pickup" && pickupCodeForNotification
        ? `Your order is ready for pickup. Show this code at the store: ${pickupCodeForNotification}`
        : null;
    notifyOrderStatusChange(updatedOrder, status, pickupReadyMessage, io);

    await sendGiftRecipientCodeIfNeeded({
      orderId,
      order,
      updatedOrder,
      status,
      actorId,
      actorRole,
    });

    await resetRiderDeliveryStatusIfNeeded({ order, status });
    fireDeliveryAnalyticsSideEffects({
      order,
      updatedOrder,
      status,
      actorRole,
      normalizedCancellationReason,
    });

    await triggerDispatchIfNeeded({ orderId, order, updatedOrder, status });

    if (status === "cancelled") {
      dispatchRetryService.markRetryCancelled(orderId, "order_cancelled").catch(() => null);
      dispatchService.cancelOrderReservations(orderId).catch((error) => {
        logger.error({
          event: "cancel_order_reservations_failed",
          orderId,
          error: error?.message || String(error),
        });
      });
    }

    syncTrackingStatusIfNeeded({ orderId, status });
  };

  return {
    runOrderStatusPostUpdateSideEffects,
  };
};

module.exports = {
  createOrderStatusSideEffectsHelpers,
};
