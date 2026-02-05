/**
 * Cache middleware for Express routes
 * Automatically caches GET request responses in Redis
 */

const cache = require('../utils/cache');

/**
 * Cache middleware for GET requests
 * @param {string} keyPrefix - Cache key prefix from cache.CACHE_KEYS
 * @param {number} ttl - Time to live in seconds (default: 300 = 5 minutes)
 * @param {boolean} isPersonalized - Whether to include user ID in cache key
 * @returns {Function} Express middleware
 */
const cacheMiddleware = (keyPrefix, ttl = 300, isPersonalized = false) => {
    return async (req, res, next) => {
        // Only cache GET requests
        if (req.method !== 'GET') {
            return next();
        }

        try {
            // Normalize and sort query params to ensure consistent cache keys
            const sortedQuery = Object.keys(req.query)
                .sort()
                .reduce((acc, key) => {
                    acc[key] = req.query[key];
                    return acc;
                }, {});

            const userId = isPersonalized ? (req.user?.id || req.headers['x-user-id'] || 'guest') : 'global';
            const queryString = JSON.stringify(sortedQuery);
            const cacheKey = `${userId}:${cache.makeKey(keyPrefix, queryString)}`;

            // Try to get from cache
            const cachedData = await cache.get(cacheKey);

            if (cachedData) {
                console.log(`✅ [Cache HIT] ${cacheKey}`);
                return res.json(cachedData);
            }

            console.log(`❌ [Cache MISS] ${cacheKey}`);

            // Store original res.json
            const originalJson = res.json.bind(res);

            // Override res.json to cache the response
            res.json = (data) => {
                // Only cache successful responses (where success is not explicitly false)
                if (data && data.success !== false) {
                    cache.set(cacheKey, data, ttl).catch(err => {
                        console.error('[Cache] Set error:', err.message);
                    });
                }
                return originalJson(data);
            };

            next();
        } catch (error) {
            console.error('[Cache Middleware] Error:', error.message);
            next();
        }
    };
};

/**
 * Helper to invalidate cache patterns for all users
 * @param {string[]} patterns - Array of cache key patterns to delete
 */
const invalidateCache = async (patterns) => {
    try {
        for (const pattern of patterns) {
            // Using * at the beginning to catch all user prefixes (userId:prefix:* or global:prefix:*)
            const deleted = await cache.delByPattern(`*:${pattern}:*`);
            if (deleted > 0) {
                console.log(`🗑️  [Cache] Invalidated ${deleted} keys matching ${pattern}`);
            }
        }
    } catch (error) {
        console.error('[Cache] Invalidation error:', error.message);
    }
};

module.exports = {
    cacheMiddleware,
    invalidateCache,
};
