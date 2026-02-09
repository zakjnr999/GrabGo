const cron = require('node-cron');
const { processFavoritesNudges } = require('../services/favorites_nudge_service');
const { processReorderSuggestions } = require('../services/reorder_suggestion_service');
const cache = require('../utils/cache');

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
        const lock = await cache.acquireLock('job:engagement:favorites', 10 * 60);
        if (!lock) {
            console.log('⏭️ Favorites nudges skipped (lock held)');
            return;
        }
        try {
            await processFavoritesNudges(io);
        } finally {
            await cache.releaseLock(lock);
        }
    }, {
        timezone: 'GMT'
    });
    console.log('✅ Favorites nudges scheduled (10:30 AM GMT daily)');

    // Reorder Prompt - 4:30 PM GMT daily
    cron.schedule('30 16 * * *', async () => {
        console.log('\n🔄 REORDER PROMPT - Checking for frequent items...');
        const lock = await cache.acquireLock('job:engagement:reorder', 10 * 60);
        if (!lock) {
            console.log('⏭️ Reorder nudges skipped (lock held)');
            return;
        }
        try {
            await processReorderSuggestions(io);
        } finally {
            await cache.releaseLock(lock);
        }
    }, {
        timezone: 'GMT'
    });
    console.log('✅ Reorder prompts scheduled (4:30 PM GMT daily)');

    // Note: Re-engagement nudges will be added in subsequent steps
};

module.exports = {
    initializeEngagementNudges
};
