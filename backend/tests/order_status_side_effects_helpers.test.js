jest.mock("../models/RiderStatus", () => ({
  findOneAndUpdate: jest.fn(),
}));

jest.mock("../services/delivery_settlement_service", () => ({
  fireDeliverySettlementSideEffects: jest.fn(),
}));

jest.mock("../services/delivery_analytics_service", () => ({
  recordDeliveryCancellation: jest.fn(() => Promise.resolve()),
}));

const RiderStatus = require("../models/RiderStatus");
const {
  fireDeliverySettlementSideEffects,
} = require("../services/delivery_settlement_service");
const {
  recordDeliveryCancellation,
} = require("../services/delivery_analytics_service");
const {
  createOrderStatusSideEffectsHelpers,
} = require("../routes/support/order_status_side_effects_helpers");

describe("order_status_side_effects_helpers", () => {
  let deps;
  let helpers;

  beforeEach(() => {
    jest.clearAllMocks();

    deps = {
      creditService: {
        releaseHold: jest.fn().mockResolvedValue(undefined),
      },
      releaseInventoryHolds: jest.fn().mockResolvedValue(undefined),
      createOrderAudit: jest.fn().mockResolvedValue(undefined),
      getIO: jest.fn(() => ({ io: true })),
      notifyOrderStatusChange: jest.fn(),
      decryptDeliveryCode: jest.fn(() => "123456"),
      sendDeliveryCodeSms: jest.fn().mockResolvedValue({ success: true, provider: "hubtel" }),
      safeDispatchRetrySideEffect: jest.fn((label, operation) => operation()),
      queueDispatchRetryIfNeeded: jest.fn().mockResolvedValue(undefined),
      dispatchService: {
        dispatchOrder: jest.fn().mockResolvedValue({ success: true, riderName: "Yaw" }),
        cancelOrderReservations: jest.fn().mockResolvedValue(undefined),
      },
      dispatchRetryService: {
        markRetryCancelled: jest.fn().mockResolvedValue(undefined),
        markRetryResolved: jest.fn().mockResolvedValue(undefined),
        enqueueDispatchRetry: jest.fn().mockResolvedValue(undefined),
      },
      trackingService: {
        updateOrderStatus: jest.fn().mockResolvedValue(undefined),
      },
      shouldTriggerDispatchForOrder: jest.fn(),
      ORDER_TO_TRACKING_STATUS_MAP: {
        preparing: "preparing",
        on_the_way: "in_transit",
        cancelled: "cancelled",
      },
      COD_NO_SHOW_REASON: "customer_not_available",
      logger: {
        info: jest.fn(),
        warn: jest.fn(),
        error: jest.fn(),
      },
    };

    helpers = createOrderStatusSideEffectsHelpers(deps);
  });

  it("handles cancellation side effects including credits, audits, analytics, reservations, and tracking", async () => {
    await helpers.runOrderStatusPostUpdateSideEffects({
      orderId: "order-1",
      order: {
        id: "order-1",
        status: "preparing",
        customerId: "cust-1",
        creditsApplied: 12,
        fulfillmentMode: "pickup",
        riderId: "rider-1",
        orderType: "food",
      },
      updatedOrder: {
        id: "order-1",
        status: "cancelled",
        fulfillmentMode: "pickup",
      },
      status: "cancelled",
      actorId: "admin-1",
      actorRole: "admin",
      normalizedCancellationReason: "customer_not_available",
      normalizedNoShowEvidence: { waitedMinutes: 10 },
      deliveryVerification: null,
      pickupCodeForNotification: null,
      isCodNoShowCancellation: true,
    });

    expect(deps.creditService.releaseHold).toHaveBeenCalledWith("cust-1", "order-1");
    expect(deps.releaseInventoryHolds).toHaveBeenCalledWith({ orderId: "order-1" });
    expect(deps.createOrderAudit).toHaveBeenCalledTimes(2);
    expect(RiderStatus.findOneAndUpdate).toHaveBeenCalledWith(
      { riderId: "rider-1" },
      { $set: { isOnDelivery: false, currentOrderId: null } }
    );
    expect(recordDeliveryCancellation).toHaveBeenCalledWith({
      riderId: "rider-1",
      orderId: "order-1",
      orderType: "food",
      fault: "customer",
      reason: "customer_not_available",
    });
    expect(deps.dispatchRetryService.markRetryCancelled).toHaveBeenCalledWith(
      "order-1",
      "order_cancelled"
    );
    expect(deps.dispatchService.cancelOrderReservations).toHaveBeenCalledWith("order-1");
    expect(deps.trackingService.updateOrderStatus).toHaveBeenCalledWith("order-1", "cancelled");
  });

  it("handles on-the-way notification and successful dispatch trigger", async () => {
    deps.shouldTriggerDispatchForOrder.mockReturnValue(true);

    await helpers.runOrderStatusPostUpdateSideEffects({
      orderId: "order-2",
      order: {
        id: "order-2",
        status: "confirmed",
        customerId: "cust-2",
        creditsApplied: 0,
        fulfillmentMode: "delivery",
        riderId: null,
        paymentStatus: "paid",
        isGiftOrder: true,
        deliveryVerificationRequired: true,
        giftRecipientPhone: "+233555000333",
        giftRecipientName: "Ama",
        deliveryCodeEncrypted: "cipher",
        orderType: "food",
      },
      updatedOrder: {
        id: "order-2",
        orderNumber: "ORD-2",
        status: "on_the_way",
        fulfillmentMode: "delivery",
        riderId: null,
        paymentStatus: "paid",
      },
      status: "on_the_way",
      actorId: "rider-2",
      actorRole: "rider",
      normalizedCancellationReason: null,
      normalizedNoShowEvidence: null,
      deliveryVerification: null,
      pickupCodeForNotification: null,
      isCodNoShowCancellation: false,
    });

    expect(deps.notifyOrderStatusChange).toHaveBeenCalledWith(
      expect.objectContaining({ id: "order-2" }),
      "on_the_way",
      null,
      { io: true }
    );
    expect(deps.decryptDeliveryCode).toHaveBeenCalledWith("cipher");
    expect(deps.sendDeliveryCodeSms).toHaveBeenCalledWith({
      phoneNumber: "+233555000333",
      orderNumber: "ORD-2",
      code: "123456",
      audience: "recipient",
      recipientName: "Ama",
    });
    expect(deps.dispatchService.dispatchOrder).toHaveBeenCalledWith("order-2");
    expect(deps.dispatchRetryService.markRetryResolved).toHaveBeenCalledWith(
      "order-2",
      "dispatch_succeeded"
    );
    expect(deps.trackingService.updateOrderStatus).toHaveBeenCalledWith("order-2", "in_transit");
    expect(fireDeliverySettlementSideEffects).not.toHaveBeenCalled();
  });
});
