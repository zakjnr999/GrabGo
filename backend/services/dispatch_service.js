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
const featureFlags = require('../config/feature_flags');

const ORDER_RESERVATION_ENTITY = 'order';
const buildOrderReservationQuery = (query = {}) =>
    OrderReservation.buildEntityQuery(ORDER_RESERVATION_ENTITY, query);

// Configuration
const CONFIG = {
    DEFAULT_TIMEOUT_MS: 30000,     // 30 seconds default reservation window
    MIN_TIMEOUT_MS: 20000,         // 20 seconds minimum
    MAX_TIMEOUT_MS: 45000,         // 45 seconds maximum
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
    // Battery level scoring
    LOW_BATTERY_PENALTY: -25,      // -25 points if battery < 20% (may not complete delivery)
    CRITICAL_BATTERY_PENALTY: -50, // -50 points if battery < 10% (very risky)
    CHARGING_BONUS: 5,             // +5 points if currently charging (battery improving)
    // Vehicle type scoring
    VEHICLE_LONG_DISTANCE_BONUS: 15,   // +15 points for motorcycle/car on orders > 5km
    VEHICLE_LARGE_ORDER_BONUS: 10,     // +10 points for car/scooter on large orders
    BICYCLE_SHORT_DISTANCE_BONUS: 10,  // +10 points for bicycle on orders < 2km (eco-friendly, traffic)
    // On-time performance scoring
    ON_TIME_BONUS: 15,                 // +15 points for riders with 90%+ on-time rate
    GOOD_ON_TIME_BONUS: 8,             // +8 points for riders with 80-89% on-time rate
    LOW_ON_TIME_PENALTY: -20,          // -20 points for riders with <70% on-time rate (consistently late)
};

const DISPATCHABLE_STATUSES = new Set(['preparing', 'ready']);
const DISPATCHABLE_PAYMENT_STATUSES = new Set(['paid', 'successful']);

const parsePositiveIntEnv = (name, fallback, { min = 0, max = Number.MAX_SAFE_INTEGER } = {}) => {
    const parsed = Number.parseInt(String(process.env[name]), 10);
    if (!Number.isFinite(parsed) || parsed < min || parsed > max) {
        return fallback;
    }
    return parsed;
};

const CONFIRMED_PREDISPATCH_BUFFER_MINUTES = parsePositiveIntEnv(
    'CONFIRMED_PREDISPATCH_BUFFER_MINUTES',
    5,
    { min: 0, max: 60 }
);

const CONFIRMED_PREDISPATCH_AVG_SPEED_KMPH = parsePositiveIntEnv(
    'CONFIRMED_PREDISPATCH_AVG_SPEED_KMPH',
    20,
    { min: 5, max: 80 }
);

const CONFIRMED_PREDISPATCH_DEFAULT_PREP_MINUTES = parsePositiveIntEnv(
    'CONFIRMED_PREDISPATCH_DEFAULT_PREP_MINUTES',
    15,
    { min: 1, max: 120 }
);

const firstDefined = (...values) =>
    values.find((value) => value !== null && value !== undefined);

const getPickupLocation = (order) => ({
    latitude: firstDefined(
        order?.restaurant?.latitude,
        order?.groceryStore?.latitude,
        order?.pharmacyStore?.latitude,
        order?.grabMartStore?.latitude
    ),
    longitude: firstDefined(
        order?.restaurant?.longitude,
        order?.groceryStore?.longitude,
        order?.pharmacyStore?.longitude,
        order?.grabMartStore?.longitude
    )
});

const getStoreName = (order) =>
    firstDefined(order?.restaurant?.restaurantName, order?.groceryStore?.storeName, order?.pharmacyStore?.storeName, order?.grabMartStore?.storeName) || 'Unknown';

const getStoreLogo = (order) =>
    firstDefined(order?.restaurant?.logo, order?.groceryStore?.logo, order?.pharmacyStore?.logo, order?.grabMartStore?.logo) || null;

const getPickupAddress = (order) =>
    firstDefined(order?.restaurant?.address, order?.groceryStore?.address, order?.pharmacyStore?.address, order?.grabMartStore?.address) || 'Unknown';

