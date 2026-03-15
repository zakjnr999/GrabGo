const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const User = require('../models/User');
const GroceryStore = require('../models/GroceryStore');
const GroceryItem = require('../models/GroceryItem');
const Order = require('../models/Order');

const daysAgo = (days) => {
    const date = new Date();
    date.setDate(date.getDate() - days);
    return date;
};

async function seedGroceryOrderHistory() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        // Find a customer user
        const customer = await User.findOne({ role: 'customer' });
        if (!customer) {
            console.log('❌ No customer user found. Please create a customer account first.');
            process.exit(0);
        }

        console.log(`📋 Creating grocery order history for customer: ${customer.email}`);

        // Get some grocery items
        const groceryItems = await GroceryItem.find({ isAvailable: true })
            .populate('store')
            .limit(15);

        if (groceryItems.length === 0) {
            console.log('❌ No grocery items found. Please run setup-groceries.js first.');
            process.exit(0);
        }

        // Delete existing grocery orders for this customer
        await Order.deleteMany({ customer: customer._id, orderType: 'grocery' });
        console.log('🗑️  Cleared existing grocery orders for this customer');

        // Create 5 completed grocery orders with different dates
        const ordersToCreate = [
            {
                daysAgo: 3,
                items: [groceryItems[0], groceryItems[1], groceryItems[2]],
                total: 85.00
            },
            {
                daysAgo: 6,
                items: [groceryItems[3], groceryItems[4]],
                total: 52.00
            },
            {
                daysAgo: 9,
                items: [groceryItems[5], groceryItems[6], groceryItems[7], groceryItems[8]],
                total: 135.00
            },
            {
                daysAgo: 12,
                items: [groceryItems[9], groceryItems[10]],
                total: 48.00
            },
            {
                daysAgo: 16,
                items: [groceryItems[11], groceryItems[12], groceryItems[13]],
                total: 95.00
            }
        ];

        for (const orderData of ordersToCreate) {
            const orderDate = daysAgo(orderData.daysAgo);
            const deliveredDate = new Date(orderDate.getTime() + 60 * 60 * 1000); // 60 mins later

            const orderItems = orderData.items.map((item, index) => ({
                itemType: 'grocery',
                groceryItem: item._id,
                quantity: index === 0 ? 3 : (index === 1 ? 2 : 1),
                price: item.price,
                name: item.name,
                image: item.thumbnailImage,
                unit: item.unit
            }));

            const order = await Order.create({
                customer: customer._id,
                orderType: 'grocery',
                groceryStore: orderData.items[0].store._id,
                items: orderItems,
                subtotal: orderData.total - 5.00,
                totalAmount: orderData.total,
                deliveryFee: 5.00,
                status: 'delivered',
                paymentMethod: 'card',
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

            console.log(`   ✅ Created grocery order from ${orderData.daysAgo} days ago (${orderData.items.length} items)`);
        }

        console.log('\n✅ Grocery order history seeding completed!');
        console.log(`📊 Created ${ordersToCreate.length} completed grocery orders for ${customer.email}`);

        process.exit(0);
    } catch (error) {
        console.error('❌ Error seeding grocery order history:', error);
        process.exit(1);
    }
}

seedGroceryOrderHistory();
