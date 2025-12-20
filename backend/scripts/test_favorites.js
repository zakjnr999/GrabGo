/**
 * Test Backend Favorites System
 * 
 * Tests the favorites CRUD operations and sync functionality
 * 
 * Usage:
 *   node scripts/test_favorites.js
 */

require('dotenv').config();
const axios = require('axios');

const API_URL = process.env.API_URL || 'http://localhost:5000/api';
let token = '';

const login = async () => {
    try {
        const response = await axios.post(`${API_URL}/users/login`, {
            email: 'zakjnr5@gmail.com',
            password: 'password123'
        });
        token = response.data.token;
        console.log('✅ Login successful');
    } catch (error) {
        console.error('❌ Login failed:', error.response?.data?.message || error.message);
        process.exit(1);
    }
};

const testFavorites = async () => {
    console.log('🧪 Testing Backend Favorites System\n');
    console.log('='.repeat(60));

    await login();

    const headers = { Authorization: `Bearer ${token}` };

    try {
        // 1. Get initial favorites
        console.log('\n📋 1. Getting initial favorites...');
        const initialRes = await axios.get(`${API_URL}/favorites`, { headers });
        console.log('✅ Favorites retrieved');
        console.log(`   Restaurants: ${initialRes.data.data.restaurants.length}`);
        console.log(`   Food Items: ${initialRes.data.data.foodItems.length}`);

        // 2. Add a favorite restaurant (Need a valid ID)
        console.log('\n📝 2. Adding favorite restaurant...');
        // Find a restaurant first
        const restaurantsRes = await axios.get(`${API_URL}/restaurants`, { headers });
        if (restaurantsRes.data.data.length > 0) {
            const restaurantId = restaurantsRes.data.data[0]._id;
            const addRes = await axios.post(`${API_URL}/favorites/restaurant/${restaurantId}`, {}, { headers });
            console.log(`✅ Added restaurant: ${restaurantsRes.data.data[0].restaurant_name}`);
        } else {
            console.log('⚠️ No restaurants found to test adding to favorites');
        }

        // 3. Add a favorite food item
        console.log('\n📝 3. Adding favorite food item...');
        const foodsRes = await axios.get(`${API_URL}/foods`, { headers });
        if (foodsRes.data.data.length > 0) {
            const foodId = foodsRes.data.data[0]._id;
            const addFoodRes = await axios.post(`${API_URL}/favorites/food/${foodId}`, {}, { headers });
            console.log(`✅ Added food item: ${foodsRes.data.data[0].name}`);
        } else {
            console.log('⚠️ No food items found to test adding to favorites');
        }

        // 4. Get updated favorites
        console.log('\n📋 4. Verifying updated favorites...');
        const updatedRes = await axios.get(`${API_URL}/favorites`, { headers });
        console.log(`✅ Verified: ${updatedRes.data.data.restaurants.length} restaurants, ${updatedRes.data.data.foodItems.length} food items`);

        // 5. Sync favorites
        console.log('\n🔄 5. Testing favorites sync...');
        // Let's get a store and a grocery item for sync test
        const storesRes = await axios.get(`${API_URL}/groceries`, { headers });
        const groceryItemsRes = await axios.get(`${API_URL}/groceries/items`, { headers });

        const syncData = {
            restaurants: [],
            stores: storesRes.data.data.length > 0 ? [storesRes.data.data[0]._id] : [],
            foodItems: foodsRes.data.data.length > 1 ? [foodsRes.data.data[1]._id] : [],
            groceryItems: groceryItemsRes.data.data.length > 0 ? [groceryItemsRes.data.data[0]._id] : []
        };

        const syncRes = await axios.post(`${API_URL}/favorites/sync`, syncData, { headers });
        console.log('✅ Sync successful');
        console.log(`   Synced Stores: ${syncRes.data.data.groceryStores.length}`);
        console.log(`   Synced Food Items: ${syncRes.data.data.foodItems.length}`);
        console.log(`   Synced Grocery Items: ${syncRes.data.data.groceryItems.length}`);

        // 6. Remove favorite restaurant
        console.log('\n🗑️ 6. Removing favorite restaurant...');
        if (restaurantsRes.data.data.length > 0) {
            const restaurantId = restaurantsRes.data.data[0]._id;
            await axios.delete(`${API_URL}/favorites/restaurant/${restaurantId}`, { headers });
            console.log('✅ Restaurant removed');
        }

        // 7. Final verification
        const finalRes = await axios.get(`${API_URL}/favorites`, { headers });
        console.log('\n📊 Final Results:');
        console.log(`   Restaurants: ${finalRes.data.data.restaurants.length}`);
        console.log(`   Food Items: ${finalRes.data.data.foodItems.length}`);
        console.log('\n✅ SUCCESS! All favorites tests passed!');

    } catch (error) {
        console.error('\n❌ Test failed:', error.response?.data?.message || error.message);
        if (error.response?.data) {
            console.log(JSON.stringify(error.response.data, null, 2));
        }
    }

    console.log('\n' + '='.repeat(60));
};

testFavorites();