const getVendorPrepMinutes = (order) => {
    const raw = firstDefined(
        order?.restaurant?.averagePreparationTime,
        order?.groceryStore?.averagePreparationTime,
        order?.pharmacyStore?.averagePreparationTime
    );
    const parsed = Number(raw);
    if (Number.isFinite(parsed) && parsed > 0) {
        return Math.ceil(parsed);
    }
    return CONFIRMED_PREDISPATCH_DEFAULT_PREP_MINUTES;
};

const getPrepBaselineAt = (order) => {
    const candidate = firstDefined(
        order?.preparingAt,
        order?.acceptedAt,
        order?.updatedAt,
        order?.orderDate,
        order?.createdAt
    );
    const date = candidate ? new Date(candidate) : null;
    if (date && !Number.isNaN(date.getTime())) {
        return date;
    }
    return new Date();
};

const estimateTravelMinutesFromDistanceKm = (distanceKm) => {
    const distance = Number(distanceKm);
    if (!Number.isFinite(distance) || distance < 0) return null;
    return Math.max(1, Math.ceil((distance / CONFIRMED_PREDISPATCH_AVG_SPEED_KMPH) * 60));
};

const evaluateConfirmedPredispatch = (order, eligibleRiders) => {
    const validDistances = (eligibleRiders || [])
        .map((rider) => Number(rider?._distanceToPickup))
        .filter((distance) => Number.isFinite(distance) && distance >= 0);

    if (validDistances.length === 0) {
        return {
            shouldDispatch: false,
            reason: 'No eligible riders available',
            nearestRiderDistanceKm: null,
            nearestRiderTravelMinutes: null,
            remainingPrepMinutes: null,
            thresholdMinutes: null,
        };
    }

    const nearestRiderDistanceKm = Math.min(...validDistances);
    const nearestRiderTravelMinutes = estimateTravelMinutesFromDistanceKm(nearestRiderDistanceKm);
    if (!Number.isFinite(nearestRiderTravelMinutes)) {
        return {
            shouldDispatch: false,
            reason: 'Unable to estimate rider travel time',
            nearestRiderDistanceKm,
            nearestRiderTravelMinutes: null,
            remainingPrepMinutes: null,
            thresholdMinutes: null,
        };
    }

    const prepMinutes = getVendorPrepMinutes(order);
    const baselineAt = getPrepBaselineAt(order);
    const elapsedMinutes = Math.max(0, (Date.now() - baselineAt.getTime()) / (60 * 1000));
    const remainingPrepMinutes = Math.max(0, prepMinutes - elapsedMinutes);
    const thresholdMinutes = Math.max(0, remainingPrepMinutes - CONFIRMED_PREDISPATCH_BUFFER_MINUTES);
    const shouldDispatch = nearestRiderTravelMinutes >= thresholdMinutes;

    return {
        shouldDispatch,
        reason: shouldDispatch
            ? 'Dispatch is timely for confirmed order'
            : 'Dispatch deferred until vendor is closer to ready',
        nearestRiderDistanceKm: Number(nearestRiderDistanceKm.toFixed(2)),
        nearestRiderTravelMinutes,
        remainingPrepMinutes: Number(remainingPrepMinutes.toFixed(2)),
        thresholdMinutes: Number(thresholdMinutes.toFixed(2)),
        prepMinutes,
        elapsedMinutes: Number(elapsedMinutes.toFixed(2)),
        bufferMinutes: CONFIRMED_PREDISPATCH_BUFFER_MINUTES,
    };
};

const normalizeAcceptanceRate = (rawRate) => {
    const numeric = Number(rawRate);
    if (!Number.isFinite(numeric) || numeric < 0) return 0.5;
    if (numeric > 1) {
        return Math.max(0, Math.min(1, numeric / 100));
    }
    return Math.max(0, Math.min(1, numeric));
};

