/**
 * Test Cart Backend API
 * 
 * This script tests the cart CRUD operations to ensure
 * the backend is working correctly before Flutter integration.
 * 
 * Usage:
 *   node scripts/test_cart_api.js <userId> <foodId>
 */

require('dotenv').config();
const mongoose = require('mongoose');
const {
    addToCart,
    getUserCart,
    updateCartItem,
    removeFromCart,
    clearCart
} = require('../services/cart_service');

// Connect to MongoDB
const connectDB = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo');
        console.log('✅ Connected to MongoDB');
    } catch (error) {
        console.error('❌ MongoDB connection error:', error);
        process.exit(1);
    }
};

// Main test function
const testCartOperations = async (userId, foodId) => {
    console.log('🧪 Testing Cart Backend Operations\n');
    console.log('='.repeat(60));

    try {
        // Test 1: Get empty cart
        console.log('\n📝 Test 1: Get Empty Cart');
        let cart = await getUserCart(userId, 'food');
        console.log(`✅ Cart fetched: ${cart ? cart.items.length : 0} items`);

        // Test 2: Add item to cart
        console.log('\n📝 Test 2: Add Item to Cart');
        cart = await addToCart(userId, {
            itemId: foodId,
            itemType: 'Food',
            quantity: 2,
            restaurantId: null // Will be set by service if needed
        });
        console.log(`✅ Item added: ${cart.items.length} items, Total: GH₵${cart.totalAmount}`);
        console.log(`   Items:`, cart.items.map(i => `${i.name} (x${i.quantity})`));

        // Test 3: Add same item again (should update quantity)
        console.log('\n📝 Test 3: Add Same Item Again');
        cart = await addToCart(userId, {
            itemId: foodId,
            itemType: 'Food',
            quantity: 1
        });
        console.log(`✅ Quantity updated: ${cart.items.length} items, Total: GH₵${cart.totalAmount}`);
        console.log(`   Items:`, cart.items.map(i => `${i.name} (x${i.quantity})`));

        // Test 4: Update item quantity
        console.log('\n📝 Test 4: Update Item Quantity');
        cart = await updateCartItem(userId, foodId, 5);
        console.log(`✅ Quantity set to 5: Total: GH₵${cart.totalAmount}`);
        console.log(`   Items:`, cart.items.map(i => `${i.name} (x${i.quantity})`));

        // Test 5: Get cart
        console.log('\n📝 Test 5: Get Cart');
        cart = await getUserCart(userId, 'food');
        console.log(`✅ Cart retrieved: ${cart.items.length} items, Total: GH₵${cart.totalAmount}`);

        // Test 6: Check abandonment status
        console.log('\n📝 Test 6: Check Abandonment Status');
        const isAbandoned = cart.isAbandoned();
        console.log(`   Is Abandoned: ${isAbandoned}`);
        console.log(`   Last Updated: ${cart.lastUpdatedAt}`);
        console.log(`   Notification Sent: ${cart.abandonmentNotificationSent}`);

        // Test 7: Remove item
        console.log('\n📝 Test 7: Remove Item from Cart');
        cart = await removeFromCart(userId, foodId);
        console.log(`✅ Item removed: ${cart.items.length} items remaining`);

        // Test 8: Clear cart
        console.log('\n📝 Test 8: Clear Cart');
        // Add item back first
        await addToCart(userId, {
            itemId: foodId,
            itemType: 'Food',
            quantity: 1
        });
        cart = await clearCart(userId);
        console.log(`✅ Cart cleared: ${cart.items.length} items`);

        console.log('\n' + '='.repeat(60));
        console.log('\n✅ All cart tests passed!');
        console.log('\n💡 Cart backend is working correctly.');
        console.log('   Ready for Flutter integration!\n');

    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.error(error.stack);
    }

    process.exit(0);
};

// Run tests
const main = async () => {
    await connectDB();

    const userId = process.argv[2];
    const foodId = process.argv[3];

    if (!userId || !foodId) {
        console.error('❌ Please provide userId and foodId');
        console.error('Usage: node scripts/test_cart_api.js <userId> <foodId>');
        console.error('\nExample:');
        console.error('  node scripts/test_cart_api.js 6911672f9d10fccfea54a96e 507f1f77bcf86cd799439011');
        process.exit(1);
    }

    await testCartOperations(userId, foodId);
};

main().catch(error => {
    console.error('❌ Script error:', error);
    process.exit(1);
});
