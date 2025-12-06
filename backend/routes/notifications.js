const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const Notification = require('../models/Notification');
const {
    getUserNotifications,
    markAsRead,
    markAllAsRead,
    clearAllNotifications,
    getUnreadCount
} = require('../services/notification_service');

// @route   GET /api/notifications
// @desc    Get user notifications with pagination
// @access  Private
router.get('/', protect, async (req, res) => {
    try {
        // Validate and sanitize pagination parameters
        const page = Math.max(1, parseInt(req.query.page) || 1);
        const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 20));
        const skip = (page - 1) * limit;

        const notifications = await getUserNotifications(req.user._id, limit, skip);
        const total = await Notification.countDocuments({ user: req.user._id });
        const hasMore = skip + notifications.length < total;

        res.json({
            success: true,
            notifications,
            pagination: {
                page,
                limit,
                total,
                hasMore,
                totalPages: Math.ceil(total / limit)
            }
        });
    } catch (error) {
        console.error('Get notifications error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch notifications',
            error: error.message
        });
    }
});

// @route   GET /api/notifications/unread-count
// @desc    Get unread notification count
// @access  Private
router.get('/unread-count', protect, async (req, res) => {
    try {
        const count = await getUnreadCount(req.user._id);

        res.json({
            success: true,
            count
        });
    } catch (error) {
        console.error('Get unread count error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to get unread count',
            error: error.message
        });
    }
});

// @route   PATCH /api/notifications/:id/read
// @desc    Mark notification as read
// @access  Private
router.patch('/:id/read', protect, async (req, res) => {
    try {
        const success = await markAsRead(req.params.id, req.user._id);

        if (!success) {
            return res.status(404).json({
                success: false,
                message: 'Notification not found'
            });
        }

        res.json({
            success: true,
            message: 'Notification marked as read'
        });
    } catch (error) {
        console.error('Mark as read error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to mark notification as read',
            error: error.message
        });
    }
});

// @route   PATCH /api/notifications/read-all
// @desc    Mark all notifications as read
// @access  Private
router.patch('/read-all', protect, async (req, res) => {
    try {
        await markAllAsRead(req.user._id);

        res.json({
            success: true,
            message: 'All notifications marked as read'
        });
    } catch (error) {
        console.error('Mark all as read error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to mark all as read',
            error: error.message
        });
    }
});

// @route   DELETE /api/notifications
// @desc    Clear all notifications
// @access  Private
router.delete('/', protect, async (req, res) => {
    try {
        await clearAllNotifications(req.user._id);

        res.json({
            success: true,
            message: 'All notifications cleared'
        });
    } catch (error) {
        console.error('Clear notifications error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to clear notifications',
            error: error.message
        });
    }
});

module.exports = router;
