/**
 * Dispatch Service - Hybrid Order Reservation System
 * 
 * Handles intelligent order distribution to riders using:
 * 1. Rider scoring algorithm (distance, rating, acceptance rate, etc.)
 * 2. Exclusive reservations (one rider per order at a time)
 * 3. Automatic reassignment on timeout/decline
 * 4. Real-time notifications via Socket.IO + FCM
 */

const prisma = require('../config/prisma');
const OrderReservation = require('../models/OrderReservation');
const RiderStatus = require('../models/RiderStatus');
const { calculateRiderEarnings, calculateDistance } = require('../utils/riderEarningsCalculator');
const socketService = require('./socket_service');
const { sendToUser } = require('./fcm_service');

// Configuration
const CONFIG = {
    DEFAULT_TIMEOUT_MS: 8000,      // 8 seconds default reservation window
    MIN_TIMEOUT_MS: 5000,          // 5 seconds minimum
    MAX_TIMEOUT_MS: 12000,         // 12 seconds maximum
    MAX_ATTEMPTS: 5,               // Max riders to try before marking order as unassignable
    DEFAULT_RADIUS_KM: 10,         // Default search radius for riders
    MAX_RADIUS_KM: 25,             // Maximum search radius
    RADIUS_EXPANSION_KM: 5,        // How much to expand radius if not enough riders
    MIN_RIDERS_BEFORE_EXPAND: 3,   // Minimum riders before considering radius expansion
};

// Scoring weights
const SCORING = {
    DISTANCE_WEIGHT: -5,           // -5 points per km from pickup
    RATING_BONUS: 10,              // +10 points for each rating point above 4.0
    ACCEPTANCE_RATE_WEIGHT: 20,    // Up to +20 points for 100% acceptance rate
    RECENT_DECLINE_PENALTY: -15,   // -15 points if declined in last 5 minutes
    ORDER_TYPE_MATCH_BONUS: 10,    // +10 points if rider prefers this order type
    RECENT_DELIVERY_BONUS: 5,      // +5 points if delivered in last 30 minutes (active)
    LOW_EARNINGS_TODAY_BONUS: 10,  // +10 points if rider has low earnings today (fairness)
};

/**
 * Main dispatch function - Called when a new order needs a rider
 * @param {string} orderId - PostgreSQL Order ID
 * @returns {Object} Result with reservation details or error
 */
async function dispatchOrder(orderId) {
    console.log(`\n🚀 [Dispatch] Starting dispatch for order: ${orderId}`);
    
    try {
        // 1. Fetch order with all necessary details
        const order = await prisma.order.findUnique({
            where: { id: orderId },
            include: {
                customer: { select: { id: true, username: true, phone: true } },
                restaurant: { select: { restaurantName: true, logo: true, address: true, latitude: true, longitude: true } },
                groceryStore: { select: { storeName: true, logo: true, address: true, latitude: true, longitude: true } },
                pharmacyStore: { select: { storeName: true, logo: true, address: true, latitude: true, longitude: true } },
                items: { select: { id: true, name: true, quantity: true, price: true } }
            }
        });

        if (!order) {
            console.log(`❌ [Dispatch] Order not found: ${orderId}`);
            return { success: false, error: 'Order not found' };
        }

        // Check if order already has a rider
        if (order.riderId) {
            console.log(`⚠️ [Dispatch] Order already has rider: ${order.riderId}`);
            return { success: false, error: 'Order already assigned to a rider' };
        }

        // Check if order is in dispatchable status
        if (!['confirmed', 'preparing', 'ready'].includes(order.status)) {
            console.log(`⚠️ [Dispatch] Order status not dispatchable: ${order.status}`);
            return { success: false, error: `Order status "${order.status}" is not dispatchable` };
        }

        // 2. Check for existing active reservation
        const existingReservation = await OrderReservation.getActiveForOrder(orderId);
        if (existingReservation) {
            console.log(`⚠️ [Dispatch] Order already has active reservation for rider: ${existingReservation.riderId}`);
            return { 
                success: false, 
                error: 'Order already has active reservation',
                reservation: existingReservation
            };
        }

        // 3. Get previous attempts for this order
        const previousAttempts = await OrderReservation.find({ orderId }).sort({ attemptNumber: -1 }).limit(1);
        const attemptNumber = previousAttempts.length > 0 ? previousAttempts[0].attemptNumber + 1 : 1;

        if (attemptNumber > CONFIG.MAX_ATTEMPTS) {
            console.log(`❌ [Dispatch] Max attempts reached for order: ${orderId}`);
            return { success: false, error: 'Max dispatch attempts reached', attemptNumber };
        }

        // Get list of riders who already declined/expired for this order
        const excludedRiderIds = await OrderReservation.find({ 
            orderId,
            status: { $in: ['declined', 'expired'] }
        }).distinct('riderId');

        // 4. Find eligible riders
        const eligibleRiders = await findEligibleRiders(order, excludedRiderIds);
        
        if (eligibleRiders.length === 0) {
            console.log(`❌ [Dispatch] No eligible riders found for order: ${orderId}`);
            return { success: false, error: 'No eligible riders available' };
        }

        console.log(`📊 [Dispatch] Found ${eligibleRiders.length} eligible riders`);

        // 5. Score and rank riders
        const scoredRiders = await scoreRiders(eligibleRiders, order);
        scoredRiders.sort((a, b) => b.score - a.score);

        console.log(`🏆 [Dispatch] Top 3 riders:`, scoredRiders.slice(0, 3).map(r => ({
            id: r.rider.id,
            name: r.rider.username,
            score: r.score,
            distance: r.distanceToPickup
        })));

        // 6. Select top rider and create reservation
        const topRider = scoredRiders[0];
        const reservation = await createReservation(order, topRider, attemptNumber);

        // 7. Notify the rider via Socket.IO and FCM
        await notifyRiderOfReservation(reservation, order);

        console.log(`✅ [Dispatch] Reservation created for rider ${topRider.rider.username} (attempt ${attemptNumber})`);

        return {
            success: true,
            reservation,
            attemptNumber,
            riderId: topRider.rider.id,
            riderName: topRider.rider.username,
            expiresAt: reservation.expiresAt
        };

    } catch (error) {
        console.error(`❌ [Dispatch] Error dispatching order ${orderId}:`, error);
        return { success: false, error: error.message };
    }
}

