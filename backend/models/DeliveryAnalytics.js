const mongoose = require('mongoose');

const deliveryAnalyticsSchema = new mongoose.Schema({
    orderId: { type: String, required: true, index: true }, // References PostgreSQL Order ID
    riderId: { type: String, required: true, index: true }, // References PostgreSQL User ID

    // Time metrics
    pickupTime: Date,
    deliveryTime: Date,
    totalDuration: Number, // in seconds

    // Distance metrics
    totalDistance: Number, // in meters
    straightLineDistance: Number,

    // ETA accuracy
    initialETA: Number, // Initial estimated time in seconds
    actualDeliveryTime: Number, // Actual time from assignment to delivery in seconds
    etaAccuracy: Number, // percentage (100% = perfect, >100 = faster, <100 = slower)

    // On-time tracking
    deliveryWindowMin: Number, // Expected min delivery time in minutes
    deliveryWindowMax: Number, // Expected max delivery time in minutes
    wasOnTime: Boolean, // Did rider deliver within window?
    minutesLate: Number, // If late, how many minutes late? (null if on time)

    // Performance metrics
    averageSpeed: Number,
    stopsCount: Number,
    routeDeviation: Number, // how much rider deviated from optimal route

    // Location data
    locationUpdatesCount: Number,
    averageUpdateInterval: Number,

    createdAt: { type: Date, default: Date.now }
});

// Index for rider performance queries
deliveryAnalyticsSchema.index({ riderId: 1, createdAt: -1 });
deliveryAnalyticsSchema.index({ riderId: 1, wasOnTime: 1 });

/**
 * Calculate rider's on-time rate
 * @param {string} riderId 
 * @param {number} minDeliveries - Minimum deliveries required for valid rate
 * @returns {Object} { onTimeRate, totalDeliveries, onTimeCount, isReliable }
 */
deliveryAnalyticsSchema.statics.getRiderOnTimeRate = async function(riderId, minDeliveries = 20) {
    const stats = await this.aggregate([
        { $match: { riderId, wasOnTime: { $ne: null } } },
        {
            $group: {
                _id: '$riderId',
                totalDeliveries: { $sum: 1 },
                onTimeCount: { $sum: { $cond: ['$wasOnTime', 1, 0] } },
                avgMinutesLate: { $avg: { $cond: ['$wasOnTime', 0, '$minutesLate'] } },
                avgEtaAccuracy: { $avg: '$etaAccuracy' }
            }
        }
    ]);

    if (stats.length === 0) {
        return {
            onTimeRate: 100, // Default for new riders
            totalDeliveries: 0,
            onTimeCount: 0,
            avgMinutesLate: 0,
            avgEtaAccuracy: 100,
            isReliable: false // Not enough data
        };
    }

    const { totalDeliveries, onTimeCount, avgMinutesLate, avgEtaAccuracy } = stats[0];
    const onTimeRate = Math.round((onTimeCount / totalDeliveries) * 100);

    return {
        onTimeRate,
        totalDeliveries,
        onTimeCount,
        avgMinutesLate: Math.round(avgMinutesLate || 0),
        avgEtaAccuracy: Math.round(avgEtaAccuracy || 100),
        isReliable: totalDeliveries >= minDeliveries
    };
};

/**
 * Get rider performance summary for last N days
 */
deliveryAnalyticsSchema.statics.getRiderPerformanceSummary = async function(riderId, days = 30) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const stats = await this.aggregate([
        { 
            $match: { 
                riderId, 
                createdAt: { $gte: startDate },
                wasOnTime: { $ne: null }
            } 
        },
        {
            $group: {
                _id: '$riderId',
                totalDeliveries: { $sum: 1 },
                onTimeCount: { $sum: { $cond: ['$wasOnTime', 1, 0] } },
                lateCount: { $sum: { $cond: ['$wasOnTime', 0, 1] } },
                avgDeliveryTime: { $avg: '$actualDeliveryTime' },
                avgDistance: { $avg: '$totalDistance' },
                avgEtaAccuracy: { $avg: '$etaAccuracy' },
                totalDistance: { $sum: '$totalDistance' }
            }
        }
    ]);

    if (stats.length === 0) {
        return {
            totalDeliveries: 0,
            onTimeRate: 100,
            onTimeCount: 0,
            lateCount: 0,
            avgDeliveryTimeMinutes: 0,
            avgDistanceKm: 0,
            avgEtaAccuracy: 100,
            totalDistanceKm: 0,
            performanceRating: 'new' // new, excellent, good, average, needs_improvement
        };
    }

    const s = stats[0];
    const onTimeRate = Math.round((s.onTimeCount / s.totalDeliveries) * 100);

    // Determine performance rating
    let performanceRating;
    if (s.totalDeliveries < 20) {
        performanceRating = 'new';
    } else if (onTimeRate >= 90) {
        performanceRating = 'excellent';
    } else if (onTimeRate >= 80) {
        performanceRating = 'good';
    } else if (onTimeRate >= 70) {
        performanceRating = 'average';
    } else {
        performanceRating = 'needs_improvement';
    }

    return {
        totalDeliveries: s.totalDeliveries,
        onTimeRate,
        onTimeCount: s.onTimeCount,
        lateCount: s.lateCount,
        avgDeliveryTimeMinutes: Math.round((s.avgDeliveryTime || 0) / 60),
        avgDistanceKm: Math.round((s.avgDistance || 0) / 1000 * 10) / 10,
        avgEtaAccuracy: Math.round(s.avgEtaAccuracy || 100),
        totalDistanceKm: Math.round((s.totalDistance || 0) / 1000),
        performanceRating
    };
};

module.exports = mongoose.model('DeliveryAnalytics', deliveryAnalyticsSchema);
