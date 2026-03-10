const { calculateDistance } = require('./distance');

/**
 * Validate and sanitize location parameters
 * @param {string|number} userLat - User latitude
 * @param {string|number} userLng - User longitude
 * @param {string|number} maxDistance - Maximum distance (default: 15)
 * @returns {Object|null} {userLatitude, userLongitude, maxDistanceKm} or null if invalid
 */
function validateLocationParams(userLat, userLng, maxDistance = 15) {
    const hasLat = userLat !== undefined && userLat !== null && userLat !== '';
    const hasLng = userLng !== undefined && userLng !== null && userLng !== '';
    const userLatitude = hasLat ? parseFloat(userLat) : null;
    const userLongitude = hasLng ? parseFloat(userLng) : null;
    let maxDistanceKm = parseFloat(maxDistance);

    // Check if coordinates are valid numbers
    if (userLatitude === null || userLongitude === null || isNaN(userLatitude) || isNaN(userLongitude)) {
        return null; // Invalid or missing coordinates
    }

    // Validate coordinate ranges
    if (userLatitude < -90 || userLatitude > 90 || userLongitude < -180 || userLongitude > 180) {
        return null; // Out of valid range
    }

    // Validate and sanitize maxDistance
    if (isNaN(maxDistanceKm) || maxDistanceKm <= 0) {
        maxDistanceKm = 15; // Default to 15km
    }

    // Cap maximum distance to reasonable limit (100km)
    maxDistanceKm = Math.min(maxDistanceKm, 100);

    return { userLatitude, userLongitude, maxDistanceKm };
}

/**
 * Filter vendors by distance from user location
 * @param {Array} vendors - Array of vendor objects with latitude/longitude
 * @param {number} userLat - User latitude
 * @param {number} userLng - User longitude
 * @param {number} maxDistanceKm - Maximum distance in kilometers (default: 15)
 * @returns {Array} Filtered vendors within distance, with distance property added
 */
function filterVendorsByDistance(vendors, userLat, userLng, maxDistanceKm = 15) {
    if (userLat === undefined || userLat === null || userLng === undefined || userLng === null || isNaN(userLat) || isNaN(userLng)) {
        // No user location provided - return all vendors
        return vendors;
    }

    const vendorsWithDistance = vendors
        .map(vendor => {
            if (!vendor.latitude || !vendor.longitude) {
                return null; // Skip vendors without coordinates
            }

            const distance = calculateDistance(
                vendor.latitude,
                vendor.longitude,
                userLat,
                userLng
            );

            return {
                ...vendor,
                _distance: distance // Add distance for sorting/debugging
            };
        })
        .filter(vendor => vendor !== null && vendor._distance <= maxDistanceKm);

    // Sort by distance (closest first)
    vendorsWithDistance.sort((a, b) => a._distance - b._distance);

    return vendorsWithDistance;
}

/**
 * Get bounding box for quick pre-filtering
 * Approximation: 1 degree ≈ 111km
 * @param {number} lat - Center latitude
 * @param {number} lng - Center longitude
 * @param {number} distanceKm - Distance in kilometers
 * @returns {Object} Bounding box {minLat, maxLat, minLng, maxLng}
 */
function getBoundingBox(lat, lng, distanceKm) {
    // Validate inputs
    if (isNaN(lat) || isNaN(lng) || isNaN(distanceKm)) {
        throw new Error('Invalid coordinates or distance');
    }

    // Clamp latitude to valid range
    lat = Math.max(-90, Math.min(90, lat));

    // Normalize longitude to -180 to 180 range
    lng = ((lng + 180) % 360) - 180;

    const latDelta = distanceKm / 111.0;

    // Prevent division by zero and extreme values near poles
    // At latitudes > 85° or < -85°, use a simplified calculation
    let lngDelta;
    if (Math.abs(lat) > 85) {
        // Near poles, use a large longitude delta (essentially search all longitudes)
        lngDelta = 180;
    } else {
        lngDelta = distanceKm / (111.0 * Math.cos(lat * Math.PI / 180));
        // Cap longitude delta to prevent wrapping issues
        lngDelta = Math.min(lngDelta, 180);
    }

    return {
        minLat: Math.max(-90, lat - latDelta),
        maxLat: Math.min(90, lat + latDelta),
        minLng: Math.max(-180, lng - lngDelta),
        maxLng: Math.min(180, lng + lngDelta)
    };
}

module.exports = {
    validateLocationParams,
    filterVendorsByDistance,
    getBoundingBox
};