/**
 * Find eligible riders for an order
 */
async function findEligibleRiders(order, excludedRiderIds = []) {
    const pickupLat = order.restaurant?.latitude || order.groceryStore?.latitude || order.pharmacyStore?.latitude;
    const pickupLon = order.restaurant?.longitude || order.groceryStore?.longitude || order.pharmacyStore?.longitude;

    if (!pickupLat || !pickupLon) {
        console.log('⚠️ [Dispatch] No pickup coordinates available');
        return [];
    }

    // Get riders who have active reservations already (to exclude)
    const ridersWithActiveReservations = await OrderReservation.find({
        status: 'pending',
        expiresAt: { $gt: new Date() }
    }).distinct('riderId');

    // Combine excluded IDs
    const allExcludedIds = [...new Set([...excludedRiderIds, ...ridersWithActiveReservations])];

    // Find online, available riders from MongoDB RiderStatus
    let radius = CONFIG.DEFAULT_RADIUS_KM;
    let eligibleRiders = [];

    while (eligibleRiders.length < CONFIG.MIN_RIDERS_BEFORE_EXPAND && radius <= CONFIG.MAX_RADIUS_KM) {
        const radiusInMeters = radius * 1000;
        
        // Query MongoDB for online riders within radius
        const riderStatuses = await RiderStatus.find({
            isOnline: true,
            isOnDelivery: false,
            isApproved: true,
            riderId: { $nin: allExcludedIds },
            location: {
                $near: {
                    $geometry: {
                        type: 'Point',
                        coordinates: [pickupLon, pickupLat]
                    },
                    $maxDistance: radiusInMeters
                }
            }
        }).limit(20); // Limit to prevent overload

        // Fetch user details from Prisma for each rider
        eligibleRiders = [];
        for (const status of riderStatuses) {
            const user = await prisma.user.findUnique({
                where: { id: status.riderId },
                select: {
                    id: true,
                    username: true,
                    email: true,
                    phone: true,
                    profilePicture: true,
                    rider: {
                        select: {
                            vehicleType: true,
                            verificationStatus: true
                        }
                    }
                }
            });

            if (user && user.rider?.verificationStatus === 'approved') {
                // Calculate distance
                const distance = status.distanceTo(pickupLon, pickupLat);
                
                eligibleRiders.push({
                    ...user,
                    _status: status,
                    _distanceToPickup: distance,
                    // Merge metrics from RiderStatus
                    riderRating: status.metrics.rating,
                    riderTotalDeliveries: status.metrics.totalDeliveries,
                    riderAcceptanceRate: status.metrics.acceptanceRate,
                    riderPreferredOrderTypes: status.preferredOrderTypes,
                    recentDeclines: status.recentDeclines
                });
            }
        }

        if (eligibleRiders.length < CONFIG.MIN_RIDERS_BEFORE_EXPAND) {
            radius += CONFIG.RADIUS_EXPANSION_KM;
            console.log(`📍 [Dispatch] Expanding radius to ${radius}km (found ${eligibleRiders.length} riders)`);
        }
    }

    return eligibleRiders;
}

