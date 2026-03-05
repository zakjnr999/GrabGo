const RiderStatus = require('../models/RiderStatus');
const DeliveryAnalytics = require('../models/DeliveryAnalytics');
const prisma = require('../config/prisma');

/**
 * Syncs RiderStatus.metrics (MongoDB) with authoritative data after each
 * delivery completion. This keeps dispatch scoring fresh without requiring
 * a separate batch job for every assignment cycle.
 *
 * @param {string} riderUserId  - The rider's User ID (used in RiderStatus.riderId)
 * @param {number} [earningsToAdd] - GHS earned on this delivery (for logging)
 */
const syncRiderMetricsOnDelivery = async (riderUserId, earningsToAdd = 0) => {
  try {
    // Get the rider record for rating data
    const rider = await prisma.rider.findFirst({
      where: { userId: riderUserId },
      select: {
        rating: true,
        ratingCount: true,
        totalDeliveries: true,
      },
    });

    if (!rider) {
      console.warn(`[RiderMetricsSync] Rider not found for userId=${riderUserId}`);
      return;
    }

    // Get today's boundaries (Africa/Accra = UTC+0, no DST)
    const now = new Date();
    const todayStart = new Date(now);
    todayStart.setUTCHours(0, 0, 0, 0);
    const todayEnd = new Date(now);
    todayEnd.setUTCHours(23, 59, 59, 999);

    // Count today's completed deliveries from analytics
    const todayStats = await DeliveryAnalytics.aggregate([
      {
        $match: {
          riderId: riderUserId,
          status: 'completed',
          createdAt: { $gte: todayStart, $lte: todayEnd },
        },
      },
      {
        $group: {
          _id: null,
          count: { $sum: 1 },
          earnings: { $sum: '$riderEarnings' },
        },
      },
    ]);

    const todayDeliveries = todayStats.length > 0 ? todayStats[0].count : 0;
    const todayEarnings = todayStats.length > 0 ? todayStats[0].earnings : 0;

    // Atomically update RiderStatus metrics
    const updateResult = await RiderStatus.findOneAndUpdate(
      { riderId: riderUserId },
      {
        $set: {
          'metrics.rating': rider.rating || 5.0,
          'metrics.totalDeliveries': rider.totalDeliveries || 0,
          'metrics.todayDeliveries': todayDeliveries,
          'metrics.todayEarnings': Math.round(todayEarnings * 100) / 100,
        },
      },
      { new: true, upsert: false }
    );

    if (!updateResult) {
      console.warn(`[RiderMetricsSync] No RiderStatus found for rider=${riderUserId}`);
      return;
    }

    console.log(
      `[RiderMetricsSync] Updated rider=${riderUserId} ` +
      `todayDeliveries=${todayDeliveries} todayEarnings=${todayEarnings} ` +
      `rating=${rider.rating}`
    );
  } catch (error) {
    // Non-fatal: don't break delivery flow for metrics sync
    console.error(`[RiderMetricsSync] Failed for rider=${riderUserId}:`, error.message);
  }
};

/**
 * Increment rider's totalDeliveries in Prisma after a successful delivery.
 * This ensures the Prisma rider record stays consistent.
 *
 * @param {string} riderUserId
 */
const incrementRiderDeliveryCount = async (riderUserId) => {
  try {
    await prisma.rider.updateMany({
      where: { userId: riderUserId },
      data: {
        totalDeliveries: { increment: 1 },
      },
    });
  } catch (error) {
    console.error(`[RiderMetricsSync] Failed to increment delivery count for rider=${riderUserId}:`, error.message);
  }
};

module.exports = {
  syncRiderMetricsOnDelivery,
  incrementRiderDeliveryCount,
};
