/**
 * Test Script for Scheduled Notifications
 * 
 * This script allows you to test the scheduled notifications feature
 * by creating notifications scheduled for the near future.
 * 
 * Usage:
 *   node scripts/test_scheduled_notifications.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const { createScheduledNotification } = require('../services/scheduled_notification_service');

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

// Test 1: Schedule notification for 2 minutes from now
const testBasicScheduling = async () => {
    console.log('\n📝 Test 1: Basic Scheduling (2 minutes from now)');

    const scheduledFor = new Date(Date.now() + 2 * 60 * 1000); // 2 minutes from now

    try {
        const notification = await createScheduledNotification({
            scheduledFor,
            timezone: 'UTC',
            type: 'promo',
            title: '🎉 Test Promo Notification',
            message: 'This is a test scheduled notification sent 2 minutes after creation!',
            notificationData: {
                promoCode: 'TEST50',
                route: '/promos'
            },
            targetType: 'all'
        });

        console.log('✅ Created:', {
            id: notification._id,
            scheduledFor: notification.scheduledFor,
            status: notification.status,
            title: notification.title
        });
    } catch (error) {
        console.error('❌ Error:', error.message);
    }
};

// Test 2: Schedule notification for 30 seconds from now
const testQuickScheduling = async () => {
    console.log('\n📝 Test 2: Quick Scheduling (30 seconds from now)');

    const scheduledFor = new Date(Date.now() + 30 * 1000); // 30 seconds from now

    try {
        const notification = await createScheduledNotification({
            scheduledFor,
            timezone: 'UTC',
            type: 'system',
            title: '🔔 Quick Test Notification',
            message: 'This notification was scheduled for 30 seconds in the future!',
            notificationData: {
                route: '/notifications'
            },
            targetType: 'all'
        });

        console.log('✅ Created:', {
            id: notification._id,
            scheduledFor: notification.scheduledFor,
            status: notification.status,
            title: notification.title
        });
    } catch (error) {
        console.error('❌ Error:', error.message);
    }
};

// Test 3: Schedule notification for tomorrow at 9 AM
const testFutureScheduling = async () => {
    console.log('\n📝 Test 3: Future Scheduling (Tomorrow at 9 AM)');

    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(9, 0, 0, 0);

    try {
        const notification = await createScheduledNotification({
            scheduledFor: tomorrow,
            timezone: 'Africa/Accra',
            type: 'promo',
            title: '☀️ Good Morning Special!',
            message: 'Start your day with 20% off breakfast orders!',
            notificationData: {
                promoCode: 'MORNING20',
                route: '/promos'
            },
            targetType: 'all'
        });

        console.log('✅ Created:', {
            id: notification._id,
            scheduledFor: notification.scheduledFor,
            status: notification.status,
            title: notification.title
        });
    } catch (error) {
        console.error('❌ Error:', error.message);
    }
};

// Test 4: Schedule recurring daily notification
const testRecurringScheduling = async () => {
    console.log('\n📝 Test 4: Recurring Daily Notification');

    const firstOccurrence = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes from now
    const endDate = new Date();
    endDate.setDate(endDate.getDate() + 7); // Recur for 7 days

    try {
        const notification = await createScheduledNotification({
            scheduledFor: firstOccurrence,
            timezone: 'UTC',
            type: 'promo',
            title: '🔄 Daily Special',
            message: 'Check out today\'s special offers!',
            notificationData: {
                route: '/promos'
            },
            targetType: 'all',
            isRecurring: true,
            recurrencePattern: {
                frequency: 'daily',
                timeOfDay: '12:00',
                endDate
            }
        });

        console.log('✅ Created recurring notification:', {
            id: notification._id,
            scheduledFor: notification.scheduledFor,
            status: notification.status,
            title: notification.title,
            recurrence: notification.recurrencePattern
        });
    } catch (error) {
        console.error('❌ Error:', error.message);
    }
};

// Test 5: Try to schedule notification in the past (should fail)
const testPastScheduling = async () => {
    console.log('\n📝 Test 5: Past Scheduling (Should Fail)');

    const pastDate = new Date(Date.now() - 60 * 1000); // 1 minute ago

    try {
        await createScheduledNotification({
            scheduledFor: pastDate,
            timezone: 'UTC',
            type: 'system',
            title: 'This should fail',
            message: 'Cannot schedule in the past',
            targetType: 'all'
        });

        console.log('❌ Should have failed but didn\'t!');
    } catch (error) {
        console.log('✅ Correctly rejected:', error.message);
    }
};

// Run all tests
const runAllTests = async () => {
    console.log('🧪 Starting Scheduled Notifications Tests\n');
    console.log('='.repeat(60));

    await connectDB();

    await testBasicScheduling();
    await testQuickScheduling();
    await testFutureScheduling();
    await testRecurringScheduling();
    await testPastScheduling();

    console.log('\n' + '='.repeat(60));
    console.log('\n✅ All tests completed!');
    console.log('\n💡 Tips:');
    console.log('   - Check your MongoDB to see the scheduled notifications');
    console.log('   - The cron job runs every minute to process due notifications');
    console.log('   - Watch your server logs to see when notifications are sent');
    console.log('   - The 30-second and 2-minute notifications should send soon!\n');

    process.exit(0);
};

// Run tests
runAllTests().catch(error => {
    console.error('❌ Test script error:', error);
    process.exit(1);
});
