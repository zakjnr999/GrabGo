/**
 * Test Script: Create Test Orders for Rider App Testing
 * 
 * This script creates test orders with status 'confirmed', 'preparing', or 'ready'
 * that riders can see and accept.
 * 
 * Usage:
 *   node scripts/create_test_orders.js          - Create 5 test orders
 *   node scripts/create_test_orders.js create 3 - Create 3 test orders
 *   node scripts/create_test_orders.js list     - List available orders
 *   node scripts/create_test_orders.js clear    - Delete test orders
 *   node scripts/create_test_orders.js reset 5  - Clear and recreate 5 test orders
 * 
 * Environment:
 *   Set MONGODB_URI in your .env file or it will use localhost
 */

require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const Order = require('../models/Order');
const User = require('../models/User');
const Restaurant = require('../models/Restaurant');

// Test data for creating orders
const testOrderItems = [
  {
    itemType: 'food',
    name: 'Jollof Rice with Chicken',
    quantity: 2,
    price: 35.00,
    image: 'https://example.com/jollof.jpg'
  },
  {
    itemType: 'food',
    name: 'Fried Plantains',
    quantity: 1,
    price: 8.00,
    image: 'https://example.com/plantains.jpg'
  },
  {
    itemType: 'food',
    name: 'Fresh Orange Juice',
    quantity: 2,
    price: 12.00,
    image: 'https://example.com/juice.jpg'
  },
  {
    itemType: 'food',
    name: 'Banku with Tilapia',
    quantity: 1,
    price: 45.00,
    image: 'https://example.com/banku.jpg'
  },
  {
    itemType: 'food',
    name: 'Kelewele (Spicy Plantains)',
    quantity: 2,
    price: 15.00,
    image: 'https://example.com/kelewele.jpg'
  }
];

const testDeliveryAddresses = [
  {
    street: '15 Independence Avenue',
    city: 'Accra',
    state: 'Greater Accra',
    zipCode: 'GA-100',
    latitude: 5.5560,
    longitude: -0.1969
  },
  {
    street: '42 Oxford Street, Osu',
    city: 'Accra',
    state: 'Greater Accra',
    zipCode: 'GA-200',
    latitude: 5.5500,
    longitude: -0.1800
  },
  {
    street: '8 Ring Road Central',
    city: 'Accra',
    state: 'Greater Accra',
    zipCode: 'GA-150',
    latitude: 5.5700,
    longitude: -0.2050
  },
  {
    street: '25 Cantonments Road',
    city: 'Accra',
    state: 'Greater Accra',
    zipCode: 'GA-300',
    latitude: 5.5620,
    longitude: -0.1720
  },
  {
    street: '10 Airport Residential Area',
    city: 'Accra',
    state: 'Greater Accra',
    zipCode: 'GA-400',
    latitude: 5.5900,
    longitude: -0.1650
  }
];

async function connectDB() {
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo';
  console.log('🔌 Connecting to MongoDB...');
  console.log(`   URI: ${uri.replace(/\/\/[^:]+:[^@]+@/, '//***:***@')}`); // Hide credentials
  
  try {
    await mongoose.connect(uri);
    console.log('✅ Connected to MongoDB');
    return true;
  } catch (error) {
    console.error('❌ MongoDB connection error:', error.message);
    return false;
  }
}

async function getOrCreateTestCustomer() {
  // Try to find an existing customer
  let customer = await User.findOne({ role: 'customer' });
  
  if (customer) {
    console.log(`📱 Using existing customer: ${customer.username || customer.email}`);
    return customer;
  }
  
  // Create a test customer if none exists
  console.log('👤 Creating test customer...');
  const hashedPassword = await bcrypt.hash('testpassword123', 10);
  
  customer = await User.create({
    username: 'testcustomer',
    email: 'testcustomer@grabgo.test',
    password: hashedPassword,
    phone: 233501234567,
    role: 'customer',
    isEmailVerified: true
  });
  
  console.log(`✅ Created test customer: ${customer.email}`);
  return customer;
}

