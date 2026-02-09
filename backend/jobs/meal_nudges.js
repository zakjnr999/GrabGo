const cron = require('node-cron');
const { processMealNudges, resetWeeklyCounters } = require('../services/meal_nudge_service');
const cache = require('../utils/cache');

/**
 * Meal-Time Nudges Cron Jobs
 * 
 * Schedules meal-time notifications for breakfast, lunch, and dinner
 * All times are in GMT (Ghana timezone)
 */

/**
 * Initialize all meal nudge cron jobs
 * @param {Object} io - Socket.io instance
 */
const initializeMealNudges = (io) => {
    console.log('📅 Initializing meal-time nudge jobs...');

    // Breakfast nudge - 7:30 AM GMT
    cron.schedule('30 7 * * *', async () => {
        console.log('\n🌅 BREAKFAST TIME - Sending nudges...');
        const lock = await cache.acquireLock('job:meal_nudge:breakfast', 10 * 60);
        if (!lock) {
            console.log('⏭️ Breakfast nudges skipped (lock held)');
            return;
        }
        try {
            await processMealNudges('breakfast', io);
        } finally {
            await cache.releaseLock(lock);
        }
    }, {
        timezone: 'GMT'
    });
    console.log('✅ Breakfast nudges scheduled (7:30 AM GMT)');

    // Lunch nudge - 12:30 PM GMT
    cron.schedule('30 12 * * *', async () => {
        console.log('\n🍔 LUNCH TIME - Sending nudges...');
        const lock = await cache.acquireLock('job:meal_nudge:lunch', 10 * 60);
        if (!lock) {
            console.log('⏭️ Lunch nudges skipped (lock held)');
            return;
        }
        try {
            await processMealNudges('lunch', io);
        } finally {
            await cache.releaseLock(lock);
        }
    }, {
        timezone: 'GMT'
    });
    console.log('✅ Lunch nudges scheduled (12:30 PM GMT)');

    // Dinner nudge - 6:30 PM GMT
    cron.schedule('30 18 * * *', async () => {
        console.log('\n🍝 DINNER TIME - Sending nudges...');
        const lock = await cache.acquireLock('job:meal_nudge:dinner', 10 * 60);
        if (!lock) {
            console.log('⏭️ Dinner nudges skipped (lock held)');
            return;
        }
        try {
            await processMealNudges('dinner', io);
        } finally {
            await cache.releaseLock(lock);
        }
    }, {
        timezone: 'GMT'
    });
    console.log('✅ Dinner nudges scheduled (6:30 PM GMT)');

    // Weekly reset - Sunday at midnight GMT
    cron.schedule('0 0 * * 0', async () => {
        console.log('\n🔄 WEEKLY RESET - Resetting meal nudge counters...');
        const lock = await cache.acquireLock('job:meal_nudge:weekly_reset', 10 * 60);
        if (!lock) {
            console.log('⏭️ Weekly meal reset skipped (lock held)');
            return;
        }
        try {
            await resetWeeklyCounters();
        } finally {
            await cache.releaseLock(lock);
        }
    }, {
        timezone: 'GMT'
    });
    console.log('✅ Weekly reset scheduled (Sunday 00:00 GMT)');

    console.log('🎉 All meal-time nudge jobs initialized!\n');
};

module.exports = {
    initializeMealNudges
};
