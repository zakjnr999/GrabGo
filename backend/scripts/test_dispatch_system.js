/**
 * Test script for Order Reservation/Dispatch System
 * 
 * Usage: 
 *   node scripts/test_dispatch_system.js
 * 
 * This script will:
 * 1. Set a rider as "online" with location
 * 2. Create a test order (or use existing)
 * 3. Trigger the dispatch system
 * 4. Show the reservation that was created
 */

require('dotenv').config();
const mongoose = require('mongoose');
const connectMongoDB = require('../config/mongodb');
const prisma = require('../config/prisma');

// Import after dotenv is configured
let dispatchService;
let OrderReservation;

async function main() {
  console.log('🚀 Testing Order Dispatch System\n');
  console.log('='.repeat(50));

  // Connect to MongoDB
  await connectMongoDB();
  console.log('✅ MongoDB connected');
  
  // Prisma is already connected via the config import
  console.log('✅ PostgreSQL connected\n');

  // Now require the services (after DB connection)
  dispatchService = require('../services/dispatch_service');
  OrderReservation = require('../models/OrderReservation');

  // Step 1: Find or create a test rider
  console.log('📍 Step 1: Setting up a test rider...');
  
  let rider = await prisma.user.findFirst({
    where: { 
      role: 'rider',
      isApproved: true 
    }
  });

  if (!rider) {
    // Find any rider
    rider = await prisma.user.findFirst({
      where: { role: 'rider' }
    });
  }

  if (!rider) {
    console.log('❌ No rider found in database. Please create a rider account first.');
    return;
  }

  console.log(`   Found rider: ${rider.name} (ID: ${rider.id})`);

  // Set rider as online with test location (Accra, Ghana as example)
  await prisma.user.update({
    where: { id: rider.id },
    data: {
      riderIsOnline: true,
      riderLatitude: 5.6037,  // Accra coordinates
      riderLongitude: -0.1870,
      riderLastActiveAt: new Date(),
      isApproved: true,
      riderAcceptanceRate: 85,
      riderRating: 4.5,
      riderTotalDeliveries: 50
    }
  });
  console.log('   ✅ Rider set to ONLINE with location (5.6037, -0.1870)\n');

  // Step 2: Find or create a test order
  console.log('📦 Step 2: Finding a test order...');
  
  let order = await prisma.order.findFirst({
    where: {
      riderId: null, // Not assigned to a rider yet
      status: { in: ['pending', 'confirmed', 'preparing'] }
    },
    include: {
      restaurant: true,
      user: true
    }
  });

  if (!order) {
    // Find any order without a rider
    order = await prisma.order.findFirst({
      where: { riderId: null },
      include: {
        restaurant: true,
        user: true
      }
    });
  }

  if (!order) {
    console.log('❌ No unassigned orders found. Creating a test order...');
    
    // Find a customer and restaurant
    const customer = await prisma.user.findFirst({ where: { role: 'customer' } });
    const restaurant = await prisma.restaurant.findFirst();
    
    if (!customer || !restaurant) {
      console.log('❌ Need at least one customer and one restaurant in database');
      return;
    }

    order = await prisma.order.create({
      data: {
        userId: customer.id,
        restaurantId: restaurant.id,
        status: 'confirmed',
        totalPrice: 25.00,
        deliveryFee: 5.00,
        deliveryAddress: '123 Test Street, Accra',
        deliveryLatitude: 5.6100,
        deliveryLongitude: -0.1900,
        paymentMethod: 'cash',
        paymentStatus: 'pending'
      },
      include: {
        restaurant: true,
        user: true
      }
    });
    console.log(`   ✅ Created test order #${order.id}`);
  } else {
    console.log(`   Found existing order #${order.id} (${order.status})`);
  }

  // Make sure restaurant has coordinates
  if (order.restaurant && (!order.restaurant.latitude || !order.restaurant.longitude)) {
    await prisma.restaurant.update({
      where: { id: order.restaurant.id },
      data: {
        latitude: 5.6050,
        longitude: -0.1880
      }
    });
    console.log('   ✅ Set restaurant coordinates');
  }

  console.log(`   Order details:`);
  console.log(`   - Restaurant: ${order.restaurant?.name || 'N/A'}`);
  console.log(`   - Customer: ${order.user?.name || 'N/A'}`);
  console.log(`   - Total: $${order.totalPrice}\n`);

  // Step 3: Clear any existing reservations for this order
  console.log('🧹 Step 3: Clearing old reservations...');
  await OrderReservation.deleteMany({ orderId: order.id });
  console.log('   ✅ Old reservations cleared\n');

  // Step 4: Trigger the dispatch
  console.log('🎯 Step 4: Triggering dispatch system...');
  console.log('   This will:');
  console.log('   - Find eligible riders');
  console.log('   - Score and rank them');
  console.log('   - Create exclusive reservation for top rider');
  console.log('');

  try {
    const result = await dispatchService.dispatchOrder(order.id);
    
    console.log('\n📊 Dispatch Result:');
    console.log('   ' + JSON.stringify(result, null, 2).replace(/\n/g, '\n   '));
    
    if (result.success) {
      console.log('\n✅ SUCCESS! Reservation created.');
      
      // Fetch the reservation details
      const reservation = await OrderReservation.findOne({ orderId: order.id, status: 'pending' });
      
      if (reservation) {
        console.log('\n📋 Reservation Details:');
        console.log(`   - Reservation ID: ${reservation._id}`);
        console.log(`   - Rider ID: ${reservation.riderId}`);
        console.log(`   - Timeout: ${reservation.timeoutMs / 1000} seconds`);
        console.log(`   - Expires at: ${reservation.expiresAt}`);
        console.log(`   - Status: ${reservation.status}`);
        
        console.log('\n🔔 What happens now:');
        console.log('   1. If rider app is connected via Socket.IO, they see a popup');
        console.log('   2. They have 8 seconds to Accept or Decline');
        console.log('   3. If they don\'t respond, it auto-moves to next rider');
        
        console.log('\n📱 To test in the rider app:');
        console.log(`   - Login as rider: ${rider.email || rider.phone}`);
        console.log('   - Make sure you\'re "Online" in the app');
        console.log('   - You should see the order popup with countdown');
      }
    } else {
      console.log('\n⚠️ Dispatch did not succeed:', result.message || result.reason);
    }
    
  } catch (error) {
    console.error('\n❌ Dispatch Error:', error.message);
    console.error(error.stack);
  }

  // Step 5: Show how to manually test accept/decline
  console.log('\n' + '='.repeat(50));
  console.log('🧪 MANUAL TESTING OPTIONS:\n');
  
  const reservation = await OrderReservation.findOne({ orderId: order.id, status: 'pending' });
  
  if (reservation) {
    console.log('Option 1: Accept the reservation via API');
    console.log(`   curl -X POST http://localhost:3000/api/riders/reservation/${reservation._id}/accept \\`);
    console.log(`        -H "Authorization: Bearer <rider_token>"`);
    
    console.log('\nOption 2: Decline the reservation via API');
    console.log(`   curl -X POST http://localhost:3000/api/riders/reservation/${reservation._id}/decline \\`);
    console.log(`        -H "Authorization: Bearer <rider_token>"`);
    
    console.log('\nOption 3: Wait for timeout (8 seconds)');
    console.log('   The reservation_expiry job will auto-expire and try next rider');
    
    console.log('\nOption 4: Simulate via Node REPL');
    console.log(`   const ds = require('./services/dispatch_service');`);
    console.log(`   await ds.acceptReservation('${reservation._id}', '${rider.id}');`);
  }

  console.log('\n' + '='.repeat(50));
  console.log('✨ Test complete!\n');
}

main()
  .catch(console.error)
  .finally(async () => {
    await prisma.$disconnect();
    await mongoose.disconnect();
    process.exit(0);
  });
