const prisma = require('../config/prisma');
const { LEVEL_MULTIPLIERS } = require('./rider_score_engine');

/**
 * Ensure a rider has milestone state records for all active milestones.
 * Creates missing states with currentCount from Prisma Rider.totalDeliveries.
 *
 * @param {string} riderId
 * @returns {Promise<Array>} All milestone states for the rider
 */
const ensureMilestoneStates = async (riderId) => {
  const activeMilestones = await prisma.milestoneDefinition.findMany({
    where: { isActive: true },
    orderBy: [{ sortOrder: 'asc' }, { targetCount: 'asc' }],
  });

  if (activeMilestones.length === 0) return [];

  // Get existing states
  const existingStates = await prisma.riderMilestoneState.findMany({
    where: { riderId },
    include: { milestone: true },
  });
  const existingMap = new Map(existingStates.map((s) => [s.milestoneId, s]));

  // Get rider's lifetime deliveries for backfill
  const rider = await prisma.rider.findFirst({
    where: { userId: riderId },
    select: { totalDeliveries: true },
  });
  const lifetimeDeliveries = rider?.totalDeliveries || 0;

  const states = [];

  for (const milestone of activeMilestones) {
    let state = existingMap.get(milestone.id);

    if (!state) {
      // Create new state with backfilled count
      const alreadyCompleted = lifetimeDeliveries >= milestone.targetCount;
      state = await prisma.riderMilestoneState.create({
        data: {
          riderId,
          milestoneId: milestone.id,
          currentCount: lifetimeDeliveries,
          isCompleted: alreadyCompleted,
          completedAt: alreadyCompleted ? new Date() : null,
        },
        include: { milestone: true },
      });
    }

    states.push(state);
  }

  return states;
};

/**
 * Increment milestone progress for a rider after a delivery.
 * Returns any newly completed milestones with reward info.
 *
 * @param {string} riderId
 * @param {Object} [options]
 * @param {string} [options.partnerLevel='L1']
 * @returns {Promise<Array>} List of newly completed milestones
 */
const incrementMilestoneProgress = async (riderId, options = {}) => {
  const { partnerLevel = 'L1' } = options;
  const now = new Date();
  const completedMilestones = [];

  const states = await ensureMilestoneStates(riderId);

  for (const state of states) {
    // Skip already completed milestones
    if (state.isCompleted) continue;

    const newCount = state.currentCount + 1;
    const milestone = state.milestone;
    const isCompleted = newCount >= milestone.targetCount;

    await prisma.riderMilestoneState.update({
      where: { id: state.id },
      data: {
        currentCount: newCount,
        isCompleted,
        completedAt: isCompleted ? now : null,
      },
    });

    if (isCompleted) {
      const multiplier = LEVEL_MULTIPLIERS[partnerLevel] || 1.0;
      const finalAmount = Math.round(milestone.rewardAmount * multiplier * 100) / 100;

      // Record reward history
      await prisma.riderMilestoneRewardHistory.create({
        data: {
          riderId,
          milestoneId: milestone.id,
          stateId: state.id,
          rewardAmount: milestone.rewardAmount,
          multiplier,
          finalAmount,
        },
      });

      completedMilestones.push({
        milestoneId: milestone.id,
        name: milestone.name,
        description: milestone.description,
        targetCount: milestone.targetCount,
        badgeIcon: milestone.badgeIcon,
        baseReward: milestone.rewardAmount,
        multiplier,
        finalReward: finalAmount,
      });

      console.log(
        `[MilestoneEngine] Rider ${riderId}: completed "${milestone.name}" ` +
        `(${milestone.targetCount} deliveries), reward GHS ${finalAmount}`
      );

      // Non-blocking notification
      const { notifyMilestoneReached } = require('./rider_incentive_notifications');
      notifyMilestoneReached(riderId, milestone.targetCount, finalAmount, milestone.name).catch(() => {});
    }
  }

  return completedMilestones;
};

/**
 * Get milestone dashboard data for the rider app.
 *
 * @param {string} riderId
 * @param {string} [partnerLevel='L1']
 * @returns {Promise<Object>} Milestone display data
 */
const getRiderMilestoneDashboard = async (riderId, partnerLevel = 'L1') => {
  const states = await ensureMilestoneStates(riderId);
  const multiplier = LEVEL_MULTIPLIERS[partnerLevel] || 1.0;

  const milestones = states.map((state) => {
    const milestone = state.milestone;
    const percentComplete = Math.min(
      100,
      Math.round((state.currentCount / milestone.targetCount) * 100)
    );

    return {
      milestoneId: milestone.id,
      name: milestone.name,
      description: milestone.description,
      badgeIcon: milestone.badgeIcon,
      currentCount: state.currentCount,
      targetCount: milestone.targetCount,
      percentComplete,
      isCompleted: state.isCompleted,
      completedAt: state.completedAt,
      baseReward: milestone.rewardAmount,
      finalReward: Math.round(milestone.rewardAmount * multiplier * 100) / 100,
    };
  });

  // Separate completed and in-progress
  const completed = milestones.filter((m) => m.isCompleted);
  const inProgress = milestones.filter((m) => !m.isCompleted);

  // Find the next milestone to achieve
  const nextMilestone = inProgress.length > 0 ? inProgress[0] : null;

  // Recent rewards
  const recentRewards = await prisma.riderMilestoneRewardHistory.findMany({
    where: { riderId },
    orderBy: { awardedAt: 'desc' },
    take: 10,
    include: {
      state: {
        include: { milestone: { select: { name: true, badgeIcon: true } } },
      },
    },
  });

  return {
    totalCompleted: completed.length,
    totalAvailable: milestones.length,
    nextMilestone,
    milestones,
    recentRewards: recentRewards.map((r) => ({
      milestoneName: r.state?.milestone?.name,
      badgeIcon: r.state?.milestone?.badgeIcon,
      rewardAmount: r.finalAmount,
      awardedAt: r.awardedAt,
    })),
  };
};

module.exports = {
  incrementMilestoneProgress,
  ensureMilestoneStates,
  getRiderMilestoneDashboard,
};
