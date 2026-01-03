const mongoose = require('mongoose');

// Sub-schema for view tracking with duration
const viewSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    viewedAt: {
        type: Date,
        default: Date.now
    },
    // Duration in milliseconds (how long user viewed the status)
    duration: {
        type: Number,
        default: 0
    }
}, { _id: false });

const statusSchema = new mongoose.Schema({
    restaurant: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Restaurant',
        required: true,
        index: true
    },
    category: {
        type: String,
        enum: ['daily_special', 'discount', 'new_item', 'video'],
        required: true,
        index: true
    },
    // Content
    title: {
        type: String,
        maxlength: 100
    },
    description: {
        type: String,
        maxlength: 500
    },
    // Media - supports images and videos
    mediaType: {
        type: String,
        enum: ['image', 'video'],
        default: 'image'
    },
    mediaUrl: {
        type: String,
        required: true
    },
    // Cloudinary public ID for cleanup
    cloudinaryPublicId: {
        type: String
    },
    thumbnailUrl: {
        type: String // For video thumbnails
    },
    thumbnailCloudinaryId: {
        type: String
    },
    blurHash: {
        type: String // For image placeholders
    },
    // For discount/promo statuses
    discountPercentage: {
        type: Number,
        min: 0,
        max: 100
    },
    promoCode: {
        type: String,
        maxlength: 20
    },
    // Link to food item (for daily special / new item)
    linkedFood: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Food'
    },
    // Engagement
    viewCount: {
        type: Number,
        default: 0
    },
    likeCount: {
        type: Number,
        default: 0
    },
    // Total view duration in milliseconds (for analytics)
    totalViewDuration: {
        type: Number,
        default: 0
    },
    // Average view duration in milliseconds
    avgViewDuration: {
        type: Number,
        default: 0
    },
    // Engagement score (calculated: views + likes*2 + avgDuration factor)
    engagementScore: {
        type: Number,
        default: 0,
        index: true
    },
    // Users who liked this status
    likedBy: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    // Users who viewed this status with duration tracking
    viewedBy: [viewSchema],
    // Status lifecycle
    isActive: {
        type: Boolean,
        default: true
    },
    isRecommended: {
        type: Boolean,
        default: false
    },
    // Statuses expire after 24 hours by default
    expiresAt: {
        type: Date,
        required: true,
        index: true
    }
}, {
    timestamps: true
});

// Index for efficient queries
statusSchema.index({ restaurant: 1, createdAt: -1 });
statusSchema.index({ category: 1, createdAt: -1 });
statusSchema.index({ isActive: 1, expiresAt: 1 });
statusSchema.index({ isRecommended: 1, createdAt: -1 });
// Compound index for common query pattern (active + not expired)
statusSchema.index({ isActive: 1, expiresAt: 1, createdAt: -1 });
// Index for user viewed statuses lookup
statusSchema.index({ 'viewedBy.user': 1 });

// Virtual for checking if status is expired
statusSchema.virtual('isExpired').get(function () {
    return new Date() > this.expiresAt;
});

// Method to calculate and update engagement score
statusSchema.methods.updateEngagementScore = function () {
    // Score formula: views + (likes * 2) + (avgDuration in seconds / 10)
    const durationFactor = this.avgViewDuration > 0 ? (this.avgViewDuration / 1000) / 10 : 0;
    this.engagementScore = this.viewCount + (this.likeCount * 2) + durationFactor;
};

// Method to record a single view with duration
statusSchema.methods.recordView = async function (userId, duration = 0) {
    const userIdStr = userId.toString();

    // Find existing view
    const existingViewIndex = this.viewedBy.findIndex(
        v => v.user.toString() === userIdStr
    );

    if (existingViewIndex > -1) {
        // Update existing view with new duration (add to it)
        const existingDuration = this.viewedBy[existingViewIndex].duration || 0;
        this.viewedBy[existingViewIndex].duration = existingDuration + duration;
        this.viewedBy[existingViewIndex].viewedAt = new Date();
    } else {
        // New view
        this.viewedBy.push({
            user: userId,
            viewedAt: new Date(),
            duration: duration
        });
        this.viewCount += 1;
    }

    // Update total and average duration
    if (duration > 0) {
        this.totalViewDuration += duration;
        this.avgViewDuration = this.viewCount > 0
            ? Math.round(this.totalViewDuration / this.viewCount)
            : 0;
    }

    // Update engagement score
    this.updateEngagementScore();

    await this.save();
    return this;
};

// Method to record view with session (for transactions)
statusSchema.methods.recordViewWithSession = async function (userId, duration = 0, session) {
    const userIdStr = userId.toString();

    const existingViewIndex = this.viewedBy.findIndex(
        v => v.user.toString() === userIdStr
    );

    if (existingViewIndex > -1) {
        const existingDuration = this.viewedBy[existingViewIndex].duration || 0;
        this.viewedBy[existingViewIndex].duration = existingDuration + duration;
        this.viewedBy[existingViewIndex].viewedAt = new Date();
    } else {
        this.viewedBy.push({
            user: userId,
            viewedAt: new Date(),
            duration: duration
        });
        this.viewCount += 1;
    }

    if (duration > 0) {
        this.totalViewDuration += duration;
        this.avgViewDuration = this.viewCount > 0
            ? Math.round(this.totalViewDuration / this.viewCount)
            : 0;
    }

    this.updateEngagementScore();
    await this.save({ session });
    return this;
};

