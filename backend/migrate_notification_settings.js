require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/User');

/**
 * Migration script to add missing notification settings to existing users
 * Run this once to update all existing users with the new notification settings
 */
async function migrateNotificationSettings() {
    try {
        console.log('🔄 Starting notification settings migration...\n');

        // Connect to MongoDB
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB\n');

        // Find all users
        const users = await User.find({});
        console.log(`📊 Found ${users.length} users to migrate\n`);

        let updatedCount = 0;
        let skippedCount = 0;

        for (const user of users) {
            const updates = {};
            let needsUpdate = false;

            // Check and add missing settings
            const defaultSettings = {
                chatMessages: true,
                orderUpdates: true,
                promoNotifications: true,
                commentReplies: true,
                commentReactions: true,
                referralUpdates: true,
                paymentUpdates: true,
                deliveryUpdates: true,
                systemUpdates: true
            };

            // Rename old 'promotions' to 'promoNotifications'
            if (user.notificationSettings?.promotions !== undefined) {
                updates['notificationSettings.promoNotifications'] = user.notificationSettings.promotions;
                updates['$unset'] = { 'notificationSettings.promotions': '' };
                needsUpdate = true;
            }

            // Add missing settings
            for (const [key, defaultValue] of Object.entries(defaultSettings)) {
                if (user.notificationSettings?.[key] === undefined) {
                    updates[`notificationSettings.${key}`] = defaultValue;
                    needsUpdate = true;
                }
            }

            if (needsUpdate) {
                await User.updateOne(
                    { _id: user._id },
                    { $set: updates, ...(updates.$unset && { $unset: updates.$unset }) }
                );
                updatedCount++;
                console.log(`✅ Updated user: ${user.username || user.email}`);
            } else {
                skippedCount++;
            }
        }

        console.log('\n📊 Migration Summary:');
        console.log(`   ✅ Updated: ${updatedCount} users`);
        console.log(`   ⏭️  Skipped: ${skippedCount} users (already up to date)`);
        console.log(`   📝 Total: ${users.length} users\n`);

        console.log('✅ Migration completed successfully!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration failed:', error);
        process.exit(1);
    }
}

// Run migration
migrateNotificationSettings();
