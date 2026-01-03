const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const User = require('../models/User');

/**
 * @route   GET /api/users/settings/notifications
 * @desc    Get user's notification settings
 * @access  Private
 */
router.get('/settings/notifications', protect, async (req, res) => {
    try {
        const user = await User.findById(req.user._id).select('notificationSettings');

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        res.json({
            success: true,
            notificationSettings: user.notificationSettings
        });
    } catch (error) {
        console.error('Error fetching notification settings:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch notification settings',
            error: error.message
        });
    }
});

/**
 * @route   PATCH /api/users/settings/notifications
 * @desc    Update user's notification settings
 * @access  Private
 */
router.patch('/settings/notifications', protect, async (req, res) => {
    try {
        const { settings } = req.body;

        if (!settings || typeof settings !== 'object') {
            return res.status(400).json({
                success: false,
                message: 'Invalid settings format'
            });
        }

        // Valid notification settings
        const validSettings = [
            'chatMessages',
            'orderUpdates',
            'promoNotifications',
            'commentReplies',
            'commentReactions',
            'referralUpdates',
            'paymentUpdates',
            'deliveryUpdates',
            'systemUpdates',
            'cartReminders',
            'favoritesReminders',
            'reorderSuggestions',
            'reengagementReminders'
        ];

        // Build update object
        const updates = {};
        for (const [key, value] of Object.entries(settings)) {
            if (validSettings.includes(key) && typeof value === 'boolean') {
                updates[`notificationSettings.${key}`] = value;
            }
        }

        if (Object.keys(updates).length === 0) {
            return res.status(400).json({
                success: false,
                message: 'No valid settings provided'
            });
        }

        // Update user
        const user = await User.findByIdAndUpdate(
            req.user._id,
            { $set: updates },
            { new: true, runValidators: true }
        ).select('notificationSettings');

        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        console.log(`✅ Notification settings updated for user ${req.user._id}`);

        res.json({
            success: true,
            message: 'Notification settings updated successfully',
            notificationSettings: user.notificationSettings
        });
    } catch (error) {
        console.error('Error updating notification settings:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update notification settings',
            error: error.message
        });
    }
});

module.exports = router;
