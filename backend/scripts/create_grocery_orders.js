const path = require('path');
const dotenv = require('dotenv');

// Load env vars from .env file in backend directory
const envPath = path.resolve(__dirname, '.env');
const result = dotenv.config({ path: envPath });

if (result.error) {
    console.error('❌ Error loading .env file:', result.error);
    console.error('   Looking for .env at:', envPath);
    process.exit(1);
}

// Validate MONGODB_URI exists
if (!process.env.MONGODB_URI) {
    console.error('❌ MONGODB_URI not found in .env file');
    console.error('   Please ensure your .env file contains MONGODB_URI');
    console.error('   Expected location:', envPath);
    process.exit(1);
}

const mongoose = require('mongoose');
const Order = require('../models/Order');
const GroceryItem = require('../models/GroceryItem');
const GroceryStore = require('../models/GroceryStore');
const User = require('../models/User');

/**
 * Script to create dummy grocery orders for testing Buy Again section
 * 
 * This will:
 * 1. Find a test user
 * 2. Find grocery items and stores
 * 3. Create several completed grocery orders
 * 4. Allow testing of the Buy Again section
 */

async function createDummyGroceryOrders() {
    try {
        // Connect to MongoDB
        console.log('📡 Connecting to MongoDB...');
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB\n');

        // Find or create a test user
        console.log('👤 Finding test user...');
        let testUser = await User.findOne({ email: 'zakjnr5@gmail.com' });

        if (!testUser) {
            console.log('⚠️  No user found with email: zakjnr5@gmail.com');
            console.log('   Please provide a user email:');
            console.log('   You can use any existing user email from your database');
            console.log('   Or create a user first and run this script again\n');
            process.exit(1);
        }

        console.log(`✅ Found user: ${testUser.name} (${testUser.email})\n`);

        // Get grocery items and stores
        console.log('🛒 Fetching grocery items and stores...');
        const groceryItems = await GroceryItem.find().limit(15);
        const groceryStores = await GroceryStore.find().limit(3);

        if (groceryItems.length === 0) {
            console.log('❌ No grocery items found. Run seed_groceries.js first');
            process.exit(1);
        }

        if (groceryStores.length === 0) {
            console.log('❌ No grocery stores found. Run seed_groceries.js first');
            process.exit(1);
        }

        console.log(`✅ Found ${groceryItems.length} grocery items`);
        console.log(`✅ Found ${groceryStores.length} grocery stores\n`);

        // Create 5 dummy orders with different dates
        const ordersToCreate = 5;
        const createdOrders = [];

        console.log(`📦 Creating ${ordersToCreate} dummy grocery orders...\n`);

        for (let i = 0; i < ordersToCreate; i++) {
            // Select random items for this order (2-5 items per order)
            const itemCount = Math.floor(Math.random() * 4) + 2; // 2-5 items
            const orderItems = [];
            let subtotal = 0;

            for (let j = 0; j < itemCount; j++) {
                const randomItem = groceryItems[Math.floor(Math.random() * groceryItems.length)];
                const quantity = Math.floor(Math.random() * 3) + 1; // 1-3 quantity
                const itemTotal = randomItem.price * quantity;

                orderItems.push({
                    groceryItem: randomItem._id,
                    itemType: 'grocery',
                    name: randomItem.name,
                    quantity,
                    price: randomItem.price,
                    image: randomItem.image,
                    unit: randomItem.unit
                });

                subtotal += itemTotal;
            }

            // Select random store
            const randomStore = groceryStores[Math.floor(Math.random() * groceryStores.length)];

            // Calculate dates (orders from 1-30 days ago)
            const daysAgo = (i + 1) * 5; // 5, 10, 15, 20, 25 days ago
            const orderDate = new Date();
            orderDate.setDate(orderDate.getDate() - daysAgo);

            const deliveredDate = new Date(orderDate);
            deliveredDate.setHours(deliveredDate.getHours() + 2); // Delivered 2 hours after order

            const deliveryFee = randomStore.deliveryFee || 5.00;
            const tax = subtotal * 0.05; // 5% tax
            const totalAmount = subtotal + deliveryFee + tax;

            // Create order
            const order = await Order.create({
                orderType: 'grocery',
                customer: testUser._id,
                groceryStore: randomStore._id,
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
                    latitude: 5.6037,
                    longitude: -0.1870
                },
                paymentMethod: 'mobile_money',
                paymentProvider: 'mtn_momo',
                paymentStatus: 'paid',
                status: 'delivered',
                orderDate,
                deliveredDate
            });

            createdOrders.push(order);

            console.log(`   ✅ Order ${i + 1}/${ordersToCreate}: ${order.orderNumber}`);
            console.log(`      📅 Ordered: ${daysAgo} days ago`);
            console.log(`      🛍️  Items: ${orderItems.length}`);
            console.log(`      💰 Total: GHS ${totalAmount.toFixed(2)}`);
            console.log(`      🏪 Store: ${randomStore.store_name}\n`);
        }

        console.log(`\n🎉 Successfully created ${createdOrders.length} grocery orders!`);
        console.log(`\n📊 Summary:`);
        console.log(`   User: ${testUser.name} (${testUser.email})`);
        console.log(`   Orders: ${createdOrders.length}`);
        console.log(`   Date Range: ${Math.max(...createdOrders.map((_, i) => (i + 1) * 5))} days ago to ${Math.min(...createdOrders.map((_, i) => (i + 1) * 5))} days ago`);
        console.log(`\n✅ You can now test the Buy Again section in the app!`);
        console.log(`   The section should show the most recently ordered grocery items.\n`);

    } catch (error) {
        console.error('\n❌ Error creating dummy orders:', error.message);
        console.error(error);
    } finally {
        await mongoose.connection.close();
        console.log('📡 Disconnected from MongoDB');
        process.exit(0);
    }
}

// Run the script
createDummyGroceryOrders();
