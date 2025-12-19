/**
 * Test Cart Abandonment Notifications
 * 
 * This script creates a cart, waits, then manually triggers
 * the abandonment check to test notifications
 * 
 * Usage:
 *   node scripts/test_cart_abandonment.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const { processAbandonedCarts } = require('../jobs/cart_abandonment');
const Cart = require('../models/Cart');

const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

const testCartAbandonment = async () => {
    console.log('🧪 Testing Cart Abandonment Notifications\n');
    console.log('='.repeat(60));

    await connectDB();

    try {
        // Find a cart with items
        const cart = await Cart.findOne({
            isActive: true,
            itemCount: { $gt: 0 }
        }).populate('user');

        if (!cart) {
            console.log('\n⚠️  No active carts with items found');
            console.log('   Create a cart first using the cart API');
            process.exit(0);
        }

        console.log(`\n📦 Found cart for user: ${cart.user.email}`);
        console.log(`   Items: ${cart.itemCount}`);
        console.log(`   Total: GH₵${cart.totalAmount}`);
        console.log(`   Last updated: ${cart.lastUpdatedAt}`);
        console.log(`   isActive: ${cart.isActive}`);
        console.log(`   convertedToOrder: ${cart.convertedToOrder}`);
        console.log(`   abandonmentNotificationSent: ${cart.abandonmentNotificationSent}`);

        // Manually set lastUpdatedAt to 35 minutes ago to simulate abandonment
        // (Using 35 min to ensure it's definitely before the 30-min cutoff)
        // Use direct update to bypass pre-save hook that resets lastUpdatedAt
        const thirtyFiveMinutesAgo = new Date(Date.now() - 35 * 60 * 1000);

        await Cart.updateOne(
            { _id: cart._id },
            {
                $set: {
                    lastUpdatedAt: thirtyFiveMinutesAgo,
                    abandonmentNotificationSent: false
                }
            }
        );

        console.log(`\n⏰ Set cart as abandoned (35 minutes old)`);
        console.log(`   New lastUpdatedAt: ${thirtyFiveMinutesAgo}`);

        // Trigger abandonment check
        console.log('\n🔔 Triggering abandonment check...');
        const result = await processAbandonedCarts(null);

        console.log('\n📊 Results:');
        console.log(`   Processed: ${result.processed}`);
        console.log(`   Notified: ${result.notified}`);
        console.log(`   Failed: ${result.failed}`);

        if (result.notified > 0) {
            console.log('\n✅ SUCCESS! Cart abandonment notification sent!');
            console.log('   Check the user\'s in-app notifications');
            console.log('   If app is closed, check for push notification');
        } else if (result.processed === 0) {
            console.log('\n⚠️  No carts were processed');
            console.log('   The cart might not meet abandonment criteria');
        } else {
            console.log('\n❌ Notification failed to send');
            console.log('   Check server logs for error details');
        }

        console.log('\n' + '='.repeat(60));

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error.stack);
    }

    process.exit(0);
};

testCartAbandonment();
