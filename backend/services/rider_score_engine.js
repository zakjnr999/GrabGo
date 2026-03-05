const prisma = require('../config/prisma');
const DeliveryAnalytics = require('../models/DeliveryAnalytics');
const OrderReservation = require('../models/OrderReservation');

// ── Score Formula Weights ──
const SCORE_WEIGHTS = {
  onTimeRate: 0.35,
  completionRate: 0.25,
  customerRating: 0.20,
  deliveryVolume: 0.15,
  acceptanceRate: 0.05,
};

// ── Level Thresholds ──
const LEVEL_THRESHOLDS = [
  { level: 'L1', min: 0, max: 39 },
  { level: 'L2', min: 40, max: 59 },
  { level: 'L3', min: 60, max: 74 },
  { level: 'L4', min: 75, max: 89 },
  { level: 'L5', min: 90, max: 100 },
];

// ── Minimum Requirements for Level Upgrades ──
// Riders must meet these thresholds in addition to the score range.
const LEVEL_MIN_REQUIREMENTS = {
  L2: { minDeliveries: 20, minRating: 3.5, minCompletionRate: 70 },
  L3: { minDeliveries: 50, minRating: 4.0, minCompletionRate: 80 },
  L4: { minDeliveries: 100, minRating: 4.3, minCompletionRate: 85 },
  L5: { minDeliveries: 200, minRating: 4.5, minCompletionRate: 90 },
};

// ── Level Multipliers (for incentive engine) ──
const LEVEL_MULTIPLIERS = {
  L1: 1.0,
  L2: 1.1,
  L3: 1.2,
  L4: 1.4,
  L5: 1.6,
};

// ── Dispatch Priority Bonuses (capped, soft) ──
const DISPATCH_PRIORITY_BONUS = {
  L1: 0,
  L2: 3,
  L3: 6,
  L4: 9,
  L5: 12,
};

// ── Hysteresis Constants ──
const UPGRADE_LOCK_DAYS = 14;
const DOWNGRADE_CONSECUTIVE_DAYS_REQUIRED = 7;
const ROLLING_WINDOW_DAYS = 28;

// ── Bayesian Rating Smoothing ──
// Global prior: assume 4.0 average with confidence of 10 ratings.
// Bayesian rating = (globalPrior * priorWeight + actualSum) / (priorWeight + ratingCount)
const BAYESIAN_PRIOR_RATING = 4.0;
const BAYESIAN_PRIOR_WEIGHT = 10;

// ── Volume Normalization ──
// How we map raw delivery count to a 0-100 score component.
// A rider doing `VOLUME_100_PERCENTILE` or more deliveries in 28 days gets 100.
const VOLUME_100_PERCENTILE = 150; // ~5.3 deliveries/day for 28 days

/**
 * Calculate the Bayesian-smoothed rating for a rider.
 * Avoids volatility for riders with few ratings.
 *
 * @param {number} avgRating - Raw average rating (1-5)
 * @param {number} ratingCount - Number of ratings received
 * @returns {number} Smoothed rating (1-5)
 */
const computeBayesianRating = (avgRating, ratingCount) => {
  if (ratingCount === 0) return BAYESIAN_PRIOR_RATING;
  const smoothed =
    (BAYESIAN_PRIOR_RATING * BAYESIAN_PRIOR_WEIGHT + avgRating * ratingCount) /
    (BAYESIAN_PRIOR_WEIGHT + ratingCount);
  return Math.max(1, Math.min(5, smoothed));
};

/**
 * Normalize a value into 0-100 range.
 */
const normalize = (value, max) => Math.min(100, Math.max(0, (value / max) * 100));

/**
 * Determine partner level from raw score.
 */
const scoreToLevel = (score) => {
  for (const t of LEVEL_THRESHOLDS) {
    if (score >= t.min && score <= t.max) return t.level;
  }
  return score >= 90 ? 'L5' : 'L1';
};

/**
 * Check if a rider meets the minimum requirements for a level.
 */
const meetsMinRequirements = (level, metrics) => {
  const req = LEVEL_MIN_REQUIREMENTS[level];
  if (!req) return true; // L1 has no requirements

  return (
    metrics.deliveryVolume >= req.minDeliveries &&
    metrics.customerRating >= req.minRating &&
    metrics.completionRate >= req.minCompletionRate
  );
};

