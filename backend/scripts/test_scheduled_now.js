/**
 * Create and Immediately Send Scheduled Notification
 * 
 * This creates a scheduled notification for RIGHT NOW and triggers
 * the scheduler to send it immediately.
 * 
 * Usage:
 *   node scripts/test_scheduled_now.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const { createScheduledNotification, processScheduledNotifications } = require('../services/scheduled_notification_service');

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
    console.log('🧪 Testing Scheduled Notification (Immediate Send)\n');
    console.log('='.repeat(60));

    await connectDB();

    try {
        // Create notification scheduled for RIGHT NOW
        const scheduledFor = new Date(Date.now() + 5000); // 5 seconds from now

        console.log('\n📝 Creating scheduled notification for 5 seconds from now...');

        const notification = await createScheduledNotification({
            scheduledFor,
            timezone: 'UTC',
            type: 'promo',
            title: '🎉 Immediate Test Notification',
            message: 'This scheduled notification should appear in 5 seconds!',
            notificationData: {
                promoCode: 'TESTNOW',
                route: '/promos'
            },
            targetType: 'all'
        });

        console.log('✅ Scheduled notification created:', notification._id);
        console.log(`   Scheduled for: ${scheduledFor.toISOString()}`);

        // Wait 6 seconds
        console.log('\n⏳ Waiting 6 seconds...');
        await new Promise(resolve => setTimeout(resolve, 6000));

        // Manually trigger the scheduler
        console.log('\n📤 Manually triggering scheduler...');
        const result = await processScheduledNotifications(null);

        console.log('\n📊 Results:');
        console.log(`   Processed: ${result.processed}`);
        console.log(`   Sent: ${result.sent}`);
        console.log(`   Failed: ${result.failed}`);

        if (result.sent > 0) {
            console.log('\n✅ SUCCESS! Scheduled notification was sent!');
            console.log('   Check your app for the notification.');
        } else if (result.processed === 0) {
            console.log('\n⚠️  No notifications were processed.');
            console.log('   The notification might not be due yet.');
        } else {
            console.log('\n❌ Notification was processed but failed to send.');
            console.log('   Check server logs for error details.');
        }

        console.log('\n' + '='.repeat(60));

    } catch (error) {
        console.error('\n❌ Error:', error.message);
        console.error(error.stack);
    }

    process.exit(0);
};

// Run
main().catch(error => {
    console.error('❌ Script error:', error);
    process.exit(1);
});
