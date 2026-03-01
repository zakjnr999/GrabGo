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
    entityType: {
        type: String,
        enum: ['order', 'parcel'],
        default: 'order',
        index: true,
    },
    orderId: {
        type: String, // References PostgreSQL Order ID
        required: true,
        index: true
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

const buildEntityScopeFilter = (entityType = 'order') =>
    entityType === 'order'
        ? { $or: [{ entityType: 'order' }, { entityType: { $exists: false } }] }
        : { entityType };

const withEntityScope = (query = {}, entityType = 'order') => {
    const scopeFilter = buildEntityScopeFilter(entityType);
    if (!query || Object.keys(query).length === 0) {
        return scopeFilter;
    }

    return {
        $and: [query, scopeFilter]
    };
};

orderTrackingSchema.statics.buildEntityQuery = function(entityType = 'order', query = {}) {
    return withEntityScope(query, entityType);
};

// Index for geospatial queries
orderTrackingSchema.index({ entityType: 1, orderId: 1 }, { unique: true });
orderTrackingSchema.index({ entityType: 1, orderId: 1, status: 1 });

module.exports = mongoose.model('OrderTracking', orderTrackingSchema);
