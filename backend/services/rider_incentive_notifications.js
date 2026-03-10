/**
 * Rider Partner & Incentive Notification Service
 *
 * Centralises all notification triggers for the partner/incentive system.
 * Uses the existing createNotification + Socket.IO pattern.
 *
 * Notification types added to the Notification model enum:
 *   partner_level_change, quest_completed, streak_reward,
 *   delivery_milestone, incentive_payout, peak_hour_bonus
 */

const { createNotification } = require('./notification_service');
const { getIO } = require('../utils/socket');
const { createScopedLogger } = require('../utils/logger');
const console = createScopedLogger('rider_incentive_notifications');

// ── helpers ─────────────────────────────────────────────────────────

const LEVEL_LABELS = {
  L1: 'Bronze',
  L2: 'Silver',
  L3: 'Gold',
  L4: 'Platinum',
  L5: 'Diamond',
};

const LEVEL_EMOJI = {
  L1: '🥉',
  L2: '🥈',
  L3: '🥇',
  L4: '💎',
  L5: '👑',
};

const formatGHS = (amount) => `GHS ${Number(amount).toFixed(2)}`;

const io = () => {
  try {
    return getIO();
  } catch {
    return null;
  }
};

// ── 1. Partner level change ─────────────────────────────────────────

/**
 * Notify rider of a partner level upgrade or downgrade.
 *
 * @param {string} riderId
 * @param {string} oldLevel   e.g. 'L2'
 * @param {string} newLevel   e.g. 'L3'
 * @param {string} reason     'score_upgrade' | 'score_downgrade' | 'manual'
 */
const notifyLevelChange = async (riderId, oldLevel, newLevel, reason) => {
  const isUpgrade = newLevel > oldLevel;
  const emoji = LEVEL_EMOJI[newLevel] || '🏅';
  const newLabel = LEVEL_LABELS[newLevel] || newLevel;
  const oldLabel = LEVEL_LABELS[oldLevel] || oldLevel;

  const title = isUpgrade
    ? `${emoji} Promoted to ${newLabel}!`
    : `📉 Level changed to ${newLabel}`;

  const message = isUpgrade
    ? `Great work! You've been promoted from ${oldLabel} to ${newLabel}. Enjoy better perks, priority dispatch, and more free withdrawals.`
    : `Your partner level has changed from ${oldLabel} to ${newLabel}. Keep completing deliveries to level up again!`;

  try {
    await createNotification(
      riderId,
      'partner_level_change',
      title,
      message,
      {
        oldLevel,
        newLevel,
        reason,
        route: '/partner/dashboard',
      },
      io()
    );
  } catch (err) {
    console.error(`[IncentiveNotify] Level change notification failed for ${riderId}:`, err.message);
  }
};

// ── 2. Quest completed ──────────────────────────────────────────────

/**
 * Notify rider that a quest has been completed.
 *
 * @param {string} riderId
 * @param {string} questName   e.g. 'Weekend Warrior'
 * @param {number} rewardAmount
 */
const notifyQuestCompleted = async (riderId, questName, rewardAmount) => {
  try {
    await createNotification(
      riderId,
      'quest_completed',
      `🎯 Quest Complete: ${questName}`,
      `You completed "${questName}" and earned ${formatGHS(rewardAmount)}! The reward will be credited after budget approval.`,
      {
        questName,
        rewardAmount: String(rewardAmount),
        route: '/partner/quests',
      },
      io()
    );
  } catch (err) {
    console.error(`[IncentiveNotify] Quest notification failed for ${riderId}:`, err.message);
  }
};

// ── 3. Streak reward ────────────────────────────────────────────────

/**
 * Notify rider of a streak reward threshold.
 *
 * @param {string} riderId
 * @param {number} streakDays
 * @param {number} rewardAmount
 */
const notifyStreakReward = async (riderId, streakDays, rewardAmount) => {
  try {
    await createNotification(
      riderId,
      'streak_reward',
      `🔥 ${streakDays}-Day Streak!`,
      `Amazing consistency! Your ${streakDays}-day delivery streak earned you ${formatGHS(rewardAmount)}. Keep it going!`,
      {
        streakDays: String(streakDays),
        rewardAmount: String(rewardAmount),
        route: '/partner/streaks',
      },
      io()
    );
  } catch (err) {
    console.error(`[IncentiveNotify] Streak notification failed for ${riderId}:`, err.message);
  }
};

// ── 4. Delivery milestone ───────────────────────────────────────────

/**
 * Notify rider of reaching a lifetime delivery milestone.
 *
 * @param {string} riderId
 * @param {number} milestoneCount  e.g. 100, 500, 1000
 * @param {number} rewardAmount
 * @param {string} badgeName       e.g. 'Century Rider'
 */
const notifyMilestoneReached = async (riderId, milestoneCount, rewardAmount, badgeName) => {
  try {
    await createNotification(
      riderId,
      'delivery_milestone',
      `🏆 Milestone: ${milestoneCount} Deliveries!`,
      `${badgeName} unlocked! You've completed ${milestoneCount} deliveries and earned ${formatGHS(rewardAmount)}. Incredible achievement!`,
      {
        milestoneCount: String(milestoneCount),
        rewardAmount: String(rewardAmount),
        badgeName,
        route: '/partner/milestones',
      },
      io()
    );
  } catch (err) {
    console.error(`[IncentiveNotify] Milestone notification failed for ${riderId}:`, err.message);
  }
};

// ── 5. Peak-hour bonus ──────────────────────────────────────────────

/**
 * Notify rider of a peak-hour delivery bonus.
 *
 * @param {string} riderId
 * @param {string} windowName  e.g. 'Lunch Rush'
 * @param {number} bonusAmount
 */
const notifyPeakHourBonus = async (riderId, windowName, bonusAmount) => {
  try {
    await createNotification(
      riderId,
      'peak_hour_bonus',
      `⚡ Peak-Hour Bonus: ${windowName}`,
      `You earned a ${formatGHS(bonusAmount)} bonus for delivering during ${windowName}!`,
      {
        windowName,
        bonusAmount: String(bonusAmount),
        route: '/partner/earnings',
      },
      io()
    );
  } catch (err) {
    console.error(`[IncentiveNotify] Peak hour notification failed for ${riderId}:`, err.message);
  }
};

// ── 6. Incentive payout ─────────────────────────────────────────────

/**
 * Notify rider that incentive earnings have been paid out to their wallet.
 *
 * @param {string} riderId
 * @param {number} amount
 * @param {string} payoutType  'instant' | 'weekly_auto'
 */
const notifyIncentivePayout = async (riderId, amount, payoutType) => {
  const typeLabel = payoutType === 'weekly_auto' ? 'Weekly auto-payout' : 'Instant withdrawal';

  try {
    await createNotification(
      riderId,
      'incentive_payout',
      `💰 ${typeLabel}: ${formatGHS(amount)}`,
      `${formatGHS(amount)} in incentive earnings has been ${payoutType === 'weekly_auto' ? 'automatically credited to' : 'withdrawn from'} your wallet.`,
      {
        amount: String(amount),
        payoutType,
        route: '/wallet',
      },
      io()
    );
  } catch (err) {
    console.error(`[IncentiveNotify] Payout notification failed for ${riderId}:`, err.message);
  }
};

module.exports = {
  notifyLevelChange,
  notifyQuestCompleted,
  notifyStreakReward,
  notifyMilestoneReached,
  notifyPeakHourBonus,
  notifyIncentivePayout,

  // Re-export labels for other modules
  LEVEL_LABELS,
  LEVEL_EMOJI,
};
