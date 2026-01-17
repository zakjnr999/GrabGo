const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, './.env') });
const Food = require('./models/Food');

async function testData() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        const total = await Food.countDocuments();
        console.log('Total food items:', total);

        const deals = await Food.find({ discountPercentage: { $gt: 0 } })
            .populate('restaurant', 'restaurantName')
            .limit(20);

        console.log('\n--- Active Deals (First 20) ---');
        deals.forEach(f => {
            console.log(`[${f.restaurant?.restaurantName || 'Unknown'}] ${f.name} - ${f.discountPercentage}% Off (GHS ${f.price})`);
        });

        const popular = await Food.find({})
            .sort({ orderCount: -1 })
            .limit(10);

        console.log('\n--- Popular Items ---');
        popular.forEach(f => {
            console.log(`${f.name}: ${f.orderCount} orders`);
        });

    } catch (err) {
        console.error('Error:', err);
    } finally {
        await mongoose.disconnect();
    }
}

testData();
