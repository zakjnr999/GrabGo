require('dotenv').config();
const mongoose = require('mongoose');

async function fixNotificationSettings() {
    try {
        console.log('🔧 Fixing notification settings...\n');

        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB\n');

        // Update using raw MongoDB driver to ensure it works
        const result = await mongoose.connection.db.collection('users').updateOne(
            { email: 'zakjnr5@gmail.com' },
            {
                $set: {
                    'notificationSettings.chatMessages': true,
                    'notificationSettings.orderUpdates': true,
                    'notificationSettings.promoNotifications': true,
                    'notificationSettings.commentReplies': true,
                    'notificationSettings.commentReactions': true,
                    'notificationSettings.referralUpdates': true,
                    'notificationSettings.paymentUpdates': true,
                    'notificationSettings.deliveryUpdates': true,
                    'notificationSettings.systemUpdates': true
                },
                $unset: {
                    'notificationSettings.promotions': ''
                }
            }
        );

        console.log('✅ Update result:', result.modifiedCount, 'document(s) modified\n');

        // Verify the update
        const user = await mongoose.connection.db.collection('users').findOne(
            { email: 'zakjnr5@gmail.com' },
            { projection: { notificationSettings: 1 } }
        );

        console.log('📊 Current notification settings:');
        console.log(JSON.stringify(user.notificationSettings, null, 2));
        console.log('\n✅ All done!');

        process.exit(0);
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
}

fixNotificationSettings();
