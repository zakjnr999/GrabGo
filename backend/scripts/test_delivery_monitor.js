/**
 * Test Script for Delivery Monitor Feature
 * 
 * This script tests:
 * 1. Soft warning to rider (5 mins before window expires)
 * 2. Customer late notification (when past window)
 * 3. Analytics tracking
 * 
 * Usage: node scripts/test_delivery_monitor.js
 */

require('dotenv').config();
const prisma = require('../config/prisma');
const mongoose = require('mongoose');
const { manualCheck, clearOrderTracking } = require('../jobs/delivery_monitor');
const socketService = require('../services/socket_service');

// Connect to MongoDB
const connectMongo = async () => {
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/grabgo';
    await mongoose.connect(mongoUri);
    console.log('✅ Connected to MongoDB');
};

/**
 * Test 1: Simulate rider warning (5 mins before deadline)
 */
async function testRiderWarning() {
    console.log('\n' + '='.repeat(60));
    console.log('TEST 1: Rider Warning (5 mins before deadline)');
    console.log('='.repeat(60));

    // Find an active order with a rider
    const order = await prisma.order.findFirst({
        where: {
            riderId: { not: null },
            status: { in: ['confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way'] }
        },
        include: {
            rider: { select: { id: true, username: true } },
            customer: { select: { id: true, username: true } }
        }
    });

    if (!order) {
        console.log('❌ No active order with rider found. Creating test scenario...');
        return await createTestOrder('warning');
    }

    console.log(`📦 Found order: #${order.orderNumber}`);
    console.log(`   Rider: ${order.rider?.username} (${order.riderId})`);
    console.log(`   Customer: ${order.customer?.username} (${order.customerId})`);
    console.log(`   Status: ${order.status}`);

    // Set delivery window to expire in 4 minutes (triggers 5-min warning)
    const now = new Date();
    const riderAssignedAt = new Date(now.getTime() - 20 * 60 * 1000); // 20 mins ago
    const deliveryWindowMax = 24; // 24 mins total, so 4 mins remaining

    await prisma.order.update({
        where: { id: order.id },
        data: {
            riderAssignedAt,
            deliveryWindowMin: 20,
            deliveryWindowMax,
            expectedDelivery: new Date(riderAssignedAt.getTime() + 22 * 60 * 1000)
        }
    });

    console.log(`\n⏰ Set delivery window: ${deliveryWindowMax} mins from assignment`);
    console.log(`   Rider assigned: ${riderAssignedAt.toISOString()}`);
    console.log(`   Window expires in: ~4 minutes (should trigger warning)`);

    // Clear any previous tracking for this order
    clearOrderTracking(order.id);

    // Run the monitor
    console.log('\n🔄 Running delivery monitor check...');
    await manualCheck();

    console.log('\n✅ Check complete! Rider should receive warning notification.');
    return order;
}

/**
 * Test 2: Simulate customer late notification (past deadline)
 */
async function testCustomerLateNotification() {
    console.log('\n' + '='.repeat(60));
    console.log('TEST 2: Customer Late Notification (past deadline)');
    console.log('='.repeat(60));

    // Find an active order with a rider
    const order = await prisma.order.findFirst({
        where: {
            riderId: { not: null },
            status: { in: ['picked_up', 'on_the_way'] }
        },
        include: {
            rider: { select: { id: true, username: true } },
            customer: { select: { id: true, username: true } }
        }
    });

    if (!order) {
        console.log('❌ No active order in delivery found.');
        return null;
    }

    console.log(`📦 Found order: #${order.orderNumber}`);
    console.log(`   Rider: ${order.rider?.username} (${order.riderId})`);
    console.log(`   Customer: ${order.customer?.username} (${order.customerId})`);

    // Set delivery window to have expired 2 minutes ago
    const now = new Date();
    const riderAssignedAt = new Date(now.getTime() - 32 * 60 * 1000); // 32 mins ago
    const deliveryWindowMax = 30; // 30 mins total, so 2 mins past

    await prisma.order.update({
        where: { id: order.id },
        data: {
            riderAssignedAt,
            deliveryWindowMin: 25,
            deliveryWindowMax,
            expectedDelivery: new Date(riderAssignedAt.getTime() + 28 * 60 * 1000)
        }
    });

    console.log(`\n⏰ Set delivery window: ${deliveryWindowMax} mins from assignment`);
    console.log(`   Rider assigned: ${riderAssignedAt.toISOString()}`);
    console.log(`   Window expired: ~2 minutes ago (should trigger late notification)`);

    // Clear any previous tracking for this order
    clearOrderTracking(order.id);

    // Run the monitor
    console.log('\n🔄 Running delivery monitor check...');
    await manualCheck();

    console.log('\n✅ Check complete! Customer should receive late notification with new ETA.');
    return order;
}

/**
 * Test 3: Direct socket emission test (no database changes)
 */
