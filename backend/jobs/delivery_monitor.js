const cron = require('node-cron');
const prisma = require('../config/prisma');
const { sendToUser } = require('../services/fcm_service');
const socketService = require('../services/socket_service');
const trackingService = require('../services/tracking_service');
const cache = require('../utils/cache');

/**
 * Delivery Monitor Job
 * 
 * Runs every minute to:
 * 1. Warn riders 5 mins before delivery window expires
 * 2. Notify customers when delivery is running late
 * 3. Update customer with new ETA when past window
 */

// Note: We now use database fields (deliveryWarningSentAt, customerLateNotifiedAt) 
// instead of in-memory Sets to persist across server restarts

/**
 * Initialize the delivery monitor
 */
const initializeDeliveryMonitor = () => {
    console.log('⏱️ Initializing delivery monitor...');

    // Run every minute
    cron.schedule('* * * * *', async () => {
        try {
            const lock = await cache.acquireLock('job:delivery_monitor', 50);
            if (!lock) {
                console.log('⏭️ Delivery monitor skipped (lock held)');
                return;
            }
            try {
                await checkDeliveryWindows();
            } finally {
                await cache.releaseLock(lock);
            }
        } catch (error) {
            console.error('❌ Delivery monitor error:', error.message);
        }
    });

    console.log('✅ Delivery monitor started (runs every minute)');
};

/**
 * Check all active orders with delivery windows
 */
async function checkDeliveryWindows() {
    const now = new Date();

    // Find orders that are:
    // - Have a rider assigned
    // - Have delivery window set
    // - Status is in active delivery states
    // - Not yet delivered or cancelled
    const activeOrders = await prisma.order.findMany({
        where: {
            riderId: { not: null },
            expectedDelivery: { not: null },
            deliveryWindowMax: { not: null },
            status: {
                in: ['confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way']
            }
        },
        select: {
            id: true,
            orderNumber: true,
            riderId: true,
            customerId: true,
            expectedDelivery: true,
            deliveryWindowMin: true,
            deliveryWindowMax: true,
            riderAssignedAt: true,
            deliveryWarningSentAt: true,
            customerLateNotifiedAt: true,
            status: true,
            deliveryLatitude: true,
            deliveryLongitude: true,
            customer: {
                select: { username: true }
            },
            rider: {
                select: { username: true }
            },
            restaurant: {
                select: { latitude: true, longitude: true }
            },
            groceryStore: {
                select: { latitude: true, longitude: true }
            },
            pharmacyStore: {
                select: { latitude: true, longitude: true }
            }
        }
    });

    for (const order of activeOrders) {
        await processOrder(order, now);
    }
}

/**
 * Process a single order for warnings and notifications
 */
async function processOrder(order, now) {
    if (!order.expectedDelivery || !order.riderAssignedAt) return;

    const expectedDeliveryTime = new Date(order.expectedDelivery);
    const minutesUntilExpected = (expectedDeliveryTime - now) / (1000 * 60);

    // Calculate max delivery time (using deliveryWindowMax)
    const riderAssignedTime = new Date(order.riderAssignedAt);
    const maxDeliveryTime = new Date(riderAssignedTime.getTime() + order.deliveryWindowMax * 60 * 1000);
    const minutesUntilMax = (maxDeliveryTime - now) / (1000 * 60);

    // 1. SOFT WARNING TO RIDER (5 mins before max window)
    // Use database field to prevent duplicate notifications across server restarts
    if (minutesUntilMax <= 5 && minutesUntilMax > 0 && !order.deliveryWarningSentAt) {
        await sendRiderWarning(order, Math.ceil(minutesUntilMax));
        // Mark as warned in database
        await prisma.order.update({
            where: { id: order.id },
            data: { deliveryWarningSentAt: new Date() }
        });
    }

    // 2. CUSTOMER NOTIFICATION WHEN LATE (past max window)
    // Use database field to prevent duplicate notifications across server restarts
    if (minutesUntilMax < 0 && !order.customerLateNotifiedAt) {
        await notifyCustomerLate(order);
        // Mark as notified in database
        await prisma.order.update({
            where: { id: order.id },
            data: { customerLateNotifiedAt: new Date() }
        });
    }
}

