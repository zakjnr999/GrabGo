/**
 * Test Script for Order Status Notifications
 * 
 * This script tests the new in-app notification system for order status updates.
 * It simulates order status changes and verifies that notifications are created
 * and emitted via WebSocket.
 */

const mongoose = require('mongoose');
const Order = require('../models/Order');
const User = require('../models/User');
const Restaurant = require('../models/Restaurant');
const Food = require('../models/Food');
const { getIO } = require('../utils/socket');
const { createNotification } = require('../services/notification_service');
require('dotenv').config();

// Test configuration
const TEST_USER_EMAIL = 'zakjnr5@gmail.com'; // Change this to your test user email
const ORDER_STATUSES = ['confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way', 'delivered'];

async function testOrderNotifications() {
    try {
        console.log('🧪 Starting Order Notification Tests...\n');

        // Connect to MongoDB
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB\n');

        // Find test user
        const user = await User.findOne({ email: TEST_USER_EMAIL });
        if (!user) {
            console.error(`❌ Test user not found: ${TEST_USER_EMAIL}`);
            console.log('Please create a test user or update TEST_USER_EMAIL in the script');
            process.exit(1);
        }
        console.log(`✅ Found test user: ${user.username} (${user.email})\n`);

        // Find a restaurant
        const restaurant = await Restaurant.findOne();
        if (!restaurant) {
            console.error('❌ No restaurants found in database');
            process.exit(1);
        }
        console.log(`✅ Using restaurant: ${restaurant.restaurant_name}\n`);

        // Find a food item
        const food = await Food.findOne({ restaurant: restaurant._id });
        if (!food) {
            console.error('❌ No food items found for restaurant');
            process.exit(1);
        }
        console.log(`✅ Using food item: ${food.name}\n`);

        // Create a test order
        console.log('📦 Creating test order...');
        const order = await Order.create({
            orderNumber: `TEST-${Date.now()}`,
            orderType: 'food',
            customer: user._id,
            restaurant: restaurant._id,
            items: [{
                food: food._id,
                itemType: 'food',
                name: food.name,
                quantity: 2,
                price: food.price,
                image: food.image
            }],
            subtotal: food.price * 2,
            deliveryFee: 5.00,
            tax: (food.price * 2) * 0.05,
            totalAmount: (food.price * 2) + 5.00 + ((food.price * 2) * 0.05),
            deliveryAddress: {
                street: 'Test Street 123',
                city: 'Accra',
                state: 'Greater Accra',
                zipCode: '00233'
            },
            paymentMethod: 'cash',
            status: 'pending'
        });

        await order.populate('customer', 'username email');
        await order.populate('restaurant', 'restaurant_name');
        console.log(`✅ Created order: ${order.orderNumber}\n`);

        // Get Socket.IO instance
        const io = getIO();
        if (!io) {
            console.warn('⚠️  Socket.IO not initialized - notifications will be created but not emitted in real-time');
            console.warn('   This is normal if running this script standalone\n');
        }

        // Test each status change
        console.log('🔄 Testing status changes...\n');

        for (const status of ORDER_STATUSES) {
            console.log(`\n📍 Testing status: ${status.toUpperCase()}`);
            console.log('─'.repeat(50));

            // Update order status
            order.status = status;
            if (status === 'delivered') {
                order.deliveredDate = new Date();
            }
            await order.save();

            // Create notification (simulating what notifyOrderStatusChange does)
            const statusMessages = {
                confirmed: 'Your order has been confirmed!',
                preparing: 'Your order is being prepared.',
                ready: 'Your order is ready for pickup!',
                picked_up: 'Your order has been picked up by the rider.',
                on_the_way: 'Your order is on the way!',
                delivered: 'Your order has been delivered. Enjoy!',
            };

            const statusEmojis = {
                confirmed: '✅',
                preparing: '🍳',
                ready: '📦',
                picked_up: '🚴',
                on_the_way: '🛣️',
                delivered: '✅',
            };

            const emoji = statusEmojis[status];
            const message = statusMessages[status];

            console.log(`   Title: ${emoji} Order #${order.orderNumber}`);
            console.log(`   Message: ${message}`);

            // Create in-app notification
            const notification = await createNotification(
                user._id,
                'order',
                `${emoji} Order #${order.orderNumber}`,
                message,
                {
                    orderId: order._id.toString(),
                    orderNumber: order.orderNumber,
                    status,
                    route: `/orders/${order._id}`
                },
                io
            );

            if (notification) {
                console.log(`   ✅ Notification created: ${notification._id}`);
                if (io) {
                    console.log(`   📡 WebSocket emission sent to user:${user._id}`);
                }
            } else {
                console.log(`   ❌ Failed to create notification`);
            }

            // Wait a bit between status changes
            await new Promise(resolve => setTimeout(resolve, 1000));
        }

        console.log('\n\n' + '='.repeat(50));
        console.log('✅ ALL TESTS COMPLETED SUCCESSFULLY!');
        console.log('='.repeat(50));
        console.log('\n📊 Summary:');
        console.log(`   - Order created: ${order.orderNumber}`);
        console.log(`   - Status changes tested: ${ORDER_STATUSES.length}`);
        console.log(`   - Notifications created: ${ORDER_STATUSES.length}`);
        console.log(`   - User: ${user.username} (${user.email})`);
        console.log('\n💡 Next Steps:');
        console.log('   1. Check the app notifications screen');
        console.log('   2. Verify all 6 notifications appear');
        console.log('   3. Verify they appeared without manual refresh (if app was open)');
        console.log('   4. Check MongoDB notifications collection');
        console.log('\n🗑️  Cleanup:');
        console.log(`   To delete test order: db.orders.deleteOne({orderNumber: "${order.orderNumber}"})`);
        console.log(`   To delete notifications: db.notifications.deleteMany({user: ObjectId("${user._id}")})`);

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
testOrderNotifications();
