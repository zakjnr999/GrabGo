const mongoose = require('mongoose');

/**
 * Order Reservation Schema
 * 
 * Tracks exclusive order reservations for riders in the hybrid dispatch system.
 * Each order can only be reserved by one rider at a time.
 * 
 * Flow:
 * 1. New order → Dispatch service scores & ranks eligible riders
 * 2. Top-ranked rider gets exclusive reservation for X seconds
 * 3. Rider can: ACCEPT (order assigned) | DECLINE (next rider) | TIMEOUT (next rider)
 * 4. Process repeats until order is accepted or max attempts reached
 */
const orderReservationSchema = new mongoose.Schema({
    // Reservation target entity
    entityType: {
        type: String,
        enum: ['order', 'parcel'],
        default: 'order',
        index: true
    },

    // References PostgreSQL Order ID
    orderId: {
        type: String,
        required: true,
        index: true
    },
    
    // Order number for display/logging
    orderNumber: {
        type: String,
        required: true
    },
    
    // References PostgreSQL User ID (rider)
    riderId: {
        type: String,
        required: true,
        index: true
    },
    
    // Reservation status
    status: {
        type: String,
        enum: ['pending', 'accepted', 'declined', 'expired', 'cancelled'],
        default: 'pending',
        index: true
    },
    
    // When this reservation expires (if no response)
    expiresAt: {
        type: Date,
        required: true,
        index: true
    },
    
    // Timeout duration in milliseconds (for adaptive timeouts)
    timeoutMs: {
        type: Number,
        default: 8000 // 8 seconds default
    },
    
    // Which attempt this is (1st rider, 2nd rider, etc.)
    attemptNumber: {
        type: Number,
        default: 1
    },
    
    // Score assigned by dispatch algorithm
    riderScore: {
        type: Number,
        default: 0
    },
    
    // Distance from rider to pickup location (km)
    distanceToPickup: {
        type: Number,
        default: 0
    },
    
    // Estimated rider earnings for this order
    estimatedEarnings: {
        type: Number,
        default: 0
    },
    
    // Order details snapshot (so rider doesn't need another API call)
    orderSnapshot: {
        orderType: String,
        totalAmount: Number,
        paymentMethod: String,
        itemCount: Number,
        pickupAddress: String,
        pickupLat: Number,
        pickupLon: Number,
        deliveryAddress: String,
        deliveryLat: Number,
        deliveryLon: Number,
        storeName: String, // Restaurant/grocery/pharmacy name
        storeLogo: String,
        customerName: String,
        distance: Number, // Delivery distance in km
        packageCategory: String,
        packageWeightKg: Number,
        declaredValueGhs: Number,
    },
    
    // When rider responded (if they did)
    respondedAt: Date,
    
    // Reason for decline (if declined)
    declineReason: {
        type: String,
        enum: ['too_far', 'busy', 'low_pay', 'other', null],
        default: null
    },
    
    // Created timestamp
    createdAt: {
        type: Date,
        default: Date.now
    }
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

// Compound index for finding active reservation for an order
orderReservationSchema.index({ entityType: 1, orderId: 1, status: 1 });

// Index for finding rider's active reservations
orderReservationSchema.index({ entityType: 1, riderId: 1, status: 1 });

// TTL index to auto-cleanup old reservations after 1 hour
orderReservationSchema.index({ createdAt: 1 }, { expireAfterSeconds: 3600 });

// Index for expiry job to find pending expired reservations
orderReservationSchema.index({ entityType: 1, status: 1, expiresAt: 1 });

/**
 * Static method: Build entity-scoped query
 */
orderReservationSchema.statics.buildEntityQuery = function(entityType = 'order', query = {}) {
    return withEntityScope(query, entityType);
};

/**
 * Static method: Get active reservation for an order
 */
orderReservationSchema.statics.getActiveForOrder = async function(orderId, entityType = 'order') {
    return this.findOne(withEntityScope({
        orderId,
        status: 'pending',
        expiresAt: { $gt: new Date() }
    }, entityType));
};

/**
 * Static method: Get active reservation for a rider
 */
orderReservationSchema.statics.getActiveForRider = async function(riderId, entityType = 'order') {
    return this.findOne(withEntityScope({
        riderId,
        status: 'pending',
        expiresAt: { $gt: new Date() }
    }, entityType));
};

/**
 * Static method: Check if order has any active reservation
 */
orderReservationSchema.statics.isOrderReserved = async function(orderId, entityType = 'order') {
    const reservation = await this.getActiveForOrder(orderId, entityType);
    return !!reservation;
};

/**
 * Static method: Get reservation history for an order
 */
orderReservationSchema.statics.getOrderHistory = async function(orderId, entityType = 'order') {
    return this.find(withEntityScope({ orderId }, entityType)).sort({ attemptNumber: 1 });
};

/**
 * Static method: Find all expired pending reservations
 */
orderReservationSchema.statics.findExpired = async function(entityType = 'order') {
    return this.find(withEntityScope({
        status: 'pending',
        expiresAt: { $lte: new Date() }
    }, entityType));
};

/**
 * Instance method: Accept reservation
 */
orderReservationSchema.methods.accept = async function() {
    this.status = 'accepted';
    this.respondedAt = new Date();
    return this.save();
};

/**
 * Instance method: Decline reservation
 */
orderReservationSchema.methods.decline = async function(reason = null) {
    this.status = 'declined';
    this.respondedAt = new Date();
    this.declineReason = reason;
    return this.save();
};

/**
 * Instance method: Expire reservation (called by scheduler)
 */
orderReservationSchema.methods.expire = async function() {
    this.status = 'expired';
    return this.save();
};

/**
 * Instance method: Cancel reservation (e.g., order cancelled by customer)
 */
orderReservationSchema.methods.cancel = async function() {
    this.status = 'cancelled';
    return this.save();
};

module.exports = mongoose.model('OrderReservation', orderReservationSchema);
