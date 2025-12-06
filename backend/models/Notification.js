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
        enum: ['order', 'promo', 'update', 'system', 'comment_reply', 'comment_reaction'],
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
    // Navigation data
    data: {
        statusId: String,
        commentId: String,
        replyId: String,
        chatId: String,
        orderId: String,
        restaurantId: String,
        restaurantName: String,
        actorId: mongoose.Schema.Types.ObjectId,
        actorName: String,
        actorAvatar: String,
        reactionType: String
    }
}, {
    timestamps: true
});

// Indexes for efficient querying
notificationSchema.index({ user: 1, createdAt: -1 });
notificationSchema.index({ user: 1, isRead: 1 });
notificationSchema.index({ user: 1, type: 1 });

module.exports = mongoose.model('Notification', notificationSchema);
