const mongoose = require('mongoose');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const GroceryItem = require('../models/GroceryItem');

async function updateGroceryOrderCounts() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        // Get all grocery items
        const items = await GroceryItem.find({});
        console.log(`📦 Found ${items.length} grocery items`);

        let updated = 0;
        for (const item of items) {
            // Generate random order count between 0 and 300
            const orderCount = Math.floor(Math.random() * 301);

            await GroceryItem.findByIdAndUpdate(item._id, { orderCount });
            updated++;
        }

        console.log(`✅ Updated ${updated} grocery items with order counts`);

        process.exit(0);
    } catch (error) {
        console.error('❌ Error updating grocery order counts:', error);
        process.exit(1);
    }
}

updateGroceryOrderCounts();
