const prisma = require('../config/prisma');
const { LEVEL_MULTIPLIERS } = require('./rider_score_engine');
const { getDailyWindowKey, getWeeklyWindowKey } = require('./rider_quest_engine');

// ── Streak Reward Configuration ──
// Rewards are given at these consecutive-day streak milestones.
// Each threshold is awarded only once per streak (not per cycle).
const STREAK_REWARD_THRESHOLDS = [
  { days: 5, baseReward: 5.0, label: '5-day streak' },
  { days: 10, baseReward: 12.0, label: '10-day streak' },
  { days: 15, baseReward: 25.0, label: '15-day streak' },
  { days: 20, baseReward: 40.0, label: '20-day streak' },
  { days: 30, baseReward: 75.0, label: '30-day streak' },
];

// Minimum deliveries in a day to qualify as a "streak day"
const MIN_DELIVERIES_FOR_STREAK_DAY = 1;

/**
 * Check if two dates are consecutive calendar days (Africa/Accra = UTC+0).
 *
 * @param {Date} prevDate - Previous delivery date
 * @param {Date} currentDate - Today's date
 * @returns {'consecutive'|'same_day'|'broken'}
 */
const checkStreakContinuity = (prevDate, currentDate) => {
  if (!prevDate) return 'broken';

  const prev = new Date(prevDate);
  const curr = new Date(currentDate);

  const prevDay = prev.toISOString().slice(0, 10);
  const currDay = curr.toISOString().slice(0, 10);

  if (prevDay === currDay) return 'same_day';

  // Check if currDay is exactly the day after prevDay
  const prevDayDate = new Date(prevDay + 'T00:00:00Z');
  const nextDay = new Date(prevDayDate.getTime() + 24 * 60 * 60 * 1000);
  const nextDayStr = nextDay.toISOString().slice(0, 10);

  return currDay === nextDayStr ? 'consecutive' : 'broken';
};

/**
 * Get or create the streak state for a rider.
 *
 * @param {string} riderId
 * @returns {Promise<Object>}
 */
const getOrCreateStreakState = async (riderId) => {
  let state = await prisma.riderStreakState.findUnique({
    where: { riderId },
  });

  if (!state) {
    state = await prisma.riderStreakState.create({
      data: {
        riderId,
        currentStreak: 0,
        longestStreak: 0,
        nextRewardThreshold: STREAK_REWARD_THRESHOLDS[0]?.days || 5,
      },
    });
  }

  return state;
};

/**
 * Process a delivery for streak tracking.
 * Called after every successful delivery.
 *
 * @param {string} riderId
 * @param {Object} [options]
 * @param {string} [options.partnerLevel='L1']
 * @returns {Promise<Object>} { state, rewards, streakBroken }
 */
