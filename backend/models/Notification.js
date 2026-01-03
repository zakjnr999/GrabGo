const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
    user: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
        index: true
    },
    type: {
        type: String,
        enum: [
            'order',
            'promo',
            'update',
            'system',
            'comment_reply',
            'comment_reaction',
            'referral_completed',
            'payment_confirmed',
            'delivery_arriving',
            'milestone_bonus',
            'cart_reminder',
            'meal_nudge_breakfast',
            'meal_nudge_lunch',
            'meal_nudge_dinner',
            'favorites_reminder',
            'reorder_suggestion',
            'reengagement_two_weeks',
            'reengagement_one_month',
            'reengagement_two_months'
        ],
        required: true
    },
    title: {
        type: String,
        required: true
    },
    message: {
        type: String,
        required: true
    },
    isRead: {
        type: Boolean,
        default: false
    },
    // Grouping fields
    actors: [{
        actorId: { type: String, required: true },
        actorName: { type: String, required: true },
        actorAvatar: String,
        reactedAt: { type: Date, default: Date.now }
    }],
    actorCount: {
        type: Number,
        default: 1
    },
    // Navigation data
    data: {
        statusId: String,
        commentId: String,
        parentCommentId: String,  // For reply deep linking
        isReply: Boolean,         // Flag to indicate if it's a reply
        replyId: String,
        chatId: String,
        orderId: String,
        restaurantId: String,
        restaurantName: String,
        actorId: mongoose.Schema.Types.ObjectId,
        actorName: String,
        actorAvatar: String,
        reactionType: String,
        commentText: String,
        replyText: String,
        itemId: String,
        itemName: String
    }
}, {
    timestamps: true
});

// Indexes for efficient querying
notificationSchema.index({ user: 1, createdAt: -1 });
// Optimized for the common query pattern in routes/notifications.js:
// .find({ user: req.user._id }).sort({ isRead: 1, createdAt: -1 })
// This index supports sorting by isRead first (better selectivity for unread filtering) then createdAt
notificationSchema.index({ user: 1, isRead: 1, createdAt: -1 });
notificationSchema.index({ user: 1, type: 1 });

// Compound indexes for grouping queries (findGroupableNotification)
// These support queries with user + type + data field + createdAt
notificationSchema.index({ user: 1, type: 1, 'data.commentId': 1, createdAt: -1 });
notificationSchema.index({ user: 1, type: 1, 'data.parentCommentId': 1, createdAt: -1 });

// TTL Index: Auto-delete notifications older than 90 days to prevent DB bloat
// 90 days = 90 * 24 * 60 * 60 = 7,776,000 seconds
notificationSchema.index({ createdAt: 1 }, { expireAfterSeconds: 7776000 });

module.exports = mongoose.model('Notification', notificationSchema);
