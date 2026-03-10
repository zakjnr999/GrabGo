const createRidersRouteHelpers = ({
  prisma,
  OrderReservation,
  sendOrderNotification,
  createNotification,
  getIO,
  logger,
}) => {
  const sendRiderError = (res, error, fallbackMessage = "Server error", fallbackStatus = 500) => {
    const explicitStatus = Number(error?.status);
    const status =
      Number.isInteger(explicitStatus) && explicitStatus >= 400 && explicitStatus < 600
        ? explicitStatus
        : fallbackStatus;

    return res.status(status).json({
      success: false,
      message: status >= 500 ? fallbackMessage : String(error?.message || fallbackMessage),
    });
  };

  const ORDER_RESERVATION_ENTITY = "order";
  const buildOrderReservationQuery = (query = {}) =>
    OrderReservation.buildEntityQuery(ORDER_RESERVATION_ENTITY, query);

  const updateWalletBalance = async (userId) => {
    const wallet = await prisma.riderWallet.findUnique({
      where: { userId },
    });

    if (!wallet) return null;

    const transactions = await prisma.transaction.findMany({
      where: {
        walletId: wallet.id,
        status: "completed",
      },
    });

    const totals = transactions.reduce(
      (acc, tx) => {
        if (["delivery", "tip", "bonus", "incentive"].includes(tx.type)) {
          acc.earnings += tx.amount;
        } else if (tx.type === "withdrawal") {
          acc.withdrawals += tx.amount;
        } else if (tx.type === "penalty") {
          acc.deductions += Math.abs(tx.amount);
        }
        return acc;
      },
      { earnings: 0, withdrawals: 0, deductions: 0 }
    );

    const pendingWithdrawalsSum = await prisma.transaction.aggregate({
      where: {
        walletId: wallet.id,
        type: "withdrawal",
        status: "pending",
      },
      _sum: { amount: true },
    });

    return prisma.riderWallet.update({
      where: { id: wallet.id },
      data: {
        totalEarnings: totals.earnings,
        totalWithdrawals: totals.withdrawals,
        pendingWithdrawals: pendingWithdrawalsSum._sum.amount || 0,
        balance: totals.earnings - totals.withdrawals - totals.deductions,
        updatedAt: new Date(),
      },
    });
  };

  const firstDefined = (...values) =>
    values.find((value) => value !== null && value !== undefined);

  const parseCoordinate = (value) => {
    if (value === null || value === undefined || value === "") return null;
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  };

  const isValidLatitude = (value) => Number.isFinite(value) && value >= -90 && value <= 90;
  const isValidLongitude = (value) => Number.isFinite(value) && value >= -180 && value <= 180;
  const hasValidCoordinatePair = (latitude, longitude) =>
    isValidLatitude(latitude) && isValidLongitude(longitude);

  const safeDispatchRetrySideEffect = async (label, operation) => {
    try {
      return await operation();
    } catch (error) {
      logger.error({ event: "dispatch_retry_side_effect_failed", label, error: error?.message || String(error) });
      return null;
    }
  };

  const getPickupLocation = (order) => ({
    latitude: firstDefined(
      order?.restaurant?.latitude,
      order?.groceryStore?.latitude,
      order?.pharmacyStore?.latitude,
      order?.grabMartStore?.latitude
    ),
    longitude: firstDefined(
      order?.restaurant?.longitude,
      order?.groceryStore?.longitude,
      order?.pharmacyStore?.longitude,
      order?.grabMartStore?.longitude
    ),
  });

  const getVendorIdFromOrder = (order) =>
    firstDefined(order?.restaurantId, order?.groceryStoreId, order?.pharmacyStoreId, order?.grabMartStoreId);

  const getVendorPrepTime = (order) =>
    firstDefined(
      order?.restaurant?.averagePreparationTime,
      order?.groceryStore?.averagePreparationTime,
      order?.pharmacyStore?.averagePreparationTime
    ) || 15;

  const ACTIVE_DELIVERY_STATUSES = ["confirmed", "preparing", "ready", "picked_up", "on_the_way"];

  const findActiveDeliveryOrderForRider = (riderId) =>
    prisma.order.findFirst({
      where: {
        riderId,
        fulfillmentMode: "delivery",
        status: { in: ACTIVE_DELIVERY_STATUSES },
      },
      orderBy: { updatedAt: "desc" },
      select: { id: true, status: true },
    });

  const notifyCustomerRiderAssignment = async (order, rider = null, io = null) => {
    try {
      if (!order?.customerId || !order?.id || !order?.orderNumber) return;

      const riderName = rider?.username || order?.rider?.username || "A rider";
      const statusToNotify = order.status === "picked_up" ? "picked_up" : order.status || "confirmed";
      const message =
        statusToNotify === "picked_up"
          ? `${riderName} is picking up your order!`
          : `${riderName} has been assigned to your order.`;
      const titleEmoji = statusToNotify === "picked_up" ? "🚴" : "✅";

      await sendOrderNotification(order.customerId, order.id, order.orderNumber, statusToNotify, message);

      const ioInstance = io || getIO();
      if (ioInstance) {
        await createNotification(
          order.customerId,
          "order",
          `${titleEmoji} Order #${order.orderNumber}`,
          message,
          {
            orderId: order.id,
            orderNumber: order.orderNumber,
            status: statusToNotify,
            riderId: order.riderId,
            route: `/orders/${order.id}`,
          },
          ioInstance,
          { sendPush: false }
        );
      }
    } catch (error) {
      logger.error({ event: "customer_rider_assignment_notification_failed", error: error?.message || String(error) });
    }
  };

  const reconcileRiderDispatchState = async (riderId, riderProfile) => {
    const isApproved = riderProfile?.verificationStatus === "approved";
    const activeOrder = await findActiveDeliveryOrderForRider(riderId);

    return {
      isApproved,
      isOnDelivery: Boolean(activeOrder),
      currentOrderId: activeOrder?.id ?? null,
      vehicleType: riderProfile?.vehicleType || null,
    };
  };

  const SENSITIVE_ORDER_FIELDS = new Set(["pickupOtpHash", "deliveryCodeHash", "deliveryCodeEncrypted"]);
  const sanitizeOrderForRider = (payload) => {
    if (Array.isArray(payload)) return payload.map((entry) => sanitizeOrderForRider(entry));
    if (!payload || typeof payload !== "object") return payload;

    const sanitized = { ...payload };
    for (const field of SENSITIVE_ORDER_FIELDS) {
      delete sanitized[field];
    }
    return sanitized;
  };

  return {
    sendRiderError,
    ORDER_RESERVATION_ENTITY,
    buildOrderReservationQuery,
    updateWalletBalance,
    firstDefined,
    parseCoordinate,
    isValidLatitude,
    isValidLongitude,
    hasValidCoordinatePair,
    safeDispatchRetrySideEffect,
    getPickupLocation,
    getVendorIdFromOrder,
    getVendorPrepTime,
    ACTIVE_DELIVERY_STATUSES,
    findActiveDeliveryOrderForRider,
    notifyCustomerRiderAssignment,
    reconcileRiderDispatchState,
    SENSITIVE_ORDER_FIELDS,
    sanitizeOrderForRider,
  };
};

module.exports = {
  createRidersRouteHelpers,
};
