const mongoose = require('mongoose');

const locationSchema = new mongoose.Schema({
    type: {
        type: String,
        enum: ['Point'],
        default: 'Point'
    },
    coordinates: {
        type: [Number], // [Longitude, latitude]
        required: true
    }
});

const orderTrackingSchema = new mongoose.Schema({
    orderId: {
        type: String, // References PostgreSQL Order ID
        required: true,
        unique: true
    },
    riderId: {
        type: String, // References PostgreSQL User ID
        required: true,
        index: true
    },
    customerId: {
        type: String, // References PostgreSQL User ID
        required: true,
        index: true
    },
    currentLocation: {
        type: locationSchema,
        index: '2dsphere'
    },
    destination: {
        type: locationSchema,
        required: true
    },
    pickupLocation: {
        type: locationSchema,
        required: true
    },
    status: {
        type: String,
        enum: ['preparing', 'picked_up', 'in_transit', 'nearby', 'delivered', 'cancelled'],
        default: 'preparing',
    },

    estimatedArrival: Date,
    distanceRemaining: Number,

    route: {
        polyline: String,
        duration: Number,
        distance: Number
    },

    locationHistory: [{
        coordinates: [Number],
        timestamp: { type: Date, default: Date.now },
        speed: Number,
        accuracy: Number
    }],
    lastUpdated: { type: Date, default: Date.now }
}, {
    timestamps: true
});

// Index for geospatial queries
orderTrackingSchema.index({ orderId: 1, status: 1 });

module.exports = mongoose.model('OrderTracking', orderTrackingSchema);
