/**
 * Script to create dummy order history for testing "Order Again" section
 * 
 * Usage: node create_dummy_orders.js
 * 
 * This will create delivered orders for existing users with random food items
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Order = require('./models/Order');
const User = require('./models/User');
const Food = require('./models/Food');
const Restaurant = require('./models/Restaurant');

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo', {
    useNewUrlParser: true,
    useUnifiedTopology: true,
});

const db = mongoose.connection;
db.on('error', console.error.bind(console, 'MongoDB connection error:'));
db.once('open', async () => {
    console.log('✅ Connected to MongoDB');
    await createDummyOrders();
});

async function createDummyOrders() {
    try {
        console.log('\n🔍 Finding customers and food items...');

        // Get all customers
        const customers = await User.find({ role: 'customer' }).limit(10);
        if (customers.length === 0) {
            console.log('❌ No customers found. Please create some users first.');
            process.exit(1);
        }
        console.log(`✅ Found ${customers.length} customers`);

        // Get all food items
        const foods = await Food.find({ isAvailable: true }).limit(50);
        if (foods.length === 0) {
            console.log('❌ No food items found. Please add some foods first.');
            process.exit(1);
        }
        console.log(`✅ Found ${foods.length} food items`);

        // Get all restaurants
        const restaurants = await Restaurant.find().limit(10);
        if (restaurants.length === 0) {
            console.log('❌ No restaurants found. Please add some restaurants first.');
            process.exit(1);
        }
        console.log(`✅ Found ${restaurants.length} restaurants`);

        console.log('\n📦 Creating dummy orders...\n');

        let ordersCreated = 0;

        // Create 3-5 orders per customer
        for (const customer of customers) {
            const orderCount = Math.floor(Math.random() * 3) + 3; // 3-5 orders

            for (let i = 0; i < orderCount; i++) {
                // Random restaurant
                const restaurant = restaurants[Math.floor(Math.random() * restaurants.length)];

                // Random 1-4 food items
                const itemCount = Math.floor(Math.random() * 4) + 1;
                const orderItems = [];
                let subtotal = 0;

                for (let j = 0; j < itemCount; j++) {
                    const food = foods[Math.floor(Math.random() * foods.length)];
                    const quantity = Math.floor(Math.random() * 2) + 1; // 1-2 quantity
                    const itemTotal = food.price * quantity;
                    subtotal += itemTotal;

                    orderItems.push({
                        food: food._id,
                        name: food.name,
                        quantity: quantity,
                        price: food.price,
                        image: food.image,
                    });
                }

                const deliveryFee = restaurant.delivery_fee || 5;
                const tax = subtotal * 0.05;
                const totalAmount = subtotal + deliveryFee + tax;

                // Random date in the last 30 days
                const daysAgo = Math.floor(Math.random() * 30);
                const deliveredDate = new Date();
                deliveredDate.setDate(deliveredDate.getDate() - daysAgo);
                deliveredDate.setHours(Math.floor(Math.random() * 24));
                deliveredDate.setMinutes(Math.floor(Math.random() * 60));

                // Create order
                const order = await Order.create({
                    orderNumber: `ORD-${Date.now()}-${Math.floor(Math.random() * 10000)}`,
                    customer: customer._id,
                    restaurant: restaurant._id,
                    items: orderItems,
                    subtotal,
                    deliveryFee,
                    tax,
                    totalAmount,
                    deliveryAddress: {
                        street: '123 Test Street',
                        city: 'Accra',
                        state: 'Greater Accra',
                        zipCode: '00233',
                    },
                    paymentMethod: 'mobile_money',
                    paymentStatus: 'paid',
                    status: 'delivered', // IMPORTANT: Set to delivered
                    orderDate: new Date(deliveredDate.getTime() - 3600000), // 1 hour before delivery
                    deliveredDate: deliveredDate,
                });

                ordersCreated++;
                console.log(`✅ Created order ${order.orderNumber} for ${customer.username}`);
                console.log(`   - Items: ${orderItems.length} items`);
                console.log(`   - Total: GHS ${totalAmount.toFixed(2)}`);
                console.log(`   - Delivered: ${daysAgo} days ago\n`);
            }
        }

        console.log(`\n🎉 Successfully created ${ordersCreated} dummy orders!`);
        console.log(`\n📊 Summary:`);
        console.log(`   - Customers with orders: ${customers.length}`);
        console.log(`   - Total orders created: ${ordersCreated}`);
        console.log(`   - Average orders per customer: ${(ordersCreated / customers.length).toFixed(1)}`);
        console.log(`\n✅ You can now test the "Order Again" section in the app!`);

        process.exit(0);
    } catch (error) {
        console.error('❌ Error creating dummy orders:', error);
        process.exit(1);
    }
}
