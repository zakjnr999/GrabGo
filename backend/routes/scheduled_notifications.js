const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/auth');
const {
    createScheduledNotification,
    cancelScheduledNotification,
    updateScheduledNotification,
    getScheduledNotifications,
    getScheduledNotificationById,
    getScheduledNotificationStats
} = require('../services/scheduled_notification_service');

// @route   POST /api/scheduled-notifications
// @desc    Create a scheduled notification
// @access  Private (Admin only)
router.post('/', protect, authorize('admin'), async (req, res) => {
    try {
        const {
            scheduledFor,
            timezone,
            type,
            title,
            message,
            data,
            targetType,
            targetUsers,
            targetSegment,
            isRecurring,
            recurrencePattern
        } = req.body;

        // Validate required fields
        if (!scheduledFor || !type || !title || !message) {
            return res.status(400).json({
                success: false,
                message: 'Missing required fields: scheduledFor, type, title, message'
            });
        }

        // Validate field lengths
        if (title.length > 200) {
            return res.status(400).json({
                success: false,
                message: 'Title must be 200 characters or less'
            });
        }

        if (message.length > 500) {
            return res.status(400).json({
                success: false,
                message: 'Message must be 500 characters or less'
            });
        }

        // Validate notification type
        const validTypes = ['order', 'promo', 'update', 'system', 'comment_reply', 'comment_reaction', 'referral_completed', 'payment_confirmed', 'delivery_arriving', 'milestone_bonus'];
        if (!validTypes.includes(type)) {
            return res.status(400).json({
                success: false,
                message: `Invalid notification type. Must be one of: ${validTypes.join(', ')}`
            });
        }

        // Validate targetType
        const validTargetTypes = ['user', 'segment', 'all'];
        if (targetType && !validTargetTypes.includes(targetType)) {
            return res.status(400).json({
                success: false,
                message: `Invalid target type. Must be one of: ${validTargetTypes.join(', ')}`
            });
        }

        const scheduledNotification = await createScheduledNotification({
            scheduledFor,
            timezone,
            type,
            title,
            message,
            notificationData: data,
            targetType,
            targetUsers,
            targetSegment,
            isRecurring,
            recurrencePattern,
            createdBy: req.user._id
        });

        res.status(201).json({
            success: true,
            message: 'Scheduled notification created successfully',
            scheduledNotification
        });
    } catch (error) {
        console.error('Create scheduled notification error:', error);
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to create scheduled notification'
        });
    }
});

// @route   GET /api/scheduled-notifications
// @desc    Get all scheduled notifications with filters
// @access  Private (Admin only)
router.get('/', protect, authorize('admin'), async (req, res) => {
    try {
        const {
            status,
            type,
            scheduledAfter,
            scheduledBefore,
            page = 1,
            limit = 50
        } = req.query;

        const filters = {};
        if (status) {
            // Validate status
            const validStatuses = ['pending', 'sent', 'cancelled', 'failed'];
            if (!validStatuses.includes(status)) {
                return res.status(400).json({
                    success: false,
                    message: `Invalid status. Must be one of: ${validStatuses.join(', ')}`
                });
            }
            filters.status = status;
        }
        if (type) {
            // Validate type
            const validTypes = ['order', 'promo', 'update', 'system', 'comment_reply', 'comment_reaction', 'referral_completed', 'payment_confirmed', 'delivery_arriving', 'milestone_bonus'];
            if (!validTypes.includes(type)) {
                return res.status(400).json({
                    success: false,
                    message: `Invalid type. Must be one of: ${validTypes.join(', ')}`
                });
            }
            filters.type = type;
        }
        if (scheduledAfter) filters.scheduledAfter = scheduledAfter;
        if (scheduledBefore) filters.scheduledBefore = scheduledBefore;

        // Validate and sanitize pagination
        const pageNum = Math.max(1, parseInt(page) || 1);
        const limitNum = Math.min(100, Math.max(1, parseInt(limit) || 50)); // Max 100 per page
        const skip = (pageNum - 1) * limitNum;

        const notifications = await getScheduledNotifications(
            filters,
            limitNum,
            skip
        );

        res.json({
            success: true,
            notifications,
            pagination: {
                page: pageNum,
                limit: limitNum
            }
        });
    } catch (error) {
        console.error('Get scheduled notifications error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch scheduled notifications'
        });
    }
});

// @route   GET /api/scheduled-notifications/stats
// @desc    Get scheduled notification statistics
// @access  Private (Admin only)
router.get('/stats', protect, authorize('admin'), async (req, res) => {
    try {
        const stats = await getScheduledNotificationStats();

        res.json({
            success: true,
            stats
        });
    } catch (error) {
        console.error('Get stats error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch statistics'
        });
    }
});

// @route   GET /api/scheduled-notifications/:id
// @desc    Get single scheduled notification
// @access  Private (Admin only)
router.get('/:id', protect, authorize('admin'), async (req, res) => {
    try {
        const notification = await getScheduledNotificationById(req.params.id);

        if (!notification) {
            return res.status(404).json({
                success: false,
                message: 'Scheduled notification not found'
            });
        }

        res.json({
            success: true,
            notification
        });
    } catch (error) {
        console.error('Get scheduled notification error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch scheduled notification'
        });
    }
});

// @route   PATCH /api/scheduled-notifications/:id
// @desc    Update a scheduled notification
// @access  Private (Admin only)
router.patch('/:id', protect, authorize('admin'), async (req, res) => {
    try {
        const updates = req.body;
        const notification = await updateScheduledNotification(
            req.params.id,
            updates,
            req.user._id
        );

        if (!notification) {
            return res.status(404).json({
                success: false,
                message: 'Scheduled notification not found or cannot be updated'
            });
        }

        res.json({
            success: true,
            message: 'Scheduled notification updated successfully',
            notification
        });
    } catch (error) {
        console.error('Update scheduled notification error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update scheduled notification'
        });
    }
});

// @route   DELETE /api/scheduled-notifications/:id
// @desc    Cancel a scheduled notification
// @access  Private (Admin only)
router.delete('/:id', protect, authorize('admin'), async (req, res) => {
    try {
        const success = await cancelScheduledNotification(
            req.params.id,
            req.user._id
        );

        if (!success) {
            return res.status(404).json({
                success: false,
                message: 'Scheduled notification not found or cannot be cancelled'
            });
        }

        res.json({
            success: true,
            message: 'Scheduled notification cancelled successfully'
        });
    } catch (error) {
        console.error('Cancel scheduled notification error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to cancel scheduled notification'
        });
    }
});

module.exports = router;
