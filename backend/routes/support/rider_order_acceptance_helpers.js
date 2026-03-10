const { calculateRiderEarnings } = require("../../utils/riderEarningsCalculator");
const OrderTracking = require("../../models/OrderTracking");
const RiderStatus = require("../../models/RiderStatus");
const trackingService = require("../../services/tracking_service");

const RIDER_ACCEPT_ORDER_INCLUDE = {
  items: { select: { id: true, name: true, quantity: true, price: true } },
  customer: { select: { username: true, email: true, phone: true, profilePicture: true } },
  restaurant: {
    select: {
      restaurantName: true,
      logo: true,
      address: true,
      latitude: true,
      longitude: true,
      averagePreparationTime: true,
    },
  },
  groceryStore: {
    select: {
      storeName: true,
      logo: true,
      address: true,
      latitude: true,
      longitude: true,
    },
  },
  pharmacyStore: {
    select: {
      storeName: true,
      logo: true,
      address: true,
      latitude: true,
      longitude: true,
    },
  },
  grabMartStore: {
    select: {
      storeName: true,
      logo: true,
      address: true,
      latitude: true,
      longitude: true,
    },
  },
  rider: { select: { username: true, email: true, phone: true } },
};

const FULL_ORDER_EARNINGS_INCLUDE = {
  restaurant: { select: { restaurantName: true, latitude: true, longitude: true } },
  groceryStore: { select: { storeName: true, latitude: true, longitude: true } },
  pharmacyStore: { select: { storeName: true, latitude: true, longitude: true } },
  grabMartStore: { select: { storeName: true, latitude: true, longitude: true } },
};

