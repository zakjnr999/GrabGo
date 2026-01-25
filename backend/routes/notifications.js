const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const NotificationService = require('../services/notification_service');
const mongoose = require('mongoose');

// @route   GET /api/notifications
// @desc    Get user notifications with pagination (MongoDB)
// @access  Private
router.get('/', protect, async (req, res) => {
    try {
        const MAX_LIMIT = parseInt(process.env.NOTIFICATION_MAX_LIMIT) || 100;
        const page = Math.max(1, parseInt(req.query.page) || 1);
        const limit = Math.min(MAX_LIMIT, Math.max(1, parseInt(req.query.limit) || 20));
        const skip = (page - 1) * limit;

        const [notifications, total] = await Promise.all([
            NotificationService.getUserNotifications(req.user.id, limit, skip),
            NotificationService.getUnreadCount(req.user.id) // This is unread count, but for total count we might need another method or just countDocuments
        ]);

        // Actually total count should be all notifications
        const totalCount = await require('../models/Notification').countDocuments({ user: req.user.id });
        const hasMore = skip + notifications.length < totalCount;

        res.json({
            success: true,
            notifications,
            pagination: {
                page,
                limit,
                total: totalCount,
                hasMore,
                totalPages: Math.ceil(totalCount / limit)
            }
        });
    } catch (error) {
        console.error('Get notifications error:', error);
        res.status(500).json({ success: false, message: 'Failed to fetch notifications', error: error.message });
    }
});

// @route   GET /api/notifications/unread-count
router.get('/unread-count', protect, async (req, res) => {
    try {
        const count = await NotificationService.getUnreadCount(req.user.id);
        res.json({ success: true, count });
    } catch (error) {
        console.error('Get unread count error:', error);
        res.status(500).json({ success: false, message: 'Failed to get unread count', error: error.message });
    }
});

// @route   PATCH /api/notifications/:id/read
router.patch('/:id/read', protect, async (req, res) => {
    try {
        const success = await NotificationService.markAsRead(req.params.id, req.user.id);
        if (!success) {
            return res.status(404).json({ success: false, message: 'Notification not found' });
        }
        res.json({ success: true, message: 'Notification marked as read' });
    } catch (error) {
        console.error('Mark as read error:', error);
        res.status(500).json({ success: false, message: 'Failed to mark notification as read', error: error.message });
    }
});

// @route   PATCH /api/notifications/read-all
router.patch('/read-all', protect, async (req, res) => {
    try {
        await NotificationService.markAllAsRead(req.user.id);
        res.json({ success: true, message: 'All notifications marked as read' });
    } catch (error) {
        console.error('Mark all as read error:', error);
        res.status(500).json({ success: false, message: 'Failed to mark all as read', error: error.message });
    }
});

// @route   DELETE /api/notifications
router.delete('/', protect, async (req, res) => {
    try {
        await NotificationService.clearAllNotifications(req.user.id);
        res.json({ success: true, message: 'All notifications cleared' });
    } catch (error) {
        console.error('Clear notifications error:', error);
        res.status(500).json({ success: false, message: 'Failed to clear notifications', error: error.message });
    }
});

// @route   GET /api/notifications/health
router.get('/health', async (req, res) => {
    const health = {
        database: 'unknown',
        firebase: 'unknown',
        socketio: 'unknown',
        timestamp: new Date().toISOString()
    };

    try {
        // Check MongoDB connectivity tramite model
        await require('../models/Notification').findOne();
        health.database = 'healthy';
    } catch (e) {
        health.database = 'unhealthy';
        health.databaseError = e.message;
    }

    try {
        const admin = require('firebase-admin');
        health.firebase = admin.apps.length > 0 ? 'healthy' : 'not_initialized';
    } catch (e) {
        health.firebase = 'error';
    }

    const io = req.app.get('io');
    health.socketio = io ? 'healthy' : 'not_initialized';

    const isHealthy = health.database === 'healthy' && health.firebase === 'healthy' && health.socketio === 'healthy';
    res.status(isHealthy ? 200 : 503).json(health);
});

module.exports = router;
