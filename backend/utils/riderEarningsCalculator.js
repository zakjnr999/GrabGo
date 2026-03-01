/**
 * Rider Earnings Calculator
 * 
 * Calculates fair rider compensation based on:
 * - Base fee
 * - Distance traveled
 * - Customer tips
 * - Platform commission
 */

// Configuration (can be moved to .env later)
const RIDER_BASE_FEE = 5.0; // GHS - Base fee for any delivery
const RATE_PER_KM = 2.0; // GHS - Rate per kilometer
const PLATFORM_COMMISSION_RATE = 0.15; // 15% platform fee

/**
 * Calculate distance between two coordinates using Haversine formula
 * @param {number} lat1 - Pickup latitude
 * @param {number} lon1 - Pickup longitude
 * @param {number} lat2 - Delivery latitude
 * @param {number} lon2 - Delivery longitude
 * @returns {number} Distance in kilometers
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
    if (!lat1 || !lon1 || !lat2 || !lon2) {
        return 0;
    }

    const R = 6371; // Radius of the Earth in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;

    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const distance = R * c;

    return Math.round(distance * 10) / 10; // Round to 1 decimal place
}

/**
 * Calculate rider earnings for an order
 * @param {Object} order - Order object with coordinates
 * @param {number} tip - Customer tip amount (default 0)
 * @returns {Object} Earnings breakdown
 */
function calculateRiderEarnings(order, tip = 0) {
    // Extract coordinates
    const pickupLat =
        order.restaurant?.latitude ??
        order.groceryStore?.latitude ??
        order.pharmacyStore?.latitude ??
        order.grabMartStore?.latitude;
    const pickupLon =
        order.restaurant?.longitude ??
        order.groceryStore?.longitude ??
        order.pharmacyStore?.longitude ??
        order.grabMartStore?.longitude;
    const deliveryLat = order.deliveryLatitude;
    const deliveryLon = order.deliveryLongitude;

    // Debug logging
    console.log('🧮 Calculating earnings for order:', order.orderNumber || order.id);
    console.log('  Pickup coords:', { lat: pickupLat, lon: pickupLon });
    console.log('  Delivery coords:', { lat: deliveryLat, lon: deliveryLon });

    // Calculate distance
    const distance = calculateDistance(pickupLat, pickupLon, deliveryLat, deliveryLon);
    console.log('  Distance calculated:', distance, 'km');

    // Calculate fees
    const baseFee = RIDER_BASE_FEE;
    const distanceFee = distance * RATE_PER_KM;
    const grossEarnings = baseFee + distanceFee + tip;
    const platformFee = grossEarnings * PLATFORM_COMMISSION_RATE;
    const netEarnings = grossEarnings - platformFee;

    console.log('  Earnings breakdown:', {
        baseFee,
        distanceFee,
        tip,
        platformFee,
        netEarnings
    });

    return {
        distance: distance,
        riderBaseFee: baseFee,
        riderDistanceFee: parseFloat(distanceFee.toFixed(2)),
        riderTip: tip,
        platformFee: parseFloat(platformFee.toFixed(2)),
        riderEarnings: parseFloat(netEarnings.toFixed(2)),
        breakdown: {
            baseFee: `GHS ${baseFee.toFixed(2)}`,
            distanceFee: `GHS ${distanceFee.toFixed(2)} (${distance} km × GHS ${RATE_PER_KM}/km)`,
            tip: tip > 0 ? `GHS ${tip.toFixed(2)}` : 'No tip',
            platformFee: `GHS ${platformFee.toFixed(2)} (${(PLATFORM_COMMISSION_RATE * 100).toFixed(0)}% commission)`,
            total: `GHS ${netEarnings.toFixed(2)}`
        }
    };
}

/**
 * Calculate rider earnings for one parcel leg using provided pricing parameters.
 * @param {number} distanceKm
 * @param {Object} options
 * @param {number} options.baseFee
 * @param {number} options.ratePerKm
 * @param {number} options.platformCommissionRate
 * @returns {Object}
 */
function calculateParcelLegEarnings(
    distanceKm,
    {
        baseFee = RIDER_BASE_FEE,
        ratePerKm = RATE_PER_KM,
        platformCommissionRate = PLATFORM_COMMISSION_RATE,
    } = {}
) {
    const safeDistance = Number.isFinite(distanceKm) && distanceKm > 0 ? distanceKm : 0;
    const gross = baseFee + safeDistance * ratePerKm;
    const platformFee = gross * platformCommissionRate;
    const net = gross - platformFee;

    return {
        distanceKm: parseFloat(safeDistance.toFixed(2)),
        baseFee: parseFloat(baseFee.toFixed(2)),
        distanceFee: parseFloat((safeDistance * ratePerKm).toFixed(2)),
        platformFee: parseFloat(platformFee.toFixed(2)),
        riderEarnings: parseFloat(net.toFixed(2)),
    };
}

/**
 * Calculate rider earnings for parcel flow with optional return-to-sender leg.
 * totalRiderEarnings = originalTripEarning + returnTripEarning
 * @param {Object} params
 * @param {number} params.originalDistanceKm
 * @param {number} params.returnDistanceKm
 * @param {Object} options
 * @returns {Object}
 */
function calculateParcelRoundTripEarnings(
    { originalDistanceKm, returnDistanceKm = 0 },
    options = {}
) {
    const originalTrip = calculateParcelLegEarnings(originalDistanceKm, options);
    const returnTrip = calculateParcelLegEarnings(returnDistanceKm, options);
    return {
        originalTripEarning: originalTrip.riderEarnings,
        returnTripEarning: returnTrip.riderEarnings,
        totalRiderEarnings: parseFloat((originalTrip.riderEarnings + returnTrip.riderEarnings).toFixed(2)),
        breakdown: {
            originalTrip,
            returnTrip,
        },
    };
}

module.exports = {
    calculateRiderEarnings,
    calculateParcelLegEarnings,
    calculateParcelRoundTripEarnings,
    calculateDistance,
    RIDER_BASE_FEE,
    RATE_PER_KM,
    PLATFORM_COMMISSION_RATE
};
