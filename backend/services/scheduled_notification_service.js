const ScheduledNotification = require('../models/ScheduledNotification');
const { createNotification } = require('./notification_service');
const User = require('../models/User');

/**
 * Create a scheduled notification
 * @param {Object} data - Notification data
 * @returns {Promise<Object>} Created scheduled notification
 */
const createScheduledNotification = async (data) => {
    try {
        const {
            scheduledFor,
            timezone = 'UTC',
            type,
            title,
            message,
            notificationData = {},
            targetType = 'all',
            targetUsers = [],
            targetSegment = null,
            isRecurring = false,
            recurrencePattern = null,
            createdBy = null
        } = data;

        // Validate scheduled time is in the future
        const scheduledDate = new Date(scheduledFor);

        // Check for invalid date
        if (isNaN(scheduledDate.getTime())) {
            throw new Error('Invalid date format for scheduledFor');
        }

        if (scheduledDate <= new Date()) {
            throw new Error('Scheduled time must be in the future');
        }

        // Validate title and message length
        if (title.length > 200) {
            throw new Error('Title must be 200 characters or less');
        }

        if (message.length > 500) {
            throw new Error('Message must be 500 characters or less');
        }

        // Create scheduled notification
        const scheduledNotification = await ScheduledNotification.create({
            scheduledFor: scheduledDate,
            timezone,
            type,
            title,
            message,
            data: notificationData,
            targetType,
            targetUsers,
            targetSegment,
            isRecurring,
            recurrencePattern,
            createdBy,
            status: 'pending'
        });

        console.log(`📅 Scheduled notification created: ${scheduledNotification._id} for ${scheduledDate}`);
        return scheduledNotification;
    } catch (error) {
        console.error('Error creating scheduled notification:', error.message);
        throw error;
    }
};

/**
 * Process scheduled notifications that are due
 * Called by cron job every minute
 * @param {Object} io - Socket.IO instance (optional)
 * @returns {Promise<Object>} Processing results
 */
