/**
 * List Scheduled Notifications Script
 * 
 * View all scheduled notifications and their status
 * 
 * Usage:
 *   node scripts/list_scheduled_notifications.js
 *   node scripts/list_scheduled_notifications.js --status pending
 *   node scripts/list_scheduled_notifications.js --status sent
 */

require('dotenv').config();
const mongoose = require('mongoose');
const { getScheduledNotifications, getScheduledNotificationStats } = require('../services/scheduled_notification_service');

// Parse command line arguments
const args = process.argv.slice(2);
const statusFilter = args.includes('--status') ? args[args.indexOf('--status') + 1] : null;

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

// Format date
const formatDate = (date) => {
    const now = new Date();
    const diff = date - now;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (diff < 0) {
        return `${Math.abs(minutes)} min ago`;
    } else if (minutes < 60) {
        return `in ${minutes} min`;
    } else if (hours < 24) {
        return `in ${hours} hours`;
    } else {
        return `in ${days} days`;
    }
};

// List notifications
const listNotifications = async () => {
    console.log('📋 Scheduled Notifications');
    console.log('='.repeat(80));

    // Get stats
    const stats = await getScheduledNotificationStats();
    console.log('\n📊 Statistics:');
    console.log(`   Pending:   ${stats.pending}`);
    console.log(`   Sent:      ${stats.sent}`);
    console.log(`   Cancelled: ${stats.cancelled}`);
    console.log(`   Failed:    ${stats.failed}`);
    console.log(`   Total:     ${stats.pending + stats.sent + stats.cancelled + stats.failed}`);

    // Get notifications
    const filters = statusFilter ? { status: statusFilter } : {};
    const notifications = await getScheduledNotifications(filters, 100);

    if (notifications.length === 0) {
        console.log('\n📭 No scheduled notifications found.\n');
        process.exit(0);
    }

    console.log(`\n📬 Showing ${notifications.length} notification(s)${statusFilter ? ` (status: ${statusFilter})` : ''}:\n`);
    console.log('─'.repeat(80));

    notifications.forEach((notif, index) => {
        const statusEmoji = {
            pending: '⏳',
            sent: '✅',
            cancelled: '❌',
            failed: '⚠️'
        }[notif.status] || '❓';

        console.log(`\n${index + 1}. ${statusEmoji} ${notif.title}`);
        console.log(`   ID:        ${notif._id}`);
        console.log(`   Type:      ${notif.type}`);
        console.log(`   Status:    ${notif.status}`);
        console.log(`   Scheduled: ${notif.scheduledFor.toLocaleString()} (${formatDate(notif.scheduledFor)})`);
        console.log(`   Target:    ${notif.targetType}`);
        console.log(`   Message:   ${notif.message.substring(0, 60)}${notif.message.length > 60 ? '...' : ''}`);

        if (notif.isRecurring) {
            console.log(`   Recurring: ${notif.recurrencePattern.frequency}`);
        }

        if (notif.sentAt) {
            console.log(`   Sent at:   ${notif.sentAt.toLocaleString()}`);
        }

        if (notif.failureReason) {
            console.log(`   Error:     ${notif.failureReason}`);
        }
    });

    console.log('\n' + '─'.repeat(80));
    console.log('\n💡 Tips:');
    console.log('   - Use --status pending to see only pending notifications');
    console.log('   - Use --status sent to see sent notifications');
    console.log('   - Use --status cancelled to see cancelled notifications\n');

    process.exit(0);
};

// Run
const run = async () => {
    await connectDB();
    await listNotifications();
};

run().catch(error => {
    console.error('❌ Script error:', error);
    process.exit(1);
});
