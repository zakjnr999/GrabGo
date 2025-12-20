/**
 * Test Backend Favorites System (Direct Service Test)
 * 
 * This script tests the favorites CRUD operations and sync functionality
 * by calling the service functions directly, avoiding HTTP/network issues.
 * 
 * Usage:
 *   node scripts/test_favorites.js
 */

require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../models/User');
const Restaurant = require('../models/Restaurant');
const GroceryStore = require('../models/GroceryStore');
const Food = require('../models/Food');
const GroceryItem = require('../models/GroceryItem');
const {
    getUserFavorites,
    addFavoriteRestaurant,
    removeFavoriteRestaurant,
    addFavoriteStore,
    removeFavoriteStore,
    addFavoriteFoodItem,
    removeFavoriteFoodItem,
    addFavoriteGroceryItem,
    removeFavoriteGroceryItem,
    syncFavorites
} = require('../services/favorites_service');

const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

const testFavorites = async () => {
    console.log('🧪 Testing Backend Favorites System (Direct)\n');
    console.log('='.repeat(60));

    await connectDB();

    try {
        // Find test user
        const user = await User.findOne({ email: 'zakjnr5@gmail.com' });
        if (!user) {
            console.log('❌ Test user zakjnr5@gmail.com not found');
            process.exit(1);
        }
        const userId = user._id;
        console.log(`👤 Testing for user: ${user.email} (${userId})`);

        // 1. Get initial favorites
        console.log('\n📋 1. Getting initial favorites...');
        const initialFavs = await getUserFavorites(userId);
        console.log('✅ Favorites retrieved');
        console.log(`   Restaurants: ${initialFavs.restaurants.length}`);
        console.log(`   Grocery Stores: ${initialFavs.groceryStores.length}`);
        console.log(`   Food Items: ${initialFavs.foodItems.length}`);
        console.log(`   Grocery Items: ${initialFavs.groceryItems.length}`);

        // 2. Add a favorite restaurant
        console.log('\n📝 2. Adding favorite restaurant...');
        const restaurant = await Restaurant.findOne();
        if (restaurant) {
            await addFavoriteRestaurant(userId, restaurant._id.toString());
            console.log(`✅ Added restaurant: ${restaurant.restaurant_name}`);
        } else {
            console.log('⚠️ No restaurants found in DB');
        }

        // 3. Add a favorite food item
        console.log('\n📝 3. Adding favorite food item...');
        const food = await Food.findOne();
        if (food) {
            await addFavoriteFoodItem(userId, food._id.toString());
            console.log(`✅ Added food item: ${food.name}`);
        } else {
            console.log('⚠️ No food items found in DB');
        }

        // 4. Verify updated favorites
        console.log('\n📋 4. Verifying updated favorites...');
        const updatedFavs = await getUserFavorites(userId);
        console.log(`✅ Verified: ${updatedFavs.restaurants.length} restaurants, ${updatedFavs.foodItems.length} food items`);

        // 5. Sync favorites (Testing deduplication and cross-category sync)
        console.log('\n🔄 5. Testing favorites sync...');
        const otherFood = await Food.findOne({ _id: { $ne: food?._id } });
        const store = await GroceryStore.findOne();
        const groceryItem = await GroceryItem.findOne();

        const localFavs = {
            restaurants: restaurant ? [restaurant._id.toString()] : [], // Existing
            stores: store ? [store._id.toString()] : [], // New
            foodItems: otherFood ? [otherFood._id.toString(), otherFood._id.toString()] : [], // New + Duplicate
            groceryItems: groceryItem ? [groceryItem._id.toString()] : [] // New
        };

        const syncedFavs = await syncFavorites(userId, localFavs);
        console.log('✅ Sync successful');
        console.log(`   Total Restaurants: ${syncedFavs.restaurants.length}`);
        console.log(`   Total Stores: ${syncedFavs.groceryStores.length}`);
        console.log(`   Total Food Items: ${syncedFavs.foodItems.length} (deduplicated)`);
        console.log(`   Total Grocery Items: ${syncedFavs.groceryItems.length}`);

        // 6. Remove favorite restaurant
        console.log('\n🗑️ 6. Removing favorite restaurant...');
        if (restaurant) {
            const finalFavs = await removeFavoriteRestaurant(userId, restaurant._id.toString());
            console.log(`✅ Restaurant removed. Remaining restaurants: ${finalFavs.restaurants.length}`);
        }

        console.log('\n📊 Final Test Completed');
        console.log('✅ SUCCESS! Favorites service verified.');

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error.stack);
    } finally {
        await mongoose.connection.close();
        process.exit(0);
    }
};

testFavorites();