const processDeliveryForStreak = async (riderId, options = {}) => {
  const { partnerLevel = 'L1' } = options;
  const now = new Date();
  const today = getDailyWindowKey(now);

  const state = await getOrCreateStreakState(riderId);
  const continuity = checkStreakContinuity(state.lastDeliveryDate, now);

  const rewards = [];
  let newStreak = state.currentStreak;
  let streakBroken = false;

  if (continuity === 'same_day') {
    // Already counted today — just update lastDeliveryDate
    await prisma.riderStreakState.update({
      where: { riderId },
      data: { lastDeliveryDate: now },
    });
    return { state, rewards, streakBroken: false };
  }

  if (continuity === 'consecutive') {
    // Streak continues
    newStreak = state.currentStreak + 1;
  } else {
    // Streak broken — restart
    newStreak = 1;
    streakBroken = state.currentStreak > 0;
  }

  const longestStreak = Math.max(state.longestStreak, newStreak);

  // Check if any reward thresholds have been crossed
  const multiplier = LEVEL_MULTIPLIERS[partnerLevel] || 1.0;
  const weekKey = getWeeklyWindowKey(now);

  // Find thresholds that were just crossed (between old streak and new streak)
  const oldStreak = continuity === 'consecutive' ? state.currentStreak : 0;
  for (const threshold of STREAK_REWARD_THRESHOLDS) {
    if (newStreak >= threshold.days && oldStreak < threshold.days) {
      // Check if this threshold was already rewarded in this streak
      const existingReward = await prisma.riderStreakRewardHistory.findFirst({
        where: {
          riderId,
          streakCount: threshold.days,
          awardedAt: {
            gte: state.streakStartDate || new Date(0),
          },
        },
      });

      if (!existingReward) {
        const finalAmount = Math.round(threshold.baseReward * multiplier * 100) / 100;

        await prisma.riderStreakRewardHistory.create({
          data: {
            riderId,
            streakCount: threshold.days,
            rewardAmount: threshold.baseReward,
            multiplier,
            finalAmount,
            windowKey: weekKey,
          },
        });

        rewards.push({
          streakCount: threshold.days,
          label: threshold.label,
          baseReward: threshold.baseReward,
          multiplier,
          finalAmount,
        });

        // Non-blocking notification
        const { notifyStreakReward } = require('./rider_incentive_notifications');
        notifyStreakReward(riderId, threshold.days, finalAmount).catch(() => {});
      }
    }
  }

  // Find next reward threshold
  let nextThreshold = STREAK_REWARD_THRESHOLDS[STREAK_REWARD_THRESHOLDS.length - 1]?.days || 30;
  for (const t of STREAK_REWARD_THRESHOLDS) {
    if (newStreak < t.days) {
      nextThreshold = t.days;
      break;
    }
  }

  // Update streak state
  await prisma.riderStreakState.update({
    where: { riderId },
    data: {
      currentStreak: newStreak,
      longestStreak,
      lastDeliveryDate: now,
      streakStartDate: continuity === 'broken' ? now : state.streakStartDate,
      lastStreakResetAt: streakBroken ? now : state.lastStreakResetAt,
      nextRewardThreshold: nextThreshold,
    },
  });

  if (rewards.length > 0) {
    console.log(
      `[StreakEngine] Rider ${riderId}: streak ${newStreak} days, awarded ${rewards.length} reward(s)`
    );
  }

  return {
    state: {
      currentStreak: newStreak,
      longestStreak,
      lastDeliveryDate: now,
      nextRewardThreshold: nextThreshold,
    },
    rewards,
    streakBroken,
  };
};

/**
 * Get streak dashboard data for the rider app.
 *
 * @param {string} riderId
 * @param {string} [partnerLevel='L1']
 * @returns {Promise<Object>} Streak display data
 */
const getRiderStreakDashboard = async (riderId, partnerLevel = 'L1') => {
  const state = await getOrCreateStreakState(riderId);
  const multiplier = LEVEL_MULTIPLIERS[partnerLevel] || 1.0;

  // Find the next reward info
  let nextReward = null;
  for (const t of STREAK_REWARD_THRESHOLDS) {
    if (state.currentStreak < t.days) {
      nextReward = {
        daysNeeded: t.days - state.currentStreak,
        threshold: t.days,
        label: t.label,
        baseReward: t.baseReward,
        finalReward: Math.round(t.baseReward * multiplier * 100) / 100,
      };
      break;
    }
  }

  // Recent streak rewards (last 10)
  const recentRewards = await prisma.riderStreakRewardHistory.findMany({
    where: { riderId },
    orderBy: { awardedAt: 'desc' },
    take: 10,
  });

  return {
    currentStreak: state.currentStreak,
    longestStreak: state.longestStreak,
    streakStartDate: state.streakStartDate,
    lastDeliveryDate: state.lastDeliveryDate,
    nextReward,
    allThresholds: STREAK_REWARD_THRESHOLDS.map((t) => ({
      days: t.days,
      label: t.label,
      baseReward: t.baseReward,
      finalReward: Math.round(t.baseReward * multiplier * 100) / 100,
      achieved: state.currentStreak >= t.days,
    })),
    recentRewards: recentRewards.map((r) => ({
      streakCount: r.streakCount,
      rewardAmount: r.finalAmount,
      awardedAt: r.awardedAt,
    })),
  };
};

module.exports = {
  processDeliveryForStreak,
  getOrCreateStreakState,
  getRiderStreakDashboard,
  checkStreakContinuity,

  // Constants (exported for seeding/testing)
  STREAK_REWARD_THRESHOLDS,
  MIN_DELIVERIES_FOR_STREAK_DAY,
};