const processScheduledNotifications = async (io = null) => {
    try {
        const now = new Date();
        const processingStartTime = new Date();

        // Find and claim notifications atomically to prevent race conditions
        // Use findOneAndUpdate in a loop to claim one at a time
        const dueNotifications = [];
        const maxBatch = 100;

        for (let i = 0; i < maxBatch; i++) {
            const notification = await ScheduledNotification.findOneAndUpdate(
                {
                    status: 'pending',
                    scheduledFor: { $lte: now },
                    // Ensure we don't process notifications already being processed
                    $or: [
                        { processingStartedAt: { $exists: false } },
                        { processingStartedAt: { $lt: new Date(Date.now() - 5 * 60 * 1000) } } // Stale after 5 min
                    ]
                },
                {
                    $set: { processingStartedAt: processingStartTime },
                    $inc: { version: 1 } // Increment version for optimistic locking
                },
                {
                    new: false, // Return original document
                    sort: { scheduledFor: 1 } // Process oldest first
                }
            );

            if (!notification) break;
            dueNotifications.push(notification);
        }

        if (dueNotifications.length === 0) {
            return { processed: 0, sent: 0, failed: 0 };
        }

        console.log(`📬 Processing ${dueNotifications.length} scheduled notifications...`);

        let sentCount = 0;
        let failedCount = 0;

        for (const scheduledNotif of dueNotifications) {
            try {
                // Get target users
                const targetUserIds = await getTargetUsers(scheduledNotif);

                if (targetUserIds.length === 0) {
                    console.warn(`⚠️ No target users found for scheduled notification ${scheduledNotif._id}`);
                    scheduledNotif.status = 'failed';
                    scheduledNotif.failureReason = 'No target users found';
                    await scheduledNotif.save();
                    failedCount++;
                    continue;
                }

                // Send notification to each target user
                // Use Promise.allSettled to handle partial failures
                const sendPromises = targetUserIds.map(userId =>
                    createNotification(
                        userId,
                        scheduledNotif.type,
                        scheduledNotif.title,
                        scheduledNotif.message,
                        {
                            ...scheduledNotif.data,
                            scheduledNotificationId: scheduledNotif._id.toString()
                        },
                        io
                    )
                );

                const results = await Promise.allSettled(sendPromises);

                // Count successes and failures
                const successCount = results.filter(r => r.status === 'fulfilled').length;
                const failureCount = results.filter(r => r.status === 'rejected').length;

                if (failureCount > 0) {
                    console.warn(`⚠️ Partial delivery: ${successCount}/${targetUserIds.length} notifications sent`);
                }

                // Only mark as sent if at least some succeeded
                if (successCount === 0) {
                    throw new Error('Failed to send to any users');
                }

                // Update status
                scheduledNotif.status = 'sent';
                scheduledNotif.sentAt = new Date();
                await scheduledNotif.save();

                console.log(`✅ Sent scheduled notification ${scheduledNotif._id} to ${targetUserIds.length} users`);
                sentCount++;

                // Handle recurring notifications
                if (scheduledNotif.isRecurring && scheduledNotif.recurrencePattern) {
                    await createNextRecurrence(scheduledNotif);
                }

            } catch (error) {
                console.error(`❌ Failed to send scheduled notification ${scheduledNotif._id}:`, error.message);

                // Update retry count
                scheduledNotif.retryCount += 1;

                if (scheduledNotif.retryCount >= scheduledNotif.maxRetries) {
                    scheduledNotif.status = 'failed';
                    scheduledNotif.failureReason = error.message;
                } else {
                    // Reschedule for 5 minutes later
                    scheduledNotif.scheduledFor = new Date(Date.now() + 5 * 60 * 1000);
                }

                await scheduledNotif.save();
                failedCount++;
            }
        }

        console.log(`📊 Scheduled notifications processed: ${sentCount} sent, ${failedCount} failed`);

        return {
            processed: dueNotifications.length,
            sent: sentCount,
            failed: failedCount
        };
    } catch (error) {
        console.error('Error processing scheduled notifications:', error.message);
        throw error;
    }
};

/**
 * Get target user IDs based on targeting criteria
 * @param {Object} scheduledNotif - Scheduled notification
 * @returns {Promise<Array>} Array of user IDs
 */
const getTargetUsers = async (scheduledNotif) => {
    try {
        if (scheduledNotif.targetType === 'user') {
            // Validate user IDs exist
            if (!scheduledNotif.targetUsers || scheduledNotif.targetUsers.length === 0) {
                return [];
            }
            return scheduledNotif.targetUsers.map(id => id.toString());
        }

        if (scheduledNotif.targetType === 'all') {
            // Use lean() for better performance and limit to prevent memory issues
            const MAX_USERS = 10000;
            const users = await User.find({ role: 'customer', isActive: true })
                .select('_id')
                .limit(MAX_USERS)
                .lean();

            if (users.length === MAX_USERS) {
                console.warn(`⚠️ Hit user limit of ${MAX_USERS}. Consider batching.`);
            }

            return users.map(u => u._id.toString());
        }

        if (scheduledNotif.targetType === 'segment' && scheduledNotif.targetSegment) {
            // Build query based on segment criteria
            const query = buildSegmentQuery(scheduledNotif.targetSegment);
            const MAX_USERS = 10000;
            const users = await User.find(query)
                .select('_id')
                .limit(MAX_USERS)
                .lean();

            return users.map(u => u._id.toString());
        }

        return [];
    } catch (error) {
        console.error('Error getting target users:', error.message);
        return [];
    }
};

/**
 * Build MongoDB query from segment criteria
 * @param {Object} segment - Segment criteria
 * @returns {Object} MongoDB query
 */
