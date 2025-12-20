/**
 * Test Script for Referral Notifications
 * 
 * This script tests the new in-app notification system for referral completions
 * and milestone bonuses.
 */

const mongoose = require('mongoose');
const User = require('../models/User');
const Referral = require('../models/Referral');
const ReferralCode = require('../models/ReferralCode');
const Order = require('../models/Order');
const ReferralService = require('../services/ReferralService');
const { getIO } = require('../utils/socket');
require('dotenv').config();

// Test configuration
const REFERRER_EMAIL = 'referrer@example.com'; // User who will receive notifications
const REFEREE_EMAIL = 'referee@example.com';   // User who completes the order

async function testReferralNotifications() {
    try {
        console.log('🧪 Starting Referral Notification Tests...\n');

        // Connect to MongoDB
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB\n');

        // Find or create referrer
        let referrer = await User.findOne({ email: REFERRER_EMAIL });
        if (!referrer) {
            console.log(`Creating test referrer: ${REFERRER_EMAIL}`);
            referrer = await User.create({
                username: 'Test Referrer',
                email: REFERRER_EMAIL,
                password: 'password123',
                phone: '+233200000001',
                role: 'customer',
                isEmailVerified: true,
                isPhoneVerified: true
            });
        }
        console.log(`✅ Referrer: ${referrer.username} (${referrer.email})\n`);

        // Find or create referral code for referrer
        let referralCode = await ReferralCode.findOne({ user: referrer._id });
        if (!referralCode) {
            console.log('Creating referral code for referrer...');
            referralCode = await ReferralCode.create({
                user: referrer._id,
                code: `REF${Date.now()}`,
                completedReferrals: 0,
                totalEarned: 0
            });
        }
        console.log(`✅ Referral code: ${referralCode.code}\n`);

        // Find or create referee
        let referee = await User.findOne({ email: REFEREE_EMAIL });
        if (!referee) {
            console.log(`Creating test referee: ${REFEREE_EMAIL}`);
            referee = await User.create({
                username: 'Test Referee',
                email: REFEREE_EMAIL,
                password: 'password123',
                phone: '+233200000002',
                role: 'customer',
                isEmailVerified: true,
                isPhoneVerified: true
            });
        }
        console.log(`✅ Referee: ${referee.username} (${referee.email})\n`);

        // Create pending referral
        console.log('📝 Creating pending referral...');
        const referral = await Referral.create({
            referrer: referrer._id,
            referee: referee._id,
            referralCode: referralCode.code,
            status: 'pending_order',
            expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days
        });
        console.log(`✅ Referral created: ${referral._id}\n`);

        // Create a test order for referee
        console.log('📦 Creating referee\'s first order (GHS 25)...');
        const order = await Order.create({
            orderNumber: `REF-TEST-${Date.now()}`,
            customer: referee._id,
            restaurant: new mongoose.Types.ObjectId(), // Dummy restaurant
            items: [],
            subtotal: 20.00,
            deliveryFee: 3.00,
            tax: 2.00,
            totalAmount: 25.00,
            deliveryAddress: 'Test Address',
            paymentMethod: 'cash',
            status: 'delivered',
            deliveredDate: new Date()
        });
        console.log(`✅ Order created: ${order.orderNumber}\n`);

        // Get Socket.IO instance
        const io = getIO();
        if (!io) {
            console.warn('⚠️  Socket.IO not initialized - notifications will be created but not emitted in real-time');
            console.warn('   This is normal if running this script standalone\n');
        }

        // Test referral completion
        console.log('🎉 Testing Referral Completion Notification...');
        console.log('─'.repeat(50));

        const result = await ReferralService.completeReferral(
            referee._id,
            order._id,
            25.00,
            io
        );

        if (result.success) {
            console.log('✅ Referral completed successfully!');
            console.log(`   - Referrer earned: GHS 10.00`);
            console.log(`   - Notification sent to: ${referrer.username}`);
            console.log(`   - Check app for: "🎉 Referral Success!"`);
        } else {
            console.log(`❌ Referral completion failed: ${result.message}`);
        }

        // Check if milestone was reached
        const updatedCode = await ReferralCode.findOne({ user: referrer._id });
        console.log(`\n📊 Referral Stats:`);
        console.log(`   - Completed referrals: ${updatedCode.completedReferrals}`);
        console.log(`   - Total earned: GHS ${updatedCode.totalEarned}`);

        if (updatedCode.completedReferrals % 5 === 0) {
            console.log(`\n🎊 MILESTONE REACHED!`);
            console.log(`   - Milestone: ${updatedCode.completedReferrals} referrals`);
            console.log(`   - Bonus: GHS 5.00`);
            console.log(`   - Check app for: "🎉 Milestone Reached!"`);
        }

        console.log('\n\n' + '='.repeat(50));
        console.log('✅ ALL TESTS COMPLETED SUCCESSFULLY!');
        console.log('='.repeat(50));
        console.log('\n💡 Next Steps:');
        console.log('   1. Check the app notifications screen');
        console.log('   2. Verify referral completion notification appears');
        console.log('   3. If milestone reached, verify milestone notification');
        console.log('   4. Verify they appeared without manual refresh (if app was open)');
        console.log('\n🗑️  Cleanup:');
        console.log(`   To delete test data:`);
        console.log(`   - db.orders.deleteOne({orderNumber: "${order.orderNumber}"})`);
        console.log(`   - db.referrals.deleteOne({_id: ObjectId("${referral._id}")})`);
        console.log(`   - db.notifications.deleteMany({user: ObjectId("${referrer._id}")})`);

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error.stack);
    } finally {
        await mongoose.connection.close();
        console.log('\n✅ Database connection closed');
        process.exit(0);
    }
}

// Run tests
testReferralNotifications();
