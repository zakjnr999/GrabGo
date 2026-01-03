/**
 * Script to add discount data to existing foods for testing deals feature
 * 
 * Usage: node add_discount_data.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const Food = require('../models/Food');

// Connect to MongoDB
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');

const db = mongoose.connection;
db.on('error', console.error.bind(console, 'MongoDB connection error:'));
db.once('open', async () => {
    console.log('✅ Connected to MongoDB');
    await addDiscountData();
});

async function addDiscountData() {
    try {
        console.log('\n🔍 Finding foods to add discounts...');

        // Get all available foods
        const foods = await Food.find({ isAvailable: true }).limit(50);

        if (foods.length === 0) {
            console.log('❌ No foods found. Please add some foods first.');
            process.exit(1);
        }

        console.log(`✅ Found ${foods.length} foods`);
        console.log('\n💰 Adding discount data...\n');

        // Discount options
        const discountOptions = [10, 20, 30, 40, 50];

        // Select random 20-30 foods for discounts
        const numberOfDeals = Math.min(Math.floor(Math.random() * 11) + 20, foods.length);
        const shuffled = foods.sort(() => 0.5 - Math.random());
        const selectedFoods = shuffled.slice(0, numberOfDeals);

        let updated = 0;

        for (const food of selectedFoods) {
            // Random discount percentage
            const discountPercentage = discountOptions[Math.floor(Math.random() * discountOptions.length)];

            // Random end date (1-30 days from now)
            const daysUntilExpiry = Math.floor(Math.random() * 30) + 1;
            const discountEndDate = new Date();
            discountEndDate.setDate(discountEndDate.getDate() + daysUntilExpiry);

            // Update food with discount
            food.discountPercentage = discountPercentage;
            food.discountEndDate = discountEndDate;
            await food.save();

            updated++;
            console.log(`✅ Added ${discountPercentage}% discount to "${food.name}"`);
            console.log(`   - Expires in ${daysUntilExpiry} days (${discountEndDate.toLocaleDateString()})\n`);
        }

        console.log(`\n🎉 Successfully added discounts to ${updated} foods!`);
        console.log(`\n📊 Summary:`);
        console.log(`   - Total foods: ${foods.length}`);
        console.log(`   - Foods with discounts: ${updated}`);
        console.log(`   - Discount range: 10% - 50%`);
        console.log(`\n✅ You can now test the deals endpoint!`);
        console.log(`\n🔗 Test API: GET http://localhost:5000/api/foods/deals`);

        process.exit(0);
    } catch (error) {
        console.error('❌ Error adding discount data:', error);
        process.exit(1);
    }
}
