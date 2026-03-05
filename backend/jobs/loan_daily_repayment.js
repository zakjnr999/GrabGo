const cron = require('node-cron');
const cache = require('../utils/cache');
const { processDailyLoanRepayments } = require('../services/rider_loan_service');

const JOB_NAME = 'loan_daily_repayment';
const LOCK_KEY = `lock:${JOB_NAME}`;
const LOCK_TTL = 120; // 2 min

/**
 * Daily loan repayment job.
 * Runs every day at 04:00 Africa/Accra — deducts dailyDeduction
 * from rider wallets for active loans.
 */
const scheduleLoanDailyRepayment = () => {
  cron.schedule('0 4 * * *', async () => {
    let lock;
    try {
      lock = await cache.acquireLock(LOCK_KEY, LOCK_TTL);
      if (!lock) {
        console.log(`[${JOB_NAME}] Another instance holds the lock – skipping`);
        return;
      }

      console.log(`[${JOB_NAME}] Starting daily loan repayment cycle...`);
      const result = await processDailyLoanRepayments();
      console.log(
        `[${JOB_NAME}] Done: ${result.processed} loans processed, GHS ${result.totalCollected} collected`
      );
    } catch (err) {
      console.error(`[${JOB_NAME}] Error:`, err.message);
    } finally {
      if (lock) await cache.releaseLock(lock).catch(() => {});
    }
  }, {
    timezone: 'Africa/Accra',
  });

  console.log(`✅ ${JOB_NAME} job scheduled (daily 04:00)`);
};

module.exports = { scheduleLoanDailyRepayment };