// Method to record multiple views at once (batch view for story swipe-through)
statusSchema.methods.recordBatchViews = async function (userId, views) {
    // views is an array of { statusId, duration } - but we only handle this status
    const userIdStr = userId.toString();
    const viewData = views.find(v => v.statusId?.toString() === this._id.toString());

    if (viewData) {
        await this.recordView(userId, viewData.duration || 0);
    }

    return this;
};

// Static method to record batch views across multiple statuses
statusSchema.statics.recordBatchViews = async function (userId, views) {
    // views is an array of { statusId, duration }
    const results = [];

    for (const view of views) {
        try {
            const status = await this.findById(view.statusId);
            if (status && status.isActive && status.expiresAt > new Date()) {
                await status.recordView(userId, view.duration || 0);
                results.push({
                    statusId: view.statusId,
                    success: true,
                    viewCount: status.viewCount
                });
            } else {
                results.push({
                    statusId: view.statusId,
                    success: false,
                    reason: status ? 'Status expired' : 'Status not found'
                });
            }
        } catch (error) {
            results.push({
                statusId: view.statusId,
                success: false,
                reason: error.message
            });
        }
    }

    return results;
};

// Static method to record batch views with MongoDB session (for transactions)
statusSchema.statics.recordBatchViewsWithSession = async function (userId, views, session) {
    const results = [];

    for (const view of views) {
        try {
            const status = await this.findById(view.statusId).session(session);
            if (status && status.isActive && status.expiresAt > new Date()) {
                await status.recordViewWithSession(userId, view.duration || 0, session);
                results.push({
                    statusId: view.statusId,
                    success: true,
                    viewCount: status.viewCount
                });
            } else {
                results.push({
                    statusId: view.statusId,
                    success: false,
                    reason: status ? 'Status expired' : 'Status not found'
                });
            }
        } catch (error) {
            results.push({
                statusId: view.statusId,
                success: false,
                reason: error.message
            });
        }
    }

    return results;
};

// Method to toggle like
statusSchema.methods.toggleLike = async function (userId) {
    const userIdStr = userId.toString();
    const likedIndex = this.likedBy.findIndex(
        id => id.toString() === userIdStr
    );

    if (likedIndex > -1) {
        // Unlike
        this.likedBy.splice(likedIndex, 1);
        this.likeCount = Math.max(0, this.likeCount - 1);
    } else {
        // Like
        this.likedBy.push(userId);
        this.likeCount += 1;
    }

    // Update engagement score
    this.updateEngagementScore();

    await this.save();
    return {
        isLiked: likedIndex === -1,
        likeCount: this.likeCount
    };
};

// Static method to get active statuses
statusSchema.statics.getActiveStatuses = function (filter = {}) {
    return this.find({
        ...filter,
        isActive: true,
        expiresAt: { $gt: new Date() }
    });
};

// Static method to clean up expired statuses and their Cloudinary images
statusSchema.statics.cleanupExpired = async function (cloudinary = null) {
    // Find expired statuses that need cleanup
    const expiredStatuses = await this.find({
        isActive: true,
        expiresAt: { $lt: new Date() }
    }).select('cloudinaryPublicId thumbnailCloudinaryId');

    // Collect Cloudinary public IDs for deletion
    const publicIds = [];
    expiredStatuses.forEach(status => {
        if (status.cloudinaryPublicId) {
            publicIds.push(status.cloudinaryPublicId);
        }
        if (status.thumbnailCloudinaryId) {
            publicIds.push(status.thumbnailCloudinaryId);
        }
    });

    // Delete from Cloudinary if available and there are IDs to delete
    let cloudinaryDeleted = 0;
    if (cloudinary && publicIds.length > 0) {
        try {
            // Delete in batches of 100 (Cloudinary limit)
            for (let i = 0; i < publicIds.length; i += 100) {
                const batch = publicIds.slice(i, i + 100);
                const result = await cloudinary.api.delete_resources(batch);
                cloudinaryDeleted += Object.keys(result.deleted || {}).length;
            }
        } catch (error) {
            console.error('Cloudinary cleanup error:', error.message);
        }
    }

    // Mark statuses as inactive
    const result = await this.updateMany(
        {
            isActive: true,
            expiresAt: { $lt: new Date() }
        },
        {
            $set: { isActive: false }
        }
    );

    return {
        statusesDeactivated: result.modifiedCount,
        cloudinaryImagesDeleted: cloudinaryDeleted
    };
};

// Ensure virtuals are included in JSON
statusSchema.set('toJSON', { virtuals: true });
statusSchema.set('toObject', { virtuals: true });

module.exports = mongoose.model('Status', statusSchema);
