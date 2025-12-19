/**
 * Manual Trigger for Scheduled Notifications
 * 
 * This script manually triggers the notification scheduler to process
 * any due notifications immediately, without waiting for the cron job.
 * 
 * Usage:
 *   node scripts/trigger_scheduler.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const { processScheduledNotifications } = require('../services/scheduled_notification_service');

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
    console.log('🔧 Manual Scheduler Trigger\n');
    console.log('='.repeat(60));

    await connectDB();

    console.log('\n📊 Processing due notifications...\n');

    try {
        const result = await processScheduledNotifications(null); // No Socket.IO in script

        console.log('='.repeat(60));
        console.log('\n✅ Processing complete!');
        console.log(`\n📊 Results:`);
        console.log(`   - Processed: ${result.processed}`);
        console.log(`   - Sent: ${result.sent}`);
        console.log(`   - Failed: ${result.failed}`);

        if (result.processed === 0) {
            console.log('\n💡 No due notifications found.');
            console.log('   - Check if any notifications are scheduled for now or earlier');
            console.log('   - Run: node scripts/list_scheduled_notifications.js');
        }

        if (result.failed > 0) {
            console.log('\n⚠️  Some notifications failed to send.');
            console.log('   - Check server logs for error details');
            console.log('   - Verify users exist in database');
        }

        console.log('');
    } catch (error) {
        console.error('\n❌ Error processing notifications:', error.message);
        console.error(error.stack);
    }

    process.exit(0);
};

// Run
main().catch(error => {
    console.error('❌ Script error:', error);
    process.exit(1);
});
