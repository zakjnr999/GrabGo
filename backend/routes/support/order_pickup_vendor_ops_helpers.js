class PickupVendorOpError extends Error {
  constructor(message, status = 400, code = null) {
    super(message);
    this.name = "PickupVendorOpError";
    this.status = status;
    this.code = code;
  }
}

const createOrderPickupVendorOpsHelpers = ({
  prisma,
  hashPickupCode,
  isPickupOtpLocked,
  PICKUP_OTP_MAX_ATTEMPTS,
  notifyOrderStatusChange,
}) => {
  const ensureVendorCanManagePickupOrder = ({ order, userRole, vendorContext }) => {
    if (!order) {
      throw new PickupVendorOpError("Order not found", 404);
    }

    if (order.fulfillmentMode !== "pickup") {
      throw new PickupVendorOpError("Order is not a pickup order", 400);
    }

    if (userRole === "restaurant") {
      const isOwnedByVendor =
        (vendorContext?.restaurantId && order.restaurantId === vendorContext.restaurantId) ||
        (vendorContext?.groceryStoreId && order.groceryStoreId === vendorContext.groceryStoreId) ||
        (vendorContext?.pharmacyStoreId && order.pharmacyStoreId === vendorContext.pharmacyStoreId) ||
        (vendorContext?.grabMartStoreId && order.grabMartStoreId === vendorContext.grabMartStoreId);

      if (!isOwnedByVendor) {
        throw new PickupVendorOpError("Not authorized to manage this order", 403);
      }
    }
  };

  const acceptPickupOrderAndNotify = async ({ orderId, order, actorId, actorRole, sanitizeOrderPayload }) => {
    if (!["confirmed", "preparing"].includes(order.status)) {
      throw new PickupVendorOpError("Only confirmed pickup orders can be accepted", 400);
    }

    const updatedOrder = await prisma.order.update({
      where: { id: orderId },
      data: {
        status: "preparing",
        acceptedAt: order.acceptedAt || new Date(),
        preparingAt: new Date(),
        rejectReason: null,
        rejectedAt: null,
        updatedAt: new Date(),
      },
    });

    await prisma.orderActionAudit.create({
      data: {
        orderId,
        actorId,
        actorRole,
        action: "pickup_accept",
        metadata: {
          previousStatus: order.status,
          nextStatus: updatedOrder.status,
        },
      },
    });

    notifyOrderStatusChange(
      updatedOrder,
      "preparing",
      "Your pickup order has been accepted and is being prepared."
    );

    return sanitizeOrderPayload(updatedOrder);
  };

  const ensurePickupOrderRejectable = ({ order }) => {
    if (["cancelled", "picked_up", "delivered"].includes(order.status)) {
      throw new PickupVendorOpError("Order can no longer be rejected", 400);
    }
  };

  const ensurePickupCodeCanBeVerified = ({ order }) => {
    if (order.status !== "ready") {
      throw new PickupVendorOpError(
        "Pickup code verification is only available when order is ready",
        400
      );
    }

    if (!order.pickupOtpHash) {
      throw new PickupVendorOpError("Pickup code is not set for this order", 400);
    }

    if (order.pickupExpiresAt && new Date(order.pickupExpiresAt).getTime() <= Date.now()) {
      throw new PickupVendorOpError("Pickup code has expired", 400);
    }

    if (isPickupOtpLocked(order)) {
      throw new PickupVendorOpError(
        "Pickup code verification is temporarily locked. Try again later.",
        429
      );
    }
  };

  const verifyPickupCodeAndCompleteOrder = async ({
    orderId,
    order,
    code,
    actorId,
    actorRole,
    sanitizeOrderPayload,
  }) => {
    const normalizedCode = String(code).trim();
    const codeHash = hashPickupCode(order.id, normalizedCode);

    if (codeHash !== order.pickupOtpHash) {
      const failedAttempts = (order.pickupOtpFailedAttempts || 0) + 1;
      await prisma.order.update({
        where: { id: order.id },
        data: {
          pickupOtpFailedAttempts: failedAttempts,
          pickupOtpLastAttemptAt: new Date(),
        },
      });

      await prisma.orderActionAudit.create({
        data: {
          orderId,
          actorId,
          actorRole,
          action: "pickup_otp_failed",
          metadata: { failedAttempts },
        },
      });

      throw new PickupVendorOpError(
        failedAttempts >= PICKUP_OTP_MAX_ATTEMPTS
          ? "Too many invalid attempts. Verification is temporarily locked."
          : "Invalid pickup code",
        400,
        failedAttempts >= PICKUP_OTP_MAX_ATTEMPTS ? "PICKUP_OTP_LOCKED" : "PICKUP_OTP_INVALID"
      );
    }

    const pickedUpAt = new Date();
    const pickupDeltaSeconds = order.readyAt
      ? Math.max(0, Math.floor((pickedUpAt.getTime() - new Date(order.readyAt).getTime()) / 1000))
      : null;

    const updatedOrder = await prisma.order.update({
      where: { id: order.id },
      data: {
        status: "picked_up",
        pickedUpAt,
        pickupReadyToCollectedSeconds: pickupDeltaSeconds,
        pickupOtpFailedAttempts: 0,
        pickupOtpLastAttemptAt: null,
        updatedAt: new Date(),
      },
    });

    await prisma.orderActionAudit.create({
      data: {
        orderId,
        actorId,
        actorRole,
        action: "pickup_verified",
        metadata: {
          pickupReadyToCollectedSeconds: pickupDeltaSeconds,
        },
      },
    });

    notifyOrderStatusChange(updatedOrder, "picked_up", "Order pickup verified successfully.");

    return sanitizeOrderPayload(updatedOrder);
  };

  return {
    PickupVendorOpError,
    ensureVendorCanManagePickupOrder,
    acceptPickupOrderAndNotify,
    ensurePickupOrderRejectable,
    ensurePickupCodeCanBeVerified,
    verifyPickupCodeAndCompleteOrder,
  };
};

module.exports = {
  PickupVendorOpError,
  createOrderPickupVendorOpsHelpers,
};