const createRiderOrderAcceptanceHelpers = ({
  prisma,
  getPickupLocation,
  parseCoordinate,
  hasValidCoordinatePair,
  getVendorPrepTime,
  getVendorIdFromOrder,
  notifyCustomerRiderAssignment,
  safeDispatchRetrySideEffect,
  dispatchRetryService,
  getIO,
  logger,
}) => {
  const lockRiderEarningsAndAssignOrder = async ({ orderId, riderId, currentStatus }) => {
    const fullOrder = await prisma.order.findUnique({
      where: { id: orderId },
      include: FULL_ORDER_EARNINGS_INCLUDE,
    });

    const earnings = calculateRiderEarnings(fullOrder, 0);

    return prisma.order.update({
      where: { id: orderId },
      data: {
        riderId,
        status: currentStatus === "ready" ? "picked_up" : currentStatus,
        riderBaseFee: earnings.riderBaseFee,
        riderDistanceFee: earnings.riderDistanceFee,
        riderTip: earnings.riderTip,
        platformFee: earnings.platformFee,
        riderEarnings: earnings.riderEarnings,
      },
      include: RIDER_ACCEPT_ORDER_INCLUDE,
    });
  };

  const ensureChatForAcceptedOrder = async (updatedOrder) => {
    try {
      const existingChat = await prisma.chat.findUnique({
        where: { orderId: updatedOrder.id },
      });

      if (!existingChat) {
        await prisma.chat.create({
          data: {
            orderId: updatedOrder.id,
            customerId: updatedOrder.customerId,
            riderId: updatedOrder.riderId,
          },
        });
      }
    } catch (error) {
      logger.error({
        event: "ensure_chat_for_accepted_order_failed",
        orderId: updatedOrder?.id,
        error: error?.message || String(error),
      });
    }
  };

  const initializeTrackingForAcceptedOrder = async (updatedOrder) => {
    try {
      await OrderTracking.findOneAndDelete(
        OrderTracking.buildEntityQuery("order", { orderId: updatedOrder.id })
      );

      const pickupLocation = getPickupLocation(updatedOrder);
      const pickupLat = parseCoordinate(pickupLocation.latitude);
      const pickupLon = parseCoordinate(pickupLocation.longitude);
      const deliveryLat = parseCoordinate(updatedOrder.deliveryLatitude);
      const deliveryLon = parseCoordinate(updatedOrder.deliveryLongitude);

      if (!hasValidCoordinatePair(pickupLat, pickupLon) || !hasValidCoordinatePair(deliveryLat, deliveryLon)) {
        throw new Error("Invalid pickup/destination coordinates for tracking initialization");
      }

      await trackingService.initializeTracking(
        updatedOrder.id,
        updatedOrder.riderId,
        updatedOrder.customerId,
        { latitude: pickupLat, longitude: pickupLon },
        { latitude: deliveryLat, longitude: deliveryLon }
      );

      logger.info({
        event: "tracking_initialized_for_accepted_order",
        orderId: updatedOrder.id,
      });
    } catch (error) {
      logger.error({
        event: "initialize_tracking_for_accepted_order_failed",
        orderId: updatedOrder?.id,
        error: error?.message || String(error),
      });
    }
  };

  const calculateDeliveryWindowForAcceptedOrder = async ({ updatedOrder, riderId }) => {
    try {
      const riderStatus = await RiderStatus.findOne({ riderId });

      if (!riderStatus?.location?.coordinates) {
        return null;
      }

      const pickupLocation = getPickupLocation(updatedOrder);
      const pickupLat = parseCoordinate(pickupLocation.latitude);
      const pickupLon = parseCoordinate(pickupLocation.longitude);
      const deliveryLat = parseCoordinate(updatedOrder.deliveryLatitude);
      const deliveryLon = parseCoordinate(updatedOrder.deliveryLongitude);
      const vendorPrepTime = getVendorPrepTime(updatedOrder);

      if (!hasValidCoordinatePair(pickupLat, pickupLon) || !hasValidCoordinatePair(deliveryLat, deliveryLon)) {
        return null;
      }

      const deliveryWindow = await trackingService.calculateInitialDeliveryWindow(
        { latitude: riderStatus.location.coordinates[1], longitude: riderStatus.location.coordinates[0] },
        { latitude: pickupLat, longitude: pickupLon },
        { latitude: deliveryLat, longitude: deliveryLon },
        updatedOrder.status,
        vendorPrepTime,
        riderId,
        getVendorIdFromOrder(updatedOrder),
        updatedOrder.items.length,
        updatedOrder.id
      );

      await prisma.order.update({
        where: { id: updatedOrder.id },
        data: {
          deliveryWindowMin: deliveryWindow.minMinutes,
          deliveryWindowMax: deliveryWindow.maxMinutes,
          expectedDelivery: deliveryWindow.expectedDeliveryTime,
          initialETASeconds: deliveryWindow.initialETASeconds,
          riderAssignedAt: new Date(),
        },
      });

      logger.info({
        event: "delivery_window_set_for_accepted_order",
        orderId: updatedOrder.id,
        displayText: deliveryWindow.deliveryWindowText,
      });

      return deliveryWindow;
    } catch (error) {
      logger.error({
        event: "calculate_delivery_window_for_accepted_order_failed",
        orderId: updatedOrder?.id,
        error: error?.message || String(error),
      });
      return null;
    }
  };

  const markRiderOnDelivery = async ({ riderId, orderId }) => {
    try {
      await RiderStatus.findOneAndUpdate(
        { riderId },
        { $set: { isOnDelivery: true, currentOrderId: orderId } }
      );

      logger.info({
        event: "rider_marked_on_delivery",
        riderId,
        orderId,
      });
    } catch (error) {
      logger.error({
        event: "mark_rider_on_delivery_failed",
        riderId,
        orderId,
        error: error?.message || String(error),
      });
    }
  };

  const finalizeAcceptedOrderAssignment = async ({
    orderId,
    riderId,
    currentStatus,
    retryLabel,
  }) => {
    const updatedOrder = await lockRiderEarningsAndAssignOrder({
      orderId,
      riderId,
      currentStatus,
    });

    await ensureChatForAcceptedOrder(updatedOrder);
    await initializeTrackingForAcceptedOrder(updatedOrder);
    const deliveryWindow = await calculateDeliveryWindowForAcceptedOrder({
      updatedOrder,
      riderId,
    });
    await markRiderOnDelivery({ riderId, orderId: updatedOrder.id });
    await notifyCustomerRiderAssignment(updatedOrder, updatedOrder.rider, getIO());
    await safeDispatchRetrySideEffect(
      `${retryLabel} (${updatedOrder.id})`,
      () => dispatchRetryService.markRetryResolved(updatedOrder.id, "rider_accepted_order")
    );

    return { updatedOrder, deliveryWindow };
  };

  return {
    finalizeAcceptedOrderAssignment,
  };
};

module.exports = {
  createRiderOrderAcceptanceHelpers,
};
