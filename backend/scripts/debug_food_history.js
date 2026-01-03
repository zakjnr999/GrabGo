require('dotenv').config({ path: './.env' });
const mongoose = require('mongoose');
const Order = require('../models/Order');
const Food = require('../models/Food');
const Category = require('../models/Category');
const Restaurant = require('../models/Restaurant');
const User = require('../models/User');

const MONGODB_URI = process.env.MONGODB_URI;

async function debugOrderHistory() {
    try {
        console.log('🔌 Connecting to MongoDB...');
        await mongoose.connect(MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        const user = await User.findOne({ email: 'zakjnr5@gmail.com' });
        if (!user) {
            console.log('User not found');
            return;
        }
        const userId = user._id;
        console.log('User ID:', userId);

        console.log('🔍 Running query...');
        // Exact query from routes/foods.js
        const orders = await Order.find({
            customer: userId,
            orderType: 'food',
            status: 'delivered'
        })
            .populate({
                path: 'items.food',
                model: 'Food',
                populate: [
                    { path: 'category', model: 'Category' },
                    { path: 'restaurant', model: 'Restaurant' }
                ]
            })
            .sort({ deliveredDate: -1, orderDate: -1 })
            .limit(50);

        console.log(`✅ Query successful! Found ${orders.length} orders.`);

        // Test the processing logic
        const itemsMap = new Map();
        orders.forEach(order => {
            order.items.forEach(item => {
                if (item.itemType === 'food' && item.food) {
                    console.log(` - Processing item: ${item.name} (${item.food._id})`);
                } else {
                    console.log(` - Skipped item (type: ${item.itemType}, food: ${item.food})`);
                }
            });
        });

    } catch (error) {
        console.error('❌ Query Failed!');
        console.error(error);
    } finally {
        await mongoose.connection.close();
    }
}

debugOrderHistory();