async function testDirectSocketEmission(riderId, customerId) {
    console.log('\n' + '='.repeat(60));
    console.log('TEST 3: Direct Socket Emission Test');
    console.log('='.repeat(60));

    if (!riderId) {
        // Get a rider from database
        const rider = await prisma.user.findFirst({
            where: { role: 'rider' },
            select: { id: true, username: true }
        });
        riderId = rider?.id;
        console.log(`Using rider: ${rider?.username} (${riderId})`);
    }

    if (!customerId) {
        // Get a customer from database
        const customer = await prisma.user.findFirst({
            where: { role: 'customer' },
            select: { id: true, username: true }
        });
        customerId = customer?.id;
        console.log(`Using customer: ${customer?.username} (${customerId})`);
    }

    if (!riderId || !customerId) {
        console.log('❌ No rider or customer found in database');
        return;
    }

    // Test rider warning
    console.log('\n📤 Emitting delivery_warning to rider...');
    socketService.emitToUser(riderId, 'delivery_warning', {
        orderId: 'test-order-id',
        orderNumber: 'TEST-001',
        minutesRemaining: 5,
        message: 'Delivery window ending in 5 mins'
    });
    console.log('   ✅ Sent delivery_warning event');

    // Wait a bit
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Test customer late notification
    console.log('\n📤 Emitting delivery_late to customer...');
    socketService.emitToUser(customerId, 'delivery_late', {
        orderId: 'test-order-id',
        orderNumber: 'TEST-001',
        newEtaMinutes: 10,
        message: 'Your delivery is running a bit late. New ETA: 10 minutes'
    });
    console.log('   ✅ Sent delivery_late event');

    console.log('\n✅ Direct socket test complete!');
    console.log('   Check rider app for warning dialog');
    console.log('   Check customer app for late notification');
}

/**
 * Show current active orders with delivery windows
 */
async function showActiveOrders() {
    console.log('\n' + '='.repeat(60));
    console.log('ACTIVE ORDERS WITH DELIVERY WINDOWS');
    console.log('='.repeat(60));

    const orders = await prisma.order.findMany({
        where: {
            riderId: { not: null },
            status: { in: ['confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way'] }
        },
        select: {
            id: true,
            orderNumber: true,
            status: true,
            riderId: true,
            customerId: true,
            riderAssignedAt: true,
            deliveryWindowMin: true,
            deliveryWindowMax: true,
            expectedDelivery: true,
            rider: { select: { username: true } },
            customer: { select: { username: true } }
        },
        take: 10
    });

    if (orders.length === 0) {
        console.log('No active orders with riders found.');
        return;
    }

    const now = new Date();
    for (const order of orders) {
        console.log(`\n📦 Order #${order.orderNumber} (${order.id})`);
        console.log(`   Status: ${order.status}`);
        console.log(`   Rider: ${order.rider?.username} (${order.riderId})`);
        console.log(`   Customer: ${order.customer?.username} (${order.customerId})`);
        
        if (order.riderAssignedAt && order.deliveryWindowMax) {
            const maxDeliveryTime = new Date(order.riderAssignedAt.getTime() + order.deliveryWindowMax * 60 * 1000);
            const minutesUntilMax = (maxDeliveryTime - now) / (1000 * 60);
            console.log(`   Window: ${order.deliveryWindowMin}-${order.deliveryWindowMax} mins`);
            console.log(`   Time until max: ${minutesUntilMax.toFixed(1)} mins ${minutesUntilMax < 0 ? '(LATE!)' : minutesUntilMax <= 5 ? '(WARNING ZONE)' : ''}`);
        } else {
            console.log(`   Window: Not set`);
        }
    }
}

/**
 * Main menu
 */
async function main() {
    console.log('\n🚀 Delivery Monitor Test Script');
    console.log('================================\n');

    await connectMongo();

    const args = process.argv.slice(2);
    const command = args[0] || 'menu';

    switch (command) {
        case 'warning':
            await testRiderWarning();
            break;
        case 'late':
            await testCustomerLateNotification();
            break;
        case 'socket':
            await testDirectSocketEmission(args[1], args[2]);
            break;
        case 'show':
            await showActiveOrders();
            break;
        case 'check':
            console.log('Running manual delivery check...');
            await manualCheck();
            break;
        default:
            console.log('Usage: node scripts/test_delivery_monitor.js <command>\n');
            console.log('Commands:');
            console.log('  show     - Show active orders with delivery windows');
            console.log('  warning  - Test rider warning (sets order to 4 mins before deadline)');
            console.log('  late     - Test customer late notification (sets order past deadline)');
            console.log('  socket   - Direct socket emission test (no DB changes)');
            console.log('  check    - Run manual delivery monitor check');
            console.log('\nExamples:');
            console.log('  node scripts/test_delivery_monitor.js show');
            console.log('  node scripts/test_delivery_monitor.js warning');
            console.log('  node scripts/test_delivery_monitor.js socket <riderId> <customerId>');
    }

    // Cleanup
    await prisma.$disconnect();
    await mongoose.disconnect();
    console.log('\n👋 Done!');
    process.exit(0);
}

main().catch(async (e) => {
    console.error('❌ Error:', e);
    await prisma.$disconnect();
    await mongoose.disconnect();
    process.exit(1);
});