/**
 * Send soft warning to rider
 */
async function sendRiderWarning(order, minutesRemaining) {
    console.log(`⏰ Warning rider for order #${order.orderNumber}: ${minutesRemaining} mins remaining`);

    // Push notification to rider
    await sendToUser(
        order.riderId,
        {
            title: '⏰ Delivery Window Ending Soon',
            body: `Order #${order.orderNumber} should be delivered in ${minutesRemaining} minutes. Please hurry!`
        },
        {
            type: 'delivery_warning',
            orderId: order.id,
            orderNumber: order.orderNumber,
            minutesRemaining: minutesRemaining.toString()
        }
    );

    // Also send via socket for immediate in-app notification (use room-based for riders)
    socketService.emitToUserRoom(order.riderId, 'delivery_warning', {
        orderId: order.id,
        orderNumber: order.orderNumber,
        minutesRemaining,
        message: `Delivery window ending in ${minutesRemaining} mins`
    });
}

/**
 * Notify customer that delivery is running late and provide new ETA
 */
async function notifyCustomerLate(order) {
    console.log(`🕐 Order #${order.orderNumber} is running late, notifying customer`);

    // Try to calculate new ETA based on current rider location
    let newEtaMinutes = null;
    let newEtaText = 'soon';

    try {
        // Get rider's current location from RiderStatus
        const RiderStatus = require('../models/RiderStatus');
        const riderStatus = await RiderStatus.findOne({ riderId: order.riderId });

        if (riderStatus?.location?.coordinates && order.deliveryLatitude && order.deliveryLongitude) {
            // Calculate new ETA from current position to customer
            const eta = await trackingService.calculateETA(
                riderStatus.location.coordinates[1], // latitude
                riderStatus.location.coordinates[0], // longitude
                [order.deliveryLongitude, order.deliveryLatitude]
            );

            if (eta?.duration) {
                newEtaMinutes = Math.ceil(eta.duration / 60);
                newEtaText = `${newEtaMinutes} minutes`;

                // Update order with new expected delivery
                await prisma.order.update({
                    where: { id: order.id },
                    data: {
                        expectedDelivery: new Date(Date.now() + eta.duration * 1000)
                    }
                });
            }
        }
    } catch (error) {
        console.error('Error calculating new ETA:', error.message);
    }

    // Push notification to customer
    await sendToUser(
        order.customerId,
        {
            title: '⏱️ Updated delivery time',
            body: `Your order #${order.orderNumber} is taking a little longer than expected. We’ve updated your estimated arrival to ${newEtaText}. Thanks for your patience.`
        },
        {
            type: 'delivery_late',
            orderId: order.id,
            orderNumber: order.orderNumber,
            newEtaMinutes: newEtaMinutes?.toString() || ''
        }
    );

    // Socket notification for real-time update
    socketService.emitToUser(order.customerId, 'delivery_late', {
        orderId: order.id,
        orderNumber: order.orderNumber,
        newEtaMinutes,
        message: `Your delivery is running a bit late. New ETA: ${newEtaText}`
    });
}

/**
 * Clean up tracked orders (call when order is completed/cancelled)
 * Resets the database fields so the order can be re-warned if needed
 */
async function clearOrderTracking(orderId) {
    try {
        await prisma.order.update({
            where: { id: orderId },
            data: {
                deliveryWarningSentAt: null,
                customerLateNotifiedAt: null
            }
        });
        console.log(`🧹 Cleared delivery tracking for order ${orderId}`);
    } catch (error) {
        console.error(`Error clearing order tracking: ${error.message}`);
    }
}

/**
 * Manual check for testing
 */
async function manualCheck() {
    console.log('🔧 Manual delivery window check...');
    await checkDeliveryWindows();
}

module.exports = {
    initializeDeliveryMonitor,
    clearOrderTracking,
    manualCheck
};