/**
 * Compute the acceptance rate for a rider from OrderReservation outcomes.
 * Uses both 'order' and 'parcel' entity types.
 *
 * Excludes cancelled reservations (not the rider's action).
 * Low-sample fallback: if fewer than 5 reservations, return neutral 100%.
 *
 * @param {string} riderId - User ID
 * @param {Date} windowStart - Start of rolling window
 * @param {Date} windowEnd - End of rolling window
 * @returns {Promise<{rate: number, total: number, accepted: number, declined: number, expired: number}>}
 */
const computeAcceptanceRate = async (riderId, windowStart, windowEnd) => {
  const LOW_SAMPLE_THRESHOLD = 5;

  const stats = await OrderReservation.aggregate([
    {
      $match: {
        riderId,
        status: { $in: ['accepted', 'declined', 'expired'] },
        createdAt: { $gte: windowStart, $lte: windowEnd },
      },
    },
    {
      $group: {
        _id: '$status',
        count: { $sum: 1 },
      },
    },
  ]);

  let accepted = 0;
  let declined = 0;
  let expired = 0;

  for (const bucket of stats) {
    if (bucket._id === 'accepted') accepted = bucket.count;
    else if (bucket._id === 'declined') declined = bucket.count;
    else if (bucket._id === 'expired') expired = bucket.count;
  }

  const total = accepted + declined + expired;

  // Low-sample neutral fallback
  if (total < LOW_SAMPLE_THRESHOLD) {
    return { rate: 100, total, accepted, declined, expired };
  }

  const rate = Math.round((accepted / total) * 100);
  return { rate, total, accepted, declined, expired };
};

/**
 * Core score computation for a single rider.
 *
 * @param {string} riderId - User ID of the rider
 * @param {Date} windowStart - Start of 28-day rolling window
 * @param {Date} windowEnd - End of window (usually now)
 * @returns {Promise<Object>} Full score breakdown
 */
const computeRiderScore = async (riderId, windowStart, windowEnd) => {
  // 1. Get performance summary from DeliveryAnalytics (MongoDB)
  const perfSummary = await DeliveryAnalytics.getRiderPerformanceSummary(
    riderId,
    windowStart,
    windowEnd
  );

  // 2. Get on-time rate with fair exclusion
  const onTimeData = await DeliveryAnalytics.getRiderOnTimeRate(
    riderId,
    0, // minDeliveries = 0 (we handle low-sample in the score)
    windowStart,
    windowEnd
  );

  // 3. Get acceptance rate from reservations
  const acceptanceData = await computeAcceptanceRate(riderId, windowStart, windowEnd);

  // 4. Get rider's rating from Prisma
  const rider = await prisma.rider.findFirst({
    where: { userId: riderId },
    select: { rating: true, ratingCount: true, totalDeliveries: true },
  });

  const rawRating = rider?.rating || 5.0;
  const ratingCount = rider?.ratingCount || 0;

  // ── Compute each component score (0-100) ──

  // On-time rate: already a percentage (0-100)
  const onTimeScore = onTimeData.onTimeRate;

  // Completion rate: already a percentage (0-100)
  const completionScore = perfSummary.completionRate;

  // Customer rating: Bayesian-smoothed, then map 1-5 → 0-100
  const smoothedRating = computeBayesianRating(rawRating, ratingCount);
  const ratingScore = normalize((smoothedRating - 1) * 25, 100); // 1→0, 5→100

  // Delivery volume: normalize against benchmark
  const volumeScore = normalize(perfSummary.completed, VOLUME_100_PERCENTILE);

  // Acceptance rate: already a percentage (0-100)
  const acceptanceScore = acceptanceData.rate;

  // ── Weighted composite score ──
  const partnerScore = Math.round(
    onTimeScore * SCORE_WEIGHTS.onTimeRate +
    completionScore * SCORE_WEIGHTS.completionRate +
    ratingScore * SCORE_WEIGHTS.customerRating +
    volumeScore * SCORE_WEIGHTS.deliveryVolume +
    acceptanceScore * SCORE_WEIGHTS.acceptanceRate
  );

  // Clamp to 0-100
  const clampedScore = Math.max(0, Math.min(100, partnerScore));

  // Determine raw level from score
  const rawLevel = scoreToLevel(clampedScore);

  return {
    partnerScore: clampedScore,
    rawLevel,
    components: {
      onTimeRate: onTimeScore,
      completionRate: completionScore,
      customerRating: Math.round(smoothedRating * 100) / 100,
      ratingScore,
      deliveryVolume: perfSummary.completed,
      volumeScore,
      acceptanceRate: acceptanceScore,
    },
    rawMetrics: {
      onTimeData,
      perfSummary,
      acceptanceData,
      rawRating,
      ratingCount,
      smoothedRating,
    },
  };
};

