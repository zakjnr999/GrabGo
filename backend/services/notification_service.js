const Notification = require('../models/Notification');
const { sendToUser } = require('./fcm_service');

// Grouping configuration
const GROUPING_CONFIG = {
    enabled: true,
    timeWindow: 24 * 60 * 60 * 1000, // 24 hours
    groupableTypes: ['comment_reaction', 'comment_reply'],
    maxActorsInList: 50
};

/**
 * Create in-app notification record and emit via Socket.IO
 * @param {string} userId - User ID to receive notification
 * @param {string} type - Notification type
 * @param {string} title - Notification title
 * @param {string} message - Notification message
 * @param {object} data - Additional navigation data
 * @param {object} io - Socket.IO instance (optional)
 * @returns {Promise<object|null>} Created notification or null
 */
const createNotification = async (userId, type, title, message, data = {}, io = null) => {
    try {
        // Check for existing notification to group
        if (GROUPING_CONFIG.enabled && GROUPING_CONFIG.groupableTypes.includes(type)) {
            const existingNotification = await findGroupableNotification(userId, type, data);

            if (existingNotification) {
                return await updateGroupedNotification(existingNotification, data, io);
            }
        }

        // Create new notification
        const notification = await Notification.create({
            user: userId,
            type,
            title,
            message,
            data,
            actors: data.actorId ? [{
                actorId: data.actorId.toString(),
                actorName: data.actorName,
                actorAvatar: data.actorAvatar,
                reactedAt: new Date()
            }] : [],
            actorCount: data.actorId ? 1 : 0
        });

        console.log(`📬 In-app notification created for user ${userId}: ${type}`);

        // Emit real-time notification via Socket.IO (for open apps)
        if (io) {
            const notificationData = {
                _id: notification._id,
                title: notification.title,
                message: notification.message,
                type: notification.type,
                createdAt: notification.createdAt,
                isRead: notification.isRead,
                data: notification.data,
                actors: notification.actors,
                actorCount: notification.actorCount
            };

            // Emit to specific user's room (not broadcast to all!)
            io.to(`user:${userId}`).emit('newNotification', notificationData);
            console.log(`📡 Real-time notification emitted to user ${userId}`);
        }

        // Send FCM push notification (for closed apps)
        try {
            await sendToUser(
                userId,
                {
                    title: title,
                    body: message
                },
                {
                    type: type,
                    notificationId: notification._id.toString(),
                    actorCount: notification.actorCount,
                    ...data
                }
            );
            console.log(`📲 Push notification sent to user ${userId}`);
        } catch (fcmError) {
            // Don't fail the entire notification if push fails
            console.error('Push notification failed (non-critical):', fcmError.message);
        }

        return notification;
    } catch (error) {
        console.error('Error creating notification:', error.message);
        return null;
    }
};

/**
 * Find existing notification that can be grouped
 */
const findGroupableNotification = async (userId, type, data) => {
    const targetKey = type === 'comment_reaction' ? 'commentId' : 'parentCommentId';
    const targetId = data[targetKey];

    if (!targetId) return null;

    // Find recent notification (within time window) for same target
    const cutoffTime = new Date(Date.now() - GROUPING_CONFIG.timeWindow);

    const query = {
        user: userId,
        type: type,
        createdAt: { $gte: cutoffTime }
    };
    query[`data.${targetKey}`] = targetId;

    return await Notification.findOne(query).sort({ createdAt: -1 });
};

/**
 * Update grouped notification with new actor
 */
const updateGroupedNotification = async (notification, data, io) => {
    const actorId = data.actorId?.toString();
    const actorName = data.actorName;
    const actorAvatar = data.actorAvatar;

    if (!actorId || !actorName) {
        return notification;
    }

    // Check if actor already in list (prevent duplicates)
    const actorExists = notification.actors.some(a => a.actorId === actorId);

    if (!actorExists) {
        // Add new actor (limit array size)
        if (notification.actors.length < GROUPING_CONFIG.maxActorsInList) {
            notification.actors.push({
                actorId,
                actorName,
                actorAvatar,
                reactedAt: new Date()
            });
        }
        notification.actorCount = notification.actors.length;
    }

    // Update title and message
    notification.title = buildGroupedTitle(notification.type, notification.actors);
    notification.message = buildGroupedMessage(notification.type, notification.actors, data);
    notification.isRead = false; // Mark as unread again
    notification.updatedAt = new Date();

    // Update data with latest info
    if (data.commentText) notification.data.commentText = data.commentText;
    if (data.replyText) notification.data.replyText = data.replyText;
    if (data.reactionType) notification.data.reactionType = data.reactionType;

    await notification.save();

    console.log(`📬 Grouped notification updated for user ${notification.user}: ${notification.type} (${notification.actorCount} actors)`);

    // Emit via Socket.IO
    if (io) {
        io.to(`user:${notification.user}`).emit('newNotification', {
            _id: notification._id,
            title: notification.title,
            message: notification.message,
            type: notification.type,
            createdAt: notification.createdAt,
            isRead: notification.isRead,
            data: notification.data,
            actors: notification.actors,
            actorCount: notification.actorCount
        });
        console.log(`📡 Grouped notification emitted to user ${notification.user}`);
    }

    // Send FCM push
    try {
        await sendToUser(
            notification.user.toString(),
            {
                title: notification.title,
                body: notification.message
            },
            {
                type: notification.type,
                notificationId: notification._id.toString(),
                actorCount: notification.actorCount,
                ...notification.data
            }
        );
        console.log(`📲 Grouped push notification sent to user ${notification.user}`);
    } catch (fcmError) {
        console.error('Push notification failed (non-critical):', fcmError.message);
    }

    return notification;
};

