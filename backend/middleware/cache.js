const cache = require('../utils/cache');
const logger = require('../utils/logger');

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
                logger.debug('cache_hit', { cacheKey });
                return res.json(cachedData);
            }

            logger.debug('cache_miss', { cacheKey });

            const originalJson = res.json.bind(res);

            res.json = (data) => {
                if (data && data.success !== false) {
                    cache.set(cacheKey, data, ttl).catch(err => {
                        logger.error('cache_set_failed', { cacheKey, error: err });
                    });
                }
                return originalJson(data);
            };

            next();
        } catch (error) {
            logger.error('cache_middleware_failed', { error });
            next();
        }
    };
};

const invalidateCache = async (patterns) => {
    try {
        for (const pattern of patterns) {
            const deleted = await cache.delByPattern(`*:${pattern}:*`);
            if (deleted > 0) {
                logger.info('cache_invalidated', { pattern, deleted });
            }
        }
    } catch (error) {
        logger.error('cache_invalidation_failed', { error });
    }
};

module.exports = {
    cacheMiddleware,
    invalidateCache,
};
