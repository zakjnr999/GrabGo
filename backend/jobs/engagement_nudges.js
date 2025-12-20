const cron = require('node-cron');
const { processFavoritesNudges } = require('../services/favorites_nudge_service');

/**
 * Engagement Nudges Cron Jobs
 * 
 * Schedules personalized engagement notifications
 */

/**
 * Initialize all engagement nudge cron jobs
 * @param {Object} io - Socket.io instance
 */
const initializeEngagementNudges = (io) => {
    console.log('📅 Initializing engagement nudge jobs...');

    // Favorites nudge - 10:30 AM GMT daily
    cron.schedule('30 10 * * *', async () => {
        console.log('\n⭐ FAVORITES NUDGE - Checking for eligible users...');
        await processFavoritesNudges();
    }, {
        timezone: 'GMT'
    });
    console.log('✅ Favorites nudges scheduled (10:30 AM GMT daily)');

    // Note: Reorder suggestions and Re-engagement nudges will be added in subsequent steps
};

module.exports = {
    initializeEngagementNudges
};
