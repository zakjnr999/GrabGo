/**
 * Weekly Auto-Payout Job
 *
 * Runs every Monday at 06:00 Africa/Accra to settle approved incentive
 * earnings into rider wallets.
 *
 * - Processes all riders with 'available' ledger entries
 * - Credits wallet, creates transaction, marks ledger as 'paid_out'
 * - Only runs for riders whose partner level enables weekly auto-payout
 */

const cron = require('node-cron');
const cache = require('../utils/cache');
const { processWeeklyAutoPayouts } = require('../services/rider_payout_service');

const JOB_LOCK_KEY = 'lock:weekly-payout';
const JOB_LOCK_TTL = 600; // 10 min

const scheduleWeeklyPayout = () => {
  // Every Monday at 06:00 UTC (Africa/Accra = UTC+0)
  cron.schedule('0 6 * * 1', async () => {
    let lock;
    try {
      lock = await cache.acquireLock(JOB_LOCK_KEY, JOB_LOCK_TTL);
      if (!lock) {
        console.log('[WeeklyPayout] Another instance holds the lock – skipping');
        return;
      }

      console.log('[WeeklyPayout] Starting weekly auto-payout cycle...');
      const result = await processWeeklyAutoPayouts();
      console.log(
        `[WeeklyPayout] Done: ${result.payoutsCreated} payouts, GHS ${result.totalPaidOut}`
      );
    } catch (err) {
      console.error('[WeeklyPayout] Error:', err.message);
    } finally {
      if (lock) await cache.releaseLock(lock);
    }
  });

  console.log('[WeeklyPayout] Scheduled – Monday 06:00 UTC');
};

module.exports = { scheduleWeeklyPayout };
