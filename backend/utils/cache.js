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
 * Increment a numeric key
 * @param {string} key
 * @param {number|null} ttlSeconds
 * @returns {Promise<number>}
 */
const incr = async (key, ttlSeconds = null) => {
    try {
        if (useRedis && redisClient) {
            const next = await redisClient.incr(key);
            if (ttlSeconds && Number.isFinite(ttlSeconds) && ttlSeconds > 0 && next === 1) {
                await redisClient.expire(key, Math.floor(ttlSeconds));
            }
            return Number(next || 0);
        }

        const current = Number(memoryCache.get(key) || 0);
        const next = current + 1;
        if (ttlSeconds && Number.isFinite(ttlSeconds) && ttlSeconds > 0) {
            memoryCache.set(key, next, Math.floor(ttlSeconds));
        } else {
            memoryCache.set(key, next);
        }
        return next;
    } catch (error) {
        console.error('[Cache] Incr error:', error.message);
        const current = Number(memoryCache.get(key) || 0);
        const next = current + 1;
        if (ttlSeconds && Number.isFinite(ttlSeconds) && ttlSeconds > 0) {
            memoryCache.set(key, next, Math.floor(ttlSeconds));
        } else {
            memoryCache.set(key, next);
        }
        return next;
    }
};

/**
 * Get remaining TTL in seconds
 * @param {string} key
 * @returns {Promise<number>} -1 no ttl, -2 missing
 */
const ttl = async (key) => {
    try {
        if (useRedis && redisClient) {
            return Number(await redisClient.ttl(key));
        }

        const expiryMs = memoryCache.getTtl(key);
        if (!expiryMs) {
            return memoryCache.has(key) ? -1 : -2;
        }
        const remainingMs = expiryMs - Date.now();
        return remainingMs > 0 ? Math.ceil(remainingMs / 1000) : -2;
    } catch (error) {
        console.error('[Cache] TTL error:', error.message);
        return -2;
    }
};

/**
 * Add event to Redis stream. Falls back to in-memory rolling buffer when Redis is unavailable.
 * @param {string} stream
 * @param {Record<string, string>} fields
 * @param {{maxLen?: number, approximate?: boolean, id?: string}} options
 * @returns {Promise<string>} stream id
 */
const xadd = async (stream, fields = {}, options = {}) => {
    const maxLen = Number(options.maxLen || 100000);
    const approximate = options.approximate !== false;
    const id = options.id || '*';
    const entries = Object.entries(fields).flatMap(([k, v]) => [String(k), String(v ?? '')]);

    if (entries.length === 0) {
        throw new Error('xadd requires at least one field');
    }

    try {
        if (useRedis && redisClient) {
            const args = [stream];
            if (Number.isFinite(maxLen) && maxLen > 0) {
                args.push('MAXLEN');
                if (approximate) args.push('~');
                args.push(String(Math.floor(maxLen)));
            }
            args.push(id, ...entries);
            return await redisClient.xadd(...args);
        }

        // Memory fallback to support tests/dev mode without Redis.
        const fallbackKey = `grabgo:stream:fallback:${stream}`;
        const current = memoryCache.get(fallbackKey) || [];
        const streamId = `${Date.now()}-${Math.floor(Math.random() * 1000)}`;
        current.push({ id: streamId, fields });
        if (current.length > maxLen) {
            current.splice(0, current.length - maxLen);
        }
        memoryCache.set(fallbackKey, current, 3600);
        return streamId;
    } catch (error) {
        console.error('[Cache] xadd error:', error.message);
        throw error;
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
 * Acquire a distributed lock (Redis) with memory fallback
 * @param {string} key - Lock key (without prefix)
 * @param {number} ttlSeconds - Lock TTL in seconds
 * @returns {Promise<{key:string,value:string,isRedis:boolean} | null>}
 */
const acquireLock = async (key, ttlSeconds = 60) => {
    const lockKey = key.startsWith('grabgo:lock:') ? key : `grabgo:lock:${key}`;
    const lockValue = `${process.pid}-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;

    try {
        if (useRedis && redisClient) {
            const result = await redisClient.set(lockKey, lockValue, 'EX', ttlSeconds, 'NX');
            if (result === 'OK') {
                return { key: lockKey, value: lockValue, isRedis: true };
            }
            return null;
        }

        // Memory fallback
        if (memoryCache.get(lockKey)) {
            return null;
        }
        memoryCache.set(lockKey, lockValue, ttlSeconds);
        return { key: lockKey, value: lockValue, isRedis: false };
    } catch (error) {
        console.error('[Cache] Acquire lock error:', error.message);
        return null;
    }
};

/**
 * Release a distributed lock safely
 * @param {{key:string,value:string,isRedis:boolean}} lock
 * @returns {Promise<boolean>}
 */
const releaseLock = async (lock) => {
    if (!lock) return false;
    const { key, value, isRedis } = lock;

    try {
        if (useRedis && redisClient && isRedis) {
            const lua = `
                if redis.call("get", KEYS[1]) == ARGV[1] then
                    return redis.call("del", KEYS[1])
                else
                    return 0
                end
            `;
            const result = await redisClient.eval(lua, 1, key, value);
            return result === 1;
        }

        // Memory fallback
        memoryCache.del(key);
        return true;
    } catch (error) {
        console.error('[Cache] Release lock error:', error.message);
        return false;
    }
};

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

const getRedisClient = () => {
    if (useRedis && redisClient && redisClient.status === 'ready') {
        return redisClient;
    }
    return null;
};

// Cache key prefixes for different features
const CACHE_KEYS = {
    STORIES: 'grabgo:stories',
    STATUS: 'grabgo:status',
    // Food service cache keys
    // Service cache keys
    FOOD_CATEGORIES: 'grabgo:food:categories',
    FOOD_DEALS: 'grabgo:food:deals',
    FOOD_POPULAR: 'grabgo:food:popular',
    FOOD_TOP_RATED: 'grabgo:food:toprated',
    FOOD_RECOMMENDED: 'grabgo:food:recommended',
    FOOD_BANNERS: 'grabgo:food:banners',
    FOOD_ITEM: 'grabgo:food:item',
    PHARMACY: 'grabgo:pharmacy',
    GROCERY: 'grabgo:grocery',
    GRABMART: 'grabgo:grabmart',
    PROMOTIONS: 'grabgo:promotions',
    // Live tracking cache keys
    RIDER_LOCATION: 'grabgo:tracking:rider',
    ORDER_TRACKING: 'grabgo:tracking:order',
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
    incr,
    ttl,
    set,
    del,
    delByPattern,
    flushAll,
    isRedisConnected,
    acquireLock,
    releaseLock,
    getStats,
    xadd,
    getRedisClient,
    close,
    CACHE_KEYS,
    makeKey,
};
