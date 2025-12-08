const Notification = require('../models/Notification');

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
        const notification = await Notification.create({
            user: userId,
            type,
            title,
            message,
            data
        });

        console.log(`📬 In-app notification created for user ${userId}: ${type}`);

        // Emit real-time notification via Socket.IO
        if (io) {
            const notificationData = {
                _id: notification._id,
                title: notification.title,
                message: notification.message,
                type: notification.type,
                createdAt: notification.createdAt,
                isRead: notification.isRead,
                data: notification.data
            };

            // Emit to specific user's room (not broadcast to all!)
            io.to(`user:${userId}`).emit('newNotification', notificationData);
            console.log(`📡 Real-time notification emitted to user ${userId}`);
        }

        return notification;
    } catch (error) {
        console.error('Error creating notification:', error.message);
        return null;
    }
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
