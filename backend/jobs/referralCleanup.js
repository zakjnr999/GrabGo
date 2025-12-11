const cron = require('node-cron');
const ReferralService = require('../services/ReferralService');

/**
 * Schedule cleanup of expired referrals and credits
 * Runs daily at 2:00 AM
 */
function scheduleReferralCleanup() {
    // Run every day at 2:00 AM
    cron.schedule('0 2 * * *', async () => {
        console.log('🧹 Running referral cleanup job...');
        try {
            await ReferralService.expireOldRecords();
            console.log('✅ Referral cleanup completed');
        } catch (error) {
            console.error('❌ Referral cleanup failed:', error);
        }
    });

    console.log('✅ Referral cleanup job scheduled (daily at 2:00 AM)');
}

module.exports = { scheduleReferralCleanup };