async function getOrCreateTestRestaurant() {
  // Try to find an existing active restaurant
  let restaurant = await Restaurant.findOne({ isActive: true });
  
  if (restaurant) {
    console.log(`🍽️  Using existing restaurant: ${restaurant.restaurantName}`);
    return restaurant;
  }
  
  // Try to find any restaurant
  restaurant = await Restaurant.findOne();
  
  if (restaurant) {
    console.log(`🍽️  Using existing restaurant: ${restaurant.restaurantName}`);
    return restaurant;
  }
  
  // Create a test restaurant
  console.log('🏪 Creating test restaurant...');
  const hashedPassword = await bcrypt.hash('testpassword123', 10);
  
  restaurant = await Restaurant.create({
    restaurantName: 'Accra Kitchen Test',
    email: 'accrakitchen@grabgo.test',
    phone: '+233502223333',
    location: {
      type: 'Point',
      coordinates: [-0.2100, 5.5800], // [longitude, latitude]
      address: '100 Liberation Road',
      city: 'Accra',
      area: 'East Legon'
    },
    ownerFullName: 'Test Restaurant Owner',
    ownerContactNumber: '+233509876543',
    businessIdNumber: 'TEST-BIZ-001',
    password: hashedPassword,
    isActive: true,
    isApproved: true,
    openingHours: {
      monday: { open: '08:00', close: '22:00' },
      tuesday: { open: '08:00', close: '22:00' },
      wednesday: { open: '08:00', close: '22:00' },
      thursday: { open: '08:00', close: '22:00' },
      friday: { open: '08:00', close: '22:00' },
      saturday: { open: '10:00', close: '23:00' },
      sunday: { open: '10:00', close: '21:00' }
    },
    minimumOrder: 20,
    deliveryFee: 5,
    averageDeliveryTime: 30
  });
  
  console.log(`✅ Created test restaurant: ${restaurant.restaurantName}`);
  return restaurant;
}

async function createTestOrders(count = 5) {
  console.log(`\n📦 Creating ${count} test orders...\n`);
  
  const customer = await getOrCreateTestCustomer();
  const restaurant = await getOrCreateTestRestaurant();
  
  const statuses = ['confirmed', 'preparing', 'ready'];
  const paymentMethods = ['cash', 'card', 'card'];
  const createdOrders = [];
  
  for (let i = 0; i < count; i++) {
    const status = statuses[i % statuses.length];
    const address = testDeliveryAddresses[i % testDeliveryAddresses.length];
    const paymentMethod = paymentMethods[i % paymentMethods.length];
    
    // Randomize items
    const numItems = Math.floor(Math.random() * 3) + 1;
    const items = testOrderItems.slice(0, numItems).map(item => ({
      ...item,
      quantity: Math.floor(Math.random() * 3) + 1
    }));
    
    // Calculate totals
    const subtotal = items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    const deliveryFee = 5 + Math.random() * 10;
    const tax = subtotal * 0.05; // 5% tax
    const totalAmount = subtotal + deliveryFee + tax;
    
    try {
      const order = await Order.create({
        orderType: 'food',
        customer: customer._id,
        restaurant: restaurant._id,
        rider: null, // Important: rider must be null for available orders
        items: items,
        subtotal: parseFloat(subtotal.toFixed(2)),
        deliveryFee: parseFloat(deliveryFee.toFixed(2)),
        tax: parseFloat(tax.toFixed(2)),
        totalAmount: parseFloat(totalAmount.toFixed(2)),
        deliveryAddress: address,
        paymentMethod: paymentMethod,
        paymentStatus: 'paid', // Assume payment is done
        status: status, // Must be confirmed, preparing, or ready
        notes: `Test order ${i + 1} for rider app testing`,
        expectedDelivery: new Date(Date.now() + (30 + i * 10) * 60000) // 30-70 mins from now
      });
      
      createdOrders.push(order);
      console.log(`  ✅ Order #${order.orderNumber}`);
      console.log(`     Status: ${status}`);
      console.log(`     Total: GH₵${totalAmount.toFixed(2)}`);
      console.log(`     Delivery to: ${address.street}, ${address.city}`);
      console.log('');
    } catch (error) {
      console.error(`  ❌ Failed to create order ${i + 1}:`, error.message);
    }
  }
  
  return createdOrders;
}

