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
    initialETA: Number,
    actualDeliveryTime: Number,
    etaAccuracy: Number, // percentage

    // Performance metrics
    averageSpeed: Number,
    stopsCount: Number,
    routeDeviation: Number, // how much rider deviated from optimal route

    // Location data
    locationUpdatesCount: Number,
    averageUpdateInterval: Number,

    createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('DeliveryAnalytics', deliveryAnalyticsSchema);