/**
 * Evaluate and persist the partner profile for a single rider.
 * Applies hysteresis rules (upgrade lock + downgrade delay).
 *
 * @param {string} riderId - User ID
 * @param {Object} [options]
 * @param {boolean} [options.forceLevel] - Override hysteresis (for admin/backfill)
 * @param {string} [options.reason] - Override reason for level history
 * @returns {Promise<Object>} Updated profile and any level change
 */
const evaluateRiderPartnerLevel = async (riderId, options = {}) => {
  const now = new Date();
  const windowEnd = new Date(now);
  const windowStart = new Date(now);
  windowStart.setDate(windowStart.getDate() - ROLLING_WINDOW_DAYS);

  // Compute score
  const scoreResult = await computeRiderScore(riderId, windowStart, windowEnd);
  const { partnerScore, rawLevel, components } = scoreResult;

  // Get or create partner profile
  let profile = await prisma.riderPartnerProfile.findUnique({
    where: { riderId },
  });

  const isNewProfile = !profile;
  const previousLevel = profile?.partnerLevel || 'L1';

  if (!profile) {
    profile = await prisma.riderPartnerProfile.create({
      data: {
        riderId,
        partnerScore,
        partnerLevel: 'L1',
        scoreWindowStart: windowStart,
        scoreWindowEnd: windowEnd,
        lastEvaluatedAt: now,
        onTimeRate: components.onTimeRate,
        completionRate: components.completionRate,
        customerRating: components.customerRating,
        deliveryVolume: components.deliveryVolume,
        acceptanceRate: components.acceptanceRate,
      },
    });
  }

  // ── Determine effective level with hysteresis ──
  let effectiveLevel = previousLevel;
  let levelChanged = false;
  let changeReason = null;

  const levelIndex = (l) => ['L1', 'L2', 'L3', 'L4', 'L5'].indexOf(l);
  const isUpgrade = levelIndex(rawLevel) > levelIndex(previousLevel);
  const isDowngrade = levelIndex(rawLevel) < levelIndex(previousLevel);

  if (options.forceLevel || isNewProfile) {
    // Forced or initial placement: apply raw level directly
    effectiveLevel = rawLevel;
    levelChanged = rawLevel !== previousLevel;
    changeReason = options.reason || (isNewProfile ? 'initial_placement' : 'manual_adjustment');
  } else if (isUpgrade) {
    // Check if level is currently locked (recent upgrade protection)
    const isLocked = profile.levelLockedUntil && profile.levelLockedUntil > now;
    if (isLocked) {
      effectiveLevel = previousLevel; // Stay at current level
    } else if (meetsMinRequirements(rawLevel, {
      deliveryVolume: components.deliveryVolume,
      customerRating: components.customerRating,
      completionRate: components.completionRate,
    })) {
      effectiveLevel = rawLevel;
      levelChanged = true;
      changeReason = 'score_upgrade';
    } else {
      effectiveLevel = previousLevel; // Doesn't meet min requirements
    }
  } else if (isDowngrade) {
    // Downgrade hysteresis: require consecutive days below threshold
    const isLocked = profile.levelLockedUntil && profile.levelLockedUntil > now;
    if (isLocked) {
      effectiveLevel = previousLevel; // Lock still active
    } else {
      // Increment consecutive days below threshold
      const newConsecutiveDays = (profile.consecutiveDaysBelowThreshold || 0) + 1;

      if (newConsecutiveDays >= DOWNGRADE_CONSECUTIVE_DAYS_REQUIRED) {
        effectiveLevel = rawLevel;
        levelChanged = true;
        changeReason = 'score_downgrade';
      } else {
        effectiveLevel = previousLevel; // Not enough consecutive days
        // Update the counter
        await prisma.riderPartnerProfile.update({
          where: { riderId },
          data: { consecutiveDaysBelowThreshold: newConsecutiveDays },
        });
      }
    }
  }
  // If rawLevel === previousLevel (no change), reset downgrade counter
  if (!isDowngrade && !isNewProfile) {
    if (profile.consecutiveDaysBelowThreshold > 0) {
      await prisma.riderPartnerProfile.update({
        where: { riderId },
        data: { consecutiveDaysBelowThreshold: 0 },
      });
    }
  }

  // ── Persist updated profile ──
  const lockUntil = (levelChanged && changeReason === 'score_upgrade')
    ? new Date(now.getTime() + UPGRADE_LOCK_DAYS * 24 * 60 * 60 * 1000)
    : profile.levelLockedUntil;

  const updatedProfile = await prisma.riderPartnerProfile.update({
    where: { riderId },
    data: {
      partnerScore,
      partnerLevel: effectiveLevel,
      scoreWindowStart: windowStart,
      scoreWindowEnd: windowEnd,
      lastEvaluatedAt: now,
      levelLockedUntil: lockUntil,
      // Reset downgrade counter if level changed
      consecutiveDaysBelowThreshold: levelChanged ? 0 : undefined,
      downgradeEligibleAt: (isDowngrade && !levelChanged)
        ? (profile.downgradeEligibleAt || new Date(now.getTime() + DOWNGRADE_CONSECUTIVE_DAYS_REQUIRED * 24 * 60 * 60 * 1000))
        : (isDowngrade ? profile.downgradeEligibleAt : null),
      // Component metrics snapshot
      onTimeRate: components.onTimeRate,
      completionRate: components.completionRate,
      customerRating: components.customerRating,
      deliveryVolume: components.deliveryVolume,
      acceptanceRate: components.acceptanceRate,
    },
  });

  // ── Record level history if changed ──
  let levelHistoryEntry = null;
  if (levelChanged) {
    levelHistoryEntry = await prisma.riderLevelHistory.create({
      data: {
        riderId,
        fromLevel: previousLevel,
        toLevel: effectiveLevel,
        score: partnerScore,
        reason: changeReason,
        changedAt: now,
        lockUntil: lockUntil || null,
      },
    });

    console.log(
      `[ScoreEngine] Rider ${riderId}: ${previousLevel} → ${effectiveLevel} ` +
      `(score=${partnerScore}, reason=${changeReason})`
    );

    // Non-blocking notification
    const { notifyLevelChange } = require('./rider_incentive_notifications');
    notifyLevelChange(riderId, previousLevel, effectiveLevel, changeReason).catch(() => {});
  }

  return {
    profile: updatedProfile,
    scoreResult,
    levelChanged,
    previousLevel,
    effectiveLevel,
    changeReason,
    levelHistoryEntry,
  };
};

