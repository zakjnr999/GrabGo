/**
 * Test Direct Notification Delivery
 * 
 * This script sends a notification directly to a specific user
 * to test if the notification delivery mechanism is working.
 * 
 * Usage:
 *   node scripts/test_direct_notification.js <userId>
 *   node scripts/test_direct_notification.js zakjnr5@gmail.com
 */

require('dotenv').config();
const mongoose = require('mongoose');
const { createNotification } = require('../services/notification_service');
const User = require('../models/User');

// Connect to MongoDB
const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

// Main function
const main = async () => {
    console.log('🧪 Testing Direct Notification Delivery\n');
    console.log('='.repeat(60));

    await connectDB();

    // Get user identifier from command line or use default
    const userIdentifier = process.argv[2] || 'zakjnr5@gmail.com';

    try {
        // Find user by email or username
        const user = await User.findOne({
            $or: [
                { email: userIdentifier },
                { username: userIdentifier },
                { _id: mongoose.Types.ObjectId.isValid(userIdentifier) ? userIdentifier : null }
            ]
        });

        if (!user) {
            console.error(`\n❌ User not found: ${userIdentifier}`);
            console.log('\n💡 Available users:');
            const users = await User.find({ role: 'customer', isActive: true })
                .select('username email')
                .limit(5);
            users.forEach(u => console.log(`   - ${u.username} (${u.email})`));
            process.exit(1);
        }

        console.log(`\n✅ Found user: ${user.username} (${user.email})`);
        console.log(`   ID: ${user._id}`);

        // Send test notification
        console.log('\n📤 Sending test notification...');

        const notification = await createNotification(
            user._id,
            'system',
            '🧪 Test Notification',
            'This is a direct test notification to verify delivery is working!',
            {
                route: '/notifications',
                testId: Date.now()
            },
            null // No Socket.IO instance (script context)
        );

        console.log('\n✅ Notification created successfully!');
        console.log(`   Notification ID: ${notification._id}`);
        console.log(`   Title: ${notification.title}`);
        console.log(`   Message: ${notification.message}`);
        console.log(`   Type: ${notification.type}`);

        console.log('\n📊 What happened:');
        console.log('   ✅ In-app notification created in database');
        console.log('   ⚠️  Socket.IO real-time notification: SKIPPED (no io instance)');
        console.log('   📱 FCM push notification: ATTEMPTED');

        console.log('\n💡 To receive this notification:');
        console.log('   1. Open the GrabGo app');
        console.log('   2. Go to the Notifications page');
        console.log('   3. You should see the test notification');
        console.log('   4. If you have FCM token registered, you may get a push notification');

        console.log('\n' + '='.repeat(60));

    } catch (error) {
        console.error('\n❌ Error sending notification:', error.message);
        console.error(error.stack);
    }

    process.exit(0);
};

// Run
main().catch(error => {
    console.error('❌ Script error:', error);
    process.exit(1);
});