async function listAvailableOrders() {
  console.log('\n📋 Current Available Orders (rider: null, status: confirmed/preparing/ready):\n');
  
  const orders = await Order.find({
    rider: null,
    status: { $in: ['confirmed', 'preparing', 'ready'] }
  })
  .populate('customer', 'name email phone')
  .populate('restaurant', 'restaurantName address')
  .sort({ createdAt: -1 });
  
  if (orders.length === 0) {
    console.log('  No available orders found.\n');
    return;
  }
  
  orders.forEach((order, index) => {
    console.log(`  ${index + 1}. Order #${order.orderNumber}`);
    console.log(`     ID: ${order._id}`);
    console.log(`     Status: ${order.status}`);
    console.log(`     Restaurant: ${order.restaurant?.restaurantName || 'Unknown'}`);
    console.log(`     Customer: ${order.customer?.name || 'Unknown'}`);
    console.log(`     Total: GH₵${order.totalAmount?.toFixed(2)}`);
    console.log(`     Delivery: ${order.deliveryAddress?.street}, ${order.deliveryAddress?.city}`);
    console.log(`     Created: ${order.createdAt?.toLocaleString()}`);
    console.log('');
  });
  
  console.log(`  Total: ${orders.length} available orders\n`);
}

async function clearTestOrders() {
  console.log('\n🧹 Clearing test/available orders and tracking data...');
  
  // Clear test orders (orders with rider app testing notes)
  const testResult = await Order.deleteMany({
    notes: { $regex: /^Test order .* for rider app testing$/ }
  });
  console.log(`  Deleted ${testResult.deletedCount} test orders`);
  
  // Clear all available orders (no rider assigned, not delivered/cancelled)
  const availableResult = await Order.deleteMany({
    rider: null,
    status: { $in: ['pending', 'confirmed', 'preparing', 'ready'] }
  });
  console.log(`  Deleted ${availableResult.deletedCount} available orders`);
  
  // Clear tracking data for deleted orders
  try {
    const OrderTracking = require('../models/OrderTracking');
    const trackingResult = await OrderTracking.deleteMany({});
    console.log(`  Deleted ${trackingResult.deletedCount} tracking records`);
  } catch (error) {
    console.log(`  ⚠️ Could not clear tracking data: ${error.message}`);
  }
  
  console.log('');
}

async function main() {
  const args = process.argv.slice(2);
  const command = args[0] || 'create';
  const count = parseInt(args[1]) || 5;
  
  console.log('\n🚀 GrabGo Test Order Generator\n');
  console.log('=' .repeat(50));
  
  const connected = await connectDB();
  if (!connected) {
    process.exit(1);
  }
  
  try {
    switch (command) {
      case 'create':
        await createTestOrders(count);
        await listAvailableOrders();
        break;
        
      case 'list':
        await listAvailableOrders();
        break;
        
      case 'clear':
        await clearTestOrders();
        await listAvailableOrders();
        break;
        
      case 'reset':
        await clearTestOrders();
        await createTestOrders(count);
        await listAvailableOrders();
        break;
        
      default:
        console.log('Usage:');
        console.log('  node scripts/create_test_orders.js create [count]  - Create test orders (default: 5)');
        console.log('  node scripts/create_test_orders.js list            - List available orders');
        console.log('  node scripts/create_test_orders.js clear           - Delete test orders');
        console.log('  node scripts/create_test_orders.js reset [count]   - Clear and recreate test orders');
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
  } finally {
    await mongoose.connection.close();
    console.log('🔌 Disconnected from MongoDB');
  }
}

main();