const buildSegmentQuery = (segment) => {
    const query = { role: 'customer' };

    // Example segment criteria:
    // { inactive: true, daysSinceLastOrder: 7 }
    // { newUsers: true, registeredWithinDays: 7 }
    // { highValue: true, minTotalSpent: 100 }

    if (segment.inactive && segment.daysSinceLastOrder) {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - segment.daysSinceLastOrder);
        query.lastOrderDate = { $lt: cutoffDate };
    }

    if (segment.newUsers && segment.registeredWithinDays) {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - segment.registeredWithinDays);
        query.createdAt = { $gte: cutoffDate };
    }

    if (segment.highValue && segment.minTotalSpent) {
        query.totalSpent = { $gte: segment.minTotalSpent };
    }

    return query;
};

/**
 * Create next occurrence for recurring notification
 * @param {Object} scheduledNotif - Original scheduled notification
 * @returns {Promise<Object>} Next scheduled notification
 */
const createNextRecurrence = async (scheduledNotif) => {
    try {
        const pattern = scheduledNotif.recurrencePattern;

        // Check if recurrence has ended
        if (pattern.endDate && new Date(pattern.endDate) < new Date()) {
            console.log(`🔚 Recurrence ended for ${scheduledNotif._id}`);
            return null;
        }

        // Calculate next occurrence
        let nextDate = new Date(scheduledNotif.scheduledFor);

        if (pattern.frequency === 'daily') {
            nextDate.setDate(nextDate.getDate() + 1);
        } else if (pattern.frequency === 'weekly') {
            nextDate.setDate(nextDate.getDate() + 7);
        } else if (pattern.frequency === 'monthly') {
            nextDate.setMonth(nextDate.getMonth() + 1);
        }

        // Create next occurrence
        const nextNotification = await ScheduledNotification.create({
            scheduledFor: nextDate,
            timezone: scheduledNotif.timezone,
            type: scheduledNotif.type,
            title: scheduledNotif.title,
            message: scheduledNotif.message,
            data: scheduledNotif.data,
            targetType: scheduledNotif.targetType,
            targetUsers: scheduledNotif.targetUsers,
            targetSegment: scheduledNotif.targetSegment,
            isRecurring: true,
            recurrencePattern: pattern,
            createdBy: scheduledNotif.createdBy,
            status: 'pending'
        });

        console.log(`🔄 Created next recurrence: ${nextNotification._id} for ${nextDate}`);
        return nextNotification;
    } catch (error) {
        console.error('Error creating next recurrence:', error.message);
        return null;
    }
};

/**
 * Cancel a scheduled notification
 * @param {string} notificationId - Notification ID
 * @param {string} userId - User ID (for permission check)
 * @returns {Promise<boolean>} Success status
 */
const cancelScheduledNotification = async (notificationId, userId = null) => {
    try {
        const query = { _id: notificationId, status: 'pending' };
        if (userId) {
            query.createdBy = userId;
        }

        const notification = await ScheduledNotification.findOneAndUpdate(
            query,
            { status: 'cancelled' },
            { new: true }
        );

        if (!notification) {
            return false;
        }

        console.log(`❌ Cancelled scheduled notification ${notificationId}`);
        return true;
    } catch (error) {
        console.error('Error cancelling scheduled notification:', error.message);
        return false;
    }
};

/**
 * Update a scheduled notification
 * @param {string} notificationId - Notification ID
 * @param {Object} updates - Fields to update
 * @param {string} userId - User ID (for permission check)
 * @returns {Promise<Object|null>} Updated notification or null
 */
