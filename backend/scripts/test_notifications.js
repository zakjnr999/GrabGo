require('dotenv').config();
const mongoose = require('mongoose');
const {
    sendChatNotification,
    sendOrderNotification,
    sendPaymentConfirmation,
    sendDeliveryArrivingNotification,
    sendReferralNotification,
    sendMilestoneBonusNotification,
    sendPromoNotification,
    sendSystemUpdate
} = require('../services/fcm_service');

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI);

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function testAllNotifications(userId) {
    console.log('🧪 Testing all notification types...\n');
    console.log(`📱 Sending to user: ${userId}\n`);

    try {
        // 1. Chat Message
        console.log('1️⃣ Testing Chat Message...');
        await sendChatNotification(userId, 'chat123', 'John Doe', 'Hey there! This is a test message.');
        await sleep(2000);

        // 2. Order Update
        console.log('2️⃣ Testing Order Update...');
        await sendOrderNotification(userId, 'order123', '12345', 'confirmed');
        await sleep(2000);

        // 3. Payment Confirmation
        console.log('3️⃣ Testing Payment Confirmation...');
        await sendPaymentConfirmation(userId, 'order123', 25.50, 'momo');
        await sleep(2000);

        // 4. Delivery Arriving
        console.log('4️⃣ Testing Delivery Arriving...');
        await sendDeliveryArrivingNotification(userId, 'order123', '12345', 5);
        await sleep(2000);

        // 5. Referral Completed
        console.log('5️⃣ Testing Referral Completed...');
        await sendReferralNotification(userId, 'Jane Doe', 10);
        await sleep(2000);

        // 6. Milestone Bonus
        console.log('6️⃣ Testing Milestone Bonus...');
        await sendMilestoneBonusNotification(userId, 10, 5);
        await sleep(2000);

        // 7. Promo Notification
        console.log('7️⃣ Testing Promo Notification...');
        await sendPromoNotification(
            userId,
            'Special Offer! 🎉',
            'Get 20% off your next order with code SAVE20',
            'SAVE20'
        );
        await sleep(2000);

        // 8. System Update
        console.log('8️⃣ Testing System Update...');
        await sendSystemUpdate(userId, 'New Feature', 'Check out our new restaurant ratings!', 'feature');

        console.log('\n✅ All notification tests complete!');
        console.log('📱 Check your emulator for the notifications!');
        process.exit(0);
    } catch (error) {
        console.error('\n❌ Error sending notifications:', error);
        process.exit(1);
    }
}

// Usage: node test_notifications.js USER_ID
const userId = process.argv[2];
if (!userId) {
    console.error('❌ Please provide user ID');
    console.error('Usage: node test_notifications.js USER_ID');
    console.error('Example: node test_notifications.js 6911672f9d10fccfea54a96e');
    process.exit(1);
}

testAllNotifications(userId);
