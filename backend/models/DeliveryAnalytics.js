const mongoose = require('mongoose');

const deliveryAnalyticsSchema = new mongoose.Schema({
    orderId: { type: String, required: true }, // References PostgreSQL Order ID
    riderId: { type: String, required: true, index: true }, // References PostgreSQL User ID

    // Order classification (for multi-entity score engine)
    orderType: {
        type: String,
        enum: ['food', 'grocery', 'pharmacy', 'grabmart', 'parcel'],
        default: 'food',
    },

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
    
    // Delay reason tracking (for fair penalty assessment)
    delayReason: { 
        type: String, 
        enum: ['traffic', 'vendor_delay', 'customer_unreachable', 'weather', 'vehicle_issue', 'other', null]
    },
    delayReasonNote: String, // Additional notes for "other" reason
    isRiderFault: Boolean, // true if delay was rider's fault (vehicle_issue, other)

    // Rider earnings (authoritative for score engine volume calculation)
    riderEarnings: {
        type: Number,
        default: 0,
    },

    // Delivery outcome status
    status: {
        type: String,
        enum: ['completed', 'cancelled'],
        default: 'completed',
    },

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
// Compound indexes for partner score engine (rolling 28-day windows)
deliveryAnalyticsSchema.index({ riderId: 1, status: 1, createdAt: -1 });
// Unique on orderId to prevent duplicate analytics entries
deliveryAnalyticsSchema.index({ orderId: 1 }, { unique: true, sparse: true });

/**
 * Calculate rider's on-time rate
 * Excludes non-rider-fault delays for fair assessment (evidence-based exclusion).
 * @param {string} riderId 
 * @param {number} minDeliveries - Minimum deliveries required for valid rate
 * @param {Date} [startDate] - Optional start of window
 * @param {Date} [endDate] - Optional end of window
 * @returns {Object} { onTimeRate, totalDeliveries, onTimeCount, isReliable }
 */
deliveryAnalyticsSchema.statics.getRiderOnTimeRate = async function(riderId, minDeliveries = 20, startDate = null, endDate = null) {
    const match = { riderId, status: 'completed', wasOnTime: { $ne: null } };
    if (startDate || endDate) {
        match.createdAt = {};
        if (startDate) match.createdAt.$gte = startDate;
        if (endDate) match.createdAt.$lte = endDate;
    }

    const stats = await this.aggregate([
        { $match: match },
        {
            $group: {
                _id: '$riderId',
                totalDeliveries: { $sum: 1 },
                onTimeCount: { $sum: { $cond: ['$wasOnTime', 1, 0] } },
                // Count late deliveries that were NOT rider's fault (for fair exclusion)
                nonRiderFaultLate: {
                    $sum: {
                        $cond: [
                            { $and: [
                                { $eq: ['$wasOnTime', false] },
                                { $eq: ['$isRiderFault', false] }
                            ]},
                            1, 0
                        ]
                    }
                },
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

    const { totalDeliveries, onTimeCount, nonRiderFaultLate, avgMinutesLate, avgEtaAccuracy } = stats[0];
    // Fair on-time rate: exclude non-rider-fault late deliveries from denominator
    const fairDenominator = totalDeliveries - nonRiderFaultLate;
    const onTimeRate = fairDenominator > 0
        ? Math.round((onTimeCount / fairDenominator) * 100)
        : 100;

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
 * Get rider performance summary for a date range.
 * Returns all metrics needed by the partner score engine:
 * - completionRate (excluding non-rider-fault cancellations)
 * - onTimeRate (excluding non-rider-fault delays)
 * - deliveryVolume (total completed across all order types)
 * - avgRating + ratingCount (for Bayesian smoothing)
 * - riderFaultCancellations vs nonRiderFaultCancellations
 *
 * @param {string} riderId
 * @param {number|Date} daysOrStartDate - Number of days back, or a start Date
 * @param {Date} [endDate] - Optional end date (defaults to now)
 */
deliveryAnalyticsSchema.statics.getRiderPerformanceSummary = async function(riderId, daysOrStartDate = 30, endDate = null) {
    let startDate;
    if (daysOrStartDate instanceof Date) {
        startDate = daysOrStartDate;
    } else {
        startDate = new Date();
        startDate.setDate(startDate.getDate() - daysOrStartDate);
    }

    const match = {
        riderId,
        createdAt: { $gte: startDate },
    };
    if (endDate) {
        match.createdAt.$lte = endDate;
    }

    const stats = await this.aggregate([
        { $match: match },
        {
            $group: {
                _id: '$status',
                count: { $sum: 1 },
                onTimeCount: {
                    $sum: {
                        $cond: [
                            { $and: [{ $eq: ['$status', 'completed'] }, { $eq: ['$wasOnTime', true] }] },
                            1, 0
                        ]
                    }
                },
                // Non-rider-fault late (for fair on-time calculation)
                nonRiderFaultLate: {
                    $sum: {
                        $cond: [
                            { $and: [
                                { $eq: ['$status', 'completed'] },
                                { $eq: ['$wasOnTime', false] },
                                { $eq: ['$isRiderFault', false] }
                            ]},
                            1, 0
                        ]
                    }
                },
                avgDeliveryTime: { $avg: '$actualDeliveryTime' },
                avgDistance: { $avg: '$totalDistance' },
                totalDistance: { $sum: '$totalDistance' },
                avgEtaAccuracy: { $avg: '$etaAccuracy' },
                totalEarnings: {
                    $sum: { $cond: [{ $eq: ['$status', 'completed'] }, '$riderEarnings', 0] }
                },
                riderFaultCancellations: {
                    $sum: {
                        $cond: [
                            { $and: [{ $eq: ['$status', 'cancelled'] }, { $eq: ['$isRiderFault', true] }] },
                            1, 0
                        ]
                    }
                },
                nonRiderFaultCancellations: {
                    $sum: {
                        $cond: [
                            { $and: [{ $eq: ['$status', 'cancelled'] }, { $ne: ['$isRiderFault', true] }] },
                            1, 0
                        ]
                    }
                },
            }
        }
    ]);

    let completed = 0;
    let cancelled = 0;
    let onTimeCount = 0;
    let nonRiderFaultLate = 0;
    let avgDeliveryTime = 0;
    let avgDistance = 0;
    let totalDistance = 0;
    let avgEtaAccuracy = 100;
    let totalEarnings = 0;
    let riderFaultCancellations = 0;
    let nonRiderFaultCancellations = 0;

    for (const bucket of stats) {
        if (bucket._id === 'completed') {
            completed = bucket.count;
            onTimeCount = bucket.onTimeCount;
            nonRiderFaultLate = bucket.nonRiderFaultLate;
            avgDeliveryTime = bucket.avgDeliveryTime;
            avgDistance = bucket.avgDistance;
            totalDistance = bucket.totalDistance;
            avgEtaAccuracy = bucket.avgEtaAccuracy;
            totalEarnings = bucket.totalEarnings;
        } else if (bucket._id === 'cancelled') {
            cancelled = bucket.count;
            riderFaultCancellations = bucket.riderFaultCancellations;
            nonRiderFaultCancellations = bucket.nonRiderFaultCancellations;
        }
    }

    const totalAssigned = completed + cancelled;

    // Completion rate: exclude non-rider-fault cancellations from denominator
    const completionDenominator = completed + riderFaultCancellations;
    const completionRate = completionDenominator > 0
        ? Math.round((completed / completionDenominator) * 100)
        : 100;

    // Fair on-time rate: exclude non-rider-fault late deliveries
    const fairOnTimeDenominator = completed - nonRiderFaultLate;
    const onTimeRate = fairOnTimeDenominator > 0
        ? Math.round((onTimeCount / fairOnTimeDenominator) * 100)
        : 100;

    // Performance rating
    let performanceRating;
    if (completed < 20) {
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
        completed,
        cancelled,
        totalAssigned,
        onTimeRate,
        onTimeCount,
        lateCount: completed - onTimeCount,
        completionRate,
        totalEarnings: Math.round(totalEarnings * 100) / 100,
        avgDeliveryTimeMinutes: Math.round((avgDeliveryTime || 0) / 60),
        avgDistanceKm: Math.round((avgDistance || 0) / 1000 * 10) / 10,
        avgEtaAccuracy: Math.round(avgEtaAccuracy || 100),
        totalDistanceKm: Math.round((totalDistance || 0) / 1000),
        riderFaultCancellations,
        nonRiderFaultCancellations,
        performanceRating,
    };
};

module.exports = mongoose.model('DeliveryAnalytics', deliveryAnalyticsSchema);
