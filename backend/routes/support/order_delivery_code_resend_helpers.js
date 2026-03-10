class DeliveryCodeResendRouteError extends Error {
  constructor(message, status = 400, code = null, meta = null) {
    super(message);
    this.name = "DeliveryCodeResendRouteError";
    this.status = status;
    this.code = code;
    this.meta = meta;
  }
}

const createOrderDeliveryCodeResendHelpers = ({
  prisma,
  DELIVERY_ACTIVE_STATUSES,
  getResendAvailability,
  decryptDeliveryCode,
  sendDeliveryCodeSms,
  createOrderAudit,
}) => {
  const ensureDeliveryCodeResendAllowed = ({ order, target, actor }) => {
    if (!order) {
      throw new DeliveryCodeResendRouteError("Order not found", 404);
    }

    if (!order.isGiftOrder || !order.deliveryVerificationRequired) {
      throw new DeliveryCodeResendRouteError(
        "Delivery code resend is only available for gift orders",
        400
      );
    }

    if (!order.deliveryCodeEncrypted) {
      throw new DeliveryCodeResendRouteError(
        "Delivery code is unavailable for this order",
        400
      );
    }

    if (["delivered", "cancelled"].includes(order.status)) {
      throw new DeliveryCodeResendRouteError(
        "Cannot resend delivery code for completed or cancelled orders",
        400,
        "DELIVERY_CODE_RESEND_NOT_ALLOWED"
      );
    }

    if (actor.role === "customer") {
      if (order.customerId !== actor.id) {
        throw new DeliveryCodeResendRouteError("Not authorized to resend code for this order", 403);
      }
    } else if (actor.role === "rider") {
      if (order.riderId !== actor.id) {
        throw new DeliveryCodeResendRouteError("Not authorized to resend code for this order", 403);
      }
      if (target !== "recipient") {
        throw new DeliveryCodeResendRouteError("Riders can only resend code to recipient", 403);
      }
      if (!DELIVERY_ACTIVE_STATUSES.has(order.status)) {
        throw new DeliveryCodeResendRouteError(
          "Code can only be resent while delivery is active",
          400
        );
      }
    } else if (actor.role !== "admin") {
      throw new DeliveryCodeResendRouteError("Not authorized to resend delivery codes", 403);
    }

    const resendAvailability = getResendAvailability(order);
    if (!resendAvailability.allowed) {
      throw new DeliveryCodeResendRouteError(
        resendAvailability.message,
        resendAvailability.status,
        resendAvailability.code,
        { retryAfterSeconds: resendAvailability.retryAfterSeconds || null }
      );
    }
  };

  const resendDeliveryCode = async ({ order, target, actor }) => {
    const deliveryCode = decryptDeliveryCode(order.deliveryCodeEncrypted);
    let phoneNumber = null;
    let audience = target;

    if (target === "customer") {
      const customer = await prisma.user.findUnique({
        where: { id: order.customerId },
        select: { phone: true },
      });
      phoneNumber = customer?.phone || null;
      if (!phoneNumber) {
        throw new DeliveryCodeResendRouteError(
          "Customer phone number is unavailable for this order",
          400
        );
      }
    } else {
      phoneNumber = order.giftRecipientPhone;
      audience = "recipient";
      if (!phoneNumber) {
        throw new DeliveryCodeResendRouteError(
          "Gift recipient phone number is unavailable for this order",
          400
        );
      }
    }

    const sendResult = await sendDeliveryCodeSms({
      phoneNumber,
      orderNumber: order.orderNumber,
      code: deliveryCode,
      audience,
      recipientName: order.giftRecipientName,
    });

    if (!sendResult?.success) {
      throw new DeliveryCodeResendRouteError(
        sendResult?.message || "Failed to resend delivery code",
        502,
        "DELIVERY_CODE_RESEND_FAILED"
      );
    }

    const resentAt = new Date();
    await prisma.order.update({
      where: { id: order.id },
      data: {
        deliveryCodeResendCount: { increment: 1 },
        deliveryCodeLastSentAt: resentAt,
      },
    });

    await createOrderAudit({
      orderId: order.id,
      actorId: actor.id,
      actorRole: actor.role,
      action: "gift_code_resent",
      metadata: {
        target,
        provider: sendResult.provider || null,
        resentAt: resentAt.toISOString(),
      },
    }).catch(() => null);

    const responseData = {
      orderId: order.id,
      target,
      resentAt: resentAt.toISOString(),
    };

    if (actor.role === "customer" && target === "customer") {
      responseData.giftDeliveryCode = deliveryCode;
    }

    return responseData;
  };

  return {
    ensureDeliveryCodeResendAllowed,
    resendDeliveryCode,
  };
};

module.exports = {
  DeliveryCodeResendRouteError,
  createOrderDeliveryCodeResendHelpers,
};
