class DeliveryProofUploadError extends Error {
  constructor(message, status = 400, code = null) {
    super(message);
    this.name = "DeliveryProofUploadError";
    this.status = status;
    this.code = code;
  }
}

const createOrderDeliveryProofHelpers = ({
  DELIVERY_ACTIVE_STATUSES,
  createOrderAudit,
}) => {
  const ensureDeliveryProofUploadAllowed = ({ order, actor, file }) => {
    if (!order) {
      throw new DeliveryProofUploadError("Order not found", 404);
    }

    if (!order.isGiftOrder || !order.deliveryVerificationRequired) {
      throw new DeliveryProofUploadError(
        "Delivery proof upload is only available for gift orders requiring verification",
        400
      );
    }

    if (actor.role === "rider") {
      if (order.riderId !== actor.id) {
        throw new DeliveryProofUploadError("Not authorized to upload proof for this order", 403);
      }

      if (!DELIVERY_ACTIVE_STATUSES.has(order.status)) {
        throw new DeliveryProofUploadError(
          "Delivery proof can only be uploaded while delivery is active",
          400
        );
      }
    }

    if (!file || !file.cloudinaryUrl) {
      throw new DeliveryProofUploadError("No delivery proof photo uploaded", 400);
    }
  };

  const recordDeliveryProofUpload = async ({ orderId, actor, file }) => {
    await createOrderAudit({
      orderId,
      actorId: actor.id,
      actorRole: actor.role,
      action: "gift_delivery_photo_uploaded",
      metadata: {
        photoUrl: file.cloudinaryUrl,
        uploadedAt: new Date().toISOString(),
      },
    }).catch(() => null);

    return {
      orderId,
      photoUrl: file.cloudinaryUrl,
      blurHash: file.blurHash || null,
    };
  };

  return {
    ensureDeliveryProofUploadAllowed,
    recordDeliveryProofUpload,
  };
};

module.exports = {
  DeliveryProofUploadError,
  createOrderDeliveryProofHelpers,
};
