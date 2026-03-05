/**
 * Subscription Expiry Job
 *
 * Runs periodically to:
 * 1. Mark active/past_due subscriptions that have passed their currentPeriodEnd as 'expired'
 * 2. Log expiry statistics
 *
 * Run via cron every hour: node jobs/subscription_expiry.js
 */

const { expireStaleSubscriptions } = require('../services/subscription_service');

const run = async () => {
  console.log('🕐 [SUBSCRIPTION_EXPIRY] Starting expiry check...');

  try {
    const count = await expireStaleSubscriptions();
    console.log(`✅ [SUBSCRIPTION_EXPIRY] Done. Expired ${count} subscription(s).`);
  } catch (error) {
    console.error('❌ [SUBSCRIPTION_EXPIRY] Error:', error);
  }
};

// Allow direct execution or import
if (require.main === module) {
  run()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = { run };
