jest.mock("../utils/riderEarningsCalculator", () => ({
  calculateRiderEarnings: jest.fn(),
  calculateDistance: jest.fn(),
}));

const {
  calculateRiderEarnings,
  calculateDistance,
} = require("../utils/riderEarningsCalculator");
const {
  createRiderAvailableOrdersHelpers,
} = require("../routes/support/rider_available_orders_helpers");

describe("rider_available_orders_helpers", () => {
  let logger;
  let helpers;

  beforeEach(() => {
    jest.clearAllMocks();
    logger = {
      info: jest.fn(),
    };
    helpers = createRiderAvailableOrdersHelpers({
      featureFlags: { riderAvailableMaxRadiusKm: 20 },
      getPickupLocation: (order) => order.pickupLocation,
      logger,
    });
  });

  it("attaches rider earnings data to available orders", () => {
    calculateRiderEarnings.mockReturnValue({
      distance: 4.25,
      riderEarnings: 18.5,
      riderBaseFee: 8,
      riderDistanceFee: 7.5,
      riderTip: 3,
      platformFee: 2,
    });

    const result = helpers.attachAvailableOrderEarnings([{ id: "order-1" }]);

    expect(result).toEqual([
      expect.objectContaining({
        id: "order-1",
        distance: 4.25,
        riderEarnings: 18.5,
        earningsBreakdown: {
          baseFee: 8,
          distanceFee: 7.5,
          tip: 3,
          platformFee: 2,
          total: 18.5,
        },
      }),
    ]);
    expect(calculateRiderEarnings).toHaveBeenCalledWith({ id: "order-1" }, 0);
  });

  it("filters by rider distance and expands radius when needed", () => {
    calculateDistance
      .mockReturnValueOnce(12)
      .mockReturnValueOnce(14)
      .mockReturnValueOnce(6)
      .mockReturnValueOnce(9);

    const { filteredOrders, filterApplied, expandedRadius, radius } =
      helpers.filterAvailableOrdersForRiderLocation(
        [
          { id: "order-1", pickupLocation: { latitude: 5.6, longitude: -0.1 } },
          { id: "order-2", pickupLocation: { latitude: 5.61, longitude: -0.11 } },
        ],
        { lat: "5.58", lon: "-0.21", radius: "5" }
      );

    expect(filterApplied).toBe(true);
    expect(expandedRadius).toBe(true);
    expect(radius).toBe(20);
    expect(filteredOrders.map((order) => order.id)).toEqual(["order-1", "order-2"]);
    expect(filteredOrders[0].distanceToPickup).toBe(12);
    expect(filteredOrders[1].distanceToPickup).toBe(14);
    expect(logger.info).toHaveBeenCalledWith(
      expect.objectContaining({
        event: "rider_available_orders_filtered",
        count: 2,
        radiusKm: 20,
      })
    );
  });

  it("keeps orders untouched when rider coordinates are missing", () => {
    const orders = [{ id: "order-1", riderEarnings: 12, distance: 3 }];

    const result = helpers.filterAvailableOrdersForRiderLocation(orders, {});

    expect(result.filteredOrders).toEqual(orders);
    expect(result.filterApplied).toBe(false);
    expect(result.expandedRadius).toBe(false);
    expect(result.radius).toBe(10);
    expect(calculateDistance).not.toHaveBeenCalled();
  });

  it("builds aggregate available order statistics", () => {
    const statistics = helpers.buildAvailableOrderStatistics({
      filteredOrders: [
        { riderEarnings: 10, earningsBreakdown: { tip: 2 }, distance: 3 },
        { riderEarnings: 20, earningsBreakdown: { tip: 1 }, distance: 5 },
      ],
      filterApplied: true,
      expandedRadius: false,
      radius: 8,
    });

    expect(statistics).toEqual({
      totalOrders: 2,
      totalDropPoints: 2,
      totalEarnings: 30,
      totalTips: 3,
      totalDistance: 8,
      averageEarningsPerOrder: 15,
      averageDistance: 4,
      filterApplied: true,
      radius: 8,
      expandedRadius: false,
    });
  });
});
