/**
 * Dummy Data Generator for Testing
 * 
 * This script generates realistic test data for:
 * - Order counts (for popular items)
 * - Order history with dates
 * - Discount percentages
 * 
 * Run with: node backend/generate_dummy_data.js
 */

// Load environment variables
require('dotenv').config();

const mongoose = require('mongoose');

// Import models
const GroceryItem = require('../models/GroceryItem');

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
        console.log('\n🚀 Starting dummy data generation...\n');

        // Step 1: Add order counts to items
        await generateOrderCounts();

        // Step 2: Add discount percentages to some items
        await generateDiscounts();

        // Step 3: Create sample order history (optional)
        // await generateOrderHistory();

        console.log('\n✅ Dummy data generation complete!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Error generating dummy data:', error);
        process.exit(1);
    }
}

/**
 * Generate realistic order counts for items
 * - Popular items: 50-200 orders
 * - Regular items: 10-50 orders
 * - Less popular: 0-10 orders
 */
async function generateOrderCounts() {
    console.log('📊 Generating order counts...');

    const items = await GroceryItem.find({ isAvailable: true });

    if (!items || items.length === 0) {
        console.log('   ⚠️  No items found in database');
        console.log('   💡 Tip: Add items first before running this script');
        return;
    }

    console.log(`   Found ${items.length} items`);

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

    console.log(`   ✅ Updated ${updated} items with order counts`);

    // Show top 10 popular items
    const topItems = await GroceryItem.find({ isAvailable: true })
        .sort({ orderCount: -1 })
        .limit(10)
        .select('name orderCount rating');

    console.log('\n   📈 Top 10 Popular Items:');
    topItems.forEach((item, index) => {
        console.log(`   ${index + 1}. ${item.name} - ${item.orderCount} orders (⭐ ${item.rating})`);
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

    const items = await GroceryItem.find({ isAvailable: true });

    if (!items || items.length === 0) {
        console.log('   ⚠️  No items found in database');
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

    console.log(`   ✅ Applied discounts to ${updated} items`);

    // Show sample discounted items
    const discountedItems = await GroceryItem.find({
        discountPercentage: { $gt: 0 },
        isAvailable: true
    })
        .sort({ discountPercentage: -1 })
        .limit(5)
        .select('name price discountPercentage discountEndDate');

    console.log('\n   🔥 Sample Discounted Items:');
    discountedItems.forEach((item, index) => {
        const originalPrice = item.price;
        const discountedPrice = (originalPrice * (1 - item.discountPercentage / 100)).toFixed(2);
        const daysLeft = Math.ceil((item.discountEndDate - new Date()) / (1000 * 60 * 60 * 24));
        console.log(`   ${index + 1}. ${item.name}`);
        console.log(`      ${item.discountPercentage}% OFF - $${originalPrice} → $${discountedPrice}`);
        console.log(`      Ends in ${daysLeft} days`);
    });
}

/**
 * Generate sample order history for testing
 * This creates orders with different dates for testing "days ago" feature
 */
async function generateOrderHistory() {
    console.log('\n📦 Generating order history...');

    // This would require user IDs and more complex logic
    // Implement if needed for testing order history features

    console.log('   ⚠️  Order history generation not implemented yet');
    console.log('   💡 Tip: Create orders manually or through the app for testing');
}

// Handle process termination
process.on('SIGINT', () => {
    console.log('\n\n⚠️  Process interrupted');
    mongoose.connection.close();
    process.exit(0);
});
