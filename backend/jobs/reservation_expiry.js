/**
 * Reservation Expiry Job
 * 
 * Runs every 2 seconds to check for expired order reservations
 * and automatically reassigns them to the next eligible rider.
 * 
 * This is the heart of the hybrid dispatch system - ensures orders
 * keep moving to new riders until someone accepts.
 */

const dispatchService = require('../services/dispatch_service');
const socketService = require('../services/socket_service');
const OrderReservation = require('../models/OrderReservation');
const cache = require('../utils/cache');

let isRunning = false;
let intervalId = null;

// Configuration
const CHECK_INTERVAL_MS = 2000; // Check every 2 seconds
const MAX_CONSECUTIVE_ERRORS = 5;
let consecutiveErrors = 0;

/**
 * Process expired reservations
 */
async function processExpiredReservations() {
    const lock = await cache.acquireLock('job:reservation_expiry', 3);
    if (!lock) {
        return;
    }
    if (isRunning) {
        await cache.releaseLock(lock);
        return; // Prevent overlapping runs
    }

    isRunning = true;

    try {
        // Find all expired pending reservations
        const expiredReservations = await OrderReservation.find({
            status: 'pending',
            expiresAt: { $lte: new Date() }
        });

        if (expiredReservations.length === 0) {
            consecutiveErrors = 0; // Reset error counter on successful run
            isRunning = false;
            return;
        }

        console.log(`\n⏰ [ReservationExpiry] Found ${expiredReservations.length} expired reservations`);

        for (const reservation of expiredReservations) {
            try {
                // Mark as expired
                reservation.status = 'expired';
                await reservation.save();

                console.log(`   ⏰ Expired: Order ${reservation.orderNumber} (was reserved for rider ${reservation.riderId})`);

                // Notify the rider that their reservation expired
                socketService.notifyReservationExpired(
                    reservation.riderId,
                    reservation._id.toString(),
                    reservation.orderId
                );

                // Update rider's acceptance rate (expired counts as non-response)
                await updateRiderStats(reservation.riderId);

                // Dispatch to next rider
                const nextDispatch = await dispatchService.dispatchOrder(reservation.orderId);

                if (nextDispatch.success) {
                    console.log(`   ✅ Reassigned to rider ${nextDispatch.riderName} (attempt ${nextDispatch.attemptNumber})`);
                } else if (nextDispatch.error === 'Max dispatch attempts reached') {
                    console.log(`   ⚠️ Max attempts reached for order ${reservation.orderNumber} - marking as unassignable`);
                    // Optionally: notify admin or take other action
                    await handleUnassignableOrder(reservation.orderId, reservation.orderNumber);
                } else if (nextDispatch.error === 'No eligible riders available') {
                    console.log(`   ⚠️ No riders available for order ${reservation.orderNumber} - will retry`);
                    // The order stays in the pool - dispatch will be retried when riders become available
                } else {
                    console.log(`   ❌ Failed to reassign: ${nextDispatch.error}`);
                }

            } catch (error) {
                console.error(`   ❌ Error processing expired reservation ${reservation._id}:`, error.message);
            }
        }

        consecutiveErrors = 0; // Reset error counter on successful run

    } catch (error) {
        consecutiveErrors++;
        console.error(`❌ [ReservationExpiry] Job error (${consecutiveErrors}/${MAX_CONSECUTIVE_ERRORS}):`, error.message);

        if (consecutiveErrors >= MAX_CONSECUTIVE_ERRORS) {
            console.error('❌ [ReservationExpiry] Max consecutive errors reached, pausing job...');
            stop();
            // Auto-restart after 30 seconds
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

/**
 * Update rider's statistics after expired reservation
 */
async function updateRiderStats(riderId) {
    try {
        const RiderStatus = require('../models/RiderStatus');
        
        // Get rider's last 50 reservations
        const history = await OrderReservation.find({
            riderId,
            status: { $in: ['accepted', 'declined', 'expired'] }
        })
        .sort({ createdAt: -1 })
        .limit(50);

        if (history.length === 0) return;

        const acceptedCount = history.filter(r => r.status === 'accepted').length;
        const acceptanceRate = (acceptedCount / history.length) * 100; // Store as percentage 0-100

        // Update MongoDB RiderStatus instead of Prisma User
        await RiderStatus.findOneAndUpdate(
            { riderId },
            { $set: { 'metrics.acceptanceRate': acceptanceRate } }
        );
        
        console.log(`📊 [ReservationExpiry] Updated acceptance rate for rider ${riderId}: ${acceptanceRate.toFixed(1)}%`);
    } catch (error) {
        console.error(`⚠️ [ReservationExpiry] Error updating rider stats:`, error.message);
    }
}

/**
 * Handle orders that couldn't be assigned after max attempts
 */
async function handleUnassignableOrder(orderId, orderNumber) {
    try {
        const prisma = require('../config/prisma');
        const { createNotification } = require('../services/notification_service');
        const { getIO } = require('../utils/socket');

        // Get the order
        const order = await prisma.order.findUnique({
            where: { id: orderId },
            include: {
                customer: { select: { id: true, username: true } }
            }
        });

        if (!order) return;

        // Create notification for admin (if you have an admin notification system)
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
                    { orderId },
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

/**
 * Start the expiry job
 */
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

/**
 * Stop the expiry job
 */
function stop() {
    if (intervalId) {
        clearInterval(intervalId);
        intervalId = null;
        console.log('🛑 [ReservationExpiry] Job stopped');
    }
}

/**
 * Check if job is running
 */
function isJobRunning() {
    return intervalId !== null;
}

/**
 * Get job status
 */
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
    processExpiredReservations // Export for manual triggering if needed
};
