const cron = require('node-cron');
const prisma = require('../config/prisma');
const { sendToUser } = require('../services/fcm_service');
const socketService = require('../services/socket_service');
const trackingService = require('../services/tracking_service');
const cache = require('../utils/cache');
const { createScopedLogger } = require('../utils/logger');

const console = createScopedLogger('delivery_monitor_job');

const initializeDeliveryMonitor = () => {
    console.log('⏱️ Initializing delivery monitor...');

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

async function checkDeliveryWindows() {
    const now = new Date();

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

async function processOrder(order, now) {
    if (!order.expectedDelivery || !order.riderAssignedAt) return;

    const expectedDeliveryTime = new Date(order.expectedDelivery);
    const minutesUntilExpected = (expectedDeliveryTime - now) / (1000 * 60);

    const riderAssignedTime = new Date(order.riderAssignedAt);
    const maxDeliveryTime = new Date(riderAssignedTime.getTime() + order.deliveryWindowMax * 60 * 1000);
    const minutesUntilMax = (maxDeliveryTime - now) / (1000 * 60);

    if (minutesUntilMax <= 5 && minutesUntilMax > 0 && !order.deliveryWarningSentAt) {
        await sendRiderWarning(order, Math.ceil(minutesUntilMax));
        await prisma.order.update({
            where: { id: order.id },
            data: { deliveryWarningSentAt: new Date() }
        });
    }

    if (minutesUntilMax < 0 && !order.customerLateNotifiedAt) {
        await notifyCustomerLate(order);
        await prisma.order.update({
            where: { id: order.id },
            data: { customerLateNotifiedAt: new Date() }
        });
    }
}

async function sendRiderWarning(order, minutesRemaining) {
    console.log(`⏰ Warning rider for order #${order.orderNumber}: ${minutesRemaining} mins remaining`);

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

    socketService.emitToUserRoom(order.riderId, 'delivery_warning', {
        orderId: order.id,
        orderNumber: order.orderNumber,
        minutesRemaining,
        message: `Delivery window ending in ${minutesRemaining} mins`
    });
}

async function notifyCustomerLate(order) {
    console.log(`🕐 Order #${order.orderNumber} is running late, notifying customer`);

    let newEtaMinutes = null;
    let newEtaText = 'soon';

    try {
        const RiderStatus = require('../models/RiderStatus');
        const riderStatus = await RiderStatus.findOne({ riderId: order.riderId });

        if (riderStatus?.location?.coordinates && order.deliveryLatitude && order.deliveryLongitude) {
            const eta = await trackingService.calculateETA(
                riderStatus.location.coordinates[1],
                riderStatus.location.coordinates[0],
                [order.deliveryLongitude, order.deliveryLatitude]
            );

            if (eta?.duration) {
                newEtaMinutes = Math.ceil(eta.duration / 60);
                newEtaText = `${newEtaMinutes} minutes`;

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

    socketService.emitToUser(order.customerId, 'delivery_late', {
        orderId: order.id,
        orderNumber: order.orderNumber,
        newEtaMinutes,
        message: `Your delivery is running a bit late. New ETA: ${newEtaText}`
    });
}

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

async function manualCheck() {
    console.log('🔧 Manual delivery window check...');
    await checkDeliveryWindows();
}

module.exports = {
    initializeDeliveryMonitor,
    clearOrderTracking,
    manualCheck
};
