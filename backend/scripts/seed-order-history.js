const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const User = require('../models/User');
const Restaurant = require('../models/Restaurant');
const Food = require('../models/Food');
const Order = require('../models/Order');

const daysAgo = (days) => {
    const date = new Date();
    date.setDate(date.getDate() - days);
    return date;
};

async function seedOrderHistory() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        // Find a customer user
        const customer = await User.findOne({ role: 'customer' });
        if (!customer) {
            console.log('❌ No customer user found. Please create a customer account first.');
            process.exit(0);
        }

        console.log(`📋 Creating order history for customer: ${customer.email}`);

        // Get some food items
        const foods = await Food.find({ isAvailable: true })
            .populate('restaurant')
            .limit(10);

        if (foods.length === 0) {
            console.log('❌ No food items found. Please run setup-restaurants-and-foods.js first.');
            process.exit(0);
        }

        // Delete existing orders for this customer to start fresh
        await Order.deleteMany({ customer: customer._id, orderType: 'food' });
        console.log('🗑️  Cleared existing food orders for this customer');

        // Create 5 completed orders with different dates
        const ordersToCreate = [
            {
                daysAgo: 2,
                items: [foods[0], foods[1]],
                total: 75.50
            },
            {
                daysAgo: 5,
                items: [foods[2]],
                total: 42.00
            },
            {
                daysAgo: 7,
                items: [foods[3], foods[4], foods[5]],
                total: 120.00
            },
            {
                daysAgo: 10,
                items: [foods[6]],
                total: 35.00
            },
            {
                daysAgo: 14,
                items: [foods[7], foods[8]],
                total: 88.50
            }
        ];

        for (const orderData of ordersToCreate) {
            const orderDate = daysAgo(orderData.daysAgo);
            const deliveredDate = new Date(orderDate.getTime() + 45 * 60 * 1000); // 45 mins later

            const orderItems = orderData.items.map((food, index) => ({
                itemType: 'food',
                food: food._id,
                quantity: index === 0 ? 2 : 1,
                price: food.price,
                name: food.name,
                image: food.foodImage
            }));

            const order = await Order.create({
                customer: customer._id,
                orderType: 'food',
                restaurant: orderData.items[0].restaurant._id,
                items: orderItems,
                subtotal: orderData.total - 5.00,
                totalAmount: orderData.total,
                deliveryFee: 5.00,
                status: 'delivered',
                paymentMethod: 'mobile_money',
                paymentStatus: 'paid',
                deliveryAddress: {
                    street: '123 Test Street',
                    city: 'Accra',
                    latitude: 5.6,
                    longitude: -0.1
                },
                orderDate: orderDate,
                deliveredDate: deliveredDate
            });

            console.log(`   ✅ Created order from ${orderData.daysAgo} days ago (${orderData.items.length} items)`);
        }

        console.log('\n✅ Order history seeding completed!');
        console.log(`📊 Created ${ordersToCreate.length} completed orders for ${customer.email}`);

        process.exit(0);
    } catch (error) {
        console.error('❌ Error seeding order history:', error);
        process.exit(1);
    }
}

seedOrderHistory();
