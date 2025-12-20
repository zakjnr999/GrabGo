/**
 * Test Meal-Time Nudges
 * 
 * Tests the meal nudge system by finding eligible users
 * and sending test notifications
 * 
 * Usage:
 *   node scripts/test_meal_nudges.js [mealType]
 *   
 * Examples:
 *   node scripts/test_meal_nudges.js breakfast
 *   node scripts/test_meal_nudges.js lunch
 *   node scripts/test_meal_nudges.js dinner
 */

require('dotenv').config();
const mongoose = require('mongoose');
const {
    findEligibleUsers,
    generatePersonalizedMessage,
    processMealNudges
} = require('../services/meal_nudge_service');

const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

const testMealNudges = async () => {
    const mealType = process.argv[2] || 'lunch';

    console.log('🧪 Testing Meal-Time Nudges\n');
    console.log('='.repeat(60));
    console.log(`Meal Type: ${mealType.toUpperCase()}\n`);

    await connectDB();

    try {
        // Test 1: Find eligible users
        console.log('📋 Test 1: Finding eligible users...');
        const eligibleUsers = await findEligibleUsers(mealType);

        if (eligibleUsers.length === 0) {
            console.log('⚠️  No eligible users found');
            console.log('\n💡 To test, you need users who:');
            console.log('   - Have ordered before (lastOrderDate exists)');
            console.log('   - Haven\'t ordered in 3+ days');
            console.log('   - Have meal notifications enabled');
            console.log('   - Haven\'t hit frequency limits (1/day, 3/week)');
            process.exit(0);
        }

        console.log(`✅ Found ${eligibleUsers.length} eligible user(s)\n`);

        // Test 2: Generate personalized messages
        console.log('📝 Test 2: Generating personalized messages...');
        for (let i = 0; i < Math.min(3, eligibleUsers.length); i++) {
            const user = eligibleUsers[i];
            const message = await generatePersonalizedMessage(user, mealType);

            console.log(`\n   User: ${user.email}`);
            console.log(`   Title: ${message.title}`);
            console.log(`   Message: ${message.message}`);
        }

        console.log('\n✅ Message generation working!\n');

        // Test 3: Ask to send actual notifications
        console.log('🔔 Test 3: Send notifications?');
        console.log(`   This will send ${mealType} nudges to ${eligibleUsers.length} user(s)`);
        console.log('   Press Ctrl+C to cancel, or wait 5 seconds to proceed...\n');

        await new Promise(resolve => setTimeout(resolve, 5000));

        console.log('📤 Sending notifications...\n');
        const result = await processMealNudges(mealType, null);

        console.log('\n📊 Results:');
        console.log(`   Sent: ${result.sent}`);
        console.log(`   Failed: ${result.failed}`);

        if (result.sent > 0) {
            console.log('\n✅ SUCCESS! Meal nudges sent!');
            console.log('   Check users\' in-app notifications');
            console.log('   If app is closed, check for push notifications');
        } else {
            console.log('\n⚠️  No notifications sent');
        }

        console.log('\n' + '='.repeat(60));

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error.stack);
    }

    process.exit(0);
};

testMealNudges();
