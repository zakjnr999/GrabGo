const crypto = require("crypto");

const createOrdersRouteHelpers = ({
  prisma,
  invalidateCache,
  cache,
  featureFlags,
  dispatchRetryService,
  isCodDispatchAllowedStatus,
  getCodExternalPaymentAmount,
  getCodRemainingCashAmount,
  normalizeGhanaPhone,
  sendOrderNotification,
  sendToUser,
  createNotification,
  getIO,
  logger,
}) => {
  const invalidateFoodOrderHistoryCaches = async () => {
    await invalidateCache([
      `${cache.CACHE_KEYS.FOOD_ITEM}:history`,
      `${cache.CACHE_KEYS.FOOD_ITEM}:recent`,
    ]);
  };

  const normalizeFulfillmentMode = (mode) => {
    if (!mode) return "delivery";
    return String(mode).trim().toLowerCase() === "pickup" ? "pickup" : "delivery";
  };

  const normalizePromoCode = (value) => {
    if (!value) return null;
    const normalized = String(value).trim().toUpperCase();
    return normalized.length > 0 ? normalized : null;
  };

  const decrementPromoUsageIfNeeded = async ({ tx = prisma, promoCode }) => {
    const normalizedCode = normalizePromoCode(promoCode);
    if (!normalizedCode) return;

    await tx.promoCode
      .updateMany({
        where: {
          code: normalizedCode,
          currentUses: { gt: 0 },
        },
        data: {
          currentUses: { decrement: 1 },
        },
      })
      .catch(() => null);
  };

  const reservePromoUsage = async (tx, promoCode) => {
    const normalizedCode = normalizePromoCode(promoCode);
    if (!normalizedCode) {
      return { success: true };
    }

    const promo = await tx.promoCode.findUnique({
      where: { code: normalizedCode },
      select: {
        id: true,
        isActive: true,
        maxUses: true,
      },
    });

    if (!promo || !promo.isActive) {
      return {
        success: false,
        message: "This promo code is no longer active",
      };
    }

    const promoUsageWhere =
      promo.maxUses === null
        ? { id: promo.id, isActive: true }
        : { id: promo.id, isActive: true, currentUses: { lt: promo.maxUses } };

    const updated = await tx.promoCode
      .updateMany({
        where: promoUsageWhere,
        data: {
          currentUses: { increment: 1 },
        },
      })
      .catch(() => ({ count: 0 }));

    if (!updated || Number(updated.count || 0) === 0) {
      return {
        success: false,
        message: "This promo code has reached its usage limit",
      };
    }

    return { success: true };
  };

  const PICKUP_OTP_SECRET = process.env.PICKUP_OTP_SECRET || process.env.JWT_SECRET || "grabgo-pickup-otp-secret";
  const PICKUP_OTP_MAX_ATTEMPTS = Number(process.env.PICKUP_OTP_MAX_ATTEMPTS || 5);
  const PICKUP_OTP_LOCK_SECONDS = Number(process.env.PICKUP_OTP_LOCK_SECONDS || 300);
  const PICKUP_ACCEPT_TIMEOUT_MINUTES = Number(process.env.PICKUP_ACCEPT_TIMEOUT_MINUTES || 10);
  const PICKUP_READY_EXPIRY_MINUTES = Number(process.env.PICKUP_READY_EXPIRY_MINUTES || 30);
  const DELIVERY_ACTIVE_STATUSES = new Set(["picked_up", "on_the_way"]);
  const STATUS_UPDATE_ROLE_RULES = {
    customer: new Set(["cancelled"]),
    restaurant: new Set(["confirmed", "preparing", "ready", "cancelled"]),
    rider: new Set(["picked_up", "on_the_way", "delivered", "cancelled"]),
    admin: null,
  };
  const ALLOWED_ORDER_STATUS_TRANSITIONS = {
    pending: new Set(["confirmed", "preparing", "cancelled"]),
    confirmed: new Set(["preparing", "ready", "picked_up", "cancelled"]),
    preparing: new Set(["ready", "picked_up", "cancelled"]),
    ready: new Set(["picked_up", "cancelled"]),
    picked_up: new Set(["on_the_way", "delivered", "cancelled"]),
    on_the_way: new Set(["delivered", "cancelled"]),
    delivered: new Set(),
    cancelled: new Set(),
  };
  const canTransitionOrderStatus = (currentStatus, nextStatus, actorRole) => {
    if (currentStatus === nextStatus) return true;
    if (actorRole === "admin") return true;
    const allowed = ALLOWED_ORDER_STATUS_TRANSITIONS[currentStatus];
    return Boolean(allowed && allowed.has(nextStatus));
  };
  const DISPATCH_TRIGGER_STATUSES = new Set(["preparing", "ready"]);
  const shouldTriggerDispatchForStatus = (status) =>
    DISPATCH_TRIGGER_STATUSES.has(status) ||
    (featureFlags.isConfirmedPredispatchEnabled && status === "confirmed");
  const ORDER_TO_TRACKING_STATUS_MAP = {
    preparing: "preparing",
    picked_up: "picked_up",
    on_the_way: "in_transit",
    delivered: "delivered",
    cancelled: "cancelled",
  };
  const shouldTriggerDispatchForOrder = (order, status = order?.status) => {
    if (!order) return false;
    if (order.paymentMethod === "cash") {
      return isCodDispatchAllowedStatus(status);
    }
    return shouldTriggerDispatchForStatus(status);
  };
  const queueDispatchRetryIfNeeded = async ({
    orderId,
    orderNumber,
    result,
    source,
    delaySeconds = null,
    metadata = {},
  }) => {
    if (!orderId || !result || result.success) {
      return;
    }

    if (!dispatchRetryService.isRecoverableDispatchFailure(result)) {
      return;
    }

    if (result.error === "Max dispatch attempts reached") {
      await dispatchRetryService.resetDispatchAttemptHistory(orderId);
    }

    const queueResult = await dispatchRetryService.enqueueDispatchRetry({
      orderId,
      orderNumber,
      result,
      source,
      delaySeconds,
      metadata,
    });

    logger.info({
      event: "dispatch_retry_queued",
      orderId,
      orderNumber,
      source,
      delaySeconds: queueResult?.delaySeconds ?? null,
    });
  };
  const safeDispatchRetrySideEffect = async (label, operation) => {
    try {
      return await operation();
    } catch (error) {
      logger.error({ event: "dispatch_retry_side_effect_failed", label, error: error?.message || String(error) });
      return null;
    }
  };
  const SENSITIVE_ORDER_FIELDS = new Set(["pickupOtpHash", "deliveryCodeHash", "deliveryCodeEncrypted"]);

  const generatePickupCode = () => String(Math.floor(100000 + Math.random() * 900000));

  const hashPickupCode = (orderId, code) =>
    crypto.createHmac("sha256", PICKUP_OTP_SECRET).update(`${orderId}:${code}`).digest("hex");

  const isPickupOtpLocked = (order) => {
    if (!order?.pickupOtpLastAttemptAt || !order?.pickupOtpFailedAttempts) return false;
    if (order.pickupOtpFailedAttempts < PICKUP_OTP_MAX_ATTEMPTS) return false;

    const lockUntil = new Date(order.pickupOtpLastAttemptAt).getTime() + PICKUP_OTP_LOCK_SECONDS * 1000;
    return Date.now() < lockUntil;
  };

  const sanitizeOrderPayload = (payload) => {
    if (Array.isArray(payload)) {
      return payload.map((entry) => sanitizeOrderPayload(entry));
    }
    if (!payload || typeof payload !== "object") {
      return payload;
    }

    const sanitized = { ...payload };
    for (const field of SENSITIVE_ORDER_FIELDS) {
      delete sanitized[field];
    }
    if (sanitized.paymentMethod === "cash") {
      sanitized.cod = {
        upfrontAmount: getCodExternalPaymentAmount(sanitized, {
          includeRainFee: featureFlags.codUpfrontIncludeRainFee,
        }),
        remainingCashOnDelivery: getCodRemainingCashAmount(sanitized, {
          includeRainFee: featureFlags.codUpfrontIncludeRainFee,
        }),
        includeRainFeeInUpfront: featureFlags.codUpfrontIncludeRainFee,
      };
    }
    return sanitized;
  };

  const computeGroupMetaForOrders = async (orders) => {
    const safeOrders = Array.isArray(orders) ? orders : [];
    const groupIds = [...new Set(safeOrders.map((order) => order?.groupId).filter(Boolean))];
    if (groupIds.length === 0) return safeOrders;

    const groupOrders = await prisma.order.findMany({
      where: { groupId: { in: groupIds } },
      select: {
        groupId: true,
        totalAmount: true,
        paymentStatus: true,
        status: true,
      },
    });

    const grouped = new Map();
    for (const entry of groupOrders) {
      if (!entry?.groupId) continue;
      const bucket = grouped.get(entry.groupId) || [];
      bucket.push(entry);
      grouped.set(entry.groupId, bucket);
    }

    return safeOrders.map((order) => {
      if (!order?.groupId) return order;
      const children = grouped.get(order.groupId) || [];
      if (children.length === 0) return order;

      const groupTotal = children.reduce((sum, child) => sum + Number(child.totalAmount || 0), 0);
      const vendorCount = children.length;
      const paymentStatuses = new Set(children.map((child) => child.paymentStatus).filter(Boolean));
      const statuses = new Set(children.map((child) => child.status).filter(Boolean));

      let groupPaymentStatus = "pending";
      if (paymentStatuses.size === 1) {
        groupPaymentStatus = [...paymentStatuses][0];
      } else if (paymentStatuses.has("failed")) {
        groupPaymentStatus = "failed";
      } else if (paymentStatuses.has("processing")) {
        groupPaymentStatus = "processing";
      } else if (paymentStatuses.has("paid") || paymentStatuses.has("successful")) {
        groupPaymentStatus = "processing";
      }

      return {
        ...order,
        groupMeta: {
          vendorCount,
          groupTotal: Math.round((groupTotal + Number.EPSILON) * 100) / 100,
          groupPaymentStatus,
          childStatuses: [...statuses],
        },
      };
    });
  };

  const getVendorContextForUser = async (user) => {
    if (!user?.email) return null;
    const [restaurant, groceryStore, pharmacyStore, grabMartStore] = await Promise.all([
      prisma.restaurant.findFirst({ where: { email: user.email }, select: { id: true } }),
      prisma.groceryStore.findFirst({ where: { email: user.email }, select: { id: true } }),
      prisma.pharmacyStore.findFirst({ where: { email: user.email }, select: { id: true } }),
      prisma.grabMartStore.findFirst({ where: { email: user.email }, select: { id: true } }),
    ]);

    return {
      restaurantId: restaurant?.id || null,
      groceryStoreId: groceryStore?.id || null,
      pharmacyStoreId: pharmacyStore?.id || null,
      grabMartStoreId: grabMartStore?.id || null,
    };
  };

  const isOrderOwnedByVendorContext = (order, vendorContext) =>
    Boolean(
      (vendorContext?.restaurantId && order?.restaurantId === vendorContext.restaurantId) ||
        (vendorContext?.groceryStoreId && order?.groceryStoreId === vendorContext.groceryStoreId) ||
        (vendorContext?.pharmacyStoreId && order?.pharmacyStoreId === vendorContext.pharmacyStoreId) ||
        (vendorContext?.grabMartStoreId && order?.grabMartStoreId === vendorContext.grabMartStoreId)
    );

  const normalizeGiftRecipientPhone = (phoneNumber) => {
    if (!phoneNumber) return null;
    const normalized = normalizeGhanaPhone(phoneNumber);
    return normalized ? normalized.e164 : null;
  };

  const notifyOrderStatusChange = async (order, status, customMessage = null, io = null) => {
    try {
      if (!order.customerId && !order.customer) return;

      const customerId = order.customerId || order.customer.id;
      const orderNumber = order.orderNumber;
      const orderId = order.id;

      await sendOrderNotification(customerId, orderId, orderNumber, status, customMessage);

      const statusMessages = {
        confirmed: "Your order has been confirmed!",
        preparing: "Your order is being prepared.",
        ready: "Your order is ready for pickup!",
        picked_up: "Your order has been picked up.",
        on_the_way: "Your order is on the way!",
        delivered: "Your order has been delivered. Enjoy!",
        cancelled: "Your order has been cancelled.",
      };

      const statusEmojis = {
        confirmed: "✅",
        preparing: "🍳",
        ready: "📦",
        picked_up: "🚴",
        on_the_way: "🛣️",
        delivered: "✅",
        cancelled: "❌",
      };

      const emoji = statusEmojis[status] || "📦";
      const message = customMessage || statusMessages[status] || `Order status: ${status}`;

      const ioInstance = io || getIO();
      if (ioInstance) {
        await createNotification(
          customerId,
          "order",
          `${emoji} Order #${orderNumber}`,
          message,
          {
            orderId,
            orderNumber,
            status,
            route: `/orders/${orderId}`,
          },
          ioInstance,
          { sendPush: false }
        );
      }
    } catch (error) {
      logger.error({ event: "order_status_notification_failed", error: error?.message || String(error), orderId: order?.id, status });
    }
  };

  const notifyRiderAssignment = async (riderId, order) => {
    try {
      await sendToUser(
        riderId,
        {
          title: "🚴 New Delivery Assignment",
          body: `Order #${order.orderNumber} has been assigned to you. Tap to view details.`,
        },
        {
          type: "rider_assignment",
          orderId: order.id,
          orderNumber: order.orderNumber,
        }
      );
    } catch (error) {
      logger.error({ event: "rider_assignment_notification_failed", error: error?.message || String(error), riderId, orderId: order?.id });
    }
  };

  const generateOrderNumber = async () => {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 10000);
    let orderNumber = `ORD-${timestamp}-${random}`;

    let exists = await prisma.order.findUnique({ where: { orderNumber } });
    let attempts = 0;
    while (exists && attempts < 5) {
      const newRandom = Math.floor(Math.random() * 10000);
      orderNumber = `ORD-${timestamp}-${newRandom}`;
      exists = await prisma.order.findUnique({ where: { orderNumber } });
      attempts++;
    }
    return orderNumber;
  };

  return {
    invalidateFoodOrderHistoryCaches,
    normalizeFulfillmentMode,
    normalizePromoCode,
    decrementPromoUsageIfNeeded,
    reservePromoUsage,
    PICKUP_OTP_SECRET,
    PICKUP_OTP_MAX_ATTEMPTS,
    PICKUP_OTP_LOCK_SECONDS,
    PICKUP_ACCEPT_TIMEOUT_MINUTES,
    PICKUP_READY_EXPIRY_MINUTES,
    DELIVERY_ACTIVE_STATUSES,
    STATUS_UPDATE_ROLE_RULES,
    ALLOWED_ORDER_STATUS_TRANSITIONS,
    canTransitionOrderStatus,
    DISPATCH_TRIGGER_STATUSES,
    shouldTriggerDispatchForStatus,
    ORDER_TO_TRACKING_STATUS_MAP,
    shouldTriggerDispatchForOrder,
    queueDispatchRetryIfNeeded,
    safeDispatchRetrySideEffect,
    SENSITIVE_ORDER_FIELDS,
    generatePickupCode,
    hashPickupCode,
    isPickupOtpLocked,
    sanitizeOrderPayload,
    computeGroupMetaForOrders,
    getVendorContextForUser,
    isOrderOwnedByVendorContext,
    normalizeGiftRecipientPhone,
    notifyOrderStatusChange,
    notifyRiderAssignment,
    generateOrderNumber,
  };
};

module.exports = {
  createOrdersRouteHelpers,
};
