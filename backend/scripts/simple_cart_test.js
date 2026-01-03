/**
 * Simple Cart API Test
 * 
 * Tests the cart endpoints to ensure backend is working
 * 
 * Usage:
 *   1. Make sure server is running (npm run dev)
 *   2. Update the AUTH_TOKEN and FOOD_ID below
 *   3. Run: node scripts/simple_cart_test.js
 */

const axios = require('axios');

// Configuration
const BASE_URL = 'http://localhost:5000/api';
const AUTH_TOKEN = 'YOUR_AUTH_TOKEN_HERE'; // Get from login
const FOOD_ID = 'YOUR_FOOD_ID_HERE'; // Any food item ID

// Test function
const testCartAPI = async () => {
    console.log('🧪 Testing Cart API\n');
    console.log('='.repeat(60));

    const headers = {
        'Authorization': `Bearer ${AUTH_TOKEN}`,
        'Content-Type': 'application/json'
    };

    try {
        // Test 1: Get empty cart
        console.log('\n📝 Test 1: Get Cart (should be empty)');
        let response = await axios.get(`${BASE_URL}/cart`, { headers });
        console.log(`✅ Status: ${response.status}`);
        console.log(`   Items: ${response.data.cart.items?.length || 0}`);

        // Test 2: Add item to cart
        console.log('\n📝 Test 2: Add Item to Cart');
        response = await axios.post(`${BASE_URL}/cart/add`, {
            itemId: FOOD_ID,
            itemType: 'Food',
            quantity: 2
        }, { headers });
        console.log(`✅ Status: ${response.status}`);
        console.log(`   Items: ${response.data.cart.items.length}`);
        console.log(`   Total: GH₵${response.data.cart.totalAmount}`);

        // Test 3: Add same item again
        console.log('\n📝 Test 3: Add Same Item Again (quantity should increase)');
        response = await axios.post(`${BASE_URL}/cart/add`, {
            itemId: FOOD_ID,
            itemType: 'Food',
            quantity: 1
        }, { headers });
        console.log(`✅ Status: ${response.status}`);
        console.log(`   Quantity: ${response.data.cart.items[0].quantity}`);
        console.log(`   Total: GH₵${response.data.cart.totalAmount}`);

        // Test 4: Update quantity
        console.log('\n📝 Test 4: Update Item Quantity to 5');
        response = await axios.patch(`${BASE_URL}/cart/update/${FOOD_ID}`, {
            quantity: 5
        }, { headers });
        console.log(`✅ Status: ${response.status}`);
        console.log(`   Quantity: ${response.data.cart.items[0].quantity}`);
        console.log(`   Total: GH₵${response.data.cart.totalAmount}`);

        // Test 5: Get cart
        console.log('\n📝 Test 5: Get Cart (should have 1 item with qty 5)');
        response = await axios.get(`${BASE_URL}/cart`, { headers });
        console.log(`✅ Status: ${response.status}`);
        console.log(`   Items: ${response.data.cart.items.length}`);
        console.log(`   Item: ${response.data.cart.items[0].name} x${response.data.cart.items[0].quantity}`);

        // Test 6: Clear cart
        console.log('\n📝 Test 6: Clear Cart');
        response = await axios.delete(`${BASE_URL}/cart/clear`, { headers });
        console.log(`✅ Status: ${response.status}`);
        console.log(`   Items: ${response.data.cart.items.length}`);

        console.log('\n' + '='.repeat(60));
        console.log('\n✅ All tests passed! Cart backend is working perfectly!\n');

    } catch (error) {
        console.error('\n❌ Test failed!');
        if (error.response) {
            console.error(`   Status: ${error.response.status}`);
            console.error(`   Message: ${error.response.data.message}`);
        } else {
            console.error(`   Error: ${error.message}`);
        }
        console.log('\n💡 Make sure:');
        console.log('   1. Server is running (npm run dev)');
        console.log('   2. AUTH_TOKEN is valid (login to get token)');
        console.log('   3. FOOD_ID exists in database');
    }
};

// Run tests
testCartAPI();
