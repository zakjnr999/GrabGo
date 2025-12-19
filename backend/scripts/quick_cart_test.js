/**
 * Quick Cart Backend Test
 * 
 * Tests cart API using your credentials
 * 
 * Usage:
 *   node scripts/quick_cart_test.js
 */

require('dotenv').config();
const axios = require('axios');

const BASE_URL = 'http://localhost:5000/api';

// Your credentials
const EMAIL = 'zakjnr5@gmail.com';
const PASSWORD = 'Daddy@20033'; // Update this

const testCart = async () => {
    console.log('🧪 Quick Cart Backend Test\n');
    console.log('='.repeat(60));

    try {
        // Step 1: Login to get token
        console.log('\n🔐 Step 1: Logging in...');
        let response = await axios.post(`${BASE_URL}/users/login`, {
            email: EMAIL,
            password: PASSWORD
        });

        const token = response.data.token;
        const headers = {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        };
        console.log('✅ Logged in successfully');

        // Step 2: Get a food item
        console.log('\n🍔 Step 2: Getting a food item...');
        response = await axios.get(`${BASE_URL}/foods`);
        const food = response.data.foods[0];
        console.log(`✅ Found: ${food.name} (GH₵${food.price})`);

        // Step 3: Get current cart
        console.log('\n📦 Step 3: Getting current cart...');
        response = await axios.get(`${BASE_URL}/cart`, { headers });
        console.log(`✅ Current cart: ${response.data.cart.items?.length || 0} items`);

        // Step 4: Add item to cart
        console.log('\n➕ Step 4: Adding item to cart...');
        response = await axios.post(`${BASE_URL}/cart/add`, {
            itemId: food._id,
            itemType: 'Food',
            quantity: 2,
            restaurantId: food.restaurant
        }, { headers });
        console.log(`✅ Added: ${response.data.cart.items[0].name} x${response.data.cart.items[0].quantity}`);
        console.log(`   Total: GH₵${response.data.cart.totalAmount}`);

        // Step 5: Update quantity
        console.log('\n📝 Step 5: Updating quantity to 5...');
        response = await axios.patch(`${BASE_URL}/cart/update/${food._id}`, {
            quantity: 5
        }, { headers });
        console.log(`✅ Updated: ${response.data.cart.items[0].name} x${response.data.cart.items[0].quantity}`);
        console.log(`   Total: GH₵${response.data.cart.totalAmount}`);

        // Step 6: Get cart again
        console.log('\n📦 Step 6: Getting updated cart...');
        response = await axios.get(`${BASE_URL}/cart`, { headers });
        console.log(`✅ Cart has ${response.data.cart.items.length} item(s)`);
        console.log(`   Total: GH₵${response.data.cart.totalAmount}`);

        // Step 7: Clear cart
        console.log('\n🗑️  Step 7: Clearing cart...');
        response = await axios.delete(`${BASE_URL}/cart/clear`, { headers });
        console.log(`✅ Cart cleared: ${response.data.cart.items.length} items`);

        console.log('\n' + '='.repeat(60));
        console.log('\n🎉 SUCCESS! All cart operations working perfectly!\n');

    } catch (error) {
        console.error('\n❌ Test failed!');
        if (error.response) {
            console.error(`   Status: ${error.response.status}`);
            console.error(`   Message: ${error.response.data.message || error.response.data}`);
            console.error(`   Full error:`, error.response.data);
        } else if (error.request) {
            console.error(`   No response received from server`);
            console.error(`   Request:`, error.request);
        } else {
            console.error(`   Error: ${error.message}`);
            console.error(`   Stack:`, error.stack);
        }
        console.log('\n💡 Troubleshooting:');
        console.log('   1. Update PASSWORD in the script');
        console.log('   2. Make sure server is running on port 5000');
        console.log('   3. Check if there are food items in database');
    }
};

testCart();
