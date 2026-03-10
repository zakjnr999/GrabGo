const express = require('express');
const { protect } = require('../middleware/auth');
const { createNotification } = require('../services/notification_service');
const { getIO } = require('../utils/socket');
const { sendBrandedPreviewEmail } = require('../utils/emailService');
const { createScopedLogger } = require('../utils/logger');

const router = express.Router();
const console = createScopedLogger('test_route');

/**
 * @route   POST /api/test/notification-public/:userId
 * @desc    Public test endpoint (for testing only - remove in production!)
 * @access  Public
 */
router.post('/notification-public/:userId', async (req, res) => {
    if (process.env.NODE_ENV === 'production') {
        return res.status(404).json({
            success: false,
            message: 'Route not found'
        });
    }
    try {
        const { userId } = req.params;
        const { status = 'confirmed' } = req.body;
        const io = getIO();
        
        if (!io) {
            return res.status(500).json({
                success: false,
                message: 'Socket.IO not initialized'
            });
        }

        const statusEmojis = {
            confirmed: '✅',
            preparing: '🍳',
            ready: '📦',
            picked_up: '🚴',
            on_the_way: '🛣️',
            delivered: '✅',
            cancelled: '❌'
        };

        const statusMessages = {
            confirmed: 'Your order has been confirmed!',
            preparing: 'Your order is being prepared.',
            ready: 'Your order is ready for pickup!',
            picked_up: 'Your order has been picked up by the rider.',
            on_the_way: 'Your order is on the way!',
            delivered: 'Your order has been delivered. Enjoy!',
            cancelled: 'Your order has been cancelled.'
        };

        const emoji = statusEmojis[status] || '📦';
        const message = statusMessages[status] || `Order status: ${status}`;
        const orderNumber = `TEST-${Date.now()}`;

        // Create order status notification
        const notification = await createNotification(
            userId,
            'order',
            `${emoji} Order #${orderNumber}`,
            message,
            {
                orderId: 'test-order-id',
                orderNumber,
                status,
                route: '/orders/test'
            },
            io
        );

        res.json({
            success: true,
            message: `${status.toUpperCase()} notification sent! Check your app - it should appear instantly.`,
            notification: {
                id: notification._id,
                title: notification.title,
                message: notification.message,
                status,
                createdAt: notification.createdAt
            }
        });
    } catch (error) {
        console.error('Test notification error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to send test notification'
        });
    }
});

/**
 * @route   POST /api/test/notification
 * @desc    Test endpoint to trigger a notification (for testing WebSocket delivery)
 * @access  Private
 */
router.post('/notification', protect, async (req, res) => {
    try {
        const io = getIO();

        if (!io) {
            return res.status(500).json({
                success: false,
                message: 'Socket.IO not initialized'
            });
        }

        // Create a test notification
        const notification = await createNotification(
            req.user._id,
            'order',
            '🧪 Test Notification',
            'This is a test notification to verify real-time WebSocket delivery!',
            {
                test: true,
                timestamp: new Date().toISOString()
            },
            io
        );

        res.json({
            success: true,
            message: 'Test notification sent! Check your app - it should appear instantly without refresh.',
            notification: {
                id: notification._id,
                title: notification.title,
                message: notification.message,
                createdAt: notification.createdAt
            }
        });
    } catch (error) {
        console.error('Test notification error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to send test notification'
        });
    }
});

/**
 * @route   POST /api/test/order-notification
 * @desc    Test endpoint to simulate order status notification
 * @access  Private
 */
router.post('/order-notification', protect, async (req, res) => {
    try {
        const { status = 'confirmed' } = req.body;
        const io = getIO();

        if (!io) {
            return res.status(500).json({
                success: false,
                message: 'Socket.IO not initialized'
            });
        }

        const statusEmojis = {
            confirmed: '✅',
            preparing: '🍳',
            ready: '📦',
            picked_up: '🚴',
            on_the_way: '🛣️',
            delivered: '✅',
            cancelled: '❌'
        };

        const statusMessages = {
            confirmed: 'Your order has been confirmed!',
            preparing: 'Your order is being prepared.',
            ready: 'Your order is ready for pickup!',
            picked_up: 'Your order has been picked up by the rider.',
            on_the_way: 'Your order is on the way!',
            delivered: 'Your order has been delivered. Enjoy!',
            cancelled: 'Your order has been cancelled.'
        };

        const emoji = statusEmojis[status] || '📦';
        const message = statusMessages[status] || `Order status: ${status}`;
        const orderNumber = `TEST-${Date.now()}`;

        // Create order status notification
        const notification = await createNotification(
            req.user._id,
            'order',
            `${emoji} Order #${orderNumber}`,
            message,
            {
                orderId: 'test-order-id',
                orderNumber,
                status,
                route: '/orders/test'
            },
            io
        );

        res.json({
            success: true,
            message: `${status.toUpperCase()} notification sent! Check your app - it should appear instantly.`,
            notification: {
                id: notification._id,
                title: notification.title,
                message: notification.message,
                status,
                createdAt: notification.createdAt
            }
        });
    } catch (error) {
        console.error('Test order notification error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to send test notification'
        });
    }
});

/**
 * @route   POST /api/test/email-preview
 * @desc    Send branded email preview to authenticated user (or provided email)
 * @access  Private
 */
router.post('/email-preview', protect, async (req, res) => {
    if (process.env.NODE_ENV === 'production' && process.env.ENABLE_TEST_EMAIL_ENDPOINT !== 'true') {
        return res.status(404).json({
            success: false,
            message: 'Route not found'
        });
    }

    try {
        const { email, username } = req.body || {};
        const targetEmail = (email || req.user.email || '').trim().toLowerCase();
        const previewName = (username || req.user.username || 'there').trim();

        if (!targetEmail) {
            return res.status(400).json({
                success: false,
                message: 'Target email is required'
            });
        }

        const result = await sendBrandedPreviewEmail(targetEmail, previewName);

        if (!result?.success) {
            return res.status(500).json({
                success: false,
                message: result?.error || result?.message || 'Failed to send preview email'
            });
        }

        return res.json({
            success: true,
            message: 'Preview email sent successfully',
            to: targetEmail,
            messageId: result.messageId || null,
        });
    } catch (error) {
        console.error('Preview email test error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to send preview email'
        });
    }
});

/**
 * @route   POST /api/test/referral-notification
 * @desc    Test endpoint to simulate referral notification
 * @access  Private
 */
router.post('/referral-notification', protect, async (req, res) => {
    try {
        const io = getIO();

        if (!io) {
            return res.status(500).json({
                success: false,
                message: 'Socket.IO not initialized'
            });
        }

        // Create referral notification
        const notification = await createNotification(
            req.user._id,
            'referral_completed',
            '🎉 Referral Success!',
            'Your friend completed their first order. You earned GHS 10.00!',
            {
                refereeName: 'Test Friend',
                rewardAmount: 10.00,
                route: '/referral'
            },
            io
        );

        res.json({
            success: true,
            message: 'Referral notification sent! Check your app - it should appear instantly.',
            notification: {
                id: notification._id,
                title: notification.title,
                message: notification.message,
                createdAt: notification.createdAt
            }
        });
    } catch (error) {
        console.error('Test referral notification error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to send test notification'
        });
    }
});

module.exports = router;
