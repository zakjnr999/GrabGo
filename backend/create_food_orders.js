require('dotenv').config({ path: './.env' });
const mongoose = require('mongoose');
const Order = require('./models/Order');
const Food = require('./models/Food');
const User = require('./models/User');

// MongoDB connection
const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
    console.error('❌ MONGODB_URI is not defined in .env file');
    process.exit(1);
}

async function createFoodOrders() {
    try {
        console.log('🔌 Connecting to MongoDB...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        // Find the test user
        const user = await User.findOne({ email: 'zakjnr5@gmail.com' });
        if (!user) {
            console.error('❌ User zakjnr5@gmail.com not found');
            process.exit(1);
        }
        console.log(`✅ Found user: ${user.email}`);

        // Get some food items
        const foods = await Food.find().limit(10);
        if (foods.length === 0) {
            console.error('❌ No food items found in database');
            process.exit(1);
        }
        console.log(`✅ Found ${foods.length} food items`);

        // Delete existing food orders for this user
        const deleteResult = await Order.deleteMany({
            customer: user._id,
            orderType: 'food'
        });
        console.log(`🗑️  Deleted ${deleteResult.deletedCount} existing food orders`);

        // Create 5 food orders with different dates
        const orders = [];
        const now = new Date();

        for (let i = 0; i < 5; i++) {
            // Select 2-4 random food items for this order
            const itemCount = Math.floor(Math.random() * 3) + 2;
            const selectedFoods = [];
            const usedIndices = new Set();

            while (selectedFoods.length < itemCount) {
                const randomIndex = Math.floor(Math.random() * foods.length);
                if (!usedIndices.has(randomIndex)) {
                    usedIndices.add(randomIndex);
                    selectedFoods.push(foods[randomIndex]);
                }
            }

            // Create order items
            const orderItems = selectedFoods.map(food => ({
                food: food._id,
                itemType: 'food',
                name: food.name,
                quantity: Math.floor(Math.random() * 3) + 1,
                price: food.price,
                image: food.food_image
            }));

            // Calculate total
            const subtotal = orderItems.reduce((sum, item) => sum + (item.price * item.quantity), 0);
            const deliveryFee = 5.00;
            const total = subtotal + deliveryFee;

            // Create order date (going back in time)
            const daysAgo = (i + 1) * 3; // 3, 6, 9, 12, 15 days ago
            const orderDate = new Date(now);
            orderDate.setDate(orderDate.getDate() - daysAgo);

            const deliveredDate = new Date(orderDate);
            deliveredDate.setHours(deliveredDate.getHours() + 1); // Delivered 1 hour after order

            const order = new Order({
                customer: user._id,
                orderType: 'food',
                items: orderItems,
                subtotal: subtotal,
                deliveryFee: deliveryFee,
                total: total,
                totalAmount: total, // Required field
                status: 'delivered',
                orderDate: orderDate,
                deliveredDate: deliveredDate,
                deliveryAddress: {
                    street: '123 Test Street',
                    city: 'Accra',
                    state: 'Greater Accra',
                    country: 'Ghana',
                    postalCode: '00233'
                },
                paymentMethod: 'card',
                paymentStatus: 'paid'
            });

            orders.push(order);
        }

        // Save orders one at a time to allow pre-save hook to generate orderNumber
        console.log(`\n💾 Saving ${orders.length} orders...`);
        for (let i = 0; i < orders.length; i++) {
            await orders[i].save();
            console.log(`  ✅ Saved order ${i + 1}/${orders.length}`);
        }

        console.log(`✅ Created ${orders.length} food orders`);

        // Display summary
        console.log('\n📊 Order Summary:');
        orders.forEach((order, index) => {
            console.log(`\nOrder ${index + 1}:`);
            console.log(`  Date: ${order.orderDate.toLocaleDateString()}`);
            console.log(`  Items: ${order.items.length}`);
            order.items.forEach(item => {
                console.log(`    - ${item.name} x${item.quantity} @ GHS ${item.price}`);
            });
            console.log(`  Total: GHS ${order.total.toFixed(2)}`);
        });

        console.log('\n✅ Food orders created successfully!');
        console.log('🔄 Restart the app to see the Order Again section');

    } catch (error) {
        console.error('❌ Error creating food orders:', error);
    } finally {
        await mongoose.connection.close();
        console.log('🔌 Disconnected from MongoDB');
    }
}

createFoodOrders();
