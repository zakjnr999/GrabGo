const prisma = require('../config/prisma');
const featureFlags = require('../config/feature_flags');
const { incrementQuestProgress, expireStaleQuests, getWindowKey } = require('./rider_quest_engine');
const { processDeliveryForStreak } = require('./rider_streak_engine');
const { incrementMilestoneProgress } = require('./rider_milestone_engine');
const { processPeakHourBonus } = require('./rider_peak_hour_service');
const { createScopedLogger } = require('../utils/logger');
const console = createScopedLogger('rider_incentive_orchestrator');

/**
 * Incentive Orchestrator
 *
 * Single entry-point called after every delivery completion.
 * Coordinates quest progress, streak tracking, and milestone checks,
 * then writes earned incentives to the RiderIncentiveLedger for
 * budget approval and eventual payout.
 *
 * Flow:
 *   delivery completed
 *   → fireDeliverySettlementSideEffects (existing)
 *   → processDeliveryIncentives (this function, added as another side-effect)
 *   → quest engine increments all active quests
 *   → streak engine checks consecutive-day streaks
 *   → milestone engine checks lifetime milestones
 *   → any earned rewards are written to incentive ledger
 */

/**
 * Build a deterministic ledger sourceRef to guarantee idempotency.
 * Format: "<sourceType>:<entityId>:<windowKey>"
 *
 * @param {string} sourceType - 'quest' | 'streak' | 'milestone'
 * @param {string} entityId  - questId / "streak-<days>" / milestoneId
 * @param {string} windowKey - e.g. "2026-03-05" or "2026-W10"
 * @returns {string}
 */
const buildSourceRef = (sourceType, entityId, windowKey) => {
  return `${sourceType}:${entityId}:${windowKey}`;
};

/**
 * Write an incentive to the ledger, respecting idempotency via unique(sourceType, sourceRef).
 *
 * @param {Object} params
 * @param {string} params.riderId
 * @param {string} params.sourceType - 'quest' | 'streak' | 'milestone'
 * @param {string} params.sourceRef - Deterministic key
 * @param {number} params.baseAmount
 * @param {number} params.multiplier
 * @param {number} params.finalAmount
 * @param {string} params.windowKey
 * @param {Object} [params.metadata]
 * @returns {Promise<Object|null>} Created ledger entry or null if duplicate
 */
const writeLedgerEntry = async (params) => {
  const {
    riderId,
    sourceType,
    sourceRef,
    baseAmount,
    multiplier,
    finalAmount,
    windowKey,
    metadata,
  } = params;

  try {
    const entry = await prisma.riderIncentiveLedger.create({
      data: {
        riderId,
        sourceType,
        sourceRef,
        baseAmount,
        multiplier,
        finalAmount,
        status: 'pending_budget',
        windowKey,
        metadata: metadata || undefined,
      },
    });

    return entry;
  } catch (err) {
    // P2002 = unique constraint violation → already written (idempotent)
    if (err.code === 'P2002') {
      return null;
    }
    throw err;
  }
};

/**
 * Process all incentive engines after a delivery.
 *
 * This is the main entry-point for the incentive system. It should be
 * called non-blocking from fireDeliverySettlementSideEffects.
 *
 * @param {Object} params
 * @param {string} params.riderId - Rider user ID
 * @param {string} params.orderId - Delivered order ID
 * @param {string} [params.orderType='food']
 * @returns {Promise<Object>} Summary of all earned incentives
 */
