const prisma = require('../config/prisma');
const featureFlags = require('../config/feature_flags');
const { recordDeliveryAnalytics } = require('./delivery_analytics_service');
const { syncRiderMetricsOnDelivery, incrementRiderDeliveryCount } = require('./rider_metrics_sync_service');
const { processDeliveryIncentives } = require('./rider_incentive_orchestrator');

/**
 * Unified delivery settlement handler.
 *
 * Replaces the inline wallet-credit logic in orders.js for the `delivered`
 * status transition. Handles:
 *
 * 1. Credit rider wallet with locked riderEarnings (not deliveryFee)
 * 2. Record delivery analytics for score engine
 * 3. Sync RiderStatus.metrics for dispatch freshness
 * 4. Increment rider delivery count
 *
 * This function is called from within a Prisma transaction for the wallet
 * credit, and fires non-blocking side-effects for analytics and metrics.
 *
 * @param {Object} params
 * @param {import('@prisma/client').PrismaClient} params.tx - Prisma transaction client
 * @param {Object} params.order           - The order being delivered
 * @param {string} params.riderId         - Rider's user ID
 * @param {string} [params.orderType]     - 'food' | 'grocery' | 'pharmacy' | 'grabmart'
 * @returns {Object} { creditAmount, riderEarnings, deliveryFee, walletCredited }
 */
const settleDeliveryInTransaction = async ({ tx, order, riderId, orderType }) => {
  // ---- 1. Determine correct earnings amount ----
  // Use the locked riderEarnings field, NOT deliveryFee
  const riderEarnings = Number(order.riderEarnings) || 0;
  const deliveryFee = Number(order.deliveryFee) || 0;

  // Fallback: if riderEarnings was never set (legacy orders), use deliveryFee
  const creditAmount = riderEarnings > 0 ? riderEarnings : deliveryFee;

  if (riderEarnings > 0 && riderEarnings !== deliveryFee) {
    console.log(
      `[DeliverySettlement] Using riderEarnings=${riderEarnings} (deliveryFee=${deliveryFee}) for order=${order.id}`
    );
  }

  let walletCredited = false;

  if (creditAmount > 0) {
    // Check idempotency: has this order already been settled?
    const existingTransaction = await tx.transaction.findFirst({
      where: {
        referenceId: order.id,
        type: 'delivery',
        userId: riderId,
      },
    });

    if (!existingTransaction) {
      // Find or create rider wallet
      let wallet = await tx.riderWallet.findUnique({
        where: { userId: riderId },
      });

      if (!wallet) {
        wallet = await tx.riderWallet.create({
          data: { userId: riderId },
        });
      }

      // Create transaction with correct riderEarnings
      await tx.transaction.create({
        data: {
          walletId: wallet.id,
          userId: riderId,
          amount: creditAmount,
          type: 'delivery',
          description: `Delivery earnings for order ${order.orderNumber || order.id}`,
          referenceId: order.id,
          status: 'completed',
        },
      });

      // Update wallet balance
      await tx.riderWallet.update({
        where: { id: wallet.id },
        data: {
          balance: { increment: creditAmount },
          totalEarnings: { increment: creditAmount },
        },
      });

      walletCredited = true;
      console.log(
        `[DeliverySettlement] Credited GHS ${creditAmount} to rider=${riderId} for order=${order.id}`
      );
    } else {
      console.log(`[DeliverySettlement] Already settled order=${order.id} for rider=${riderId}, skipping`);
    }
  }

  return { creditAmount, riderEarnings, deliveryFee, walletCredited };
};

/**
 * Fire non-blocking side-effects after a delivery is settled.
 * Call this AFTER the Prisma transaction commits successfully.
 *
 * @param {Object} params
 * @param {Object} params.order     - The delivered order
 * @param {string} params.riderId   - Rider's user ID
 * @param {number} params.creditAmount - Amount credited
 * @param {string} [params.orderType]  - Order type
 */
const fireDeliverySettlementSideEffects = (params) => {
  const { order, riderId, creditAmount, orderType = 'food' } = params;

  // Record delivery analytics (non-blocking)
  if (featureFlags.isRiderDeliveryAnalyticsEnabled) {
    recordDeliveryAnalytics({
      riderId,
      orderId: order.id,
      orderType: orderType || order.orderType || 'food',
      vendorId: order.restaurantId || order.groceryStoreId || order.pharmacyStoreId || order.grabMartStoreId || null,
      distanceKm: Number(order.distanceKm) || 0,
      riderEarnings: creditAmount,
      assignedAt: order.riderAssignedAt || order.acceptedAt || order.createdAt,
      pickedUpAt: order.pickedUpAt || null,
      deliveredAt: order.deliveredDate || new Date(),
      estimatedMinutes: order.deliveryWindowMin || order.deliveryWindowMax || null,
    }).catch((err) => {
      console.error(`[DeliverySettlement] Analytics write failed for order=${order.id}:`, err.message);
    });
  }

  // Sync RiderStatus.metrics for dispatch scoring freshness (non-blocking)
  if (featureFlags.isRiderMetricsSyncEnabled) {
    syncRiderMetricsOnDelivery(riderId, creditAmount).catch((err) => {
      console.error(`[DeliverySettlement] Metrics sync failed for rider=${riderId}:`, err.message);
    });

    // Increment rider delivery count in Prisma
    incrementRiderDeliveryCount(riderId).catch((err) => {
      console.error(`[DeliverySettlement] Delivery count increment failed for rider=${riderId}:`, err.message);
    });
  }

  // Process incentive engines (quest progress, streak tracking, milestone checks, peak-hour bonuses)
  if (featureFlags.isRiderIncentivesEnabled) {
    processDeliveryIncentives({
      riderId,
      orderId: order.id,
      orderType: orderType || order.orderType || 'food',
      deliveryEarnings: creditAmount,
      deliveredAt: order.deliveredDate || new Date(),
    }).catch((err) => {
      console.error(`[DeliverySettlement] Incentive processing failed for rider=${riderId}:`, err.message);
    });
  }
};

module.exports = {
  settleDeliveryInTransaction,
  fireDeliverySettlementSideEffects,
};
