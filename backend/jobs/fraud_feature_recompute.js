const prisma = require('../config/prisma');
const { setFeature } = require('../services/fraud/fraud_feature_store');

let intervalRef = null;
let isRunning = false;
let startupTimeoutRef = null;

const getDistinctActors = async () => {
  try {
    const rows = await prisma.fraudDecision.findMany({
      where: {
        createdAt: { gte: new Date(Date.now() - 24 * 60 * 60 * 1000) },
      },
      distinct: ['actorType', 'actorId'],
      select: {
        actorType: true,
        actorId: true,
      },
      take: 500,
    });
    return rows || [];
  } catch {
    return [];
  }
};

const recomputeCustomerFeatures = async (actorId) => {
  const now = Date.now();
  const oneHourAgo = new Date(now - 60 * 60 * 1000);
  const oneDayAgo = new Date(now - 24 * 60 * 60 * 1000);
  const tenMinAgo = new Date(now - 10 * 60 * 1000);
  const thirtyDaysAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);

  const [orders1h, orders24h, failedPayments10m, totalPayments30d, refundedPayments30d] = await Promise.all([
    prisma.order.count({ where: { customerId: actorId, createdAt: { gte: oneHourAgo } } }).catch(() => 0),
    prisma.order.count({ where: { customerId: actorId, createdAt: { gte: oneDayAgo } } }).catch(() => 0),
    prisma.payment.count({ where: { customerId: actorId, status: 'failed', createdAt: { gte: tenMinAgo } } }).catch(() => 0),
    prisma.payment.count({ where: { customerId: actorId, createdAt: { gte: thirtyDaysAgo } } }).catch(() => 0),
    prisma.payment.count({ where: { customerId: actorId, status: 'refunded', createdAt: { gte: thirtyDaysAgo } } }).catch(() => 0),
  ]);

  const uniqueDevices7d = await prisma.fraudGraphEdge.count({
    where: {
      fromActorType: 'customer',
      fromActorId: actorId,
      edgeType: 'actor_device',
      lastSeenAt: { gte: new Date(now - 7 * 24 * 60 * 60 * 1000) },
    },
  }).catch(() => 0);

  const promoAttempts1h = await prisma.fraudDecision.count({
    where: {
      actorType: 'customer',
      actorId,
      actionType: 'promo_apply',
      createdAt: { gte: oneHourAgo },
    },
  }).catch(() => 0);

  const refundRate30d = totalPayments30d > 0 ? refundedPayments30d / totalPayments30d : 0;

  await Promise.all([
    setFeature({ actorType: 'customer', actorId, featureName: 'orders_last_1h', value: { count: orders1h } }),
    setFeature({ actorType: 'customer', actorId, featureName: 'orders_last_24h', value: { count: orders24h } }),
    setFeature({ actorType: 'customer', actorId, featureName: 'failed_payments_last_10m', value: { count: failedPayments10m } }),
    setFeature({ actorType: 'customer', actorId, featureName: 'unique_devices_last_7d', value: { count: uniqueDevices7d } }),
    setFeature({ actorType: 'customer', actorId, featureName: 'promo_attempts_last_1h', value: { count: promoAttempts1h } }),
    setFeature({ actorType: 'customer', actorId, featureName: 'refund_rate_30d', value: { ratio: refundRate30d } }),
  ]);
};

