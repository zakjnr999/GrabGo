const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const prisma = require('../config/prisma');

/**
 * @route   GET /api/users/settings/notifications
 * @desc    Get user's notification settings
 * @access  Private
 */
router.get('/settings/notifications', protect, async (req, res) => {
    try {
        const settings = await prisma.userNotificationSettings.findUnique({
            where: { userId: req.user.id }
        });

        if (!settings) {
            // If settings don't exist yet, return defaults
            return res.json({
                success: true,
                notificationSettings: {
                    chatMessages: true,
                    orderUpdates: true,
                    promoNotifications: true,
                    commentReplies: true,
                    commentReactions: true,
                    referralUpdates: true,
                    paymentUpdates: true,
                    deliveryUpdates: true,
                    systemUpdates: true,
                    cartReminders: true,
                    favoritesReminders: true,
                    reorderSuggestions: true,
                    reengagementReminders: true
                }
            });
        }

        res.json({
            success: true,
            notificationSettings: settings
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

        // Valid notification settings keys
        const validSettingsKeys = [
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
        const updateData = {};
        for (const [key, value] of Object.entries(settings)) {
            if (validSettingsKeys.includes(key) && typeof value === 'boolean') {
                updateData[key] = value;
            }
        }

        if (Object.keys(updateData).length === 0) {
            return res.status(400).json({
                success: false,
                message: 'No valid settings provided'
            });
        }

        // Update or create notification settings
        const updatedSettings = await prisma.userNotificationSettings.upsert({
            where: { userId: req.user.id },
            update: updateData,
            create: {
                userId: req.user.id,
                ...updateData
            }
        });

        console.log(`✅ Notification settings updated for user ${req.user.id}`);

        res.json({
            success: true,
            message: 'Notification settings updated successfully',
            notificationSettings: updatedSettings
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
