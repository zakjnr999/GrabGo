const createOrderDeliveryVerificationHelpers = ({
  DeliveryVerificationError,
  verifyDeliveryCodeOrThrow,
}) => {
  const toFiniteNumberOrNull = (value) => {
    const numeric = Number(value);
    return Number.isFinite(numeric) ? numeric : null;
  };

  const ensureDeliveryVerificationPayload = ({ status, order, deliveryVerification }) => {
    if (status !== "delivered" || !order.deliveryVerificationRequired) {
      return;
    }

    if (!deliveryVerification || typeof deliveryVerification !== "object") {
      throw new DeliveryVerificationError(
        "deliveryVerification is required before marking this order as delivered",
        400,
        "DELIVERY_VERIFICATION_REQUIRED"
      );
    }

    const method = deliveryVerification.method;
    if (!["code", "authorized_photo"].includes(method)) {
      throw new DeliveryVerificationError(
        "Invalid deliveryVerification.method",
        400,
        "DELIVERY_VERIFICATION_METHOD_INVALID"
      );
    }

    if (method === "code") {
      if (!deliveryVerification.code || !String(deliveryVerification.code).trim()) {
        throw new DeliveryVerificationError(
          "deliveryVerification.code is required for code verification",
          400,
          "DELIVERY_CODE_REQUIRED"
        );
      }
      return;
    }

    if (!deliveryVerification.photoUrl || !String(deliveryVerification.photoUrl).trim()) {
      throw new DeliveryVerificationError(
        "deliveryVerification.photoUrl is required for fallback verification",
        400,
        "DELIVERY_PROOF_PHOTO_REQUIRED"
      );
    }

    if (!deliveryVerification.reason || !String(deliveryVerification.reason).trim()) {
      throw new DeliveryVerificationError(
        "deliveryVerification.reason is required for fallback verification",
        400,
        "DELIVERY_PROOF_REASON_REQUIRED"
      );
    }

    if (deliveryVerification.contactAttempted !== true) {
      throw new DeliveryVerificationError(
        "deliveryVerification.contactAttempted must be true for fallback verification",
        400,
        "DELIVERY_CONTACT_ATTEMPT_REQUIRED"
      );
    }
  };

  const resolveCodeVerificationUpdateData = async ({
    tx,
    status,
    order,
    deliveryVerification,
    actorId,
    actorRole,
  }) => {
    if (
      status !== "delivered" ||
      !order.deliveryVerificationRequired ||
      deliveryVerification?.method !== "code"
    ) {
      return null;
    }

    return verifyDeliveryCodeOrThrow({
      tx,
      order,
      code: deliveryVerification?.code,
      actorId,
      actorRole,
      riderLat: deliveryVerification?.riderLat,
      riderLng: deliveryVerification?.riderLng,
      skipSuccessAudit: true,
    });
  };

  const applyDeliveredVerificationUpdate = async ({
    tx,
    orderId,
    order,
    deliveryVerification,
    codeVerificationUpdateData,
    updateData,
    actorId,
    actorRole,
  }) => {
    if (!order.deliveryVerificationRequired) {
      return updateData;
    }

    const latestVerificationState = await tx.order.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        deliveryCodeVerifiedAt: true,
        deliveryVerificationMethod: true,
      },
    });

    if (!latestVerificationState) {
      throw new DeliveryVerificationError("Order not found", 404, "ORDER_NOT_FOUND");
    }

    const alreadyCompleted =
      latestVerificationState.deliveryCodeVerifiedAt ||
      latestVerificationState.deliveryVerificationMethod === "authorized_photo";

    if (alreadyCompleted) {
      throw new DeliveryVerificationError(
        "Delivery verification has already been completed for this order",
        400,
        "DELIVERY_VERIFICATION_ALREADY_COMPLETED"
      );
    }

    const method = deliveryVerification?.method;
    if (method === "code") {
      const nextUpdateData = {
        ...updateData,
        ...codeVerificationUpdateData,
      };

      await tx.orderActionAudit.create({
        data: {
          orderId,
          actorId,
          actorRole,
          action: "gift_code_verified",
          metadata: {
            riderLat: toFiniteNumberOrNull(deliveryVerification?.riderLat),
            riderLng: toFiniteNumberOrNull(deliveryVerification?.riderLng),
            verifiedAt: codeVerificationUpdateData?.deliveryCodeVerifiedAt
              ? new Date(codeVerificationUpdateData.deliveryCodeVerifiedAt).toISOString()
              : new Date().toISOString(),
          },
        },
      });

      return nextUpdateData;
    }

    const nextUpdateData = {
      ...updateData,
      deliveryVerificationMethod: "authorized_photo",
      deliveryProofPhotoUrl: String(deliveryVerification.photoUrl).trim(),
      deliveryProofReason: String(deliveryVerification.reason).trim(),
      deliveryProofCapturedAt: new Date(),
      deliveryVerificationLat: toFiniteNumberOrNull(deliveryVerification?.riderLat),
      deliveryVerificationLng: toFiniteNumberOrNull(deliveryVerification?.riderLng),
    };

    await tx.orderActionAudit.create({
      data: {
        orderId,
        actorId,
        actorRole,
        action: "gift_delivered_fallback",
        metadata: {
          reason: nextUpdateData.deliveryProofReason,
          photoUrl: nextUpdateData.deliveryProofPhotoUrl,
          contactAttempted: deliveryVerification?.contactAttempted === true,
          authorizedRecipientName: deliveryVerification?.authorizedRecipientName || null,
          riderLat: nextUpdateData.deliveryVerificationLat,
          riderLng: nextUpdateData.deliveryVerificationLng,
        },
      },
    });

    return nextUpdateData;
  };

  return {
    ensureDeliveryVerificationPayload,
    resolveCodeVerificationUpdateData,
    applyDeliveredVerificationUpdate,
  };
};

module.exports = {
  createOrderDeliveryVerificationHelpers,
};
