class SupportOrderOpError extends Error {
  constructor(message, status = 400, code = null) {
    super(message);
    this.name = "SupportOrderOpError";
    this.status = status;
    this.code = code;
  }
}

const createOrderSupportOpsHelpers = ({
  prisma,
  cancelPickupOrder,
  decrementPromoUsageIfNeeded,
  createOrderAudit,
  releaseInventoryHolds,
  sanitizeOrderPayload,
}) => {
  const ensureSupportOrderExists = (order) => {
    if (!order) {
      throw new SupportOrderOpError("Order not found", 404);
    }
  };

  const cancelOrderBySupport = async ({ orderId, order, reason, refund, actorId, actorRole }) => {
    ensureSupportOrderExists(order);

    let updatedOrder = null;
    if (order.fulfillmentMode === "pickup") {
      updatedOrder = await cancelPickupOrder({
        orderId,
        reason,
        refund,
        actorId,
        actorRole,
        action: "support_cancel",
        metadata: { previousStatus: order.status },
      });
    } else {
      updatedOrder = await prisma.$transaction(async (tx) => {
        const currentOrder = await tx.order.findUnique({
          where: { id: orderId },
          select: {
            status: true,
            paymentStatus: true,
            promoCode: true,
          },
        });

        if (!currentOrder) {
          throw new SupportOrderOpError("Order not found", 404);
        }

        const cancelledOrder = await tx.order.update({
          where: { id: orderId },
          data: {
            status: "cancelled",
            cancelledDate: new Date(),
            cancellationReason: reason,
            paymentStatus:
              refund && ["paid", "successful"].includes(currentOrder.paymentStatus)
                ? "refunded"
                : currentOrder.paymentStatus,
            updatedAt: new Date(),
          },
        });

        if (currentOrder.status !== "cancelled") {
          await decrementPromoUsageIfNeeded({ tx, promoCode: currentOrder.promoCode });
        }

        await createOrderAudit({
          tx,
          orderId,
          actorId,
          actorRole,
          action: "support_cancel",
          reason,
          metadata: { previousStatus: currentOrder.status, refund },
        });

        return cancelledOrder;
      });
    }

    return sanitizeOrderPayload(updatedOrder);
  };

  const refundOrderBySupport = async ({ orderId, order, reason, actorId, actorRole }) => {
    ensureSupportOrderExists(order);

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        paymentStatus: "refunded",
        updatedAt: new Date(),
      },
    });

    if (order.fulfillmentMode === "pickup") {
      await releaseInventoryHolds({ orderId }).catch(() => null);
    }

    await createOrderAudit({
      orderId,
      actorId,
      actorRole,
      action: "support_refund",
      reason,
      metadata: {
        previousPaymentStatus: order.paymentStatus,
        currentStatus: order.status,
      },
    });

    return sanitizeOrderPayload(updatedOrder);
  };

  const forceCompleteOrderBySupport = async ({ orderId, order, reason, actorId, actorRole }) => {
    ensureSupportOrderExists(order);

    const now = new Date();
    const nextStatus = order.fulfillmentMode === "pickup" ? "picked_up" : "delivered";
    const updateData = {
      status: nextStatus,
      updatedAt: now,
    };

    if (order.fulfillmentMode === "pickup") {
      updateData.pickedUpAt = now;
      if (order.readyAt) {
        updateData.pickupReadyToCollectedSeconds = Math.max(
          0,
          Math.floor((now.getTime() - new Date(order.readyAt).getTime()) / 1000)
        );
      }
    } else {
      updateData.deliveredDate = now;
    }

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: updateData,
    });

    await createOrderAudit({
      orderId,
      actorId,
      actorRole,
      action: "support_force_complete",
      reason,
      metadata: {
        previousStatus: order.status,
        nextStatus,
      },
    });

    return sanitizeOrderPayload(updatedOrder);
  };

  return {
    ensureSupportOrderExists,
    cancelOrderBySupport,
    refundOrderBySupport,
    forceCompleteOrderBySupport,
  };
};

module.exports = {
  SupportOrderOpError,
  createOrderSupportOpsHelpers,
};
