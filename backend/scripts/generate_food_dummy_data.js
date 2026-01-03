/**
 * Dummy Data Generator for Food Items
 * 
 * This script generates realistic test data for:
 * - Order counts (for popular items)
 * - Discount percentages
 * 
 * Run with: node backend/generate_food_dummy_data.js
 */

// Load environment variables
require('dotenv').config();

const mongoose = require('mongoose');

// Import models
const Food = require('../models/Food');
const Restaurant = require('../models/Restaurant'); // For populate

// Connect to MongoDB (uses MONGODB_URI from .env)
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');

const db = mongoose.connection;
db.on('error', console.error.bind(console, 'MongoDB connection error:'));
db.once('open', () => {
    console.log('✅ Connected to MongoDB');
    generateDummyData();
});

async function generateDummyData() {
    try {
        console.log('\n🚀 Starting dummy data generation for Food items...\n');

        // Step 1: Add order counts to items
        await generateOrderCounts();

        // Step 2: Add discount percentages to some items
        await generateDiscounts();

        console.log('\n✅ Dummy data generation complete!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error generating dummy data:', error);
        process.exit(1);
    }
}

/**
 * Generate realistic order counts for food items
 * - Popular items: 50-200 orders
 * - Regular items: 10-50 orders
 * - Less popular: 0-10 orders
 */
async function generateOrderCounts() {
    console.log('📊 Generating order counts...');

    const items = await Food.find({ isAvailable: true });

    if (!items || items.length === 0) {
        console.log('   ⚠️  No food items found in database');
        console.log('   💡 Tip: Add food items first before running this script');
        return;
    }

    console.log(`   Found ${items.length} food items`);

    let updated = 0;

    for (const item of items) {
        // Generate order count based on rating
        // Higher rated items tend to have more orders
        let orderCount;

        if (item.rating >= 4.5) {
            // Popular items (high rating)
            orderCount = Math.floor(Math.random() * 150) + 50; // 50-200
        } else if (item.rating >= 4.0) {
            // Regular items (good rating)
            orderCount = Math.floor(Math.random() * 40) + 10; // 10-50
        } else if (item.rating >= 3.0) {
            // Less popular items
            orderCount = Math.floor(Math.random() * 10); // 0-10
        } else {
            // Low rated items
            orderCount = Math.floor(Math.random() * 5); // 0-5
        }

        item.orderCount = orderCount;
        await item.save();
        updated++;

        if (updated % 50 === 0) {
            console.log(`   Updated ${updated}/${items.length} items...`);
        }
    }

    console.log(`   ✅ Updated ${updated} food items with order counts`);

    // Show top 10 popular items
    const topItems = await Food.find({ isAvailable: true })
        .sort({ orderCount: -1 })
        .limit(10)
        .select('name orderCount rating')
        .populate('restaurant', 'restaurant_name');

    console.log('\n   📈 Top 10 Popular Food Items:');
    topItems.forEach((item, index) => {
        const restaurantName = item.restaurant?.restaurant_name || 'Unknown';
        console.log(`   ${index + 1}. ${item.name} (${restaurantName}) - ${item.orderCount} orders (⭐ ${item.rating})`);
    });
}

/**
 * Generate discount percentages for items
 * - 20% of items get discounts
 * - Discounts range from 10% to 50%
 * - Set discount end dates
 */
async function generateDiscounts() {
    console.log('\n🏷️  Generating discounts...');

    const items = await Food.find({ isAvailable: true });

    if (!items || items.length === 0) {
        console.log('   ⚠️  No food items found in database');
        return;
    }

    const itemsToDiscount = Math.floor(items.length * 0.2); // 20% of items

    console.log(`   Applying discounts to ${itemsToDiscount} items...`);

    // Shuffle items and take first 20%
    const shuffled = items.sort(() => 0.5 - Math.random());
    const discountItems = shuffled.slice(0, itemsToDiscount);

    let updated = 0;

    for (const item of discountItems) {
        // Generate discount percentage (10-50%)
        const discountPercent = Math.floor(Math.random() * 40) + 10;

        // Set discount end date (1-30 days from now)
        const daysUntilEnd = Math.floor(Math.random() * 30) + 1;
        const endDate = new Date();
        endDate.setDate(endDate.getDate() + daysUntilEnd);

        item.discountPercentage = discountPercent;
        item.discountEndDate = endDate;
        await item.save();
        updated++;
    }

    console.log(`   ✅ Applied discounts to ${updated} food items`);

    // Show sample discounted items
    const discountedItems = await Food.find({
        discountPercentage: { $gt: 0 },
        isAvailable: true
    })
        .sort({ discountPercentage: -1 })
        .limit(5)
        .select('name price discountPercentage discountEndDate')
        .populate('restaurant', 'restaurant_name');

    console.log('\n   🔥 Sample Discounted Food Items:');
    discountedItems.forEach((item, index) => {
        const originalPrice = item.price;
        const discountedPrice = (originalPrice * (1 - item.discountPercentage / 100)).toFixed(2);
        const daysLeft = Math.ceil((item.discountEndDate - new Date()) / (1000 * 60 * 60 * 24));
        const restaurantName = item.restaurant?.restaurant_name || 'Unknown';
        console.log(`   ${index + 1}. ${item.name} (${restaurantName})`);
        console.log(`      ${item.discountPercentage}% OFF - $${originalPrice} → $${discountedPrice}`);
        console.log(`      Ends in ${daysLeft} days`);
    });
}

// Handle process termination
process.on('SIGINT', () => {
    console.log('\n\n⚠️  Process interrupted');
    mongoose.connection.close();
    process.exit(0);
});
