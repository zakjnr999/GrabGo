const dispatchService = require('../services/dispatch_service');
const socketService = require('../services/socket_service');
const OrderReservation = require('../models/OrderReservation');
const cache = require('../utils/cache');

const ORDER_RESERVATION_ENTITY = 'order';
const buildOrderReservationQuery = (query = {}) =>
    OrderReservation.buildEntityQuery(ORDER_RESERVATION_ENTITY, query);

let isRunning = false;
let intervalId = null;

const CHECK_INTERVAL_MS = 2000;
const MAX_CONSECUTIVE_ERRORS = 5;
let consecutiveErrors = 0;

async function processExpiredReservations() {
    const lock = await cache.acquireLock('job:reservation_expiry', 3);
    if (!lock) {
        return;
    }
    if (isRunning) {
        await cache.releaseLock(lock);
        return;
    }

    isRunning = true;

    try {
        const expiredReservations = await OrderReservation.find(
            buildOrderReservationQuery({
                status: 'pending',
                expiresAt: { $lte: new Date() }
            })
        );

        if (expiredReservations.length === 0) {
            consecutiveErrors = 0;
            isRunning = false;
            return;
        }

        console.log(`\n⏰ [ReservationExpiry] Found ${expiredReservations.length} expired reservations`);

        for (const reservation of expiredReservations) {
            try {
                reservation.status = 'expired';
                await reservation.save();

                console.log(`   ⏰ Expired: Order ${reservation.orderNumber} (was reserved for rider ${reservation.riderId})`);

                socketService.notifyReservationExpired(
                    reservation.riderId,
                    reservation._id.toString(),
                    reservation.orderId
                );

                await updateRiderStats(reservation.riderId);

                const nextDispatch = await dispatchService.dispatchOrder(reservation.orderId);

                if (nextDispatch.success) {
                    console.log(`   ✅ Reassigned to rider ${nextDispatch.riderName} (attempt ${nextDispatch.attemptNumber})`);
                } else if (nextDispatch.error === 'Max dispatch attempts reached') {
                    console.log(`   ⚠️ Max attempts reached for order ${reservation.orderNumber} - marking as unassignable`);
                    await handleUnassignableOrder(reservation.orderId, reservation.orderNumber);
                } else if (nextDispatch.error === 'No eligible riders available') {
                    console.log(`   ⚠️ No riders available for order ${reservation.orderNumber} - will retry`);
                } else {
                    console.log(`   ❌ Failed to reassign: ${nextDispatch.error}`);
                }

            } catch (error) {
                console.error(`   ❌ Error processing expired reservation ${reservation._id}:`, error.message);
            }
        }

        consecutiveErrors = 0;

    } catch (error) {
        consecutiveErrors++;
        console.error(`❌ [ReservationExpiry] Job error (${consecutiveErrors}/${MAX_CONSECUTIVE_ERRORS}):`, error.message);

        if (consecutiveErrors >= MAX_CONSECUTIVE_ERRORS) {
            console.error('❌ [ReservationExpiry] Max consecutive errors reached, pausing job...');
            stop();
            setTimeout(() => {
                console.log('🔄 [ReservationExpiry] Auto-restarting after error pause...');
                consecutiveErrors = 0;
                start();
            }, 30000);
        }
    } finally {
        isRunning = false;
        await cache.releaseLock(lock);
    }
}

async function updateRiderStats(riderId) {
    try {
        const RiderStatus = require('../models/RiderStatus');
        
        const history = await OrderReservation.find(
            buildOrderReservationQuery({
                riderId,
                status: { $in: ['accepted', 'declined', 'expired'] }
            })
        )
        .sort({ createdAt: -1 })
        .limit(50);

        if (history.length === 0) return;

        const acceptedCount = history.filter(r => r.status === 'accepted').length;
        const acceptanceRate = (acceptedCount / history.length) * 100;

        await RiderStatus.findOneAndUpdate(
            { riderId },
            { $set: { 'metrics.acceptanceRate': acceptanceRate } }
        );
        
        console.log(`📊 [ReservationExpiry] Updated acceptance rate for rider ${riderId}: ${acceptanceRate.toFixed(1)}%`);
    } catch (error) {
        console.error(`⚠️ [ReservationExpiry] Error updating rider stats:`, error.message);
    }
}

async function handleUnassignableOrder(orderId, orderNumber) {
    try {
        const prisma = require('../config/prisma');
        const { createNotification } = require('../services/notification_service');
        const { getIO } = require('../utils/socket');

        const order = await prisma.order.findUnique({
            where: { id: orderId },
            include: {
                customer: { select: { id: true, username: true } }
            }
        });

        if (!order) return;

        // Create notification for admin
        console.log(`📢 [ReservationExpiry] Order ${orderNumber} needs manual attention - no riders accepted`);

        // Optionally notify customer that there's a delay
        if (order.customerId) {
            const io = getIO();
            await createNotification(
                order.customerId,
                'order',
                '⏳ Finding a Rider',
                `We're experiencing high demand. We'll assign a rider to your order #${orderNumber} shortly.`,
                {
                    orderId,
                    orderNumber,
                    type: 'rider_delay',
                    route: `/orders/${orderId}`
                },
                io
            );
        }

        // Schedule a retry dispatch in 2 minutes
        setTimeout(async () => {
            console.log(`🔄 [ReservationExpiry] Retrying dispatch for unassignable order ${orderNumber}`);
            
            // Check if order still needs a rider
            const currentOrder = await prisma.order.findUnique({
                where: { id: orderId }
            });

            if (currentOrder && !currentOrder.riderId && 
                ['confirmed', 'preparing', 'ready'].includes(currentOrder.status)) {
                
                // Reset attempt count by clearing old reservations
                await OrderReservation.updateMany(
                    buildOrderReservationQuery({ orderId }),
                    { $set: { status: 'cancelled' } }
                );

                // Try dispatch again
                await dispatchService.dispatchOrder(orderId);
            }
        }, 120000); // 2 minutes

    } catch (error) {
        console.error(`⚠️ [ReservationExpiry] Error handling unassignable order:`, error.message);
    }
}

function start() {
    if (intervalId) {
        console.log('[ReservationExpiry] Job already running');
        return;
    }

    console.log(`✅ [ReservationExpiry] Starting job (checking every ${CHECK_INTERVAL_MS / 1000}s)`);
    intervalId = setInterval(processExpiredReservations, CHECK_INTERVAL_MS);

    // Run immediately on start
    processExpiredReservations();
}

function stop() {
    if (intervalId) {
        clearInterval(intervalId);
        intervalId = null;
        console.log('🛑 [ReservationExpiry] Job stopped');
    }
}

function isJobRunning() {
    return intervalId !== null;
}

function getStatus() {
    return {
        running: intervalId !== null,
        processing: isRunning,
        consecutiveErrors,
        checkIntervalMs: CHECK_INTERVAL_MS
    };
}

module.exports = {
    start,
    stop,
    isJobRunning,
    getStatus,
    processExpiredReservations
};
