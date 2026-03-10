const Notification = require('../models/Notification');
const { sendToUser } = require('./fcm_service');
const { checkRateLimit, validateNotificationInput } = require('../utils/validation');
const { createScopedLogger } = require('../utils/logger');
const metrics = require('../utils/metrics');

const console = createScopedLogger('notification_service');

// Grouping configuration
const GROUPING_CONFIG = {
    enabled: true,
    timeWindow: 12 * 60 * 60 * 1000, // 12 hours
    groupableTypes: ['comment_reaction', 'comment_reply'],
    maxActorsInList: 50
};

// Text truncation limits for consistency
const TRUNCATION_LIMITS = {
    COMMENT_TEXT: 50,
    REPLY_TEXT: 100,
    MESSAGE_PREVIEW: 100,
    TITLE: 200,
    MESSAGE: 1000
};

/**
 * Prepare FCM data payload by converting all values to strings
 */
const prepareFCMData = (data) => {
    const fcmData = {};
    for (const [key, value] of Object.entries(data)) {
        if (value !== null && value !== undefined) {
            if (typeof value === 'object' && !Array.isArray(value)) {
                fcmData[key] = JSON.stringify(value);
            } else if (typeof value === 'boolean') {
                fcmData[key] = value ? 'true' : 'false';
            } else {
                fcmData[key] = String(value);
            }
        }
    }
    return fcmData;
};

/**
 * Create in-app notification record and emit via Socket.IO
 */
const createNotification = async (
    userId,
    type,
    title,
    message,
    data = {},
    io = null,
    options = {}
) => {
    try {
        const shouldSendPush = options?.sendPush !== false;

        // SECURITY: Validate and sanitize all inputs
        const validated = validateNotificationInput(userId, type, title, message, data);
        userId = validated.userId;
        type = validated.type;
        title = validated.title;
        message = validated.message;
        data = validated.data;

        // SECURITY: Check rate limits (now async for Redis support)
        const withinRateLimit = await checkRateLimit(userId, type);
        if (!withinRateLimit) {
            console.warn(`⚠️ Rate limit exceeded for user ${userId}, type ${type}`);
            metrics.recordNotificationEvent({ channel: 'in_app', result: 'skipped' });
            return null;
        }

        // Check for existing notification to group
        if (GROUPING_CONFIG.enabled && GROUPING_CONFIG.groupableTypes.includes(type)) {
            const existingNotification = await findGroupableNotification(userId, type, data);

            if (existingNotification) {
                return await updateGroupedNotification(existingNotification, data, io);
            }
        }

        // Create new notification in MongoDB
        const notificationData = {
            user: userId,
            type,
            title,
            message,
            data,
            actorCount: data.actorId ? 1 : 0,
            actors: data.actorId ? [{
                actorId: String(data.actorId),
                actorName: data.actorName,
                actorAvatar: data.actorAvatar,
                reactedAt: new Date()
            }] : []
        };

        const notification = await Notification.create(notificationData);
        metrics.recordNotificationEvent({ channel: 'in_app', result: 'success' });

        console.log(`📬 In-app notification created in MongoDB for user ${userId}: ${type}`);

        // Emit real-time notification via Socket.IO
        if (io) {
            io.to(`user:${userId}`).emit('newNotification', notification);
            console.log(`📡 Real-time notification emitted to user ${userId}`);
        }

        // Send FCM push notification (optional for callers that already sent one)
        if (shouldSendPush) {
            try {
                await sendToUser(
                    userId,
                    { title: title, body: message },
                    prepareFCMData({
                        type: type,
                        notificationId: notification._id.toString(),
                        actorCount: notification.actorCount,
                        ...data
                    })
                );
            } catch (fcmError) {
                console.error(`❌ Push notification error for user ${userId}:`, fcmError.message);
            }
        }

        return notification;
    } catch (error) {
        console.error('❌ Error creating notification:', error);
        metrics.recordNotificationEvent({ channel: 'in_app', result: 'failure' });
        return null;
    }
};

/**
 * Find existing notification that can be grouped using MongoDB query
 */
