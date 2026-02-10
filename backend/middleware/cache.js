const cache = require('../utils/cache');

const cacheMiddleware = (keyPrefix, ttl = 300, isPersonalized = false) => {
    return async (req, res, next) => {
        if (req.method !== 'GET') {
            return next();
        }

        try {
            const sortedQuery = Object.keys(req.query)
                .sort()
                .reduce((acc, key) => {
                    acc[key] = req.query[key];
                    return acc;
                }, {});

            const userId = isPersonalized ? (req.user?.id || req.headers['x-user-id'] || 'guest') : 'global';
            const queryString = JSON.stringify(sortedQuery);
            const cacheKey = `${userId}:${cache.makeKey(keyPrefix, queryString)}`;

            const cachedData = await cache.get(cacheKey);

            if (cachedData) {
                console.log(`✅ [Cache HIT] ${cacheKey}`);
                return res.json(cachedData);
            }

            console.log(`❌ [Cache MISS] ${cacheKey}`);

            const originalJson = res.json.bind(res);

            res.json = (data) => {
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

const invalidateCache = async (patterns) => {
    try {
        for (const pattern of patterns) {
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
