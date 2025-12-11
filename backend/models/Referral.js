const mongoose = require('mongoose');

const referralSchema = new mongoose.Schema({
    referrer: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    referee: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        unique: true // Each user can only be referred once
    },
    referralCode: {
        type: String,
        required: true,
        uppercase: true
    },
    status: {
        type: String,
        enum: ['pending_order', 'completed', 'expired'],
        default: 'pending_order'
    },
    referrerCreditAmount: {
        type: Number,
        default: 10.00
    },
    refereeDiscountAmount: {
        type: Number,
        default: 10.00
    },
    referrerCreditId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'UserCredit',
        default: null
    },
    refereeCreditId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'UserCredit',
        default: null
    },
    referrerCreditedAt: {
        type: Date,
        default: null
    },
    refereeOrderId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Order',
        default: null
    },
    completedAt: {
        type: Date,
        default: null
    },
    expiresAt: {
        type: Date,
        required: true
    },
    // Track device/IP for fraud prevention
    deviceId: {
        type: String,
        default: null
    },
    ipAddress: {
        type: String,
        default: null
    }
}, {
    timestamps: true
});

// Indexes for faster queries
referralSchema.index({ referrer: 1, status: 1 });
referralSchema.index({ referee: 1 });
referralSchema.index({ status: 1 });
referralSchema.index({ expiresAt: 1 });

module.exports = mongoose.model('Referral', referralSchema);