/**
 * Score riders based on multiple factors
 */
async function scoreRiders(riders, order) {
    const scoredRiders = [];

    for (const rider of riders) {
        let score = 100; // Base score

        // 1. Distance penalty (closer = better)
        const distanceToPickup = rider._distanceToPickup || 0;
        score += distanceToPickup * SCORING.DISTANCE_WEIGHT;

        // 2. Rating bonus
        const rating = rider.riderRating || 4.0;
        if (rating > 4.0) {
            score += (rating - 4.0) * SCORING.RATING_BONUS;
        }

        // 3. Acceptance rate bonus
        const acceptanceRate = rider.riderAcceptanceRate || 0.5;
        score += acceptanceRate * SCORING.ACCEPTANCE_RATE_WEIGHT;

        // 4. Recent decline penalty - check if rider declined anything in last 5 min
        const recentDecline = await OrderReservation.findOne({
            riderId: rider.id,
            status: 'declined',
            respondedAt: { $gte: new Date(Date.now() - 5 * 60 * 1000) }
        });
        if (recentDecline) {
            score += SCORING.RECENT_DECLINE_PENALTY;
        }

        // 5. Order type preference match
        const orderType = order.orderType || 'food';
        const preferredTypes = rider.riderPreferredOrderTypes || [];
        if (preferredTypes.includes(orderType)) {
            score += SCORING.ORDER_TYPE_MATCH_BONUS;
        }

        // 6. Recent activity bonus (delivered in last 30 min = active & warmed up)
        const recentDelivery = await prisma.order.findFirst({
            where: {
                riderId: rider.id,
                status: 'delivered',
                deliveredDate: { gte: new Date(Date.now() - 30 * 60 * 1000) }
            }
        });
        if (recentDelivery) {
            score += SCORING.RECENT_DELIVERY_BONUS;
        }

        // 7. Low earnings today bonus (fairness - give opportunities to those with less)
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);
        
        const todayEarnings = await prisma.order.aggregate({
            where: {
                riderId: rider.id,
                status: 'delivered',
                deliveredDate: { gte: todayStart }
            },
            _sum: { riderEarnings: true }
        });

        const earnings = todayEarnings._sum.riderEarnings || 0;
        if (earnings < 50) { // Less than GHS 50 today
            score += SCORING.LOW_EARNINGS_TODAY_BONUS;
        }

        scoredRiders.push({
            rider,
            score: Math.round(score * 10) / 10,
            distanceToPickup,
            factors: {
                distance: distanceToPickup,
                rating,
                acceptanceRate,
                hadRecentDecline: !!recentDecline,
                matchesPreference: preferredTypes.includes(orderType),
                recentlyActive: !!recentDelivery,
                lowEarningsToday: earnings < 50
            }
        });
    }

    return scoredRiders;
}

/**
 * Create a reservation for a rider
 */
async function createReservation(order, scoredRider, attemptNumber) {
    const { rider, score, distanceToPickup } = scoredRider;
    
    // Calculate adaptive timeout based on rider's response history
    const timeoutMs = await calculateAdaptiveTimeout(rider.id);
    const expiresAt = new Date(Date.now() + timeoutMs);

    // Calculate estimated earnings
    const earnings = calculateRiderEarnings(order, 0);

    // Build order snapshot
    const storeName = order.restaurant?.restaurantName || 
                      order.groceryStore?.storeName || 
                      order.pharmacyStore?.storeName || 'Unknown';
    
    const storeLogo = order.restaurant?.logo || 
                      order.groceryStore?.logo || 
                      order.pharmacyStore?.logo || null;

    const pickupAddress = order.restaurant?.address || 
                          order.groceryStore?.address || 
                          order.pharmacyStore?.address || 'Unknown';

    const pickupLat = order.restaurant?.latitude || 
                      order.groceryStore?.latitude || 
                      order.pharmacyStore?.latitude;

    const pickupLon = order.restaurant?.longitude || 
                      order.groceryStore?.longitude || 
                      order.pharmacyStore?.longitude;

    const reservation = new OrderReservation({
        orderId: order.id,
        orderNumber: order.orderNumber,
        riderId: rider.id,
        status: 'pending',
        expiresAt,
        timeoutMs,
        attemptNumber,
        riderScore: score,
        distanceToPickup,
        estimatedEarnings: earnings.riderEarnings,
        orderSnapshot: {
            orderType: order.orderType || 'food',
            totalAmount: order.totalAmount,
            paymentMethod: order.paymentMethod,
            itemCount: order.items?.length || 0,
            pickupAddress,
            pickupLat,
            pickupLon,
            deliveryAddress: `${order.deliveryStreet || ''}, ${order.deliveryCity || ''}`.trim(),
            deliveryLat: order.deliveryLatitude,
            deliveryLon: order.deliveryLongitude,
            storeName,
            storeLogo,
            customerName: order.customer?.username || 'Customer',
            distance: earnings.distance
        }
    });

    await reservation.save();
    return reservation;
}

