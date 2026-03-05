const cron = require('node-cron');
const cache = require('../utils/cache');
const featureFlags = require('../config/feature_flags');
const { approvePendingIncentives, closeExpiredBudgetWindows } = require('../services/rider_budget_service');
const { expireStaleQuests } = require('../services/rider_quest_engine');

const JOB_NAME = 'incentive_budget_approval';
const LOCK_KEY = `job:${JOB_NAME}`;
const LOCK_TTL_SECONDS = 60;

let isRunning = false;

/**
 * Run the budget approval cycle.
 * - Approve pending incentives against daily budget
 * - Close expired budget windows
 * - Expire stale quests
 */
const runBudgetApprovalCycle = async () => {
  if (isRunning) return;
  if (!featureFlags.isRiderIncentivesEnabled) return;

  let lock = null;
  try {
    lock = await cache.acquireLock(LOCK_KEY, LOCK_TTL_SECONDS);
    if (!lock) return;

    isRunning = true;

    // 1. Approve pending incentives
    const approvalResult = await approvePendingIncentives();

    // 2. Close expired budget windows
    await closeExpiredBudgetWindows();

    // 3. Expire stale quests (daily/weekly window rollover)
    await expireStaleQuests();

    if (approvalResult.approved > 0) {
      console.log(
        `[${JOB_NAME}] Cycle complete: approved=${approvalResult.approved}, ` +
        `amount=GHS ${approvalResult.totalAmount}, remaining=GHS ${approvalResult.remaining}`
      );
    }
  } catch (err) {
    console.error(`[${JOB_NAME}] Error:`, err);
  } finally {
    isRunning = false;
    if (lock) {
      await cache.releaseLock(lock).catch(() => {});
    }
  }
};

/**
 * Schedule the budget approval job.
 * Runs every 5 minutes to keep incentive approvals near real-time.
 */
const scheduleIncentiveBudgetApproval = () => {
  // Every 5 minutes
  cron.schedule('*/5 * * * *', async () => {
    await runBudgetApprovalCycle();
  }, {
    timezone: 'Africa/Accra',
  });

  console.log(`✅ ${JOB_NAME} job scheduled (every 5 minutes)`);
};

module.exports = {
  scheduleIncentiveBudgetApproval,
  runBudgetApprovalCycle,
};
