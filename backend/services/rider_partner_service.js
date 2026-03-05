const prisma = require('../config/prisma');
const featureFlags = require('../config/feature_flags');
const {
  computeRiderScore,
  evaluateRiderPartnerLevel,
  getNextLevelTarget,
  LEVEL_MULTIPLIERS,
  DISPATCH_PRIORITY_BONUS,
  ROLLING_WINDOW_DAYS,
  LEVEL_MIN_REQUIREMENTS,
} = require('./rider_score_engine');

/**
 * Get or bootstrap a rider's partner profile.
 * If no profile exists, creates one with L1 defaults and computes the initial score.
 *
 * @param {string} riderId - User ID
 * @returns {Promise<Object>} Profile with full breakdown
 */
const getOrCreatePartnerProfile = async (riderId) => {
  let profile = await prisma.riderPartnerProfile.findUnique({
    where: { riderId },
    include: {
      levelHistory: {
        orderBy: { changedAt: 'desc' },
        take: 5,
      },
    },
  });

  if (!profile) {
    // Bootstrap: create a default L1 profile
    profile = await prisma.riderPartnerProfile.create({
      data: {
        riderId,
        partnerScore: 0,
        partnerLevel: 'L1',
      },
      include: {
        levelHistory: true,
      },
    });
  }

  return profile;
};

/**
 * Build the full partner dashboard payload for the rider app.
 *
 * @param {string} riderId - User ID
 * @returns {Promise<Object>} Dashboard payload
 */
const getPartnerDashboard = async (riderId) => {
  const profile = await getOrCreatePartnerProfile(riderId);

  const now = new Date();
  const windowEnd = new Date(now);
  const windowStart = new Date(now);
  windowStart.setDate(windowStart.getDate() - ROLLING_WINDOW_DAYS);

  // Compute live score (may differ slightly from last nightly recalc)
  let liveScore = null;
  try {
    liveScore = await computeRiderScore(riderId, windowStart, windowEnd);
  } catch (err) {
    console.error(`[PartnerService] Live score computation failed for ${riderId}:`, err.message);
  }

  const currentLevel = profile.partnerLevel;
  const multiplier = LEVEL_MULTIPLIERS[currentLevel] || 1.0;
  const dispatchBonus = DISPATCH_PRIORITY_BONUS[currentLevel] || 0;
  const nextTarget = getNextLevelTarget(currentLevel, profile.partnerScore);
  const requirements = LEVEL_MIN_REQUIREMENTS[currentLevel] || null;

  // Level lock info
  const isLocked = profile.levelLockedUntil && profile.levelLockedUntil > now;
  const lockDaysRemaining = isLocked
    ? Math.ceil((profile.levelLockedUntil.getTime() - now.getTime()) / (24 * 60 * 60 * 1000))
    : 0;

  return {
    profile: {
      riderId: profile.riderId,
      partnerLevel: currentLevel,
      partnerScore: profile.partnerScore,
      lastEvaluatedAt: profile.lastEvaluatedAt,
      scoreWindowStart: profile.scoreWindowStart,
      scoreWindowEnd: profile.scoreWindowEnd,
    },
    level: {
      current: currentLevel,
      multiplier,
      dispatchBonus,
      isLocked,
      lockDaysRemaining,
      levelLockedUntil: profile.levelLockedUntil,
    },
    metrics: {
      onTimeRate: profile.onTimeRate,
      completionRate: profile.completionRate,
      customerRating: profile.customerRating,
      deliveryVolume: profile.deliveryVolume,
      acceptanceRate: profile.acceptanceRate,
    },
    liveScore: liveScore
      ? {
          partnerScore: liveScore.partnerScore,
          components: liveScore.components,
        }
      : null,
    nextLevel: nextTarget,
    currentLevelRequirements: requirements,
    recentHistory: profile.levelHistory.map((h) => ({
      from: h.fromLevel,
      to: h.toLevel,
      score: h.score,
      reason: h.reason,
      changedAt: h.changedAt,
    })),
  };
};

/**
 * Get the score breakdown for a rider (admin/debug view).
 *
 * @param {string} riderId - User ID
 * @returns {Promise<Object>} Detailed score breakdown with raw metrics
 */
const getScoreBreakdown = async (riderId) => {
  const now = new Date();
  const windowEnd = new Date(now);
  const windowStart = new Date(now);
  windowStart.setDate(windowStart.getDate() - ROLLING_WINDOW_DAYS);

  const scoreResult = await computeRiderScore(riderId, windowStart, windowEnd);

  return {
    riderId,
    windowStart,
    windowEnd,
    windowDays: ROLLING_WINDOW_DAYS,
    ...scoreResult,
  };
};

/**
 * Force-recalculate a rider's partner level (admin action).
 *
 * @param {string} riderId - User ID
 * @param {Object} [options]
 * @param {boolean} [options.force] - Force level application ignoring hysteresis
 * @param {string} [options.reason] - Override reason for history
 * @returns {Promise<Object>} Evaluation result
 */
const recalculateRiderLevel = async (riderId, options = {}) => {
  return evaluateRiderPartnerLevel(riderId, {
    forceLevel: options.force || false,
    reason: options.reason || 'manual_recalculation',
  });
};

/**
 * Get the level history for a rider.
 *
 * @param {string} riderId - User ID
 * @param {number} [limit=20]
 * @returns {Promise<Array>} Level history entries
 */
const getLevelHistory = async (riderId, limit = 20) => {
  return prisma.riderLevelHistory.findMany({
    where: { riderId },
    orderBy: { changedAt: 'desc' },
    take: limit,
  });
};

/**
 * Get aggregate partner level distribution (admin analytics).
 *
 * @returns {Promise<Object>} Distribution counts
 */
const getLevelDistribution = async () => {
  const distribution = await prisma.riderPartnerProfile.groupBy({
    by: ['partnerLevel'],
    _count: { riderId: true },
    _avg: { partnerScore: true },
  });

  const total = distribution.reduce((sum, d) => sum + d._count.riderId, 0);

  return {
    total,
    levels: distribution.map((d) => ({
      level: d.partnerLevel,
      count: d._count.riderId,
      avgScore: Math.round((d._avg.partnerScore || 0) * 10) / 10,
      percentage: total > 0 ? Math.round((d._count.riderId / total) * 1000) / 10 : 0,
    })),
  };
};

module.exports = {
  getOrCreatePartnerProfile,
  getPartnerDashboard,
  getScoreBreakdown,
  recalculateRiderLevel,
  getLevelHistory,
  getLevelDistribution,
};
