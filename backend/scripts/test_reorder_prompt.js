/**
 * Test Reorder Prompts
 * 
 * This script verifies the logic for identifying items users order frequently
 * and sending them a reorder nudge.
 * 
 * Usage:
 *   node scripts/test_reorder_prompt.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const Order = require('../models/Order');
const Food = require('../models/Food');
const Notification = require('../models/Notification');
const { processReorderSuggestions } = require('../services/reorder_suggestion_service');

const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

const testReorderPrompt = async () => {
    console.log('🧪 Testing Reorder Prompts\n');
    console.log('='.repeat(60));

    await connectDB();

    try {
        // 1. Prepare test user
        console.log('\n👤 1. Preparing test user...');
        const user = await User.findOne({ email: 'zakjnr5@gmail.com' });
        if (!user) {
            console.log('❌ Test user zakjnr5@gmail.com not found');
            process.exit(1);
        }

        // 2. Create mock frequent order history
        console.log('\n📦 2. Creating mock frequent order history...');

        // Find a random food item
        const food = await Food.findOne();
        if (!food) {
            console.log('❌ No food items found in DB to mock orders');
            process.exit(1);
        }

        // Delete any existing mock orders for this test to be clean
        await Order.deleteMany({ customer: user._id, notes: 'mocker_order_test' });

        // Create 3 orders in the last 15 days, but not in the last 5 days
        const orderDates = [
            new Date(Date.now() - 20 * 24 * 60 * 60 * 1000),
            new Date(Date.now() - 15 * 24 * 60 * 60 * 1000),
            new Date(Date.now() - 10 * 24 * 60 * 60 * 1000)
        ];

        for (let i = 0; i < orderDates.length; i++) {
            await Order.create({
                customer: user._id,
                orderType: 'food',
                restaurant: food.restaurant,
                items: [{
                    food: food._id,
                    itemType: 'food',
                    name: food.name,
                    quantity: 1,
                    price: food.price
                }],
                subtotal: food.price,
                totalAmount: food.price + 5,
                deliveryAddress: { street: 'Test St', city: 'Accra' },
                paymentMethod: 'cash',
                status: 'delivered',
                orderDate: orderDates[i],
                notes: 'mocker_order_test'
            });
        }

        console.log(`✅ Created 3 mock orders for "${food.name}"`);
        console.log(`   Dates: ${orderDates.map(d => d.toDateString()).join(', ')}`);

        // Reset user tracking
        await User.findByIdAndUpdate(user._id, {
            lastReorderSuggestionAt: null,
            reorderSuggestionsThisWeek: 0,
            'notificationSettings.promoNotifications': true
        });

        // 3. Trigger reorder prompts
        console.log('\n🚀 3. Triggering reorder prompt processing...');
        await processReorderSuggestions();

        // 4. Verify results
        console.log('\n📊 4. Verifying results...');
        const updatedUser = await User.findById(user._id);
        const notification = await Notification.findOne({
            user: user._id,
            type: 'reorder_suggestion'
        }).sort({ createdAt: -1 });

        if (notification) {
            console.log('✅ Success! Notification created');
            console.log(`   Title: ${notification.title}`);
            console.log(`   Message: ${notification.message}`);
            console.log(`   Item: ${notification.data.itemName}`);
        } else {
            console.log('❌ Failed: No notification found');
        }

        if (updatedUser.reorderSuggestionsThisWeek === 1) {
            console.log('✅ Success! User tracking updated (suggestionsCount = 1)');
        } else {
            console.log(`❌ Failed: User tracking not updated correctly (${updatedUser.reorderSuggestionsThisWeek})`);
        }

        console.log('\n✅ TEST COMPLETE');

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error.stack);
    } finally {
        // Cleanup mock orders
        // await Order.deleteMany({ notes: 'mocker_order_test' });
        await mongoose.connection.close();
        process.exit(0);
    }
};

testReorderPrompt();