const buildOnTimeStatsMap = async (riderIds, minDeliveries = 20) => {
    if (!Array.isArray(riderIds) || riderIds.length === 0) {
        return new Map();
    }

    const normalizedRiderIds = riderIds.map((id) => String(id));

    try {
        const DeliveryAnalytics = require('../models/DeliveryAnalytics');
        const rows = await DeliveryAnalytics.aggregate([
            {
                $match: {
                    riderId: { $in: normalizedRiderIds },
                    wasOnTime: { $ne: null },
                },
            },
            {
                $group: {
                    _id: '$riderId',
                    totalDeliveries: { $sum: 1 },
                    onTimeCount: {
                        $sum: {
                            $cond: ['$wasOnTime', 1, 0],
                        },
                    },
                },
            },
        ]);

        const result = new Map();
        for (const row of rows) {
            const totalDeliveries = Number(row?.totalDeliveries || 0);
            const onTimeCount = Number(row?.onTimeCount || 0);
            const onTimeRate = totalDeliveries > 0
                ? Math.round((onTimeCount / totalDeliveries) * 100)
                : 100;
            result.set(String(row?._id), {
                onTimeRate,
                totalDeliveries,
                onTimeCount,
                isReliable: totalDeliveries >= minDeliveries,
            });
        }

        return result;
    } catch (error) {
        console.error('[Dispatch] Failed to load rider on-time analytics:', error.message);
        return new Map();
    }
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
                restaurant: { select: { restaurantName: true, logo: true, address: true, latitude: true, longitude: true, averagePreparationTime: true } },
                groceryStore: { select: { storeName: true, logo: true, address: true, latitude: true, longitude: true, averagePreparationTime: true } },
                pharmacyStore: { select: { storeName: true, logo: true, address: true, latitude: true, longitude: true, averagePreparationTime: true } },
                grabMartStore: { select: { storeName: true, logo: true, address: true, latitude: true, longitude: true } },
                items: { select: { id: true, name: true, quantity: true, price: true } }
            }
        });

        if (!order) {
            console.log(`❌ [Dispatch] Order not found: ${orderId}`);
            return { success: false, error: 'Order not found' };
        }

        if (order.fulfillmentMode === 'pickup') {
            console.log(`⛔ [Dispatch] Skipping pickup order: ${orderId}`);
            return { success: false, error: 'Pickup orders are not dispatchable' };
        }

        // Check if order already has a rider
        if (order.riderId) {
            console.log(`⚠️ [Dispatch] Order already has rider: ${order.riderId}`);
            return { success: false, error: 'Order already assigned to a rider' };
        }

        // Check if order payment is confirmed
        if (!DISPATCHABLE_PAYMENT_STATUSES.has(order.paymentStatus)) {
            console.log(`⚠️ [Dispatch] Order payment not dispatchable: ${order.paymentStatus}`);
            return { success: false, error: `Order payment status "${order.paymentStatus}" is not dispatchable` };
        }

        // Check if order is in dispatchable status
        const isCodOrder = order.paymentMethod === 'cash';
        const isConfirmedPredispatch =
            order.status === 'confirmed' &&
            featureFlags.isConfirmedPredispatchEnabled &&
            !isCodOrder;
        if (!DISPATCHABLE_STATUSES.has(order.status) && !isConfirmedPredispatch) {
            console.log(`⚠️ [Dispatch] Order status not dispatchable: ${order.status}`);
            return { success: false, error: `Order status "${order.status}" is not dispatchable` };
        }
        if (isCodOrder && order.status === 'confirmed') {
            console.log(`⏳ [Dispatch] COD order ${order.orderNumber} waiting for vendor prep before dispatch`);
            return { success: false, error: 'COD order not dispatchable at confirmed status' };
        }

        // 2. Check for existing active reservation
        const existingReservation = await OrderReservation.getActiveForOrder(orderId, ORDER_RESERVATION_ENTITY);
        if (existingReservation) {
            console.log(`⚠️ [Dispatch] Order already has active reservation for rider: ${existingReservation.riderId}`);
            return { 
                success: false, 
                error: 'Order already has active reservation',
                reservation: existingReservation
            };
        }

        // 3. Get previous attempts for this order
        const previousAttempts = await OrderReservation.find(
            buildOrderReservationQuery({ orderId })
        ).sort({ attemptNumber: -1 }).limit(1);
        const attemptNumber = previousAttempts.length > 0 ? previousAttempts[0].attemptNumber + 1 : 1;

        if (attemptNumber > CONFIG.MAX_ATTEMPTS) {
            console.log(`❌ [Dispatch] Max attempts reached for order: ${orderId}`);
            return { success: false, error: 'Max dispatch attempts reached', attemptNumber };
        }

        // Get list of riders who already declined/expired for this order
        const excludedRiderIds = await OrderReservation.find(
            buildOrderReservationQuery({
                orderId,
                status: { $in: ['declined', 'expired'] }
            })
        ).distinct('riderId');

        // 4. Find eligible riders
        const eligibleRiders = await findEligibleRiders(order, excludedRiderIds);
        
        if (eligibleRiders.length === 0) {
            console.log(`❌ [Dispatch] No eligible riders found for order: ${orderId}`);
            return { success: false, error: 'No eligible riders available' };
        }

        console.log(`📊 [Dispatch] Found ${eligibleRiders.length} eligible riders`);

        if (isConfirmedPredispatch) {
            const decision = evaluateConfirmedPredispatch(order, eligibleRiders);
            if (!decision.shouldDispatch) {
                console.log(
                    `⏳ [Dispatch] Predispatch deferred for order ${order.orderNumber}: ${decision.reason} ` +
                    `(nearest=${decision.nearestRiderTravelMinutes ?? 'n/a'}m, remainingPrep=${decision.remainingPrepMinutes ?? 'n/a'}m, threshold=${decision.thresholdMinutes ?? 'n/a'}m)`
                );
                return {
                    success: false,
                    error: decision.reason,
                    code: 'PREDISPATCH_DEFERRED',
                    meta: decision,
                };
            }
            console.log(
                `🚦 [Dispatch] Predispatch allowed for order ${order.orderNumber} ` +
                `(nearest=${decision.nearestRiderTravelMinutes}m, remainingPrep=${decision.remainingPrepMinutes}m, threshold=${decision.thresholdMinutes}m)`
            );
        }

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
    const pickupLocation = getPickupLocation(order);
    const pickupLat = pickupLocation.latitude;
    const pickupLon = pickupLocation.longitude;

    if (!pickupLat || !pickupLon) {
        console.log('⚠️ [Dispatch] No pickup coordinates available');
        return [];
    }

    // Get riders who have active reservations already (to exclude)
    const ridersWithActiveReservations = await OrderReservation.find(
        buildOrderReservationQuery({
            status: 'pending',
            expiresAt: { $gt: new Date() }
        })
    ).distinct('riderId');

    // Combine excluded IDs
    const allExcludedIds = [...new Set([...excludedRiderIds, ...ridersWithActiveReservations])];

    // Find online, available riders from MongoDB RiderStatus
    let radius = CONFIG.DEFAULT_RADIUS_KM;
    let eligibleRiders = [];

    const mapRiderStatusesToEligible = async (riderStatuses) => {
        const riderIds = riderStatuses.map((status) => String(status.riderId));
        const riderUsers = riderIds.length > 0
            ? await prisma.user.findMany({
                where: { id: { in: riderIds } },
                select: {
                    id: true,
                    username: true,
                    email: true,
                    phone: true,
                    profilePicture: true,
                    rider: {
                        select: {
                            vehicleType: true,
                            verificationStatus: true,
                        },
                    },
                },
            })
            : [];
        const riderById = new Map(riderUsers.map((user) => [user.id, user]));

        // Build eligible riders from batched user fetch + Mongo rider status
        const mapped = [];
        for (const status of riderStatuses) {
            const riderId = String(status.riderId);
            const user = riderById.get(riderId);

            if (user && user.rider?.verificationStatus === 'approved') {
                // Calculate distance to pickup for scoring and ETA estimation.
                const distance = status.distanceTo(pickupLon, pickupLat);

                mapped.push({
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

        return mapped;
    };

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

        eligibleRiders = await mapRiderStatusesToEligible(riderStatuses);

        if (eligibleRiders.length < CONFIG.MIN_RIDERS_BEFORE_EXPAND) {
            radius += CONFIG.RADIUS_EXPANSION_KM;
            console.log(`📍 [Dispatch] Expanding radius to ${radius}km (found ${eligibleRiders.length} riders)`);
        }
    }

    if (eligibleRiders.length === 0 && featureFlags.isDispatchGeoFallbackEnabled) {
        console.log('🧪 [Dispatch] Geo fallback enabled - retrying without distance constraint');

        const fallbackStatuses = await RiderStatus.find({
            isOnline: true,
            isOnDelivery: false,
            isApproved: true,
            riderId: { $nin: allExcludedIds },
        })
            .sort({ lastActiveAt: -1 })
            .limit(20);

        eligibleRiders = await mapRiderStatusesToEligible(fallbackStatuses);
        console.log(`🧪 [Dispatch] Geo fallback found ${eligibleRiders.length} eligible riders`);
    }

    return eligibleRiders;
}

/**
 * Score riders based on multiple factors
 */
async function scoreRiders(riders, order) {
    if (!Array.isArray(riders) || riders.length === 0) {
        return [];
    }

    const scoredRiders = [];
    const riderIds = riders.map((rider) => String(rider.id)).filter(Boolean);

    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);

    const [declineIdsRaw, recentDeliveryRows, onTimeStatsByRider] = await Promise.all([
        OrderReservation.find(
            buildOrderReservationQuery({
                riderId: { $in: riderIds },
                status: 'declined',
                respondedAt: { $gte: fiveMinutesAgo },
            })
        ).distinct('riderId').catch((error) => {
            console.error('[Dispatch] Failed to fetch recent rider declines:', error.message);
            return [];
        }),
        prisma.order.findMany({
            where: {
                riderId: { in: riderIds },
                status: 'delivered',
                deliveredDate: { gte: thirtyMinutesAgo },
            },
            select: { riderId: true },
            distinct: ['riderId'],
        }).catch((error) => {
            console.error('[Dispatch] Failed to fetch recent delivered orders for scoring:', error.message);
            return [];
        }),
        buildOnTimeStatsMap(riderIds, 20).catch((error) => {
            console.error('[Dispatch] Failed to build on-time stats map:', error.message);
            return new Map();
        }),
    ]);

    const recentDeclineIds = new Set((declineIdsRaw || []).map((id) => String(id)));
    const recentDeliveryIds = new Set(
        (recentDeliveryRows || []).map((row) => String(row.riderId)).filter(Boolean)
    );

    for (const rider of riders) {
        const riderId = String(rider.id);
        let score = 0;

        // 1) Pickup ETA is the dominant term to prioritize fast deliveries.
        const distanceToPickup = rider._distanceToPickup || 0;
        const pickupEtaMinutes = estimateTravelMinutesFromDistanceKm(distanceToPickup) || 60;
        const etaScore = Math.max(-120, 120 - pickupEtaMinutes * 8);
        score += etaScore;
        // Keep a small tie-breaker for actual distance.
        score += distanceToPickup * -1;

        // 2) Service quality modifiers (smaller than ETA impact).
        const rating = rider.riderRating || 4.0;
        if (rating > 4.0) {
            score += (rating - 4.0) * SCORING.RATING_BONUS;
        }

        const acceptanceRate = normalizeAcceptanceRate(rider.riderAcceptanceRate);
        score += acceptanceRate * SCORING.ACCEPTANCE_RATE_WEIGHT;

        const recentDecline = recentDeclineIds.has(riderId);
        if (recentDecline) {
            score += SCORING.RECENT_DECLINE_PENALTY;
        }

        // 3) Preference / activity bonuses.
        const orderType = order.orderType || 'food';
        const preferredTypes = rider.riderPreferredOrderTypes || [];
        if (preferredTypes.includes(orderType)) {
            score += SCORING.ORDER_TYPE_MATCH_BONUS;
        }

        const recentDelivery = recentDeliveryIds.has(riderId);
        if (recentDelivery) {
            score += SCORING.RECENT_DELIVERY_BONUS;
        }

        // 4) Fairness (small bonus).
        const todayEarnings = rider._status?.metrics?.todayEarnings || 0;
        if (todayEarnings < 50) {
            score += SCORING.LOW_EARNINGS_TODAY_BONUS;
        }

        // 5) Operational risk controls.
        const batteryLevel = rider._status?.batteryLevel ?? 100;
        const isCharging = rider._status?.isCharging || false;
        let batteryPenalty = 0;
        
        if (batteryLevel < 10) {
            // Critical battery - high risk of not completing delivery
            batteryPenalty = SCORING.CRITICAL_BATTERY_PENALTY;
        } else if (batteryLevel < 20) {
            // Low battery - some risk
            batteryPenalty = SCORING.LOW_BATTERY_PENALTY;
        }
        
        // If charging, reduce penalty and add bonus
        if (isCharging) {
            batteryPenalty = Math.round(batteryPenalty / 2); // Half penalty if charging
            score += SCORING.CHARGING_BONUS;
        }
        score += batteryPenalty;

        // 6) Vehicle fit.
        const vehicleType = rider._status?.vehicleType || null;
        const deliveryDistance = order.deliveryDistance || distanceToPickup * 2; // Estimate if not provided
        const orderItemCount = Array.isArray(order?.items) ? order.items.length : 1;
        let vehicleBonus = 0;
        
        if (vehicleType) {
            // Long distance orders (> 5km) - prefer motorized vehicles
            if (deliveryDistance > 5) {
                if (['motorcycle', 'car', 'scooter'].includes(vehicleType)) {
                    vehicleBonus += SCORING.VEHICLE_LONG_DISTANCE_BONUS;
                }
            }
            
            // Large orders (many items) - prefer vehicles with more capacity
            if (orderItemCount >= 5) {
                if (['car', 'scooter'].includes(vehicleType)) {
                    vehicleBonus += SCORING.VEHICLE_LARGE_ORDER_BONUS;
                }
            }
            
            // Short distance orders (< 2km) - bicycles can be faster (no traffic, parking)
            if (deliveryDistance <= 2 && vehicleType === 'bicycle') {
                vehicleBonus += SCORING.BICYCLE_SHORT_DISTANCE_BONUS;
            }
        }
        score += vehicleBonus;

        // 7) On-time performance from one batched analytics query.
        let onTimeBonus = 0;
        let onTimeRate = 100;
        let onTimeReliable = false;

        const performanceStats = onTimeStatsByRider.get(riderId);
        if (performanceStats) {
            onTimeRate = performanceStats.onTimeRate;
            onTimeReliable = performanceStats.isReliable;
            if (performanceStats.isReliable) {
                if (onTimeRate >= 90) {
                    onTimeBonus = SCORING.ON_TIME_BONUS;
                } else if (onTimeRate >= 80) {
                    onTimeBonus = SCORING.GOOD_ON_TIME_BONUS;
                } else if (onTimeRate < 70) {
                    onTimeBonus = SCORING.LOW_ON_TIME_PENALTY;
                }
            }
        }
        score += onTimeBonus;

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
                lowEarningsToday: todayEarnings < 50,
                batteryLevel,
                isCharging,
                batteryPenalty,
                pickupEtaMinutes,
                etaScore,
                vehicleType,
                vehicleBonus,
                onTimeRate,
                onTimeBonus,
                onTimeReliable
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
    const storeName = getStoreName(order);
    const storeLogo = getStoreLogo(order);
    const pickupAddress = getPickupAddress(order);
    const pickupLocation = getPickupLocation(order);
    const pickupLat = pickupLocation.latitude;
    const pickupLon = pickupLocation.longitude;

    const reservation = new OrderReservation({
        entityType: ORDER_RESERVATION_ENTITY,
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
    const history = await OrderReservation.find(
        buildOrderReservationQuery({
            riderId,
            status: { $in: ['accepted', 'declined'] },
            respondedAt: { $ne: null }
        })
    )
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

    if (reservation.entityType && reservation.entityType !== ORDER_RESERVATION_ENTITY) {
        return { success: false, error: 'Unsupported reservation entity for this flow' };
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

    if (reservation.entityType && reservation.entityType !== ORDER_RESERVATION_ENTITY) {
        return { success: false, error: 'Unsupported reservation entity for this flow' };
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

    const expired = await OrderReservation.findExpired(ORDER_RESERVATION_ENTITY);
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
 * Update rider's acceptance rate in MongoDB RiderStatus
 */
async function updateRiderAcceptanceRate(riderId, accepted) {
    try {
        // Get rider's last 50 reservations
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
        const acceptanceRate = (acceptedCount / history.length) * 100; // Store as percentage 0-100

        // Update MongoDB RiderStatus instead of Prisma User
        await RiderStatus.findOneAndUpdate(
            { riderId },
            { $set: { 'metrics.acceptanceRate': acceptanceRate } }
        );

        console.log(`📊 [Dispatch] Updated acceptance rate for rider ${riderId}: ${acceptanceRate.toFixed(1)}%`);
    } catch (error) {
        console.error(`⚠️ [Dispatch] Error updating acceptance rate for rider ${riderId}:`, error.message);
    }
}

/**
 * Get active reservation for a rider (used by rider app)
 */
async function getActiveReservationForRider(riderId) {
    return OrderReservation.getActiveForRider(riderId, ORDER_RESERVATION_ENTITY);
}

/**
 * Cancel all reservations for an order (e.g., when customer cancels)
 */
async function cancelOrderReservations(orderId) {
    const reservations = await OrderReservation.find(
        buildOrderReservationQuery({
            orderId,
            status: 'pending'
        })
    );

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
