/**
 * Clear ALL orders and tracking data from the database
 * Then create fresh test orders
 * 
 * Usage: node scripts/clear_all_orders.js
 */

require('dotenv').config();
const mongoose = require('mongoose');

async function main() {
  console.log('\n🧹 CLEARING ALL ORDERS AND TRACKING DATA\n');
  console.log('=' .repeat(50));
  
  try {
    // Connect to MongoDB
    const uri = process.env.MONGODB_URI;
    console.log('🔌 Connecting to MongoDB...');
    await mongoose.connect(uri);
    console.log('✅ Connected\n');
    
    // Clear ALL orders
    const Order = require('../models/Order');
    const orderCount = await Order.countDocuments();
    console.log(`📦 Found ${orderCount} orders in database`);
    
    const orderResult = await Order.deleteMany({});
    console.log(`🗑️  Deleted ${orderResult.deletedCount} orders\n`);
    
    // Clear ALL tracking records
    const OrderTracking = require('../models/OrderTracking');
    const trackingCount = await OrderTracking.countDocuments();
    console.log(`📍 Found ${trackingCount} tracking records`);
    
    const trackingResult = await OrderTracking.deleteMany({});
    console.log(`🗑️  Deleted ${trackingResult.deletedCount} tracking records\n`);
    
    console.log('=' .repeat(50));
    console.log('✅ Database cleared!\n');
    
    // Now create fresh test orders
    console.log('📦 Creating 5 fresh test orders...\n');
    
    const User = require('../models/User');
    const Restaurant = require('../models/Restaurant');
    
    // Get customer and restaurant
    const customer = await User.findOne({ role: 'customer' });
    const restaurant = await Restaurant.findOne();
    
    if (!customer) {
      console.log('❌ No customer found in database');
      return;
    }
    if (!restaurant) {
      console.log('❌ No restaurant found in database');
      return;
    }
    
    console.log(`👤 Customer: ${customer.username || customer.email}`);
    console.log(`🍽️  Restaurant: ${restaurant.restaurantName}\n`);
    
    const addresses = [
      { street: '15 Independence Avenue', city: 'Accra', state: 'Greater Accra', latitude: 5.5560, longitude: -0.1969 },
      { street: '42 Oxford Street, Osu', city: 'Accra', state: 'Greater Accra', latitude: 5.5500, longitude: -0.1800 },
      { street: '8 Ring Road Central', city: 'Accra', state: 'Greater Accra', latitude: 5.5700, longitude: -0.2050 },
      { street: '25 Cantonments Road', city: 'Accra', state: 'Greater Accra', latitude: 5.5620, longitude: -0.1720 },
      { street: '10 Airport Residential', city: 'Accra', state: 'Greater Accra', latitude: 5.5900, longitude: -0.1650 },
    ];
    
    const statuses = ['confirmed', 'preparing', 'ready', 'confirmed', 'preparing'];
    
    for (let i = 0; i < 5; i++) {
      const order = await Order.create({
        orderType: 'food',
        customer: customer._id,
        restaurant: restaurant._id,
        rider: null,
        items: [
          { itemType: 'food', name: 'Jollof Rice with Chicken', quantity: 2, price: 35.00 },
          { itemType: 'food', name: 'Fried Plantains', quantity: 1, price: 8.00 },
        ],
        subtotal: 78.00,
        deliveryFee: 5.00,
        tax: 3.90,
        totalAmount: 86.90,
        deliveryAddress: addresses[i],
        paymentMethod: 'card',
        paymentStatus: 'paid',
        status: statuses[i],
        notes: `Test order ${i + 1} for rider app testing`,
      });
      
      console.log(`  ✅ Order #${order.orderNumber} - ${statuses[i]} - ${addresses[i].street}`);
    }
    
    console.log('\n✅ Created 5 fresh test orders!');
    console.log('\nYou can now:');
    console.log('  1. Rider App: Accept an order');
    console.log('  2. Customer App: Track the same order');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  } finally {
    await mongoose.connection.close();
    console.log('\n🔌 Disconnected from MongoDB\n');
  }
}

main();
