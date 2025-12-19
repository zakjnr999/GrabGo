/**
 * Cancel Scheduled Notification Script
 * 
 * Cancel a pending scheduled notification
 * 
 * Usage:
 *   node scripts/cancel_scheduled_notification.js <notification_id>
 */

require('dotenv').config();
const mongoose = require('mongoose');
const { cancelScheduledNotification, getScheduledNotificationById } = require('../services/scheduled_notification_service');

// Get notification ID from command line
const notificationId = process.argv[2];

if (!notificationId) {
    console.error('\n❌ Error: Notification ID required');
    console.log('\nUsage:');
    console.log('   node scripts/cancel_scheduled_notification.js <notification_id>\n');
    console.log('Example:');
    console.log('   node scripts/cancel_scheduled_notification.js 507f1f77bcf86cd799439011\n');
    process.exit(1);
}

// Connect to MongoDB
const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB\n');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

// Cancel notification
const cancelNotification = async () => {
    console.log(`🔍 Looking for notification: ${notificationId}\n`);

    // First, get the notification to show details
    const notification = await getScheduledNotificationById(notificationId);

    if (!notification) {
        console.error('❌ Notification not found\n');
        process.exit(1);
    }

    console.log('📋 Notification Details:');
    console.log('─'.repeat(50));
    console.log(`Title:     ${notification.title}`);
    console.log(`Type:      ${notification.type}`);
    console.log(`Status:    ${notification.status}`);
    console.log(`Scheduled: ${notification.scheduledFor.toLocaleString()}`);
    console.log('─'.repeat(50));

    if (notification.status !== 'pending') {
        console.error(`\n❌ Cannot cancel: notification status is "${notification.status}"`);
        console.log('   Only pending notifications can be cancelled\n');
        process.exit(1);
    }

    // Cancel the notification
    const success = await cancelScheduledNotification(notificationId);

    if (success) {
        console.log('\n✅ Notification cancelled successfully!\n');
    } else {
        console.error('\n❌ Failed to cancel notification\n');
        process.exit(1);
    }

    process.exit(0);
};

// Run
const run = async () => {
    await connectDB();
    await cancelNotification();
};

run().catch(error => {
    console.error('❌ Script error:', error);
    process.exit(1);
});
