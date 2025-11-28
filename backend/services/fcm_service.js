const admin = require('firebase-admin');
const User = require('../models/User');

// Initialize Firebase Admin SDK
let firebaseInitialized = false;

const initializeFirebase = () => {
    if (firebaseInitialized) return;

    try {
        // Check if service account credentials are provided
        if (process.env.FIREBASE_SERVICE_ACCOUNT) {
            const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });
            firebaseInitialized = true;
            console.log('✅ Firebase Admin SDK initialized');
        } else if (process.env.FIREBASE_PROJECT_ID) {
            // Use application default credentials (for Google Cloud environments)
            admin.initializeApp({
                projectId: process.env.FIREBASE_PROJECT_ID,
            });
            firebaseInitialized = true;
            console.log('✅ Firebase Admin SDK initialized with default credentials');
        } else {
            console.warn('⚠️ Firebase credentials not configured. Push notifications disabled.');
        }
    } catch (error) {
        console.error('❌ Failed to initialize Firebase:', error.message);
    }
};

// Initialize on module load
initializeFirebase();

/**
 * Register or update FCM token for a user
 * @param {string} userId - User ID
 * @param {string} token - FCM token
 * @param {string} deviceId - Unique device identifier
 * @param {string} platform - 'android', 'ios', or 'web'
 */
const registerToken = async (userId, token, deviceId = null, platform = 'android') => {
    try {
        const user = await User.findById(userId);
        if (!user) {
            throw new Error('User not found');
        }

        // Remove any existing token with the same deviceId or token value
        user.fcmTokens = user.fcmTokens.filter(t =>
            t.token !== token && (deviceId ? t.deviceId !== deviceId : true)
        );

        // Add the new token
        user.fcmTokens.push({
            token,
            deviceId,
            platform,
            createdAt: new Date(),
            updatedAt: new Date(),
        });

        // Keep only the last 5 tokens per user (multiple devices)
        if (user.fcmTokens.length > 5) {
            user.fcmTokens = user.fcmTokens.slice(-5);
        }

        await user.save();
        console.log(`FCM token registered for user ${userId}`);
        return true;
    } catch (error) {
        console.error('Error registering FCM token:', error.message);
        return false;
    }
};

/**
 * Remove FCM token for a user (on logout)
 * @param {string} userId - User ID
 * @param {string} token - FCM token to remove
 */
const removeToken = async (userId, token) => {
    try {
        await User.findByIdAndUpdate(userId, {
            $pull: { fcmTokens: { token } }
        });
        console.log(`FCM token removed for user ${userId}`);
        return true;
    } catch (error) {
        console.error('Error removing FCM token:', error.message);
        return false;
    }
};

/**
 * Send push notification to a specific user
 * @param {string} userId - User ID to send notification to
 * @param {object} notification - { title, body, imageUrl? }
 * @param {object} data - Additional data payload
 */
const sendToUser = async (userId, notification, data = {}) => {
    if (!firebaseInitialized) {
        console.warn('Firebase not initialized, skipping push notification');
        return { success: false, reason: 'firebase_not_initialized' };
    }

    try {
        const user = await User.findById(userId).select('fcmTokens notificationSettings');
        if (!user || !user.fcmTokens || user.fcmTokens.length === 0) {
            return { success: false, reason: 'no_tokens' };
        }

        // Check notification settings
        if (data.type === 'chat_message' && !user.notificationSettings?.chatMessages) {
            return { success: false, reason: 'notifications_disabled' };
        }
        if (data.type === 'order_update' && !user.notificationSettings?.orderUpdates) {
            return { success: false, reason: 'notifications_disabled' };
        }

        const tokens = user.fcmTokens.map(t => t.token);
        const invalidTokens = [];

        // Send to all user's devices
        const message = {
            notification: {
                title: notification.title,
                body: notification.body,
                ...(notification.imageUrl && { imageUrl: notification.imageUrl }),
            },
            data: {
                ...data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                timestamp: new Date().toISOString(),
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: data.type === 'chat_message' ? 'chat_messages' : 'default',
                    priority: 'high',
                    defaultSound: true,
                    defaultVibrateTimings: true,
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        badge: 1,
                        contentAvailable: true,
                    },
                },
            },
        };

        const response = await admin.messaging().sendEachForMulticast({
            tokens,
            ...message,
        });

        // Track invalid tokens for cleanup
        response.responses.forEach((resp, idx) => {
            if (!resp.success) {
                const errorCode = resp.error?.code;
                if (
                    errorCode === 'messaging/invalid-registration-token' ||
                    errorCode === 'messaging/registration-token-not-registered'
                ) {
                    invalidTokens.push(tokens[idx]);
                }
            }
        });

        // Remove invalid tokens
        if (invalidTokens.length > 0) {
            await User.findByIdAndUpdate(userId, {
                $pull: { fcmTokens: { token: { $in: invalidTokens } } }
            });
            console.log(`Removed ${invalidTokens.length} invalid FCM tokens for user ${userId}`);
        }

        console.log(`Push notification sent to user ${userId}: ${response.successCount}/${tokens.length} succeeded`);

        return {
            success: response.successCount > 0,
            successCount: response.successCount,
            failureCount: response.failureCount,
        };
    } catch (error) {
        console.error('Error sending push notification:', error.message);
        return { success: false, reason: 'send_error', error: error.message };
    }
};

/**
 * Send chat message notification
 * @param {string} recipientId - User ID to receive notification
 * @param {string} senderName - Name of the message sender
 * @param {string} messagePreview - Preview of the message content
 * @param {string} chatId - Chat ID for navigation
 * @param {string} messageType - 'text', 'voice', or 'image'
 */
const sendChatNotification = async (recipientId, senderName, messagePreview, chatId, messageType = 'text') => {
    let body = messagePreview;
    if (messageType === 'voice') {
        body = '🎤 Voice message';
    } else if (messageType === 'image') {
        body = '📷 Photo';
    } else if (messagePreview && messagePreview.length > 100) {
        body = messagePreview.substring(0, 100) + '...';
    }

    return sendToUser(
        recipientId,
        {
            title: senderName,
            body,
        },
        {
            type: 'chat_message',
            chatId,
            senderId: recipientId,
            messageType,
        }
    );
};

/**
 * Send order update notification
 * @param {string} userId - User ID to receive notification
 * @param {string} orderId - Order ID
 * @param {string} orderNumber - Order number for display
 * @param {string} status - New order status
 * @param {string} message - Custom message (optional)
 */
const sendOrderNotification = async (userId, orderId, orderNumber, status, message = null) => {
    const statusMessages = {
        confirmed: 'Your order has been confirmed!',
        preparing: 'Your order is being prepared.',
        ready: 'Your order is ready for pickup!',
        picked_up: 'Your order has been picked up by the rider.',
        on_the_way: 'Your order is on the way!',
        delivered: 'Your order has been delivered. Enjoy!',
        cancelled: 'Your order has been cancelled.',
    };

    const body = message || statusMessages[status] || `Order status: ${status}`;

    return sendToUser(
        userId,
        {
            title: `Order #${orderNumber}`,
            body,
        },
        {
            type: 'order_update',
            orderId,
            orderNumber,
            status,
        }
    );
};

module.exports = {
    initializeFirebase,
    registerToken,
    removeToken,
    sendToUser,
    sendChatNotification,
    sendOrderNotification,
};
