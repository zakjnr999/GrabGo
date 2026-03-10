const cron = require('node-cron');
const { processFavoritesNudges } = require('../services/favorites_nudge_service');
const { processReorderSuggestions } = require('../services/reorder_suggestion_service');
const cache = require('../utils/cache');
const { createScopedLogger } = require('../utils/logger');

const console = createScopedLogger('engagement_nudges_job');

const initializeEngagementNudges = (io) => {
    console.log('📅 Initializing engagement nudge jobs...');

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
};

module.exports = {
    initializeEngagementNudges
};