const recomputeRiderFeatures = async (actorId) => {
  const now = Date.now();
  const sevenDaysAgo = new Date(now - 7 * 24 * 60 * 60 * 1000);
  const fourteenDaysAgo = new Date(now - 14 * 24 * 60 * 60 * 1000);
  const thirtyDaysAgo = new Date(now - 30 * 24 * 60 * 60 * 1000);

  const [totalAssigned7d, cancelled7d] = await Promise.all([
    prisma.order.count({ where: { riderId: actorId, createdAt: { gte: sevenDaysAgo } } }).catch(() => 0),
    prisma.order.count({ where: { riderId: actorId, status: 'cancelled', createdAt: { gte: sevenDaysAgo } } }).catch(() => 0),
  ]);

  const recentOrders = await prisma.order.findMany({
    where: {
      riderId: actorId,
      createdAt: { gte: thirtyDaysAgo },
    },
    select: {
      createdAt: true,
      customerId: true,
      restaurantId: true,
      groceryStoreId: true,
      pharmacyStoreId: true,
      grabMartStoreId: true,
    },
    take: 1000,
  }).catch(() => []);

  const vendorCounts14d = new Map();
  const customerCounts30d = new Map();

  for (const order of recentOrders) {
    const createdAt = new Date(order.createdAt).getTime();
    const vendorId =
      order.restaurantId ||
      order.groceryStoreId ||
      order.pharmacyStoreId ||
      order.grabMartStoreId ||
      null;

    if (createdAt >= fourteenDaysAgo.getTime() && vendorId) {
      vendorCounts14d.set(vendorId, (vendorCounts14d.get(vendorId) || 0) + 1);
    }

    if (order.customerId) {
      customerCounts30d.set(order.customerId, (customerCounts30d.get(order.customerId) || 0) + 1);
    }
  }

  const total14d = Array.from(vendorCounts14d.values()).reduce((sum, value) => sum + value, 0);
  const topVendorCount = vendorCounts14d.size ? Math.max(...vendorCounts14d.values()) : 0;
  const riderRestaurantAffinity14d = total14d > 0 ? topVendorCount / total14d : 0;

  const topCustomerPairCount = customerCounts30d.size ? Math.max(...customerCounts30d.values()) : 0;
  const riderCustomerRepeatPair30d = topCustomerPairCount;

  const cancelRate = totalAssigned7d > 0 ? cancelled7d / totalAssigned7d : 0;
  await Promise.all([
    setFeature({ actorType: 'rider', actorId, featureName: 'driver_cancel_rate_7d', value: { ratio: cancelRate } }),
    setFeature({ actorType: 'rider', actorId, featureName: 'rider_restaurant_affinity_14d', value: { ratio: riderRestaurantAffinity14d } }),
    setFeature({ actorType: 'rider', actorId, featureName: 'rider_customer_repeat_pair_30d', value: { count: riderCustomerRepeatPair30d } }),
  ]);
};

const recomputeFraudFeatures = async () => {
  const actors = await getDistinctActors();
  for (const actor of actors) {
    if (!actor?.actorType || !actor?.actorId) continue;
    if (actor.actorType === 'customer') {
      await recomputeCustomerFeatures(actor.actorId);
    } else if (actor.actorType === 'rider') {
      await recomputeRiderFeatures(actor.actorId);
    }
  }
};

const startFraudFeatureRecomputeJob = () => {
  if (intervalRef) return;

  const intervalMs = Number(process.env.FRAUD_FEATURE_RECOMPUTE_MS || 15 * 60 * 1000);
  intervalRef = setInterval(async () => {
    if (isRunning) return;
    isRunning = true;
    try {
      await recomputeFraudFeatures();
    } catch (error) {
      console.error('[FraudFeatures] Recompute job error:', error.message);
    } finally {
      isRunning = false;
    }
  }, intervalMs);

  // Warm start once with delay.
  startupTimeoutRef = setTimeout(() => {
    if (isRunning) return;
    isRunning = true;
    recomputeFraudFeatures().catch((error) => {
      console.error('[FraudFeatures] Startup recompute error:', error.message);
    }).finally(() => {
      isRunning = false;
      startupTimeoutRef = null;
    });
  }, 15_000);

  console.log(`[FraudFeatures] Recompute job started (${intervalMs}ms interval)`);
};

const stopFraudFeatureRecomputeJob = () => {
  if (!intervalRef) return;
  clearInterval(intervalRef);
  intervalRef = null;
  if (startupTimeoutRef) {
    clearTimeout(startupTimeoutRef);
    startupTimeoutRef = null;
  }
  isRunning = false;
  console.log('[FraudFeatures] Recompute job stopped');
};

module.exports = {
  startFraudFeatureRecomputeJob,
  stopFraudFeatureRecomputeJob,
};