const findGroupableNotification = async (userId, type, data) => {
    const targetKey = type === 'comment_reaction' ? 'commentId' : 'parentCommentId';
    const targetId = data[targetKey];

    if (!targetId) return null;

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
 * Update grouped notification in MongoDB
 */
const updateGroupedNotification = async (notification, data, io) => {
    const actorId = data.actorId?.toString();
    const actorName = data.actorName;
    const actorAvatar = data.actorAvatar;

    if (!actorId || !actorName) {
        return notification;
    }

    try {
        // Check if actor already in list
        const actorExists = notification.actors.some(a => a.actorId === actorId);
        if (actorExists) {
            console.log(`Actor ${actorId} already exists for notification ${notification._id}. Skipping.`);
            return notification;
        }

        const currentActors = notification.actors.map(a => ({
            actorId: a.actorId,
            actorName: a.actorName,
            actorAvatar: a.actorAvatar,
            reactedAt: a.reactedAt
        }));

        const updatedActorsForTitleMessage = [
            { actorId, actorName, actorAvatar, reactedAt: new Date() },
            ...currentActors
        ].slice(0, GROUPING_CONFIG.maxActorsInList);

        const newTitle = buildGroupedTitle(notification.type, updatedActorsForTitleMessage);
        const newMessage = buildGroupedMessage(notification.type, updatedActorsForTitleMessage, data);

        // Prepare updated data object
        const updatedDataFields = { ...notification.data };
        if (data.commentText) updatedDataFields.commentText = data.commentText;
        if (data.replyText) updatedDataFields.replyText = data.replyText;
        if (data.reactionType) updatedDataFields.reactionType = data.reactionType;

        // Perform update in MongoDB
        const updatedNotification = await Notification.findByIdAndUpdate(
            notification._id,
            {
                $set: {
                    isRead: false,
                    title: newTitle,
                    message: newMessage,
                    data: updatedDataFields,
                    updatedAt: new Date()
                },
                $inc: { actorCount: 1 },
                $push: {
                    actors: {
                        $each: [{
                            actorId,
                            actorName,
                            actorAvatar,
                            reactedAt: new Date()
                        }],
                        $position: 0,
                        $slice: GROUPING_CONFIG.maxActorsInList
                    }
                }
            },
            { new: true }
        );

        console.log(`📬 Grouped notification updated in MongoDB for user ${updatedNotification.user}: ${updatedNotification.type}`);

        if (io) {
            io.to(`user:${updatedNotification.user}`).emit('newNotification', updatedNotification);
        }

        try {
            await sendToUser(
                updatedNotification.user,
                { title: updatedNotification.title, body: updatedNotification.message },
                prepareFCMData({
                    type: updatedNotification.type,
                    notificationId: updatedNotification._id.toString(),
                    actorCount: updatedNotification.actorCount,
                    ...updatedNotification.data
                })
            );
        } catch (fcmError) {
            console.error('Push notification failed (grouped):', fcmError.message);
        }

        return updatedNotification;
    } catch (error) {
        console.error('Error updating grouped notification:', error.message);
        return notification;
    }
};

/**
 * Build grouped notification title
 */
const buildGroupedTitle = (type, actors) => {
    const count = actors.length;
    if (count === 0) return type === 'comment_reaction' ? 'Someone reacted to your comment' : 'Someone replied to your comment';
    if (count === 1) return type === 'comment_reaction' ? `${actors[0].actorName} reacted to your comment` : `${actors[0].actorName} replied to your comment`;
    if (count === 2) return type === 'comment_reaction' ? `${actors[0].actorName} and ${actors[1].actorName} reacted to your comment` : `${actors[0].actorName} and ${actors[1].actorName} replied to your comment`;

    const others = count - 2;
    return type === 'comment_reaction'
        ? `${actors[0].actorName}, ${actors[1].actorName}, and ${others} ${others === 1 ? 'other' : 'others'} reacted to your comment`
        : `${actors[0].actorName}, ${actors[1].actorName}, and ${others} ${others === 1 ? 'other' : 'others'} replied to your comment`;
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
        const preview = commentText.length > TRUNCATION_LIMITS.COMMENT_TEXT
            ? commentText.substring(0, TRUNCATION_LIMITS.COMMENT_TEXT) + '...'
            : commentText;
        return `${emoji} "${preview}"`;
    }

    if (type === 'comment_reply') {
        const replyText = data.replyText || 'replied to your comment';
        const preview = replyText.length > TRUNCATION_LIMITS.REPLY_TEXT
            ? replyText.substring(0, TRUNCATION_LIMITS.REPLY_TEXT) + '...'
            : replyText;
        return `💬 ${preview}`;
    }

    return '';
};

/**
 * Get notifications for a user from MongoDB
 */
const getUserNotifications = async (userId, limit = 50, skip = 0) => {
    try {
        return await Notification.find({ user: userId })
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limit);
    } catch (error) {
        console.error('Error fetching notifications:', error.message);
        return [];
    }
};

/**
 * Mark notification as read in MongoDB
 */
const markAsRead = async (notificationId, userId) => {
    try {
        const notification = await Notification.findOneAndUpdate(
            { _id: notificationId, user: userId },
            { $set: { isRead: true } },
            { new: true }
        );
        return !!notification;
    } catch (error) {
        console.error('Error marking notification as read:', error.message);
        return false;
    }
};

/**
 * Mark all notifications as read for a user in MongoDB
 */
const markAllAsRead = async (userId) => {
    try {
        await Notification.updateMany(
            { user: userId, isRead: false },
            { $set: { isRead: true } }
        );
        return true;
    } catch (error) {
        console.error('Error marking all notifications as read:', error.message);
        return false;
    }
};

/**
 * Delete all notifications for a user in MongoDB
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
 * Get unread notification count from MongoDB
 */
const getUnreadCount = async (userId) => {
    try {
        return await Notification.countDocuments({ user: userId, isRead: false });
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
