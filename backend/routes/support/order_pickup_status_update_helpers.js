const createOrderPickupStatusUpdateHelpers = ({
  generatePickupCode,
  hashPickupCode,
  PICKUP_READY_EXPIRY_MINUTES,
}) => {
  const applyPickupStatusUpdate = ({ order, status, updateData }) => {
    if (order.fulfillmentMode !== "pickup") {
      return {
        updateData,
        pickupCodeForNotification: null,
      };
    }

    const nextUpdateData = { ...updateData };
    let pickupCodeForNotification = null;

    if (status === "preparing") {
      nextUpdateData.preparingAt = new Date();
    } else if (status === "ready") {
      const readyAt = new Date();
      const pickupCode = generatePickupCode();
      pickupCodeForNotification = pickupCode;
      nextUpdateData.readyAt = readyAt;
      nextUpdateData.pickupExpiresAt = new Date(
        readyAt.getTime() + PICKUP_READY_EXPIRY_MINUTES * 60 * 1000
      );
      nextUpdateData.pickupOtpHash = hashPickupCode(order.id, pickupCode);
      nextUpdateData.pickupOtpFailedAttempts = 0;
      nextUpdateData.pickupOtpLastAttemptAt = null;
    } else if (status === "picked_up") {
      const pickedUpAt = new Date();
      nextUpdateData.pickedUpAt = pickedUpAt;
      if (order.readyAt) {
        nextUpdateData.pickupReadyToCollectedSeconds = Math.max(
          0,
          Math.floor((pickedUpAt.getTime() - new Date(order.readyAt).getTime()) / 1000)
        );
      }
    }

    return {
      updateData: nextUpdateData,
      pickupCodeForNotification,
    };
  };

  return {
    applyPickupStatusUpdate,
  };
};

module.exports = {
  createOrderPickupStatusUpdateHelpers,
};
