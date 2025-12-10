const mongoose = require('mongoose');

const userCreditSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true
    },
    amount: {
        type: Number,
        required: true,
        min: 0
    },
    source: {
        type: String,
        enum: ['referral_earned', 'referral_received', 'promotion', 'refund', 'bonus'],
        required: true
    },
    referralId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Referral',
        default: null
    },
    expiresAt: {
        type: Date,
        required: true
    },
    usedAt: {
        type: Date,
        default: null
    },
    orderId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Order',
        default: null
    },
    isActive: {
        type: Boolean,
        default: true
    },
    description: {
        type: String,
        default: ''
    }
}, {
    timestamps: true
});

// Indexes
userCreditSchema.index({ user: 1, isActive: 1, expiresAt: 1 });
userCreditSchema.index({ user: 1, usedAt: 1 });
userCreditSchema.index({ expiresAt: 1 });

// Method to check if credit is valid
userCreditSchema.methods.isValid = function () {
    return this.isActive && !this.usedAt && this.expiresAt > new Date();
};

module.exports = mongoose.model('UserCredit', userCreditSchema);
