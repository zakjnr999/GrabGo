/**
 * Utility functions for restaurant operations
 */

/**
 * Check if a restaurant is currently open based on hours
 * @param {Object} restaurant - Restaurant object with openingHours relation
 * @returns {boolean} - True if restaurant is open
 */
function isRestaurantOpen(restaurant) {
    // If restaurant manually set to closed, return false
    if (!restaurant.isOpen) {
        return false;
    }

    // If no hours defined, assume open (fallback to isOpen field)
    if (!restaurant.openingHours || restaurant.openingHours.length === 0) {
        return restaurant.isOpen;
    }

    const now = new Date();
    const dayOfWeek = now.getDay(); // 0 = Sunday, 1 = Monday, etc.
    const currentTime = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;

    // Find today's hours
    const todayHours = restaurant.openingHours.find(h => h.dayOfWeek === dayOfWeek);

    // If no hours for today or marked as closed, restaurant is closed
    if (!todayHours || todayHours.isClosed) {
        return false;
    }

    // Check if current time is within open hours
    const { openTime, closeTime } = todayHours;

    // Handle cases where closing time is past midnight (e.g., 02:00)
    if (closeTime < openTime) {
        // Restaurant is open past midnight
        return currentTime >= openTime || currentTime < closeTime;
    }

    // Normal case: open and close on same day
    return currentTime >= openTime && currentTime < closeTime;
}

/**
 * Get restaurant status text
 * @param {Object} restaurant - Restaurant object with openingHours relation
 * @returns {string} - Status text like "Open now", "Closed", "Opens at 09:00"
 */
function getRestaurantStatus(restaurant) {
    if (!restaurant.isOpen) {
        return "Closed";
    }

    if (!restaurant.openingHours || restaurant.openingHours.length === 0) {
        return restaurant.isOpen ? "Open now" : "Closed";
    }

    const now = new Date();
    const dayOfWeek = now.getDay();
    const currentTime = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;

    const todayHours = restaurant.openingHours.find(h => h.dayOfWeek === dayOfWeek);

    if (!todayHours || todayHours.isClosed) {
        // Find next open day
        for (let i = 1; i <= 7; i++) {
            const nextDay = (dayOfWeek + i) % 7;
            const nextDayHours = restaurant.openingHours.find(h => h.dayOfWeek === nextDay);
            if (nextDayHours && !nextDayHours.isClosed) {
                const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
                return `Opens ${i === 1 ? 'tomorrow' : days[nextDay]} at ${nextDayHours.openTime}`;
            }
        }
        return "Closed";
    }

    const { openTime, closeTime } = todayHours;

    // Check if currently open
    let isOpen = false;
    if (closeTime < openTime) {
        isOpen = currentTime >= openTime || currentTime < closeTime;
    } else {
        isOpen = currentTime >= openTime && currentTime < closeTime;
    }

    if (isOpen) {
        return `Open until ${closeTime}`;
    } else if (currentTime < openTime) {
        return `Opens at ${openTime}`;
    } else {
        // Already closed for today, find next open day
        for (let i = 1; i <= 7; i++) {
            const nextDay = (dayOfWeek + i) % 7;
            const nextDayHours = restaurant.openingHours.find(h => h.dayOfWeek === nextDay);
            if (nextDayHours && !nextDayHours.isClosed) {
                const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
                return `Opens ${i === 1 ? 'tomorrow' : days[nextDay]} at ${nextDayHours.openTime}`;
            }
        }
        return "Closed";
    }
}

module.exports = {
    isRestaurantOpen,
    getRestaurantStatus
};
