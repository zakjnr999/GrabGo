const mongoose = require('mongoose');

const orderTrackingHistorySchema = new mongoose.Schema({
    trackingId: {
        type: String, // References PostgreSQL OrderTracking ID
        required: true,
        index: true
    },
    orderId: {
        type: String, // References PostgreSQL Order ID
        required: true,
        index: true
    },
    latitude: {
        type: Number,
        required: true
    },
    longitude: {
        type: Number,
        required: true
    },
    speed: Number,
    accuracy: Number,
    timestamp: {
        type: Date,
        default: Date.now
    }
});

orderTrackingHistorySchema.index({ timestamp: 1 });

module.exports = mongoose.model('OrderTrackingHistory', orderTrackingHistorySchema);
