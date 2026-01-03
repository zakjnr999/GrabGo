const admin = require('firebase-admin');
const User = require('../models/User');
const { validateFCMToken, validatePlatform, validateDeviceId } = require('../utils/validation');

// Text truncation limits (shared with notification_service.js)
const TRUNCATION_LIMITS = {
    COMMENT_TEXT: 50,
    REPLY_TEXT: 100,
    MESSAGE_PREVIEW: 100,
    TITLE: 200,
    MESSAGE: 1000
};

/**
 * Prepare FCM data payload by converting all values to strings
 * FCM requires all data values to be strings, otherwise notifications fail silently
 * @param {object} data - Data object to prepare
 * @returns {object} - Data object with all values as strings
 */
const prepareFCMData = (data) => {
    const fcmData = {};
    for (const [key, value] of Object.entries(data)) {
        if (value !== null && value !== undefined) {
            if (typeof value === 'object' && !Array.isArray(value)) {
                fcmData[key] = JSON.stringify(value);
            } else if (typeof value === 'boolean') {
                // Explicitly convert booleans to strings for consistency
                fcmData[key] = value ? 'true' : 'false';
            } else {
                fcmData[key] = String(value);
            }
        }
    }
    return fcmData;
};

/**
 * Get appropriate notification channel for a notification type
 * @param {string} type - Notification type
 * @returns {string} - Channel ID
 */
