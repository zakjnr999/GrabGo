const cron = require('node-cron');
const { processScheduledNotifications } = require('../services/scheduled_notification_service');
const cache = require('../utils/cache');
const { createScopedLogger } = require('../utils/logger');

const console = createScopedLogger('notification_scheduler_job');

const initializeScheduler = (io) => {
    console.log('📅 Initializing notification scheduler...');

    cron.schedule('* * * * *', async () => {
        try {
            const lock = await cache.acquireLock('job:notification_scheduler', 50);
            if (!lock) {
                console.log('⏭️ Scheduler skipped (lock held)');
                return;
            }
            try {
                const result = await processScheduledNotifications(io);
                if (result.processed > 0) {
                    console.log(`📊 Scheduler run: ${result.sent} sent, ${result.failed} failed`);
                }
            } finally {
                await cache.releaseLock(lock);
            }
        } catch (error) {
            console.error('❌ Scheduler error:', error.message);
        }
    });

    console.log('✅ Notification scheduler started (runs every minute)');
};

const triggerScheduler = async (io) => {
    console.log('🔧 Manually triggering scheduler...');
    try {
        const lock = await cache.acquireLock('job:notification_scheduler', 50);
        if (!lock) {
            return { processed: 0, sent: 0, failed: 0, skipped: true };
        }
        let result;
        try {
            result = await processScheduledNotifications(io);
        } finally {
            await cache.releaseLock(lock);
        }
        console.log(`📊 Manual run: ${result.sent} sent, ${result.failed} failed`);
        return result;
    } catch (error) {
        console.error('❌ Manual trigger error:', error.message);
        throw error;
    }
};

module.exports = {
    initializeScheduler,
    triggerScheduler
};
