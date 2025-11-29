/**
 * Cron job for automatic status cleanup
 * Runs every hour to deactivate expired statuses and clean up Cloudinary images
 */

const cron = require('node-cron');
const cloudinary = require('cloudinary').v2;
const Status = require('../models/Status');

// Track if cron is already scheduled
let isScheduled = false;

/**
 * Cleanup expired statuses
 * - Marks expired statuses as inactive
 * - Deletes associated Cloudinary images
 */
const cleanupExpiredStatuses = async () => {
    console.log('[StatusCleanup] Starting cleanup job...');

    try {
        const result = await Status.cleanupExpired(cloudinary);

        console.log(`[StatusCleanup] Completed: ${result.statusesDeactivated} statuses deactivated, ${result.cloudinaryImagesDeleted} images deleted`);

        return result;
    } catch (error) {
        console.error('[StatusCleanup] Error:', error.message);
        throw error;
    }
};

/**
 * Schedule the cleanup cron job
 * Runs every hour at minute 0 (e.g., 1:00, 2:00, 3:00...)
 */
const scheduleCleanup = () => {
    if (isScheduled) {
        console.log('[StatusCleanup] Cron job already scheduled');
        return;
    }

    // Run every hour at minute 0
    cron.schedule('0 * * * *', async () => {
        try {
            await cleanupExpiredStatuses();
        } catch (error) {
            // Log error but don't crash the server
            console.error('[StatusCleanup] Cron job failed:', error.message);
        }
    }, {
        scheduled: true,
        timezone: 'UTC'
    });

    isScheduled = true;
    console.log('[StatusCleanup] Cron job scheduled to run every hour');
};

/**
 * Schedule a more frequent cleanup for development/testing
 * Runs every 15 minutes
 */
const scheduleFrequentCleanup = () => {
    if (isScheduled) {
        console.log('[StatusCleanup] Cron job already scheduled');
        return;
    }

    // Run every 15 minutes
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