/**
 * Get the next level target info for a rider (for UI display).
 *
 * @param {string} currentLevel
 * @param {number} currentScore
 * @returns {Object|null} Next level info or null if at max
 */
const getNextLevelTarget = (currentLevel, currentScore) => {
  const levels = ['L1', 'L2', 'L3', 'L4', 'L5'];
  const currentIndex = levels.indexOf(currentLevel);

  if (currentIndex >= levels.length - 1) return null; // Already at L5

  const nextLevel = levels[currentIndex + 1];
  const nextThreshold = LEVEL_THRESHOLDS.find((t) => t.level === nextLevel);
  const requirements = LEVEL_MIN_REQUIREMENTS[nextLevel];

  return {
    nextLevel,
    scoreRequired: nextThreshold?.min || 0,
    scoreGap: Math.max(0, (nextThreshold?.min || 0) - currentScore),
    requirements: requirements || null,
    multiplier: LEVEL_MULTIPLIERS[nextLevel],
    dispatchBonus: DISPATCH_PRIORITY_BONUS[nextLevel],
  };
};

module.exports = {
  // Core computation
  computeRiderScore,
  evaluateRiderPartnerLevel,
  computeAcceptanceRate,
  computeBayesianRating,

  // Constants (exported for dispatch integration and incentive engine)
  SCORE_WEIGHTS,
  LEVEL_THRESHOLDS,
  LEVEL_MIN_REQUIREMENTS,
  LEVEL_MULTIPLIERS,
  DISPATCH_PRIORITY_BONUS,
  ROLLING_WINDOW_DAYS,
  UPGRADE_LOCK_DAYS,
  DOWNGRADE_CONSECUTIVE_DAYS_REQUIRED,
  VOLUME_100_PERCENTILE,

  // Helpers
  scoreToLevel,
  meetsMinRequirements,
  getNextLevelTarget,
  normalize,
};
