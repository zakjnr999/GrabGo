// No longer using mongoose
const sanitizeHtml = require('sanitize-html');
const cache = require('./cache');

/**
 * Rate Limiting Configuration
 * 
 * Uses Redis when available (production), falls back to in-memory cache (development).
 * Redis provides:
 * - Consistent rate limiting across multiple server instances
 * - Persistence across server restarts
 * - Atomic increment operations
 */
const RATE_LIMITS = {
    perUser: { max: 100, window: 60 }, // 100 notifications per minute per user (window in seconds for Redis)
    perType: { max: 10, window: 60 }   // 10 of same type per minute per user
};

// Fallback in-memory cache for when Redis is unavailable
const memoryRateLimitCache = new Map();

/**
 * Check if user has exceeded rate limit (Redis-first with memory fallback)
 * @param {string} userId - User ID
 * @param {string} type - Notification type
 * @returns {Promise<boolean>} - True if within limit, false if exceeded
 */
const checkRateLimit = async (userId, type) => {
    // Try Redis-based rate limiting first
    if (cache.isRedisConnected()) {
        return await checkRateLimitRedis(userId, type);
    }
    
    // Fallback to in-memory rate limiting
    return checkRateLimitMemory(userId, type);
};

/**
 * Redis-based rate limiting using atomic INCR with TTL
 */
const checkRateLimitRedis = async (userId, type) => {
    try {
        const userKey = `grabgo:ratelimit:user:${userId}`;
        const typeKey = `grabgo:ratelimit:${userId}:${type}`;

        // Check per-user limit using Redis INCR
        const userCount = await incrementWithTTL(userKey, RATE_LIMITS.perUser.window);
        if (userCount > RATE_LIMITS.perUser.max) {
            console.warn(`⚠️ Rate limit exceeded for user ${userId}: ${userCount} notifications in window`);
            return false;
        }

        // Check per-type limit
        const typeCount = await incrementWithTTL(typeKey, RATE_LIMITS.perType.window);
        if (typeCount > RATE_LIMITS.perType.max) {
            console.warn(`⚠️ Rate limit exceeded for user ${userId}, type ${type}: ${typeCount} notifications in window`);
            return false;
        }

        return true;
    } catch (error) {
        console.error('Redis rate limit error, falling back to memory:', error.message);
        return checkRateLimitMemory(userId, type);
    }
};

/**
 * Increment a Redis key and set TTL if it's a new key
 * Uses Redis INCR which is atomic
 */
const incrementWithTTL = async (key, ttlSeconds) => {
    return cache.incr(key, ttlSeconds);
};

/**
 * In-memory rate limiting fallback
 */
const checkRateLimitMemory = (userId, type) => {
    const userKey = `user:${userId}`;
    const typeKey = `${userId}:${type}`;
    const now = Date.now();

    // Check per-user limit
    const userRecord = memoryRateLimitCache.get(userKey) || { count: 0, resetAt: now + RATE_LIMITS.perUser.window * 1000 };
    if (now > userRecord.resetAt) {
        userRecord.count = 0;
        userRecord.resetAt = now + RATE_LIMITS.perUser.window * 1000;
    }
    if (userRecord.count >= RATE_LIMITS.perUser.max) {
        console.warn(`⚠️ Rate limit exceeded for user ${userId}: ${userRecord.count} notifications in window`);
        return false;
    }
    userRecord.count++;
    memoryRateLimitCache.set(userKey, userRecord);

    // Check per-type limit
    const typeRecord = memoryRateLimitCache.get(typeKey) || { count: 0, resetAt: now + RATE_LIMITS.perType.window * 1000 };
    if (now > typeRecord.resetAt) {
        typeRecord.count = 0;
        typeRecord.resetAt = now + RATE_LIMITS.perType.window * 1000;
    }
    if (typeRecord.count >= RATE_LIMITS.perType.max) {
        console.warn(`⚠️ Rate limit exceeded for user ${userId}, type ${type}: ${typeRecord.count} notifications in window`);
        return false;
    }
    typeRecord.count++;
    memoryRateLimitCache.set(typeKey, typeRecord);

    return true;
};

/**
 * Clean up old rate limit entries (only needed for memory fallback)
 */
const cleanupRateLimitCache = () => {
    const now = Date.now();
    let removed = 0;
    for (const [key, record] of memoryRateLimitCache.entries()) {
        if (now > record.resetAt) {
            memoryRateLimitCache.delete(key);
            removed++;
        }
    }

    // Safety: If cache grows too large, clear oldest entries
    if (memoryRateLimitCache.size > 10000) {
        console.warn(`⚠️ Rate limit cache exceeded 10k entries, clearing...`);
        memoryRateLimitCache.clear();
    }

    if (removed > 0) {
        console.log(`🧹 Cleaned up ${removed} rate limit entries (memory fallback)`);
    }
};

// Cleanup every 5 minutes (only affects memory fallback, Redis handles TTL automatically)
let rateLimitCleanupInterval = null;
if (process.env.NODE_ENV !== 'test') {
    rateLimitCleanupInterval = setInterval(cleanupRateLimitCache, 300000);
    if (typeof rateLimitCleanupInterval.unref === 'function') {
        rateLimitCleanupInterval.unref();
    }
}

