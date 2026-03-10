const {
  createOrderPickupStatusUpdateHelpers,
} = require("../routes/support/order_pickup_status_update_helpers");

describe("order_pickup_status_update_helpers", () => {
  let generatePickupCode;
  let hashPickupCode;
  let helpers;

  beforeEach(() => {
    generatePickupCode = jest.fn(() => "123456");
    hashPickupCode = jest.fn(() => "hashed-code");
    helpers = createOrderPickupStatusUpdateHelpers({
      generatePickupCode,
      hashPickupCode,
      PICKUP_READY_EXPIRY_MINUTES: 15,
    });
  });

  it("does nothing for non-pickup orders", () => {
    const initial = { status: "confirmed" };
    const result = helpers.applyPickupStatusUpdate({
      order: { fulfillmentMode: "delivery" },
      status: "ready",
      updateData: initial,
    });

    expect(result).toEqual({
      updateData: initial,
      pickupCodeForNotification: null,
    });
  });

  it("adds ready state metadata and pickup code for pickup orders", () => {
    const result = helpers.applyPickupStatusUpdate({
      order: { id: "order-1", fulfillmentMode: "pickup" },
      status: "ready",
      updateData: { status: "ready" },
    });

    expect(generatePickupCode).toHaveBeenCalled();
    expect(hashPickupCode).toHaveBeenCalledWith("order-1", "123456");
    expect(result.pickupCodeForNotification).toBe("123456");
    expect(result.updateData).toEqual(
      expect.objectContaining({
        status: "ready",
        pickupOtpHash: "hashed-code",
        pickupOtpFailedAttempts: 0,
        pickupOtpLastAttemptAt: null,
      })
    );
    expect(result.updateData.readyAt).toBeInstanceOf(Date);
    expect(result.updateData.pickupExpiresAt).toBeInstanceOf(Date);
  });

  it("calculates pickupReadyToCollectedSeconds when pickup order is collected", () => {
    const readyAt = new Date(Date.now() - 90 * 1000);
    const result = helpers.applyPickupStatusUpdate({
      order: { fulfillmentMode: "pickup", readyAt },
      status: "picked_up",
      updateData: { status: "picked_up" },
    });

    expect(result.pickupCodeForNotification).toBeNull();
    expect(result.updateData.pickedUpAt).toBeInstanceOf(Date);
    expect(result.updateData.pickupReadyToCollectedSeconds).toBeGreaterThanOrEqual(89);
  });
});
