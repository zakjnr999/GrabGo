/**
 * Setup Test User for Meal Nudges
 * 
 * Creates a test scenario by setting a user's lastOrderDate to 4 days ago
 * so they become eligible for meal-time nudges
 * 
 * Usage:
 *   node scripts/setup_meal_nudge_test.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');

const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

const setupTestUser = async () => {
    console.log('🔧 Setting up test user for meal nudges\n');
    console.log('='.repeat(60));

    await connectDB();

    try {
        // Find a user with orders (you can change the email)
        const user = await User.findOne({
            email: 'zakjnr5@gmail.com'
        });

        if (!user) {
            console.log('❌ User not found');
            console.log('   Update the email in the script to match your test user');
            process.exit(1);
        }

        console.log(`\n📦 Found user: ${user.email}`);
        console.log(`   Current lastOrderDate: ${user.lastOrderDate || 'Not set'}`);
        console.log(`   Meal preferences enabled: ${user.mealTimePreferences?.enabled !== false}`);

        // Set lastOrderDate to 4 days ago
        const fourDaysAgo = new Date(Date.now() - 4 * 24 * 60 * 60 * 1000);

        await User.findByIdAndUpdate(user._id, {
            lastOrderDate: fourDaysAgo,
            'mealTimePreferences.enabled': true,
            'mealTimePreferences.breakfast': true,
            'mealTimePreferences.lunch': true,
            'mealTimePreferences.dinner': true,
            'notificationSettings.promoNotifications': true,
            lastMealNudgeAt: null,
            mealNudgesThisWeek: 0
        });

        console.log(`\n✅ User setup complete!`);
        console.log(`   New lastOrderDate: ${fourDaysAgo}`);
        console.log(`   Meal preferences: All enabled`);
        console.log(`   Notification settings: Enabled`);
        console.log(`   Nudge counters: Reset`);

        console.log(`\n🧪 User is now eligible for meal nudges!`);
        console.log(`   Run: node scripts/test_meal_nudges.js lunch`);

        console.log('\n' + '='.repeat(60));

    } catch (error) {
        console.error('\n❌ Setup failed:', error.message);
        console.error(error.stack);
    }

    process.exit(0);
};

setupTestUser();
