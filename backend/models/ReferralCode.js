const mongoose = require('mongoose');

const referralCodeSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        unique: true
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
referralCodeSchema.index({ user: 1 });

module.exports = mongoose.model('ReferralCode', referralCodeSchema);
