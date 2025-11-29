/**
 * Cache utility with Redis support for production
 * Falls back to in-memory cache (node-cache) for development
 */

const Redis = require('ioredis');
const NodeCache = require('node-cache');

// Cache configuration
const CACHE_CONFIG = {
    defaultTTL: 60, // 60 seconds default
    checkPeriod: 120,
};

// In-memory cache fallback
const memoryCache = new NodeCache({
    stdTTL: CACHE_CONFIG.defaultTTL,
    checkperiod: CACHE_CONFIG.checkPeriod,
    useClones: false
});

// Redis client (initialized lazily)
let redisClient = null;
let useRedis = false;

/**
 * Initialize Redis connection
 * Call this on server startup
 */
const initRedis = () => {
    const redisUrl = process.env.REDIS_URL;

    if (!redisUrl) {
        console.log('[Cache] No REDIS_URL found, using in-memory cache');
        return false;
    }

    try {
        redisClient = new Redis(redisUrl, {
            maxRetriesPerRequest: 3,
            retryDelayOnFailover: 100,
            enableReadyCheck: true,
            lazyConnect: true,
        });

        redisClient.on('connect', () => {
            console.log('[Cache] Redis connected successfully');
            useRedis = true;
        });

        redisClient.on('error', (err) => {
            console.error('[Cache] Redis error:', err.message);
            // Fall back to memory cache on error
            useRedis = false;
        });

        redisClient.on('close', () => {
            console.log('[Cache] Redis connection closed');
            useRedis = false;
        });

        // Attempt connection
        redisClient.connect().catch((err) => {
            console.error('[Cache] Redis connection failed:', err.message);
            useRedis = false;
        });

        return true;
    } catch (error) {
        console.error('[Cache] Failed to initialize Redis:', error.message);
        return false;
    }
};

/**
 * Get value from cache
 * @param {string} key - Cache key
 * @returns {Promise<any>} - Cached value or null
 */
const get = async (key) => {
    try {
        if (useRedis && redisClient) {
            const value = await redisClient.get(key);
            return value ? JSON.parse(value) : null;
        }
        return memoryCache.get(key) || null;
    } catch (error) {
        console.error('[Cache] Get error:', error.message);
        // Fallback to memory cache
        return memoryCache.get(key) || null;
    }
};

/**
 * Set value in cache
 * @param {string} key - Cache key
 * @param {any} value - Value to cache
 * @param {number} ttl - Time to live in seconds (optional)
 * @returns {Promise<boolean>} - Success status
 */
const set = async (key, value, ttl = CACHE_CONFIG.defaultTTL) => {
    try {
        if (useRedis && redisClient) {
            await redisClient.setex(key, ttl, JSON.stringify(value));
            return true;
        }
        return memoryCache.set(key, value, ttl);
    } catch (error) {
        console.error('[Cache] Set error:', error.message);
        // Fallback to memory cache
        return memoryCache.set(key, value, ttl);
    }
};

/**
 * Delete a key from cache
 * @param {string} key - Cache key
 * @returns {Promise<boolean>} - Success status
 */
const del = async (key) => {
    try {
        if (useRedis && redisClient) {
            await redisClient.del(key);
        }
        memoryCache.del(key);
        return true;
    } catch (error) {
        console.error('[Cache] Delete error:', error.message);
        memoryCache.del(key);
        return false;
    }
};

/**
 * Delete all keys matching a pattern
 * @param {string} pattern - Key pattern (e.g., 'stories_*')
 * @returns {Promise<number>} - Number of keys deleted
 */
const delByPattern = async (pattern) => {
    try {
        if (useRedis && redisClient) {
            const keys = await redisClient.keys(pattern);
            if (keys.length > 0) {
                await redisClient.del(...keys);
                return keys.length;
            }
            return 0;
        }

        // For memory cache, get all keys and filter
        const allKeys = memoryCache.keys();
        const regex = new RegExp('^' + pattern.replace('*', '.*') + '$');
        const matchingKeys = allKeys.filter(key => regex.test(key));
        matchingKeys.forEach(key => memoryCache.del(key));
        return matchingKeys.length;
    } catch (error) {
        console.error('[Cache] Delete by pattern error:', error.message);
        return 0;
    }
};

/**
 * Flush all cache
 * @returns {Promise<boolean>} - Success status
 */
const flushAll = async () => {
    try {
        if (useRedis && redisClient) {
            // Only flush keys with our prefix to avoid affecting other apps
            const keys = await redisClient.keys('grabgo:*');
            if (keys.length > 0) {
                await redisClient.del(...keys);
            }
        }
        memoryCache.flushAll();
        return true;
    } catch (error) {
        console.error('[Cache] Flush error:', error.message);
        memoryCache.flushAll();
        return false;
    }
};

/**
 * Check if Redis is connected
 * @returns {boolean}
 */
const isRedisConnected = () => useRedis && redisClient?.status === 'ready';

/**
 * Get cache stats
 * @returns {object}
 */
const getStats = () => {
    if (useRedis && redisClient) {
        return {
            type: 'redis',
            connected: redisClient.status === 'ready',
            status: redisClient.status
        };
    }

    const stats = memoryCache.getStats();
    return {
        type: 'memory',
        keys: memoryCache.keys().length,
        hits: stats.hits,
        misses: stats.misses
    };
};

/**
 * Close Redis connection gracefully
 */
const close = async () => {
    if (redisClient) {
        await redisClient.quit();
        redisClient = null;
        useRedis = false;
    }
};

// Cache key prefixes for different features
const CACHE_KEYS = {
    STORIES: 'grabgo:stories',
    STATUS: 'grabgo:status',
};

/**
 * Generate cache key with prefix
 * @param {string} prefix - Key prefix from CACHE_KEYS
 * @param {string} suffix - Key suffix
 * @returns {string}
 */
const makeKey = (prefix, suffix) => `${prefix}:${suffix}`;

module.exports = {
    initRedis,
    get,
    set,
    del,
    delByPattern,
    flushAll,
    isRedisConnected,
    getStats,
    close,
    CACHE_KEYS,
    makeKey,
};
