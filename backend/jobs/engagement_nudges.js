const cron = require('node-cron');
const { processFavoritesNudges } = require('../services/favorites_nudge_service');
const { processReorderSuggestions } = require('../services/reorder_suggestion_service');

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
        await processFavoritesNudges(io);
    }, {
        timezone: 'GMT'
    });
    console.log('✅ Favorites nudges scheduled (10:30 AM GMT daily)');

    // Reorder Prompt - 4:30 PM GMT daily
    cron.schedule('30 16 * * *', async () => {
        console.log('\n🔄 REORDER PROMPT - Checking for frequent items...');
        await processReorderSuggestions(io);
    }, {
        timezone: 'GMT'
    });
    console.log('✅ Reorder prompts scheduled (4:30 PM GMT daily)');

    // Note: Re-engagement nudges will be added in subsequent steps
};

module.exports = {
    initializeEngagementNudges
};
