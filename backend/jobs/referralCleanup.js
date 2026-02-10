const cron = require('node-cron');
const ReferralService = require('../services/referral_service');

function scheduleReferralCleanup() {
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