/**
 * Calculate adaptive timeout based on rider's historical response time
 */
async function calculateAdaptiveTimeout(riderId) {
    // Get rider's last 10 reservations
    const history = await OrderReservation.find({
        riderId,
        status: { $in: ['accepted', 'declined'] },
        respondedAt: { $ne: null }
    })
    .sort({ createdAt: -1 })
    .limit(10);

    if (history.length < 3) {
        // Not enough history, use default
        return CONFIG.DEFAULT_TIMEOUT_MS;
    }

    // Calculate average response time
    const responseTimes = history.map(r => {
        return new Date(r.respondedAt) - new Date(r.createdAt);
    });

    const avgResponseTime = responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length;

    // Add buffer (1.5x average) and clamp to min/max
    let timeout = Math.round(avgResponseTime * 1.5);
    timeout = Math.max(CONFIG.MIN_TIMEOUT_MS, Math.min(CONFIG.MAX_TIMEOUT_MS, timeout));

    console.log(`⏱️ [Dispatch] Adaptive timeout for rider ${riderId}: ${timeout}ms (avg response: ${Math.round(avgResponseTime)}ms)`);

    return timeout;
}

/**
 * Notify rider of their reservation via Socket.IO and FCM
 */
async function notifyRiderOfReservation(reservation, order) {
    const riderId = reservation.riderId;

    // Prepare notification payload
    const payload = {
        type: 'order_reserved',
        reservationId: reservation._id.toString(),
        orderId: reservation.orderId,
        orderNumber: reservation.orderNumber,
        expiresAt: reservation.expiresAt.toISOString(),
        timeoutMs: reservation.timeoutMs,
        attemptNumber: reservation.attemptNumber,
        estimatedEarnings: reservation.estimatedEarnings,
        distanceToPickup: reservation.distanceToPickup,
        order: reservation.orderSnapshot
    };

    // 1. Send via Socket.IO (real-time, in-app)
    socketService.emitToUserRoom(riderId, 'order_reserved', payload);
    console.log(`📡 [Dispatch] Socket notification sent to rider: ${riderId}`);

    // 2. Send via FCM (push notification, even if app is backgrounded)
    try {
        await sendToUser(
            riderId,
            {
                title: '🚴 New Order Available!',
                body: `${reservation.orderSnapshot.storeName} → ${reservation.orderSnapshot.deliveryAddress.split(',')[0]}. Earn GHS ${reservation.estimatedEarnings.toFixed(2)}. Tap to accept!`,
            },
            {
                type: 'order_reserved',
                reservationId: reservation._id.toString(),
                orderId: reservation.orderId,
                orderNumber: reservation.orderNumber,
                expiresAt: reservation.expiresAt.toISOString(),
                timeoutMs: reservation.timeoutMs.toString(),
                estimatedEarnings: reservation.estimatedEarnings.toString(),
            }
        );
        console.log(`📲 [Dispatch] FCM notification sent to rider: ${riderId}`);
    } catch (error) {
        console.error(`⚠️ [Dispatch] FCM notification failed for rider ${riderId}:`, error.message);
    }
}

/**
 * Handle rider accepting a reservation
 */
