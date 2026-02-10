const cron = require('node-cron');
const cloudinary = require('cloudinary').v2;
const StatusService = require('../services/status_service');

let isScheduled = false;

const cleanupExpiredStatuses = async () => {
    console.log('[StatusCleanup] Starting cleanup job...');

    try {
        const result = await StatusService.cleanupExpired(cloudinary);

        console.log(`[StatusCleanup] Completed: ${result.statusesDeactivated} statuses deactivated, ${result.cloudinaryImagesDeleted} images deleted`);

        return result;
    } catch (error) {
        console.error('[StatusCleanup] Error:', error.message);
        throw error;
    }
};

const scheduleCleanup = () => {
    if (isScheduled) {
        console.log('[StatusCleanup] Cron job already scheduled');
        return;
    }

    cron.schedule('0 * * * *', async () => {
        try {
            await cleanupExpiredStatuses();
        } catch (error) {
            console.error('[StatusCleanup] Cron job failed:', error.message);
        }
    }, {
        scheduled: true,
        timezone: 'UTC'
    });

    isScheduled = true;
    console.log('[StatusCleanup] Cron job scheduled to run every hour');
};

const scheduleFrequentCleanup = () => {
    if (isScheduled) {
        console.log('[StatusCleanup] Cron job already scheduled');
        return;
    }

    cron.schedule('*/15 * * * *', async () => {
        try {
            await cleanupExpiredStatuses();
        } catch (error) {
            console.error('[StatusCleanup] Cron job failed:', error.message);
        }
    }, {
        scheduled: true,
        timezone: 'UTC'
    });

    isScheduled = true;
    console.log('[StatusCleanup] Cron job scheduled to run every 15 minutes');
};

module.exports = {
    cleanupExpiredStatuses,
    scheduleCleanup,
    scheduleFrequentCleanup
};