/**
 * Build grouped notification title
 */
const buildGroupedTitle = (type, actors) => {
    const count = actors.length;

    if (count === 0) {
        return type === 'comment_reaction' ? 'Someone reacted to your comment' : 'Someone replied to your comment';
    }

    if (count === 1) {
        const name = actors[0].actorName;
        return type === 'comment_reaction'
            ? `${name} reacted to your comment`
            : `${name} replied to your comment`;
    }

    if (count === 2) {
        const name1 = actors[0].actorName;
        const name2 = actors[1].actorName;
        return type === 'comment_reaction'
            ? `${name1} and ${name2} reacted to your comment`
            : `${name1} and ${name2} replied to your comment`;
    }

    // 3 or more actors
    const name1 = actors[0].actorName;
    const name2 = actors[1].actorName;
    const others = count - 2;
    return type === 'comment_reaction'
        ? `${name1}, ${name2}, and ${others} ${others === 1 ? 'other' : 'others'} reacted to your comment`
        : `${name1}, ${name2}, and ${others} ${others === 1 ? 'other' : 'others'} replied to your comment`;
};

/**
 * Build grouped notification message
 */
const buildGroupedMessage = (type, actors, data) => {
    if (type === 'comment_reaction') {
        const reactionEmojis = {
            like: '👍', love: '❤️', haha: '😂',
            wow: '😮', sad: '😢', angry: '😠'
        };
        const emoji = reactionEmojis[data.reactionType] || '👍';
        const commentText = data.commentText || 'your comment';
        const preview = commentText.length > 50 ? commentText.substring(0, 50) + '...' : commentText;
        return `${emoji} "${preview}"`;
    }

    if (type === 'comment_reply') {
        const replyText = data.replyText || 'replied to your comment';
        const preview = replyText.length > 100 ? replyText.substring(0, 100) + '...' : replyText;
        return `💬 ${preview}`;
    }

    return '';
};

/**
 * Get notifications for a user
 * @param {string} userId - User ID
 * @param {number} limit - Maximum number of notifications to return
 * @param {number} skip - Number of notifications to skip (for pagination)
 * @returns {Promise<Array>} Array of notifications
 */
const getUserNotifications = async (userId, limit = 50, skip = 0) => {
    try {
        const notifications = await Notification.find({ user: userId })
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit);
        return notifications;
    } catch (error) {
        console.error('Error fetching notifications:', error.message);
        return [];
    }
};

/**
 * Mark notification as read
 * @param {string} notificationId - Notification ID
 * @param {string} userId - User ID (for security)
 * @returns {Promise<boolean>} Success status
 */
const markAsRead = async (notificationId, userId) => {
    try {
        const notification = await Notification.findOneAndUpdate(
            { _id: notificationId, user: userId },
            { isRead: true },
            { new: true }
        );
        return !!notification;
    } catch (error) {
        console.error('Error marking notification as read:', error.message);
        return false;
    }
};

/**
 * Mark all notifications as read for a user
 * @param {string} userId - User ID
 * @returns {Promise<boolean>} Success status
 */
const markAllAsRead = async (userId) => {
    try {
        await Notification.updateMany(
            { user: userId, isRead: false },
            { isRead: true }
        );
        return true;
    } catch (error) {
        console.error('Error marking all notifications as read:', error.message);
        return false;
    }
};

/**
 * Delete all notifications for a user
 * @param {string} userId - User ID
 * @returns {Promise<boolean>} Success status
 */
const clearAllNotifications = async (userId) => {
    try {
        await Notification.deleteMany({ user: userId });
        return true;
    } catch (error) {
        console.error('Error clearing notifications:', error.message);
        return false;
    }
};

/**
 * Get unread notification count
 * @param {string} userId - User ID
 * @returns {Promise<number>} Count of unread notifications
 */
const getUnreadCount = async (userId) => {
    try {
        const count = await Notification.countDocuments({ user: userId, isRead: false });
        return count;
    } catch (error) {
        console.error('Error getting unread count:', error.message);
        return 0;
    }
};

module.exports = {
    createNotification,
    getUserNotifications,
    markAsRead,
    markAllAsRead,
    clearAllNotifications,
    getUnreadCount
};