async function acceptReservation(reservationId, riderId) {
    console.log(`\n✅ [Dispatch] Rider ${riderId} accepting reservation: ${reservationId}`);

    const reservation = await OrderReservation.findById(reservationId);
    
    if (!reservation) {
        return { success: false, error: 'Reservation not found' };
    }

    if (reservation.riderId !== riderId) {
        return { success: false, error: 'Reservation belongs to another rider' };
    }

    if (reservation.status !== 'pending') {
        return { success: false, error: `Reservation already ${reservation.status}` };
    }

    if (new Date() > reservation.expiresAt) {
        await reservation.expire();
        return { success: false, error: 'Reservation has expired' };
    }

    // Mark reservation as accepted
    await reservation.accept();

    // Update rider's acceptance rate
    await updateRiderAcceptanceRate(riderId, true);

    // The actual order assignment will be handled by the rider route
    return { 
        success: true, 
        reservation,
        orderId: reservation.orderId,
        message: 'Reservation accepted successfully'
    };
}

/**
 * Handle rider declining a reservation
 */
async function declineReservation(reservationId, riderId, reason = null) {
    console.log(`\n❌ [Dispatch] Rider ${riderId} declining reservation: ${reservationId}`);

    const reservation = await OrderReservation.findById(reservationId);
    
    if (!reservation) {
        return { success: false, error: 'Reservation not found' };
    }

    if (reservation.riderId !== riderId) {
        return { success: false, error: 'Reservation belongs to another rider' };
    }

    if (reservation.status !== 'pending') {
        return { success: false, error: `Reservation already ${reservation.status}` };
    }

    // Mark reservation as declined
    await reservation.decline(reason);

    // Update rider's acceptance rate
    await updateRiderAcceptanceRate(riderId, false);

    // Dispatch to next rider
    const nextDispatch = await dispatchOrder(reservation.orderId);

    return { 
        success: true, 
        message: 'Reservation declined',
        nextDispatch
    };
}

/**
 * Handle expired reservations (called by scheduler)
 */
async function handleExpiredReservations() {
    console.log(`\n⏰ [Dispatch] Checking for expired reservations...`);

    const expired = await OrderReservation.findExpired();
    console.log(`Found ${expired.length} expired reservations`);

    const results = [];

    for (const reservation of expired) {
        try {
            // Mark as expired
            await reservation.expire();
            console.log(`⏰ [Dispatch] Marked reservation ${reservation._id} as expired`);

            // Update rider's stats (expired counts as non-response)
            await updateRiderAcceptanceRate(reservation.riderId, false);

            // Dispatch to next rider
            const nextDispatch = await dispatchOrder(reservation.orderId);
            results.push({
                reservationId: reservation._id,
                orderId: reservation.orderId,
                nextDispatch
            });

        } catch (error) {
            console.error(`❌ [Dispatch] Error handling expired reservation ${reservation._id}:`, error);
            results.push({
                reservationId: reservation._id,
                orderId: reservation.orderId,
                error: error.message
            });
        }
    }

    return results;
}

/**
 * Update rider's acceptance rate
 */
async function updateRiderAcceptanceRate(riderId, accepted) {
    try {
        // Get rider's last 50 reservations
        const history = await OrderReservation.find({
            riderId,
            status: { $in: ['accepted', 'declined', 'expired'] }
        })
        .sort({ createdAt: -1 })
        .limit(50);

        if (history.length === 0) return;

        const acceptedCount = history.filter(r => r.status === 'accepted').length;
        const acceptanceRate = acceptedCount / history.length;

        await prisma.user.update({
            where: { id: riderId },
            data: { riderAcceptanceRate: acceptanceRate }
        });

        console.log(`📊 [Dispatch] Updated acceptance rate for rider ${riderId}: ${(acceptanceRate * 100).toFixed(1)}%`);
    } catch (error) {
        console.error(`⚠️ [Dispatch] Error updating acceptance rate for rider ${riderId}:`, error);
    }
}

/**
 * Get active reservation for a rider (used by rider app)
 */
async function getActiveReservationForRider(riderId) {
    return OrderReservation.getActiveForRider(riderId);
}

/**
 * Cancel all reservations for an order (e.g., when customer cancels)
 */
async function cancelOrderReservations(orderId) {
    const reservations = await OrderReservation.find({
        orderId,
        status: 'pending'
    });

    for (const reservation of reservations) {
        await reservation.cancel();
        
        // Notify rider that reservation was cancelled
        socketService.emitToUserRoom(reservation.riderId, 'reservation_cancelled', {
            reservationId: reservation._id.toString(),
            orderId,
            reason: 'order_cancelled'
        });
    }

    return { cancelled: reservations.length };
}

module.exports = {
    dispatchOrder,
    acceptReservation,
    declineReservation,
    handleExpiredReservations,
    getActiveReservationForRider,
    cancelOrderReservations,
    findEligibleRiders,
    scoreRiders,
    CONFIG
};
