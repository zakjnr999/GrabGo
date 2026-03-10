jest.mock("../utils/riderEarningsCalculator", () => ({
  calculateRiderEarnings: jest.fn(),
}));

jest.mock("../models/OrderTracking", () => ({
  buildEntityQuery: jest.fn((entityType, query) => ({ entityType, ...query })),
  findOneAndDelete: jest.fn(),
}));

jest.mock("../models/RiderStatus", () => ({
  findOne: jest.fn(),
  findOneAndUpdate: jest.fn(),
}));

jest.mock("../services/tracking_service", () => ({
  initializeTracking: jest.fn(),
  calculateInitialDeliveryWindow: jest.fn(),
}));

const { calculateRiderEarnings } = require("../utils/riderEarningsCalculator");
const OrderTracking = require("../models/OrderTracking");
const RiderStatus = require("../models/RiderStatus");
const trackingService = require("../services/tracking_service");
const {
  createRiderOrderAcceptanceHelpers,
} = require("../routes/support/rider_order_acceptance_helpers");

describe("rider_order_acceptance_helpers", () => {
  let prisma;
  let notifyCustomerRiderAssignment;
  let safeDispatchRetrySideEffect;
  let dispatchRetryService;
  let getIO;
  let logger;
  let helpers;

  beforeEach(() => {
    jest.clearAllMocks();

    prisma = {
      order: {
        findUnique: jest.fn(),
        update: jest.fn(),
      },
      chat: {
        findUnique: jest.fn(),
        create: jest.fn(),
      },
    };
    notifyCustomerRiderAssignment = jest.fn();
    safeDispatchRetrySideEffect = jest.fn((label, operation) => operation());
    dispatchRetryService = {
      markRetryResolved: jest.fn().mockResolvedValue(undefined),
    };
    getIO = jest.fn(() => ({ io: true }));
    logger = {
      info: jest.fn(),
      error: jest.fn(),
    };

    helpers = createRiderOrderAcceptanceHelpers({
      prisma,
      getPickupLocation: (order) => ({
        latitude: order.restaurant?.latitude,
        longitude: order.restaurant?.longitude,
      }),
      parseCoordinate: (value) => {
        if (value === null || value === undefined || value === "") return null;
        const parsed = Number(value);
        return Number.isFinite(parsed) ? parsed : null;
      },
      hasValidCoordinatePair: (lat, lng) =>
        Number.isFinite(lat) && Number.isFinite(lng),
      getVendorPrepTime: (order) => order.restaurant?.averagePreparationTime || 15,
      getVendorIdFromOrder: (order) => order.restaurantId || null,
      notifyCustomerRiderAssignment,
      safeDispatchRetrySideEffect,
      dispatchRetryService,
      getIO,
      logger,
    });
  });

  it("finalizes an accepted order assignment and returns delivery window", async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: "order-1",
      orderNumber: "ORD-1",
      restaurantId: "rest-1",
      restaurant: { latitude: 5.6, longitude: -0.1 },
    });
    calculateRiderEarnings.mockReturnValue({
      riderBaseFee: 8,
      riderDistanceFee: 4,
      riderTip: 0,
      platformFee: 2,
      riderEarnings: 12,
    });
    const updatedOrder = {
      id: "order-1",
      orderNumber: "ORD-1",
      customerId: "cust-1",
      riderId: "rider-1",
      status: "picked_up",
      restaurantId: "rest-1",
      restaurant: {
        latitude: 5.6,
        longitude: -0.1,
        averagePreparationTime: 18,
      },
      deliveryLatitude: 5.7,
      deliveryLongitude: -0.12,
      items: [{ id: "item-1" }, { id: "item-2" }],
      rider: { username: "Yaw", phone: "233555000111" },
    };
    prisma.order.update
      .mockResolvedValueOnce(updatedOrder)
      .mockResolvedValueOnce(updatedOrder);
    prisma.chat.findUnique.mockResolvedValue(null);
    RiderStatus.findOne.mockResolvedValue({
      location: { coordinates: [-0.15, 5.58] },
    });
    trackingService.calculateInitialDeliveryWindow.mockResolvedValue({
      minMinutes: 12,
      maxMinutes: 18,
      expectedDeliveryTime: new Date("2026-03-10T12:00:00.000Z"),
      initialETASeconds: 900,
      deliveryWindowText: "12-18 min",
    });

    const result = await helpers.finalizeAcceptedOrderAssignment({
      orderId: "order-1",
      riderId: "rider-1",
      currentStatus: "ready",
      retryLabel: "mark retry resolved after reservation accept",
    });

    expect(prisma.order.update).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({
        where: { id: "order-1" },
        data: expect.objectContaining({
          riderId: "rider-1",
          status: "picked_up",
          riderEarnings: 12,
        }),
      })
    );
    expect(prisma.chat.create).toHaveBeenCalledWith({
      data: {
        orderId: "order-1",
        customerId: "cust-1",
        riderId: "rider-1",
      },
    });
    expect(OrderTracking.findOneAndDelete).toHaveBeenCalledWith({
      entityType: "order",
      orderId: "order-1",
    });
    expect(trackingService.initializeTracking).toHaveBeenCalledWith(
      "order-1",
      "rider-1",
      "cust-1",
      { latitude: 5.6, longitude: -0.1 },
      { latitude: 5.7, longitude: -0.12 }
    );
    expect(trackingService.calculateInitialDeliveryWindow).toHaveBeenCalled();
    expect(RiderStatus.findOneAndUpdate).toHaveBeenCalledWith(
      { riderId: "rider-1" },
      { $set: { isOnDelivery: true, currentOrderId: "order-1" } }
    );
    expect(notifyCustomerRiderAssignment).toHaveBeenCalledWith(
      updatedOrder,
      updatedOrder.rider,
      { io: true }
    );
    expect(safeDispatchRetrySideEffect).toHaveBeenCalled();
    expect(dispatchRetryService.markRetryResolved).toHaveBeenCalledWith(
      "order-1",
      "rider_accepted_order"
    );
    expect(result).toEqual({
      updatedOrder,
      deliveryWindow: expect.objectContaining({
        minMinutes: 12,
        maxMinutes: 18,
        deliveryWindowText: "12-18 min",
      }),
    });
  });

  it("continues cleanly when tracking and ETA cannot be initialized", async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: "order-2",
      orderNumber: "ORD-2",
      restaurantId: "rest-2",
      restaurant: { latitude: null, longitude: null },
    });
    calculateRiderEarnings.mockReturnValue({
      riderBaseFee: 6,
      riderDistanceFee: 2,
      riderTip: 0,
      platformFee: 1,
      riderEarnings: 8,
    });
    const updatedOrder = {
      id: "order-2",
      orderNumber: "ORD-2",
      customerId: "cust-2",
      riderId: "rider-2",
      status: "confirmed",
      restaurantId: "rest-2",
      restaurant: {
        latitude: null,
        longitude: null,
        averagePreparationTime: 15,
      },
      deliveryLatitude: null,
      deliveryLongitude: null,
      items: [{ id: "item-1" }],
      rider: { username: "Ama", phone: "233555000222" },
    };
    prisma.order.update.mockResolvedValue(updatedOrder);
    prisma.chat.findUnique.mockResolvedValue({ id: "chat-1" });
    RiderStatus.findOne.mockResolvedValue(null);

    const result = await helpers.finalizeAcceptedOrderAssignment({
      orderId: "order-2",
      riderId: "rider-2",
      currentStatus: "confirmed",
      retryLabel: "mark retry resolved after direct accept",
    });

    expect(prisma.chat.create).not.toHaveBeenCalled();
    expect(trackingService.initializeTracking).not.toHaveBeenCalled();
    expect(trackingService.calculateInitialDeliveryWindow).not.toHaveBeenCalled();
    expect(result.deliveryWindow).toBeNull();
    expect(notifyCustomerRiderAssignment).toHaveBeenCalledWith(
      updatedOrder,
      updatedOrder.rider,
      { io: true }
    );
    expect(dispatchRetryService.markRetryResolved).toHaveBeenCalledWith(
      "order-2",
      "rider_accepted_order"
    );
  });
});