const processDeliveryIncentives = async ({ riderId, orderId, orderType = 'food', deliveryEarnings = 0, deliveredAt }) => {
  if (!featureFlags.isRiderIncentivesEnabled) {
    return { quests: [], streakRewards: [], milestones: [], peakBonuses: [], totalEarned: 0 };
  }

  const now = new Date();
  const dailyWindowKey = getWindowKey('daily', now);
  const weeklyWindowKey = getWindowKey('weekly', now);

  // Get rider's partner level for reward multiplier
  let partnerLevel = 'L1';
  try {
    const profile = await prisma.riderPartnerProfile.findUnique({
      where: { riderId },
      select: { partnerLevel: true },
    });
    if (profile) partnerLevel = profile.partnerLevel;
  } catch (err) {
    console.error(`[IncentiveOrchestrator] Failed to get partner level for ${riderId}:`, err.message);
  }

  const ledgerEntries = [];

  // ── 1. Quest Progress ──
  let completedQuests = [];
  try {
    completedQuests = await incrementQuestProgress(riderId, { partnerLevel });

    for (const quest of completedQuests) {
      const windowKey = quest.windowKey;
      const sourceRef = buildSourceRef('quest', quest.questId, windowKey);

      const entry = await writeLedgerEntry({
        riderId,
        sourceType: 'quest',
        sourceRef,
        baseAmount: quest.baseReward,
        multiplier: quest.multiplier,
        finalAmount: quest.finalReward,
        windowKey,
        metadata: {
          questName: quest.questName,
          period: quest.period,
          targetCount: quest.targetCount,
          orderId,
        },
      });

      if (entry) ledgerEntries.push(entry);
    }
  } catch (err) {
    console.error(`[IncentiveOrchestrator] Quest engine error for rider ${riderId}:`, err.message);
  }

  // ── 2. Streak ──
  let streakRewards = [];
  try {
    const streakResult = await processDeliveryForStreak(riderId, { partnerLevel });
    streakRewards = streakResult.rewards;

    for (const reward of streakRewards) {
      const sourceRef = buildSourceRef('streak', `streak-${reward.streakCount}`, weeklyWindowKey);

      const entry = await writeLedgerEntry({
        riderId,
        sourceType: 'streak',
        sourceRef,
        baseAmount: reward.baseReward,
        multiplier: reward.multiplier,
        finalAmount: reward.finalAmount,
        windowKey: weeklyWindowKey,
        metadata: {
          streakCount: reward.streakCount,
          label: reward.label,
          orderId,
        },
      });

      if (entry) ledgerEntries.push(entry);
    }
  } catch (err) {
    console.error(`[IncentiveOrchestrator] Streak engine error for rider ${riderId}:`, err.message);
  }

  // ── 3. Milestones ──
  let completedMilestones = [];
  try {
    completedMilestones = await incrementMilestoneProgress(riderId, { partnerLevel });

    for (const milestone of completedMilestones) {
      const sourceRef = buildSourceRef('milestone', milestone.milestoneId, dailyWindowKey);

      const entry = await writeLedgerEntry({
        riderId,
        sourceType: 'milestone',
        sourceRef,
        baseAmount: milestone.baseReward,
        multiplier: milestone.multiplier,
        finalAmount: milestone.finalReward,
        windowKey: dailyWindowKey,
        metadata: {
          milestoneName: milestone.name,
          targetCount: milestone.targetCount,
          badgeIcon: milestone.badgeIcon,
          orderId,
        },
      });

      if (entry) ledgerEntries.push(entry);
    }
  } catch (err) {
    console.error(`[IncentiveOrchestrator] Milestone engine error for rider ${riderId}:`, err.message);
  }

  // ── 4. Peak-Hour Bonus ──
  let peakBonuses = [];
  try {
    if (deliveryEarnings > 0) {
      const peakEntries = await processPeakHourBonus({
        riderId,
        orderId,
        deliveryEarnings,
        deliveredAt: deliveredAt || now,
        partnerLevel,
      });
      peakBonuses = peakEntries;
      for (const entry of peakEntries) {
        ledgerEntries.push(entry);
      }
    }
  } catch (err) {
    console.error(`[IncentiveOrchestrator] Peak-hour engine error for rider ${riderId}:`, err.message);
  }

  // ── Summary ──
  const totalEarned = ledgerEntries.reduce((sum, e) => sum + e.finalAmount, 0);

  if (totalEarned > 0) {
    console.log(
      `[IncentiveOrchestrator] Rider ${riderId}: earned GHS ${totalEarned.toFixed(2)} total ` +
      `(quests=${completedQuests.length}, streaks=${streakRewards.length}, milestones=${completedMilestones.length}, peak=${peakBonuses.length})`
    );
  }

  return {
    quests: completedQuests,
    streakRewards,
    milestones: completedMilestones,
    peakBonuses: peakBonuses.map((e) => ({
      id: e.id,
      finalAmount: e.finalAmount,
      metadata: e.metadata,
    })),
    totalEarned: Math.round(totalEarned * 100) / 100,
    ledgerEntries: ledgerEntries.length,
  };
};

/**
 * Get incentive summary for a rider (for dashboard display).
 *
 * @param {string} riderId
 * @param {string} [windowKey] - Specific window or defaults to current week
 * @returns {Promise<Object>}
 */
const getRiderIncentiveSummary = async (riderId, windowKey) => {
  const now = new Date();
  const effectiveWindowKey = windowKey || getWindowKey('weekly', now);

  const ledgerEntries = await prisma.riderIncentiveLedger.findMany({
    where: {
      riderId,
      windowKey: effectiveWindowKey,
    },
    orderBy: { createdAt: 'desc' },
  });

  const bySource = {};
  let totalPending = 0;
  let totalAvailable = 0;
  let totalPaidOut = 0;

  for (const entry of ledgerEntries) {
    if (!bySource[entry.sourceType]) {
      bySource[entry.sourceType] = { count: 0, total: 0 };
    }
    bySource[entry.sourceType].count++;
    bySource[entry.sourceType].total += entry.finalAmount;

    if (entry.status === 'pending_budget') totalPending += entry.finalAmount;
    else if (entry.status === 'available') totalAvailable += entry.finalAmount;
    else if (entry.status === 'paid_out') totalPaidOut += entry.finalAmount;
  }

  return {
    windowKey: effectiveWindowKey,
    totalEntries: ledgerEntries.length,
    totalPending: Math.round(totalPending * 100) / 100,
    totalAvailable: Math.round(totalAvailable * 100) / 100,
    totalPaidOut: Math.round(totalPaidOut * 100) / 100,
    bySource,
    entries: ledgerEntries.map((e) => ({
      id: e.id,
      sourceType: e.sourceType,
      baseAmount: e.baseAmount,
      multiplier: e.multiplier,
      finalAmount: e.finalAmount,
      status: e.status,
      metadata: e.metadata,
      createdAt: e.createdAt,
    })),
  };
};

module.exports = {
  processDeliveryIncentives,
  writeLedgerEntry,
  buildSourceRef,
  getRiderIncentiveSummary,
  expireStaleQuests,
};