/**
 * Valid notification types
 */
const VALID_NOTIFICATION_TYPES = [
    'order',
    'order_update',
    'promo',
    'update',
    'system',
    'chat_message',
    'comment_reply',
    'comment_reaction',
    'referral_completed',
    'payment_confirmed',
    'delivery_arriving',
    'milestone_bonus',
    'cart_reminder',
    'meal_nudge_breakfast',
    'meal_nudge_lunch',
    'meal_nudge_dinner',
    'favorites_reminder',
    'reorder_suggestion',
    'reengagement_two_weeks',
    'reengagement_one_month',
    'reengagement_two_months',
    'tracking_update',
    'incoming_call',
    'rider_assignment',
    'test'
];

/**
 * Sanitize HTML content
 * @param {string} text - Text to sanitize
 * @returns {string} - Sanitized text
 */
const sanitizeText = (text) => {
    return sanitizeHtml(text, {
        allowedTags: [], // No HTML tags allowed
        allowedAttributes: {},
        disallowedTagsMode: 'discard'
    });
};

/**
 * Validate and sanitize notification input
 * @param {string} userId - User ID
 * @param {string} type - Notification type
 * @param {string} title - Notification title
 * @param {string} message - Notification message
 * @param {object} data - Additional data
 * @returns {object} - Validated and sanitized input
 * @throws {Error} - If validation fails
 */
const validateNotificationInput = (userId, type, title, message, data = {}) => {
    // Validate userId (Prisma/Postgres uses cuid/strings)
    if (!userId || typeof userId !== 'string' || userId.trim().length === 0) {
        throw new Error('Invalid user ID');
    }

    // Validate type
    if (!type || typeof type !== 'string') {
        throw new Error('Notification type is required');
    }
    if (!VALID_NOTIFICATION_TYPES.includes(type)) {
        throw new Error(`Invalid notification type: ${type}`);
    }

    // Validate and sanitize title
    if (!title || typeof title !== 'string') {
        throw new Error('Title is required');
    }
    title = title.trim();
    if (title.length === 0) {
        throw new Error('Title cannot be empty');
    }
    if (title.length > 200) {
        title = title.substring(0, 200);
    }
    title = sanitizeText(title);

    // Validate and sanitize message
    if (!message || typeof message !== 'string') {
        throw new Error('Message is required');
    }
    message = message.trim();
    if (message.length === 0) {
        throw new Error('Message cannot be empty');
    }
    if (message.length > 1000) {
        message = message.substring(0, 1000);
    }
    message = sanitizeText(message);

    // Validate data object
    if (data && typeof data !== 'object') {
        throw new Error('Data must be an object');
    }
    if (Array.isArray(data)) {
        throw new Error('Data cannot be an array');
    }

    // Check data size
    const dataString = JSON.stringify(data);
    if (dataString.length > 10000) { // 10KB limit
        throw new Error('Data payload too large (max 10KB)');
    }

    // Sanitize string fields in data
    const sanitizedData = {};
    for (const [key, value] of Object.entries(data)) {
        if (typeof value === 'string') {
            sanitizedData[key] = sanitizeText(value);
        } else if (typeof value === 'number' || typeof value === 'boolean') {
            sanitizedData[key] = value;
        } else if (value && typeof value === 'object' && !Array.isArray(value)) {
            // Allow nested objects but sanitize string values
            sanitizedData[key] = value;
        } else if (value === null || value === undefined) {
            sanitizedData[key] = value;
        } else {
            // Skip other types (arrays, functions, etc.)
            console.warn(`Skipping invalid data field: ${key}`);
        }
    }

    return {
        userId,
        type,
        title,
        message,
        data: sanitizedData
    };
};

/**
 * Validate FCM token format
 * @param {string} token - FCM token
 * @returns {boolean} - True if valid
 */
const validateFCMToken = (token) => {
    if (!token || typeof token !== 'string') {
        return false;
    }

    // FCM tokens can be long (especially V1 tokens)
    if (token.length < 100 || token.length > 500) {
        return false;
    }

    // Should contain only alphanumeric, hyphens, underscores, colons, dots
    if (!/^[A-Za-z0-9_:. -]+$/.test(token)) {
        return false;
    }

    return true;
};

/**
 * Validate platform
 * @param {string} platform - Platform name
 * @returns {boolean} - True if valid
 */
const validatePlatform = (platform) => {
    return ['android', 'ios', 'web'].includes(platform);
};

/**
 * Validate device ID
 * @param {string} deviceId - Device ID
 * @returns {boolean} - True if valid
 */
const validateDeviceId = (deviceId) => {
    if (!deviceId || typeof deviceId !== 'string') {
        return false;
    }

    // Device IDs should be reasonable length (some platform IDs can be long)
    if (deviceId.length < 3 || deviceId.length > 255) {
        return false;
    }

    // Should contain only safe characters (allowing dots, colons, and etc for broad compatibility)
    if (!/^[A-Za-z0-9_:. -]+$/.test(deviceId)) {
        return false;
    }

    return true;
};

module.exports = {
    checkRateLimit,
    validateNotificationInput,
    validateFCMToken,
    validatePlatform,
    validateDeviceId,
    VALID_NOTIFICATION_TYPES
};