const updateScheduledNotification = async (notificationId, updates, userId = null) => {
    try {
        const query = { _id: notificationId, status: 'pending' };
        if (userId) {
            query.createdBy = userId;
        }

        // Validate scheduledFor if being updated
        if (updates.scheduledFor) {
            const newDate = new Date(updates.scheduledFor);

            if (isNaN(newDate.getTime())) {
                throw new Error('Invalid date format for scheduledFor');
            }

            if (newDate <= new Date()) {
                throw new Error('Scheduled time must be in the future');
            }
        }

        // Validate title and message length if being updated
        if (updates.title && updates.title.length > 200) {
            throw new Error('Title must be 200 characters or less');
        }

        if (updates.message && updates.message.length > 500) {
            throw new Error('Message must be 500 characters or less');
        }

        // Only allow updating certain fields
        const allowedUpdates = {
            scheduledFor: updates.scheduledFor,
            title: updates.title,
            message: updates.message,
            data: updates.data,
            targetType: updates.targetType,
            targetUsers: updates.targetUsers,
            targetSegment: updates.targetSegment
        };

        // Remove undefined fields
        Object.keys(allowedUpdates).forEach(key =>
            allowedUpdates[key] === undefined && delete allowedUpdates[key]
        );

        const notification = await ScheduledNotification.findOneAndUpdate(
            query,
            allowedUpdates,
            { new: true, runValidators: true }
        );

        if (!notification) {
            return null;
        }

        console.log(`✏️ Updated scheduled notification ${notificationId}`);
        return notification;
    } catch (error) {
        console.error('Error updating scheduled notification:', error.message);
        throw error; // Throw instead of returning null to propagate validation errors
    }
};

/**
 * Get scheduled notifications with filters
 * @param {Object} filters - Query filters
 * @param {number} limit - Maximum number of results
 * @param {number} skip - Number of results to skip
 * @returns {Promise<Array>} Array of scheduled notifications
 */
const getScheduledNotifications = async (filters = {}, limit = 50, skip = 0) => {
    try {
        const query = {};

        if (filters.status) {
            query.status = filters.status;
        }

        if (filters.type) {
            query.type = filters.type;
        }

        if (filters.createdBy) {
            query.createdBy = filters.createdBy;
        }

        if (filters.scheduledAfter) {
            query.scheduledFor = { $gte: new Date(filters.scheduledAfter) };
        }

        if (filters.scheduledBefore) {
            query.scheduledFor = { ...query.scheduledFor, $lte: new Date(filters.scheduledBefore) };
        }

        const notifications = await ScheduledNotification.find(query)
            .sort({ scheduledFor: -1 })
            .skip(skip)
            .limit(limit)
            .populate('createdBy', 'name email');

        return notifications;
    } catch (error) {
        console.error('Error getting scheduled notifications:', error.message);
        return [];
    }
};

/**
 * Get scheduled notification by ID
 * @param {string} notificationId - Notification ID
 * @returns {Promise<Object|null>} Scheduled notification or null
 */
const getScheduledNotificationById = async (notificationId) => {
    try {
        const notification = await ScheduledNotification.findById(notificationId)
            .populate('createdBy', 'name email')
            .populate('targetUsers', 'name email');

        return notification;
    } catch (error) {
        console.error('Error getting scheduled notification:', error.message);
        return null;
    }
};

/**
 * Get statistics for scheduled notifications
 * @returns {Promise<Object>} Statistics
 */
const getScheduledNotificationStats = async () => {
    try {
        const stats = await ScheduledNotification.aggregate([
            {
                $group: {
                    _id: '$status',
                    count: { $sum: 1 }
                }
            }
        ]);

        const result = {
            pending: 0,
            sent: 0,
            cancelled: 0,
            failed: 0
        };

        stats.forEach(stat => {
            result[stat._id] = stat.count;
        });

        return result;
    } catch (error) {
        console.error('Error getting stats:', error.message);
        return { pending: 0, sent: 0, cancelled: 0, failed: 0 };
    }
};

module.exports = {
    createScheduledNotification,
    processScheduledNotifications,
    cancelScheduledNotification,
    updateScheduledNotification,
    getScheduledNotifications,
    getScheduledNotificationById,
    getScheduledNotificationStats
};
