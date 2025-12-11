const mongoose = require('mongoose');

const referralCodeSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: function () {
            return !this.isSystemCode; // Only required for user codes
        }
    },
    code: {
        type: String,
        required: true,
        unique: true,
        uppercase: true,
        trim: true,
        index: true
    },
    isActive: {
        type: Boolean,
        default: true
    },
    isSystemCode: {
        type: Boolean,
        default: false
    },
    discount: {
        type: Number,
        default: 10.00
    },
    minOrderValue: {
        type: Number,
        default: 20.00
    },
    validDays: {
        type: Number,
        default: 7
    },
    totalReferrals: {
        type: Number,
        default: 0
    },
    completedReferrals: {
        type: Number,
        default: 0
    },
    totalEarned: {
        type: Number,
        default: 0
    }
}, {
    timestamps: true
});

// Index for faster lookups
referralCodeSchema.index({ code: 1 });
referralCodeSchema.index({ user: 1 }, { sparse: true }); // Sparse index allows multiple null values

module.exports = mongoose.model('ReferralCode', referralCodeSchema);
