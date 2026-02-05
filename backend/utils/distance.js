/**
 * Distance calculation utilities using Haversine formula
 */

/**
 * Calculate distance between two coordinates in kilometers
 * @param {number} lat1 - Latitude of point 1
 * @param {number} lon1 - Longitude of point 1
 * @param {number} lat2 - Latitude of point 2
 * @param {number} lon2 - Longitude of point 2
 * @returns {number} Distance in kilometers
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth's radius in kilometers

    const dLat = toRadians(lat2 - lat1);
    const dLon = toRadians(lon2 - lon1);

    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);

    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c; // Distance in km
}

/**
 * Convert degrees to radians
 * @param {number} degrees 
 * @returns {number} Radians
 */
function toRadians(degrees) {
    return degrees * (Math.PI / 180);
}

/**
 * Calculate estimated delivery time based on distance
 * @param {number} distanceKm - Distance in kilometers
 * @returns {number} Estimated delivery time in minutes
 */
function estimateDeliveryTime(distanceKm) {
    // Average delivery speed in city: 20 km/h (accounting for traffic, stops, etc.)
    const averageSpeedKmh = 20;

    // Calculate time in minutes
    const timeMinutes = (distanceKm / averageSpeedKmh) * 60;

    // Round up to nearest minute
    const deliveryTime = Math.ceil(timeMinutes);

    // Minimum 10 minutes (for very close distances, rider still needs to pick up, etc.)
    // Maximum 60 minutes (beyond this, we should probably not deliver)
    return Math.max(10, Math.min(60, deliveryTime));
}

/**
 * Format distance for display
 * @param {number} distanceKm - Distance in kilometers
 * @returns {string} Formatted distance string
 */
function formatDistance(distanceKm) {
    if (distanceKm < 1) {
        return `${Math.round(distanceKm * 1000)}m`;
    }
    return `${distanceKm.toFixed(1)}km`;
}

module.exports = {
    calculateDistance,
    estimateDeliveryTime,
    formatDistance
};
