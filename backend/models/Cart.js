const mongoose = require('mongoose');

const cartItemSchema = new mongoose.Schema({
    itemId: {
        type: mongoose.Schema.Types.ObjectId,
        required: true,
        refPath: 'items.itemType'
    },
    itemType: {
        type: String,
        required: true,
        enum: ['Food', 'GroceryItem']
    },
    name: {
        type: String,
        required: true
    },
    price: {
        type: Number,
        required: true
    },
    quantity: {
        type: Number,
        required: true,
        min: 1,
        default: 1
    },
    imageUrl: {
        type: String,
        default: null
    },
    addedAt: {
        type: Date,
        default: Date.now
    }
}, { _id: false });

const cartSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true
    },
    items: [cartItemSchema],
    restaurant: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Restaurant',
        default: null
    },
    groceryStore: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'GroceryStore',
        default: null
    },
    cartType: {
        type: String,
        enum: ['food', 'grocery'],
        required: true
    },
    totalAmount: {
        type: Number,
        default: 0
    },
    itemCount: {
        type: Number,
        default: 0
    },
    lastUpdatedAt: {
        type: Date,
        default: Date.now
    },
    // Abandonment tracking
    abandonmentNotificationSent: {
        type: Boolean,
        default: false
    },
    abandonmentNotificationSentAt: {
        type: Date,
        default: null
    },
    lastAbandonmentCheckAt: {
        type: Date,
        default: null
    },
    // Metadata
    isActive: {
        type: Boolean,
        default: true
    },
    convertedToOrder: {
        type: Boolean,
        default: false
    },
    orderId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Order',
        default: null
    }
}, {
    timestamps: true
});

// Indexes for performance
cartSchema.index({ user: 1, isActive: 1 });
cartSchema.index({ lastUpdatedAt: 1, abandonmentNotificationSent: 1 });
// Compound index for abandonment query optimization
cartSchema.index({
    isActive: 1,
    convertedToOrder: 1,
    lastUpdatedAt: 1,
    abandonmentNotificationSent: 1
});

// Calculate totals before saving
cartSchema.pre('save', function (next) {
    this.itemCount = this.items.reduce((sum, item) => sum + item.quantity, 0);
    this.totalAmount = this.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    this.lastUpdatedAt = new Date();
    next();
});

// Method to check if cart is abandoned (30 minutes of inactivity)
cartSchema.methods.isAbandoned = function () {
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
    return this.lastUpdatedAt < thirtyMinutesAgo &&
        this.items.length > 0 &&
        !this.convertedToOrder;
};

// Method to mark as abandoned notification sent
cartSchema.methods.markAbandonmentNotificationSent = async function () {
    this.abandonmentNotificationSent = true;
    this.abandonmentNotificationSentAt = new Date();
    await this.save();
};

module.exports = mongoose.model('Cart', cartSchema);