const getNotificationChannel = (type) => {
    const channelMap = {
        'chat_message': 'chat_messages',
        'order': 'order_updates',
        'order_update': 'order_updates',
        'delivery_arriving': 'order_updates',
        'comment_reply': 'social',
        'comment_reaction': 'social',
        'promo': 'promotions',
        'referral_completed': 'referrals',
        'milestone_bonus': 'referrals',
        'payment_confirmed': 'payments',
        'system': 'system_updates',
        'update': 'system_updates',
    };
    return channelMap[type] || 'default';
};

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
        // SECURITY: Validate FCM token format
        if (!validateFCMToken(token)) {
            throw new Error('Invalid FCM token format');
        }

        // SECURITY: Validate platform
        if (!validatePlatform(platform)) {
            throw new Error(`Invalid platform: ${platform}. Must be 'android', 'ios', or 'web'`);
        }

        // SECURITY: Validate device ID if provided
        if (deviceId && !validateDeviceId(deviceId)) {
            throw new Error('Invalid device ID format');
        }

        const user = await User.findById(userId);
        if (!user) {
            throw new Error('User not found');
        }

        // Use atomic operations to prevent race conditions
        // First, remove any existing token with the same deviceId or token value
        await User.findByIdAndUpdate(userId, {
            $pull: {
                fcmTokens: {
                    $or: [
                        { token: token },
                        ...(deviceId ? [{ deviceId: deviceId }] : [])
                    ]
                }
            }
        });

        // Then add the new token
        await User.findByIdAndUpdate(
            userId,
            {
                $push: {
                    fcmTokens: {
                        $each: [{
                            token,
                            deviceId,
                            platform,
                            createdAt: new Date(),
                            updatedAt: new Date(),
                        }],
                        $position: 0, // Add to the beginning
                        $slice: 5 // Keep only the last 5 tokens
                    }
                }
            },
            { new: true }
        );

        console.log(`✅ FCM token registered for user ${userId} (platform: ${platform}, deviceId: ${deviceId || 'none'})`);
        return true;
    } catch (error) {
        console.error('❌ Error registering FCM token:', error.message);
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
        const settingsMap = {
            'chat_message': 'chatMessages',
            'order_update': 'orderUpdates',
            'referral_completed': 'referralUpdates',
            'payment_confirmed': 'paymentUpdates',
            'delivery_arriving': 'deliveryUpdates',
            'promo': 'promoNotifications',
            'system': 'systemUpdates',
            'update': 'systemUpdates',
            'comment_reply': 'commentReplies',
            'comment_reaction': 'commentReactions',
            'milestone_bonus': 'referralUpdates'
        };

        const settingKey = settingsMap[data.type];
        if (settingKey && !user.notificationSettings?.[settingKey]) {
            return { success: false, reason: 'notifications_disabled' };
        }

        const tokens = user.fcmTokens.map(t => t.token);
        const invalidTokens = [];

        // Build message with payload size validation
        const FCM_PAYLOAD_LIMIT = 4000; // 4KB with safety margin

        let message = {
            notification: {
                title: notification.title.substring(0, 100), // Truncate title
                body: notification.body.substring(0, 200),   // Truncate body
                ...(notification.imageUrl && { imageUrl: notification.imageUrl }),
            },
            data: prepareFCMData({
                ...data,
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                timestamp: new Date().toISOString(),
            }),
            android: {
                priority: 'high',
                notification: {
                    channelId: getNotificationChannel(data.type),
                    priority: 'high',
                    defaultSound: true,
                    defaultVibrateTimings: true,
                },
            },
            apns: {
                payload: {
                    aps: {
                        sound: 'default',
                        ...(data.badgeCount ? { badge: parseInt(data.badgeCount) } : {}),
                        contentAvailable: true,
                    },
                },
            },
        };

        // Check payload size
        const payloadSize = JSON.stringify(message).length;
        if (payloadSize > FCM_PAYLOAD_LIMIT) {
            console.warn(`⚠️ FCM payload too large (${payloadSize} bytes), truncating data`);

            // Strategy 1: Truncate long text fields first
            if (message.data.commentText && message.data.commentText.length > 50) {
                message.data.commentText = message.data.commentText.substring(0, 50) + '...';
            }
            if (message.data.replyText && message.data.replyText.length > 100) {
                message.data.replyText = message.data.replyText.substring(0, 100) + '...';
            }

            // Strategy 2: Remove avatar URLs (can be fetched on tap)
            if (JSON.stringify(message).length > FCM_PAYLOAD_LIMIT) {
                delete message.data.actorAvatar;
            }

            // Strategy 3: Only if still too large, remove preview text
            if (JSON.stringify(message).length > FCM_PAYLOAD_LIMIT) {
                delete message.data.commentText;
                delete message.data.replyText;
            }

            // Final check
            const finalSize = JSON.stringify(message).length;
            if (finalSize > FCM_PAYLOAD_LIMIT) {
                console.error(`❌ FCM payload still too large after truncation (${finalSize} bytes)`);
                return { success: false, reason: 'payload_too_large' };
            }
        }

        const response = await admin.messaging().sendEachForMulticast({
            tokens,
            ...message,
        });

        // Track invalid tokens for cleanup
        response.responses.forEach((resp, idx) => {
            if (!resp.success) {
                const errorCode = resp.error?.code;
                const errorMessage = resp.error?.message;
                console.error(`❌ FCM token ${idx + 1} failed: ${errorCode} - ${errorMessage}`);

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
const sendChatNotification = async (recipientId, senderName, messagePreview, chatId, messageType = 'text', senderId = null) => {
    let body = messagePreview;
    if (messageType === 'voice') {
        body = '🎤 Voice message';
    } else if (messageType === 'image') {
        body = '📷 Photo';
    } else if (messagePreview && messagePreview.length > TRUNCATION_LIMITS.MESSAGE_PREVIEW) {
        body = messagePreview.substring(0, TRUNCATION_LIMITS.MESSAGE_PREVIEW) + '...';
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
            senderId: senderId || '', // Actual sender ID for navigation
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

/**
 * Send comment reply notification
 * @param {string} recipientId - User ID to receive notification
 * @param {string} replierName - Name of the person who replied
 * @param {string} replyText - Text of the reply
 * @param {string} statusId - Status ID for navigation
 * @param {string} commentId - Comment ID for navigation
 * @param {string} replierId - ID of the person who replied
 * @param {string} replierAvatar - Avatar URL of the replier
 * @param {string} restaurantId - Restaurant ID for navigation
 * @param {string} restaurantName - Restaurant name for navigation
 */
const sendCommentReplyNotification = async (
    recipientId,
    replierName,
    replyText,
    statusId,
    replyId,
    parentCommentId,
    replierId,
    replierAvatar,
    restaurantId,
    restaurantName
) => {
    const body = replyText.length > TRUNCATION_LIMITS.REPLY_TEXT
        ? replyText.substring(0, TRUNCATION_LIMITS.REPLY_TEXT) + '...'
        : replyText;

    return sendToUser(
        recipientId,
        {
            title: `${replierName} replied to your comment`,
            body: `💬 ${body}`
        },
        {
            type: 'comment_reply',
            statusId,
            commentId: replyId,
            parentCommentId,
            isReply: true,
            restaurantId,
            restaurantName,
            replierId,
            replierName,
            replierAvatar
        }
    );
};

/**
 * Send comment reaction notification
 * @param {string} recipientId - User ID to receive notification
 * @param {string} reactorName - Name of the person who reacted
 * @param {string} reactionType - Type of reaction (like, love, etc.)
 * @param {string} commentText - Text of the comment that was reacted to
 * @param {string} statusId - Status ID for navigation
 * @param {string} commentId - Comment ID for navigation
 * @param {string} reactorId - ID of the person who reacted
 * @param {string} reactorAvatar - Avatar URL of the reactor
 * @param {string} restaurantId - Restaurant ID for navigation
 * @param {string} restaurantName - Restaurant name for navigation
 */
const sendCommentReactionNotification = async (
    recipientId,
    reactorName,
    reactionType,
    commentText,
    statusId,
    commentId,
    reactorId,
    reactorAvatar,
    restaurantId,
    restaurantName
) => {
    const reactionEmojis = {
        like: '👍',
        love: '❤️',
        haha: '😂',
        wow: '😮',
        sad: '😢',
        angry: '😠'
    };

    const emoji = reactionEmojis[reactionType] || '👍';
    const preview = commentText.length > TRUNCATION_LIMITS.COMMENT_TEXT
        ? commentText.substring(0, TRUNCATION_LIMITS.COMMENT_TEXT) + '...'
        : commentText;

    return sendToUser(
        recipientId,
        {
            title: `${reactorName} reacted to your comment`,
            body: `${emoji} "${preview}"`
        },
        {
            type: 'comment_reaction',
            statusId,
            commentId,
            restaurantId,
            restaurantName,
            reactorId,
            reactorName,
            reactorAvatar,
            reactionType
        }
    );
};

/**
 * Send referral completion notification
 * @param {string} referrerId - User ID of the referrer to receive notification
 * @param {string} refereeName - Name of the person who completed the order
 * @param {number} rewardAmount - Amount earned from referral
 */
const sendReferralNotification = async (referrerId, refereeName, rewardAmount = 10) => {
    return sendToUser(
        referrerId,
        {
            title: '🎉 Referral Success!',
            body: `${refereeName} completed their first order. You earned GHS ${rewardAmount}!`,
        },
        {
            type: 'referral_completed',
            refereeName,
            rewardAmount: rewardAmount.toString(),
            route: '/referral',
        }
    );
};

/**
 * Send promotional notification
 * @param {string} userId - User ID to receive notification
 * @param {string} title - Promo title
 * @param {string} message - Promo message
 * @param {string} promoCode - Optional promo code
 * @param {string} imageUrl - Optional promo image
 */
const sendPromoNotification = async (userId, title, message, promoCode = null, imageUrl = null) => {
    return sendToUser(
        userId,
        {
            title,
            body: message,
            ...(imageUrl && { imageUrl })
        },
        {
            type: 'promo',
            promoCode: promoCode || '',
            route: '/promos',
        }
    );
};

/**
 * Send payment confirmation notification
 * @param {string} userId - User ID
 * @param {string} orderId - Order ID
 * @param {number} amount - Payment amount
 * @param {string} paymentMethod - Payment method used
 */
const sendPaymentConfirmation = async (userId, orderId, amount, paymentMethod) => {
    return sendToUser(
        userId,
        {
            title: '✅ Payment Successful',
            body: `Your payment of GHS ${amount.toFixed(2)} has been confirmed.`,
        },
        {
            type: 'payment_confirmed',
            orderId,
            amount: amount.toString(),
            paymentMethod,
            route: `/orders/${orderId}`,
        }
    );
};

/**
 * Send delivery arriving notification
 * @param {string} userId - User ID
 * @param {string} orderId - Order ID
 * @param {string} orderNumber - Order number
 * @param {number} estimatedMinutes - ETA in minutes
 */
const sendDeliveryArrivingNotification = async (userId, orderId, orderNumber, estimatedMinutes = 5) => {
    return sendToUser(
        userId,
        {
            title: '🚴 Rider Arriving Soon!',
            body: `Your order #${orderNumber} will arrive in ${estimatedMinutes} minutes.`,
        },
        {
            type: 'delivery_arriving',
            orderId,
            orderNumber,
            eta: estimatedMinutes.toString(),
            route: `/orders/${orderId}`,
        }
    );
};

/**
 * Send system update notification
 * @param {string} userId - User ID (or 'all' for broadcast)
 * @param {string} title - Update title
 * @param {string} message - Update message
 * @param {string} updateType - 'maintenance', 'feature', 'bug_fix'
 */
const sendSystemUpdate = async (userId, title, message, updateType = 'feature') => {
    return sendToUser(
        userId,
        {
            title: `🔔 ${title}`,
            body: message,
        },
        {
            type: 'system',
            updateType,
            route: '/notifications',
        }
    );
};

/**
 * Send milestone bonus notification
 * @param {string} userId - User ID
 * @param {number} milestone - Milestone number (5, 10, 15, etc.)
 * @param {number} bonusAmount - Bonus amount earned
 */
const sendMilestoneBonusNotification = async (userId, milestone, bonusAmount) => {
    return sendToUser(
        userId,
        {
            title: '🎉 Milestone Reached!',
            body: `Congrats! You've completed ${milestone} referrals. Bonus GHS ${bonusAmount} added!`,
        },
        {
            type: 'milestone_bonus',
            milestone: milestone.toString(),
            bonusAmount: bonusAmount.toString(),
            route: '/referral',
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
    sendCommentReplyNotification,
    sendCommentReactionNotification,
    sendReferralNotification,
    sendPromoNotification,
    sendPaymentConfirmation,
    sendDeliveryArrivingNotification,
    sendSystemUpdate,
    sendMilestoneBonusNotification
};
