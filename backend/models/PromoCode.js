const mongoose = require('mongoose');

const promoCodeSchema = new mongoose.Schema({
    code: {
        type: String,
        required: true,
        unique: true,
        uppercase: true,
        trim: true,
        index: true
    },
    type: {
        type: String,
        enum: ['percentage', 'fixed', 'free_delivery'],
        required: true
    },
    value: {
        type: Number,
        required: true,
        min: 0
    },
    description: {
        type: String,
        default: ''
    },

    // Validity
    isActive: {
        type: Boolean,
        default: true,
        index: true
    },
    startDate: {
        type: Date,
        default: Date.now
    },
    endDate: {
        type: Date,
        default: null
    },

    // Usage Limits
    maxUses: {
        type: Number,
        default: null // null = unlimited
    },
    currentUses: {
        type: Number,
        default: 0
    },
    maxUsesPerUser: {
        type: Number,
        default: 1
    },

    // Restrictions
    minOrderAmount: {
        type: Number,
        default: 0,
        min: 0
    },
    maxDiscountAmount: {
        type: Number,
        default: null // null = no cap
    },
    applicableOrderTypes: [{
        type: String,
        enum: ['food', 'grocery']
    }],
    firstOrderOnly: {
        type: Boolean,
        default: false
    },

    // Targeting (optional)
    targetedUsers: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],

    // Metadata
    createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        default: null
    }
}, {
    timestamps: true
});

// Indexes for efficient querying
promoCodeSchema.index({ code: 1, isActive: 1 });
promoCodeSchema.index({ startDate: 1, endDate: 1 });

module.exports = mongoose.model('PromoCode', promoCodeSchema);
