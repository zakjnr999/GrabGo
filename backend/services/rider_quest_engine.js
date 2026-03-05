const prisma = require('../config/prisma');
const { LEVEL_MULTIPLIERS } = require('./rider_score_engine');

// ── Window Key Helpers ──
// Africa/Accra is UTC+0, no DST — safe to use UTC dates directly

/**
 * Get the daily window key for a date.
 * @param {Date} [date=new Date()]
 * @returns {string} e.g. "2026-03-05"
 */
const getDailyWindowKey = (date = new Date()) => {
  return date.toISOString().slice(0, 10);
};

/**
 * Get the ISO week key for a date.
 * @param {Date} [date=new Date()]
 * @returns {string} e.g. "2026-W10"
 */
const getWeeklyWindowKey = (date = new Date()) => {
  const d = new Date(date);
  d.setUTCHours(0, 0, 0, 0);
  // ISO week: Thursday determines the week
  d.setUTCDate(d.getUTCDate() + 3 - ((d.getUTCDay() + 6) % 7));
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 4));
  const weekNum = Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(weekNum).padStart(2, '0')}`;
};

/**
 * Get the correct window key based on quest period.
 */
const getWindowKey = (period, date = new Date()) => {
  return period === 'daily' ? getDailyWindowKey(date) : getWeeklyWindowKey(date);
};

/**
 * Get all active quest definitions, optionally filtered by rider level.
 *
 * @param {string} [partnerLevel='L1']
 * @returns {Promise<Array>}
 */
const getAvailableQuests = async (partnerLevel = 'L1') => {
  const levelOrder = ['L1', 'L2', 'L3', 'L4', 'L5'];
  const riderLevelIndex = levelOrder.indexOf(partnerLevel);

  const quests = await prisma.questDefinition.findMany({
    where: { isActive: true },
    orderBy: [{ sortOrder: 'asc' }, { targetCount: 'asc' }],
  });

  // Filter quests the rider is eligible for based on their level
  return quests.filter((q) => {
    const questMinIndex = levelOrder.indexOf(q.minLevel);
    return riderLevelIndex >= questMinIndex;
  });
};

/**
 * Get or create a rider's quest progress for a specific quest + window.
 *
 * @param {string} riderId
 * @param {string} questId
 * @param {string} windowKey
 * @param {number} targetCount
 * @returns {Promise<Object>} Quest progress record
 */
const getOrCreateQuestProgress = async (riderId, questId, windowKey, targetCount) => {
  let progress = await prisma.riderQuestProgress.findUnique({
    where: {
      riderId_questId_windowKey: { riderId, questId, windowKey },
    },
  });

  if (!progress) {
    progress = await prisma.riderQuestProgress.create({
      data: {
        riderId,
        questId,
        windowKey,
        currentCount: 0,
        targetCount,
        status: 'active',
      },
    });
  }

  return progress;
};

/**
 * Increment quest progress for a rider after a delivery.
 * Returns any newly completed quests.
 *
 * @param {string} riderId
 * @param {Object} [options]
 * @param {string} [options.partnerLevel='L1'] - For reward multiplier
 * @returns {Promise<Array>} List of completed quests with reward info
 */
const incrementQuestProgress = async (riderId, options = {}) => {
  const { partnerLevel = 'L1' } = options;
  const now = new Date();
  const completedQuests = [];

  // Get available quests for this rider's level
  const quests = await getAvailableQuests(partnerLevel);

  for (const quest of quests) {
    const windowKey = getWindowKey(quest.period, now);

    // Get or create progress
    const progress = await getOrCreateQuestProgress(riderId, quest.id, windowKey, quest.targetCount);

    // Skip if already completed
    if (progress.status === 'completed') continue;

    // Increment
    const newCount = progress.currentCount + 1;
    const isCompleted = newCount >= quest.targetCount;

    await prisma.riderQuestProgress.update({
      where: { id: progress.id },
      data: {
        currentCount: newCount,
        status: isCompleted ? 'completed' : 'active',
        completedAt: isCompleted ? now : null,
      },
    });

    if (isCompleted) {
      const multiplier = LEVEL_MULTIPLIERS[partnerLevel] || 1.0;
      const finalReward = Math.round(quest.rewardAmount * multiplier * 100) / 100;
      completedQuests.push({
        questId: quest.id,
        questName: quest.name,
        period: quest.period,
        windowKey,
        targetCount: quest.targetCount,
        baseReward: quest.rewardAmount,
        multiplier,
        finalReward,
      });

      // Non-blocking notification
      const { notifyQuestCompleted } = require('./rider_incentive_notifications');
      notifyQuestCompleted(riderId, quest.name, finalReward).catch(() => {});
    }
  }

  return completedQuests;
};

/**
 * Get a rider's current quest progress for all active quests.
 *
 * @param {string} riderId
 * @param {string} [partnerLevel='L1']
 * @returns {Promise<Array>} Progress list with quest details
 */
const getRiderQuestDashboard = async (riderId, partnerLevel = 'L1') => {
  const now = new Date();
  const quests = await getAvailableQuests(partnerLevel);
  const dashboard = [];

  for (const quest of quests) {
    const windowKey = getWindowKey(quest.period, now);
    const progress = await getOrCreateQuestProgress(riderId, quest.id, windowKey, quest.targetCount);

    const multiplier = LEVEL_MULTIPLIERS[partnerLevel] || 1.0;
    const percentComplete = Math.min(100, Math.round((progress.currentCount / quest.targetCount) * 100));

    dashboard.push({
      questId: quest.id,
      name: quest.name,
      description: quest.description,
      period: quest.period,
      windowKey,
      currentCount: progress.currentCount,
      targetCount: quest.targetCount,
      percentComplete,
      status: progress.status,
      completedAt: progress.completedAt,
      baseReward: quest.rewardAmount,
      multiplier,
      finalReward: Math.round(quest.rewardAmount * multiplier * 100) / 100,
      minLevel: quest.minLevel,
    });
  }

  return dashboard;
};

/**
 * Expire quests whose window has passed but are still 'active'.
 * Called by a daily job or on-demand.
 *
 * @returns {Promise<number>} Number of expired quests
 */
const expireStaleQuests = async () => {
  const now = new Date();
  const todayKey = getDailyWindowKey(now);
  const weekKey = getWeeklyWindowKey(now);

  // Daily quests: expire any active progress with windowKey < today
  const dailyExpired = await prisma.riderQuestProgress.updateMany({
    where: {
      status: 'active',
      windowKey: { lt: todayKey },
      quest: { period: 'daily' },
    },
    data: { status: 'expired' },
  });

  // Weekly quests: expire any active progress with windowKey < this week
  const weeklyExpired = await prisma.riderQuestProgress.updateMany({
    where: {
      status: 'active',
      windowKey: { lt: weekKey },
      quest: { period: 'weekly' },
    },
    data: { status: 'expired' },
  });

  const total = dailyExpired.count + weeklyExpired.count;
  if (total > 0) {
    console.log(`[QuestEngine] Expired ${total} stale quests (daily=${dailyExpired.count}, weekly=${weeklyExpired.count})`);
  }

  return total;
};

module.exports = {
  // Core
  incrementQuestProgress,
  expireStaleQuests,

  // Dashboard
  getAvailableQuests,
  getRiderQuestDashboard,

  // Helpers (exported for orchestrator and tests)
  getDailyWindowKey,
  getWeeklyWindowKey,
  getWindowKey,
  getOrCreateQuestProgress,
};
