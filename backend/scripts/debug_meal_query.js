/**
 * Debug Meal Nudge Query
 * 
 * Checks what the actual query criteria are finding
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');

const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB\n');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

const debugQuery = async () => {
    await connectDB();

    try {
        const now = new Date();
        const threeDaysAgo = new Date(now - 3 * 24 * 60 * 60 * 1000);
        const oneDayAgo = new Date(now - 24 * 60 * 60 * 1000);

        console.log('🔍 Query Criteria:');
        console.log(`   Now: ${now}`);
        console.log(`   3 days ago: ${threeDaysAgo}`);
        console.log(`   1 day ago: ${oneDayAgo}\n`);

        // Find user
        const user = await User.findOne({ email: 'zakjnr5@gmail.com' });

        if (!user) {
            console.log('❌ User not found');
            process.exit(1);
        }

        console.log('📦 User Data:');
        console.log(`   Email: ${user.email}`);
        console.log(`   lastOrderDate: ${user.lastOrderDate}`);
        console.log(`   lastOrderDate < threeDaysAgo: ${user.lastOrderDate < threeDaysAgo}`);
        console.log(`   mealTimePreferences.enabled: ${user.mealTimePreferences?.enabled}`);
        console.log(`   mealTimePreferences.lunch: ${user.mealTimePreferences?.lunch}`);
        console.log(`   notificationSettings.promoNotifications: ${user.notificationSettings?.promoNotifications}`);
        console.log(`   lastMealNudgeAt: ${user.lastMealNudgeAt}`);
        console.log(`   mealNudgesThisWeek: ${user.mealNudgesThisWeek}`);
        console.log(`   maxPerWeek: ${user.mealTimePreferences?.maxPerWeek}\n`);

        // Test each condition
        console.log('✅ Condition Checks:');
        console.log(`   ✓ lastOrderDate exists: ${user.lastOrderDate !== null && user.lastOrderDate !== undefined}`);
        console.log(`   ✓ lastOrderDate < 3 days ago: ${user.lastOrderDate && user.lastOrderDate < threeDaysAgo}`);
        console.log(`   ✓ mealTimePreferences.enabled: ${user.mealTimePreferences?.enabled === true}`);
        console.log(`   ✓ mealTimePreferences.lunch: ${user.mealTimePreferences?.lunch === true}`);
        console.log(`   ✓ promoNotifications: ${user.notificationSettings?.promoNotifications === true}`);
        console.log(`   ✓ lastMealNudgeAt check: ${!user.lastMealNudgeAt || user.lastMealNudgeAt < oneDayAgo}`);
        console.log(`   ✓ weekly limit: ${user.mealNudgesThisWeek < (user.mealTimePreferences?.maxPerWeek || 3)}\n`);

        // Try the actual query
        console.log('🔎 Running actual query...');
        const users = await User.find({
            lastOrderDate: { $exists: true, $ne: null, $lt: threeDaysAgo },
            'mealTimePreferences.enabled': true,
            'mealTimePreferences.lunch': true,
            'notificationSettings.promoNotifications': true,
            $or: [
                { lastMealNudgeAt: null },
                { lastMealNudgeAt: { $lt: oneDayAgo } }
            ],
            $expr: {
                $lt: ['$mealNudgesThisWeek', '$mealTimePreferences.maxPerWeek']
            }
        });

        console.log(`   Found ${users.length} user(s)\n`);

        if (users.length > 0) {
            console.log('✅ Query working! Users found:');
            users.forEach(u => console.log(`   - ${u.email}`));
        } else {
            console.log('❌ Query not finding users - investigating...\n');

            // Test without $expr
            const usersNoExpr = await User.find({
                lastOrderDate: { $exists: true, $ne: null, $lt: threeDaysAgo },
                'mealTimePreferences.enabled': true,
                'mealTimePreferences.lunch': true,
                'notificationSettings.promoNotifications': true,
                $or: [
                    { lastMealNudgeAt: null },
                    { lastMealNudgeAt: { $lt: oneDayAgo } }
                ]
            });
            console.log(`   Without $expr: ${usersNoExpr.length} users`);
        }

    } catch (error) {
        console.error('❌ Error:', error.message);
        console.error(error.stack);
    }

    process.exit(0);
};

debugQuery();
