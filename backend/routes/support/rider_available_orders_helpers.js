const { calculateRiderEarnings, calculateDistance } = require("../../utils/riderEarningsCalculator");

const createRiderAvailableOrdersHelpers = ({ featureFlags, getPickupLocation, logger }) => {
  const attachAvailableOrderEarnings = (availableOrders) =>
    availableOrders.map((order) => {
      const earnings = calculateRiderEarnings(order, 0);

      return {
        ...order,
        distance: earnings.distance,
        riderEarnings: earnings.riderEarnings,
        earningsBreakdown: {
          baseFee: earnings.riderBaseFee,
          distanceFee: earnings.riderDistanceFee,
          tip: earnings.riderTip,
          platformFee: earnings.platformFee,
          total: earnings.riderEarnings,
        },
      };
    });

  const filterAvailableOrdersForRiderLocation = (ordersWithEarnings, query = {}) => {
    const riderLat = parseFloat(query.lat);
    const riderLon = parseFloat(query.lon);
    const maxRadiusKm = featureFlags.riderAvailableMaxRadiusKm || 20;
    let radius = parseFloat(query.radius);
    if (!Number.isFinite(radius) || radius <= 0) {
      radius = 10;
    }
    radius = Math.min(radius, maxRadiusKm);

    let filteredOrders = ordersWithEarnings;
    let filterApplied = false;
    let expandedRadius = false;

    if (!Number.isNaN(riderLat) && !Number.isNaN(riderLon)) {
      filterApplied = true;

      const ordersWithRiderDistance = ordersWithEarnings.map((order) => {
        const pickupLocation = getPickupLocation(order);
        const distanceToPickup = calculateDistance(
          riderLat,
          riderLon,
          pickupLocation.latitude,
          pickupLocation.longitude
        );

        return {
          ...order,
          distanceToPickup,
        };
      });

      filteredOrders = ordersWithRiderDistance.filter((order) => order.distanceToPickup <= radius);

      while (filteredOrders.length < 5 && radius < maxRadiusKm) {
        const nextRadius = Math.min(radius + 5, maxRadiusKm);
        if (nextRadius <= radius) break;
        radius = nextRadius;
        filteredOrders = ordersWithRiderDistance.filter((order) => order.distanceToPickup <= radius);
        expandedRadius = true;
      }

      filteredOrders.sort((a, b) => a.distanceToPickup - b.distanceToPickup);

      logger.info({
        event: "rider_available_orders_filtered",
        count: filteredOrders.length,
        radiusKm: radius,
      });
    }

    return {
      filteredOrders,
      filterApplied,
      expandedRadius,
      radius,
    };
  };

  const buildAvailableOrderStatistics = ({
    filteredOrders,
    filterApplied,
    expandedRadius,
    radius,
  }) => ({
    totalOrders: filteredOrders.length,
    totalDropPoints: filteredOrders.length,
    totalEarnings: parseFloat(
      filteredOrders.reduce((sum, order) => sum + (order.riderEarnings || 0), 0).toFixed(2)
    ),
    totalTips: parseFloat(
      filteredOrders.reduce((sum, order) => sum + (order.earningsBreakdown?.tip || 0), 0).toFixed(2)
    ),
    totalDistance: parseFloat(
      filteredOrders.reduce((sum, order) => sum + (order.distance || 0), 0).toFixed(2)
    ),
    averageEarningsPerOrder:
      filteredOrders.length > 0
        ? parseFloat(
            (
              filteredOrders.reduce((sum, order) => sum + (order.riderEarnings || 0), 0) /
              filteredOrders.length
            ).toFixed(2)
          )
        : 0,
    averageDistance:
      filteredOrders.length > 0
        ? parseFloat(
            (
              filteredOrders.reduce((sum, order) => sum + (order.distance || 0), 0) /
              filteredOrders.length
            ).toFixed(2)
          )
        : 0,
    filterApplied,
    radius,
    expandedRadius,
  });

  return {
    attachAvailableOrderEarnings,
    filterAvailableOrdersForRiderLocation,
    buildAvailableOrderStatistics,
  };
};

module.exports = {
  createRiderAvailableOrdersHelpers,
};
