/**
 * Create Scheduled Notification Script
 * 
 * Interactive script to create a scheduled notification
 * 
 * Usage:
 *   node scripts/create_scheduled_notification.js
 * 
 * Or with arguments:
 *   node scripts/create_scheduled_notification.js \
 *     --title "Flash Sale!" \
 *     --message "50% off for the next hour!" \
 *     --type promo \
 *     --minutes 5
 */

require('dotenv').config();
const mongoose = require('mongoose');
const { createScheduledNotification } = require('../services/scheduled_notification_service');

// Parse command line arguments
const args = process.argv.slice(2);
const getArg = (name, defaultValue) => {
    const index = args.indexOf(`--${name}`);
    return index !== -1 && args[index + 1] ? args[index + 1] : defaultValue;
};

const title = getArg('title', '🎉 Special Offer!');
const message = getArg('message', 'Check out our latest deals!');
const type = getArg('type', 'promo');
const minutes = parseInt(getArg('minutes', '2'));
const targetType = getArg('target', 'all');

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

// Create notification
const createNotification = async () => {
    const scheduledFor = new Date(Date.now() + minutes * 60 * 1000);

    console.log('\n📅 Creating Scheduled Notification:');
    console.log('─'.repeat(50));
    console.log(`Title:        ${title}`);
    console.log(`Message:      ${message}`);
    console.log(`Type:         ${type}`);
    console.log(`Scheduled:    ${scheduledFor.toLocaleString()}`);
    console.log(`In:           ${minutes} minute(s)`);
    console.log(`Target:       ${targetType}`);
    console.log('─'.repeat(50));

    try {
        const notification = await createScheduledNotification({
            scheduledFor,
            timezone: 'UTC',
            type,
            title,
            message,
            notificationData: {
                route: type === 'promo' ? '/promos' : '/notifications'
            },
            targetType
        });

        console.log('\n✅ Scheduled notification created successfully!');
        console.log(`   ID: ${notification._id}`);
        console.log(`   Status: ${notification.status}`);
        console.log(`   Will be sent at: ${notification.scheduledFor.toLocaleString()}\n`);
        console.log('💡 Tip: Watch your server logs to see when it\'s sent!\n');

    } catch (error) {
        console.error('\n❌ Error creating notification:', error.message);
    }

    process.exit(0);
};

// Run
const run = async () => {
    await connectDB();
    await createNotification();
};

run().catch(error => {
    console.error('❌ Script error:', error);
    process.exit(1);
});
