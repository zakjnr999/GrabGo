const mongoose = require('mongoose');

const promotionalBannerSchema = new mongoose.Schema({
    title: {
        type: String,
        required: true,
        trim: true
    },
    subtitle: {
        type: String,
        default: null,
        trim: true
    },
    imageUrl: {
        type: String,
        required: true
    },
    discount: {
        type: String,
        default: null
    },
    backgroundColor: {
        type: String,
        default: '#FFFFFF',
        validate: {
            validator: function (v) {
                return /^#[0-9A-F]{6}$/i.test(v);
            },
            message: 'backgroundColor must be a valid hex color (e.g., #FFFFFF)'
        }
    },
    targetUrl: {
        type: String,
        default: null,
        trim: true
    },
    startDate: {
        type: Date,
        required: true
    },
    endDate: {
        type: Date,
        required: true,
        validate: {
            validator: function (v) {
                return v > this.startDate;
            },
            message: 'endDate must be after startDate'
        }
    },
    isActive: {
        type: Boolean,
        default: true
    },
    priority: {
        type: Number,
        default: 0,
        min: 0
    },
    targetAudience: {
        type: String,
        enum: ['all', 'new_users', 'premium', 'frequent'],
        default: 'all'
    }
}, {
    timestamps: true
});

// Index for efficient querying of active banners
promotionalBannerSchema.index({ isActive: 1, startDate: 1, endDate: 1, priority: -1 });

module.exports = mongoose.model('PromotionalBanner', promotionalBannerSchema);
