const mongoose = require('mongoose');

const scheduledNotificationSchema = new mongoose.Schema({
    // Scheduling information
    scheduledFor: {
        type: Date,
        required: true,
        index: true
    },
    timezone: {
        type: String,
        default: 'UTC'
    },
    status: {
        type: String,
        enum: ['pending', 'sent', 'cancelled', 'failed'],
        default: 'pending',
        index: true
    },

    // Notification content
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
            'milestone_bonus'
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
    data: {
        type: mongoose.Schema.Types.Mixed,
        default: {}
    },

    // Targeting
    targetType: {
        type: String,
        enum: ['user', 'segment', 'all'],
        required: true,
        default: 'all'
    },
    targetUsers: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }],
    targetSegment: {
        type: mongoose.Schema.Types.Mixed,
        default: null
    },

    // Recurrence (optional)
    isRecurring: {
        type: Boolean,
        default: false
    },
    recurrencePattern: {
        frequency: {
            type: String,
            enum: ['daily', 'weekly', 'monthly']
        },
        daysOfWeek: [Number], // 0=Sunday, 6=Saturday
        timeOfDay: String,    // HH:mm format
        endDate: Date
    },

    // Metadata
    createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    },
    sentAt: Date,
    failureReason: String,
    retryCount: {
        type: Number,
        default: 0
    },
    maxRetries: {
        type: Number,
        default: 3
    },
    processingStartedAt: Date, // For race condition prevention
    version: {
        type: Number,
        default: 0
    } // For optimistic locking to prevent duplicate processing
}, {
    timestamps: true
});

// Indexes for efficient querying
scheduledNotificationSchema.index({ scheduledFor: 1, status: 1 });
scheduledNotificationSchema.index({ status: 1, createdAt: -1 });
scheduledNotificationSchema.index({ createdBy: 1, status: 1 });
// Compound index for cron job query (most important)
scheduledNotificationSchema.index({ status: 1, scheduledFor: 1, processingStartedAt: 1 });

// Virtual for checking if notification is due
scheduledNotificationSchema.virtual('isDue').get(function () {
    return this.status === 'pending' && this.scheduledFor <= new Date();
});

// Method to check if notification can be cancelled
scheduledNotificationSchema.methods.canBeCancelled = function () {
    return this.status === 'pending';
};

// Method to check if notification can be edited
scheduledNotificationSchema.methods.canBeEdited = function () {
    return this.status === 'pending' && this.scheduledFor > new Date();
};

module.exports = mongoose.model('ScheduledNotification', scheduledNotificationSchema);
