const express = require('express');
const { Prisma } = require('@prisma/client');
const { createScopedLogger } = require('../utils/logger');
const router = express.Router();
const prisma = require('../config/prisma');
const { protect } = require('../middleware/auth');
const { cacheMiddleware } = require('../middleware/cache');
const cache = require('../utils/cache');
const mlClient = require('../utils/ml_client');
const { normalizeRatingResponse } = require("../utils/rating_calculator");
const {
    isGrabGoExclusiveActive,
    applyActiveExclusiveWhere,
} = require('../utils/grabgo_exclusive');
const console = createScopedLogger('pharmacies_route');

/**
 * Helper to format Pharmacy store for frontend compatibility
 */
const formatOpeningHours = (openingHours) => {
    if (!Array.isArray(openingHours)) return null;

    const dayMap = {
        0: 'sunday',
        1: 'monday',
        2: 'tuesday',
        3: 'wednesday',
        4: 'thursday',
        5: 'friday',
        6: 'saturday',
    };

    return openingHours.reduce((acc, row) => {
        const key = dayMap[row.dayOfWeek];
        if (!key) return acc;
        acc[key] = {
            open: row.openTime ?? '09:00',
            close: row.closeTime ?? '21:00',
            isClosed: Boolean(row.isClosed),
        };
        return acc;
    }, {});
};

const formatStore = (store) => {
    if (!store) return null;
    const ratingMeta = normalizeRatingResponse({
        rating: store.rating,
        ratingCount: store.ratingCount,
        totalReviews: store.totalReviews,
    });
    const formatted = {
        ...store,
        rating: ratingMeta.rating,
        rawRating: ratingMeta.rawRating,
        weightedRating: ratingMeta.weightedRating,
        ratingCount: ratingMeta.ratingCount,
        totalReviews: ratingMeta.totalReviews,
        reviewCount: ratingMeta.reviewCount,
        openingHours: formatOpeningHours(store.openingHours),
        isGrabGoExclusiveActive: isGrabGoExclusiveActive(store),
        // Legacy support mapping
        store_name: store.storeName,
        is_open: store.isOpen,
        delivery_fee: store.deliveryFee,
        min_order: store.minOrder,
        operatingHours: store.operatingHoursString || 'Scheduled', // Map back to old field name
    };

    // Construct location object if coordinates exist
    if (store.longitude !== undefined && store.latitude !== undefined) {
        formatted.location = {
            type: 'Point',
            coordinates: [store.longitude, store.latitude],
            address: store.address,
            city: store.city,
            area: store.area
        };
    }

    return formatted;
};

/**
 * Helper to format Pharmacy item for frontend compatibility
 */
const formatItem = (item) => {
    if (!item) return null;
    const ratingMeta = normalizeRatingResponse({
        rating: item.rating,
        reviewCount: item.reviewCount,
        totalReviews: item.totalReviews,
    });
    const formatted = {
        ...item,
        rating: ratingMeta.rating,
        rawRating: ratingMeta.rawRating,
        weightedRating: ratingMeta.weightedRating,
        reviewCount: ratingMeta.reviewCount,
        ratingCount: ratingMeta.ratingCount,
        totalReviews: ratingMeta.totalReviews,
        // Ensure store is formatted if it exists and is an object
        store: (item.store && typeof item.store === 'object') ? formatStore(item.store) : item.store
    };
    return formatted;
};

const optionalAuth = (req, res, next) => {
    if (req.headers.authorization) {
        return protect(req, res, next);
    }
    return next();
};

// ==================== STORES ====================

/**
 * @route   GET /api/pharmacies/stores
 * @desc    Get all pharmacy stores
 * @access  Public
 */
router.get("/stores", cacheMiddleware(cache.CACHE_KEYS.PHARMACY + ':stores', 300), async (req, res) => {
    try {
        const { isOpen, minRating, limit = 20, exclusive } = req.query;

        const where = { status: 'approved' };
        const exclusiveOnly = exclusive === 'true';

        if (isOpen !== undefined) {
            where.isOpen = isOpen === 'true';
        }

        if (minRating) {
            const rating = parseFloat(minRating);
            if (!isNaN(rating)) {
                where.rating = { gte: rating };
            }
        }

        const filteredWhere = applyActiveExclusiveWhere(where, exclusiveOnly);

        let limitValue = Math.min(parseInt(limit) || 20, 100);

        const stores = await prisma.pharmacyStore.findMany({
            where: filteredWhere,
            orderBy: [
                { rating: 'desc' },
                { ratingCount: 'desc' }
            ],
            take: limitValue
        });

        res.json({
            success: true,
            message: "Pharmacy stores retrieved successfully",
            count: stores.length,
            data: stores.map(formatStore)
        });
    } catch (error) {
        console.error("Get pharmacy stores error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
        });
    }
});

/**
 * @route   GET /api/pharmacies/search
 * @desc    Search pharmacy stores
 * @access  Public
 */
router.get("/search", async (req, res) => {
    try {
        const { q, emergencyService, prescriptionService } = req.query;

        if (!q) {
            return res.status(400).json({
                success: false,
                message: "Search query is required"
            });
        }

        const where = {
            status: 'approved',
            OR: [
                { storeName: { contains: q, mode: 'insensitive' } },
                { description: { contains: q, mode: 'insensitive' } },
                { address: { contains: q, mode: 'insensitive' } },
                { city: { contains: q, mode: 'insensitive' } },
                { area: { contains: q, mode: 'insensitive' } }
            ]
        };

        if (emergencyService === 'true') {
            where.emergencyService = true;
        }

        if (prescriptionService === 'true') {
            where.prescriptionRequired = true;
        }

        const stores = await prisma.pharmacyStore.findMany({
            where,
            orderBy: { rating: 'desc' },
            take: 30
        });

        res.json({
            success: true,
            message: "Search results retrieved successfully",
            count: stores.length,
            data: stores.map(formatStore)
        });
    } catch (error) {
        console.error("Search pharmacy stores error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
        });
    }
});

/**
 * @route   GET /api/pharmacies/emergency
 * @desc    Get pharmacies with emergency services
 * @access  Public
 */
router.get("/emergency", async (req, res) => {
    try {
        const stores = await prisma.pharmacyStore.findMany({
            where: {
                emergencyService: true,
                isOpen: true,
                status: 'approved'
            },
            orderBy: { rating: 'desc' },
            take: 10
        });

        res.json({
            success: true,
            message: "Emergency pharmacies retrieved successfully",
            count: stores.length,
            data: stores.map(formatStore)
        });
    } catch (error) {
        console.error("Get emergency pharmacies error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
        });
    }
});

// ==================== CATEGORIES ====================

/**
 * @route   GET /api/pharmacies/categories
 * @desc    Get all pharmacy categories
 * @access  Public
 */
router.get("/categories", cacheMiddleware(cache.CACHE_KEYS.PHARMACY + ':categories', 600), async (req, res) => {
    try {
        const { userLat, userLng, maxDistance = 15 } = req.query;
        const userLatitude = userLat ? parseFloat(userLat) : null;
        const userLongitude = userLng ? parseFloat(userLng) : null;
        const maxDistanceKm = parseFloat(maxDistance);

        let where = { isActive: true };

        // If location provided, only show categories that have items in nearby stores
        if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude)) {
            console.log('🌍 [PHARMACY CATEGORIES] Location-based filtering enabled');

            const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
            const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

            const nearbyStores = await prisma.pharmacyStore.findMany({
                where: {
                    latitude: { gte: bbox.minLat, lte: bbox.maxLat },
                    longitude: { gte: bbox.minLng, lte: bbox.maxLng }
                },
                select: { id: true, latitude: true, longitude: true }
            });

            const filteredStores = filterVendorsByDistance(
                nearbyStores,
                userLatitude,
                userLongitude,
                maxDistanceKm
            );

            const storeIds = filteredStores.map(s => s.id);

            if (storeIds.length > 0) {
                // Find categories that have at least one item in these stores
                const categoriesWithItems = await prisma.pharmacyItem.findMany({
                    where: {
                        storeId: { in: storeIds },
                        isAvailable: true
                    },
                    select: { categoryId: true },
                    distinct: ['categoryId']
                });

                const activeCategoryIds = categoriesWithItems
                    .map(c => c.categoryId)
                    .filter(Boolean);

                if (activeCategoryIds.length === 0) {
                    console.log('   ⚠️ No valid pharmacy categories nearby - returning 0 categories');
                    return res.json({
                        success: true,
                        message: "No pharmacy categories available in your area",
                        data: []
                    });
                }

                where.id = { in: activeCategoryIds };
                console.log(`   ✅ Filtered to ${activeCategoryIds.length} active pharmacy categories nearby`);
            } else {
                console.log('   ⚠️ No pharmacies nearby - returning 0 categories');
                return res.json({
                    success: true,
                    message: "No pharmacy categories available in your area",
                    data: []
                });
            }
        }

        const categories = await prisma.pharmacyCategory.findMany({
            where,
            orderBy: { sortOrder: 'asc' }
        });

        res.json({
            success: true,
            message: "Pharmacy categories retrieved successfully",
            count: categories.length,
            data: categories
        });
    } catch (error) {
        console.error("Get pharmacy categories error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
        });
    }
});

// ==================== ITEMS ====================

/**
 * @route   GET /api/pharmacies/items
 * @desc    Get pharmacy items with optional filters
 * @access  Public
 */
router.get("/items", async (req, res) => {
    try {
        const { category, store, minPrice, maxPrice, tags, userLat, userLng, maxDistance = 15 } = req.query;

        const userLatitude = userLat ? parseFloat(userLat) : null;
        const userLongitude = userLng ? parseFloat(userLng) : null;
        const maxDistanceKm = parseFloat(maxDistance);

        const where = { isAvailable: true };

        if (category) where.categoryId = category;

        if (minPrice || maxPrice) {
            where.price = {};
            if (minPrice) where.price.gte = parseFloat(minPrice);
            if (maxPrice) where.price.lte = parseFloat(maxPrice);
        }

        if (tags) {
            where.tags = { hasSome: tags.split(',') };
        }

        // Filter by nearby stores if user location provided
        if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude) && !store) {
            console.log('🌍 [PHARMACY ITEMS] Location-based filtering enabled');
            console.log(`   📍 User location: (${userLatitude}, ${userLongitude})`);

            const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
            const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

            const nearbyStores = await prisma.pharmacyStore.findMany({
                where: {
                    latitude: { gte: bbox.minLat, lte: bbox.maxLat },
                    longitude: { gte: bbox.minLng, lte: bbox.maxLng }
                },
                select: { id: true, latitude: true, longitude: true, storeName: true }
            });

            console.log(`   🏪 Found ${nearbyStores.length} stores in bounding box`);

            const filteredStores = filterVendorsByDistance(
                nearbyStores,
                userLatitude,
                userLongitude,
                maxDistanceKm
            );

            console.log(`   ✅ ${filteredStores.length} stores within ${maxDistanceKm}km radius`);

            const storeIds = filteredStores.map(s => s.id);

            if (storeIds.length === 0) {
                console.log('   ⚠️  No pharmacies found in area - returning empty array');
                return res.json({
                    success: true,
                    message: "No pharmacy items available in your area",
                    data: []
                });
            }

            where.storeId = { in: storeIds };
        } else if (store) {
            console.log(`🏪 [PHARMACY ITEMS] Filtering by specific store: ${store}`);
            where.storeId = store;
        } else if (!userLatitude || !userLongitude) {
            console.log('📍 [PHARMACY ITEMS] No location provided - showing all items');
        }

        const items = await prisma.pharmacyItem.findMany({
            where,
            include: {
                category: { select: { name: true, emoji: true } },
                store: {
                    select: {
                        id: true,
                        storeName: true,
                        logo: true,
                        isOpen: true,
                        deliveryFee: true,
                        minOrder: true
                    }
                }
            },
            orderBy: { orderCount: 'desc' },
            take: 50
        });

        console.log(`✅ [PHARMACY ITEMS] Returning ${items.length} items to frontend`);

        res.json({
            success: true,
            message: "Pharmacy items retrieved successfully",
            count: items.length,
            data: items.map(formatItem)
        });
    } catch (error) {
        console.error("Get pharmacy items error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
        });
    }
});

/**
 * @route   GET /api/pharmacies/recommended
 * @desc    Get personalized pharmacy recommendations (ML-first with heuristic fallback)
 * @access  Public (Optional Auth)
 */
router.get(
    "/recommended",
    optionalAuth,
    cacheMiddleware(`${cache.CACHE_KEYS.PHARMACY}:recommended`, 180, true),
    async (req, res) => {
        try {
            const userId = req.user?.id || req.headers['x-user-id'];
            let { limit = 10, page = 1, userLat, userLng, maxDistance = 15 } = req.query;

            limit = parseInt(limit, 10);
            if (isNaN(limit) || limit < 1) limit = 10;
            if (limit > 50) limit = 50;

            page = parseInt(page, 10);
            if (isNaN(page) || page < 1) page = 1;

            const userLatitude = userLat ? parseFloat(userLat) : null;
            const userLongitude = userLng ? parseFloat(userLng) : null;
            const maxDistanceKm = parseFloat(maxDistance);

            const getNearbyStoreIds = async () => {
                if (!userLatitude || !userLongitude || isNaN(userLatitude) || isNaN(userLongitude)) {
                    return null;
                }

                const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
                const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

                const nearbyStores = await prisma.pharmacyStore.findMany({
                    where: {
                        latitude: { gte: bbox.minLat, lte: bbox.maxLat },
                        longitude: { gte: bbox.minLng, lte: bbox.maxLng }
                    },
                    select: { id: true, latitude: true, longitude: true }
                });

                const filteredStores = filterVendorsByDistance(
                    nearbyStores,
                    userLatitude,
                    userLongitude,
                    maxDistanceKm
                );

                return filteredStores.map(store => store.id);
            };

            const nearbyStoreIds = await getNearbyStoreIds();
            if (nearbyStoreIds && nearbyStoreIds.length === 0) {
                return res.json({
                    success: true,
                    source: 'heuristic',
                    page,
                    limit,
                    hasMore: false,
                    data: []
                });
            }

            let mlSeedItems = [];

            if (userId) {
                try {
                    const mlRecommendations = await mlClient.getStoreRecommendations(userId, 'pharmacy', 30);
                    const recommendedStoreIds = [
                        ...new Set((mlRecommendations || []).map(rec => rec.id).filter(Boolean))
                    ];

                    if (recommendedStoreIds.length > 0) {
                        const nearbySet = nearbyStoreIds ? new Set(nearbyStoreIds) : null;
                        const eligibleStoreIds = nearbySet
                            ? recommendedStoreIds.filter(id => nearbySet.has(id))
                            : recommendedStoreIds;

                        if (eligibleStoreIds.length > 0) {
                            const storeRank = new Map(eligibleStoreIds.map((id, index) => [id, index]));
                            const storeScore = new Map(
                                (mlRecommendations || [])
                                    .filter(rec => eligibleStoreIds.includes(rec.id))
                                    .map(rec => [rec.id, Number(rec.score) || 0])
                            );

                            const candidateItems = await prisma.pharmacyItem.findMany({
                                where: {
                                    isAvailable: true,
                                    storeId: { in: eligibleStoreIds }
                                },
                                include: {
                                    category: { select: { name: true, emoji: true } },
                                    store: {
                                        select: {
                                            id: true,
                                            storeName: true,
                                            logo: true,
                                            isOpen: true,
                                            deliveryFee: true,
                                            minOrder: true
                                        }
                                    }
                                },
                                take: 200
                            });

                            if (candidateItems.length > 0) {
                                const ranked = [...candidateItems].sort((a, b) => {
                                    const scoreDiff = (storeScore.get(b.storeId) || 0) - (storeScore.get(a.storeId) || 0);
                                    if (scoreDiff !== 0) return scoreDiff;

                                    const rankDiff = (storeRank.get(a.storeId) ?? Number.MAX_SAFE_INTEGER) -
                                        (storeRank.get(b.storeId) ?? Number.MAX_SAFE_INTEGER);
                                    if (rankDiff !== 0) return rankDiff;

                                    const popularityDiff = (b.orderCount || 0) - (a.orderCount || 0);
                                    if (popularityDiff !== 0) return popularityDiff;

                                    const ratingDiff = (b.rating || 0) - (a.rating || 0);
                                    if (ratingDiff !== 0) return ratingDiff;

                                    return (b.discountPercentage || 0) - (a.discountPercentage || 0);
                                });

                                const groupedByStore = new Map();
                                for (const item of ranked) {
                                    const storeItems = groupedByStore.get(item.storeId) || [];
                                    storeItems.push(item);
                                    groupedByStore.set(item.storeId, storeItems);
                                }

                                const diversified = [];
                                let keepLooping = true;
                                while (keepLooping && diversified.length < ranked.length) {
                                    keepLooping = false;
                                    for (const storeId of eligibleStoreIds) {
                                        const queue = groupedByStore.get(storeId) || [];
                                        if (queue.length > 0) {
                                            diversified.push(queue.shift());
                                            keepLooping = true;
                                        }
                                    }
                                }

                                const startIndex = (page - 1) * limit;
                                const endIndex = startIndex + limit;
                                const paginatedItems = diversified.slice(startIndex, endIndex);

                                if (paginatedItems.length > 0 && paginatedItems.length >= limit) {
                                    return res.json({
                                        success: true,
                                        source: 'ml',
                                        page,
                                        limit,
                                        total: diversified.length,
                                        hasMore: endIndex < diversified.length,
                                        data: paginatedItems.map(formatItem)
                                    });
                                }

                                if (paginatedItems.length > 0) {
                                    mlSeedItems = paginatedItems;
                                }
                            }
                        }
                    }
                } catch (mlError) {
                    console.error('🤖 Pharmacy ML recommendation failed, using fallback:', mlError.message);
                }
            }

            const popularCount = Math.ceil(limit * 0.4);
            const ratedCount = Math.ceil(limit * 0.3);
            const dealsCount = Math.ceil(limit * 0.2);
            const randomCount = limit - (popularCount + ratedCount + dealsCount);
            const skip = (page - 1) * limit;

            const locationWhere = nearbyStoreIds ? { storeId: { in: nearbyStoreIds } } : {};

            const include = {
                category: { select: { name: true, emoji: true } },
                store: {
                    select: {
                        id: true,
                        storeName: true,
                        logo: true,
                        isOpen: true,
                        deliveryFee: true,
                        minOrder: true
                    }
                }
            };

            const [popular, topRated, deals, random] = await Promise.all([
                prisma.pharmacyItem.findMany({
                    where: { isAvailable: true, ...locationWhere },
                    orderBy: [{ orderCount: 'desc' }, { rating: 'desc' }],
                    take: popularCount,
                    skip: Math.floor(skip * 0.4),
                    include
                }),
                prisma.pharmacyItem.findMany({
                    where: { isAvailable: true, rating: { gte: 4.5 }, ...locationWhere },
                    orderBy: [{ rating: 'desc' }, { reviewCount: 'desc' }],
                    take: ratedCount,
                    skip: Math.floor(skip * 0.3),
                    include
                }),
                prisma.pharmacyItem.findMany({
                    where: { isAvailable: true, discountPercentage: { gt: 0 }, ...locationWhere },
                    orderBy: [{ discountPercentage: 'desc' }, { orderCount: 'desc' }],
                    take: dealsCount,
                    skip: Math.floor(skip * 0.2),
                    include
                }),
                prisma.pharmacyItem.findMany({
                    where: { isAvailable: true, ...locationWhere },
                    orderBy: [{ createdAt: 'desc' }],
                    take: Math.max(randomCount, 0),
                    skip: Math.floor(skip * 0.1),
                    include
                })
            ]);

            const combined = [...mlSeedItems, ...popular, ...topRated, ...deals, ...random];
            const uniqueMap = new Map();
            combined.forEach(item => uniqueMap.set(item.id, item));
            const uniqueItems = Array.from(uniqueMap.values());

            uniqueItems.sort((a, b) => {
                const aScore = (a.orderCount || 0) * 3 + (a.rating || 0) * 20 + (a.discountPercentage || 0) * 2;
                const bScore = (b.orderCount || 0) * 3 + (b.rating || 0) * 20 + (b.discountPercentage || 0) * 2;
                return bScore - aScore;
            });

            let finalRecommendations = uniqueItems.slice(0, limit);

            if (finalRecommendations.length < limit) {
                const fillCount = limit - finalRecommendations.length;
                const fallbackPool = await prisma.pharmacyItem.findMany({
                    where: {
                        isAvailable: true,
                        id: { notIn: finalRecommendations.map(item => item.id) }
                    },
                    include,
                    orderBy: [{ orderCount: 'desc' }, { rating: 'desc' }, { createdAt: 'desc' }],
                    take: fillCount
                });

                finalRecommendations = [...finalRecommendations, ...fallbackPool];
            }
            return res.json({
                success: true,
                source: 'heuristic',
                page,
                limit,
                hasMore: page < 5 && finalRecommendations.length === limit,
                data: finalRecommendations.map(formatItem)
            });
        } catch (error) {
            console.error('Get pharmacy recommended items error:', error);
            return res.status(500).json({
                success: false,
                message: 'Server error',
            });
        }
    }
);

/**
 * @route   GET /api/pharmacies/24-hours
 * @desc    Get 24-hour pharmacies
 * @access  Public
 */
router.get("/24-hours", async (req, res) => {
    try {
        const stores = await prisma.pharmacyStore.findMany({
            where: {
                operatingHoursString: '24/7',
                isOpen: true,
                status: 'approved'
            },
            orderBy: { rating: 'desc' },
            take: 10
        });

        res.json({
            success: true,
            message: "24-hour pharmacies retrieved successfully",
            count: stores.length,
            data: stores.map(formatStore)
        });
    } catch (error) {
        console.error("Get 24-hour pharmacies error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
        });
    }
});

/**
 * @route   GET /api/pharmacies/nearby
 * @desc    Get nearby pharmacies using PostGIS
 * @access  Public
 */
router.get("/nearby", cacheMiddleware(cache.CACHE_KEYS.PHARMACY + ':nearby', 180), async (req, res) => {
    try {
        const { lat, lng, radius = 5, exclusive } = req.query;

        if (!lat || !lng) {
            return res.status(400).json({
                success: false,
                message: "Latitude and longitude are required"
            });
        }

        const latitude = parseFloat(lat);
        const longitude = parseFloat(lng);
        const radiusInKm = parseFloat(radius);
        const exclusiveOnly = exclusive === 'true';
        const exclusiveClause = exclusiveOnly
            ? Prisma.sql`AND "isGrabGoExclusive" = true AND ("isGrabGoExclusiveUntil" IS NULL OR "isGrabGoExclusiveUntil" > NOW())`
            : Prisma.empty;

        const nearbyStores = await prisma.$queryRaw`
            SELECT *, 
            ST_Distance(
                ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
                ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
            ) AS distance
            FROM pharmacy_stores
            WHERE status = 'approved' AND "isOpen" = true
            ${exclusiveClause}
            AND ST_DWithin(
                ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
                ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography,
                ${radiusInKm * 1000}
            )
            ORDER BY distance ASC
            LIMIT 20
        `;

        res.json({
            success: true,
            message: "Nearby pharmacies retrieved successfully",
            count: nearbyStores.length,
            data: nearbyStores.map(store => ({
                ...formatStore(store),
                distance: store.distance
            }))
        });
    } catch (error) {
        console.error("Get nearby pharmacies error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
        });
    }
});

/**
 * @route   GET /api/pharmacies/stores/:id
 * @desc    Get pharmacy store by ID
 * @access  Public
 */
router.get("/stores/:id", async (req, res) => {
    try {
        const store = await prisma.pharmacyStore.findUnique({
            where: { id: req.params.id },
            include: {
                openingHours: {
                    select: {
                        dayOfWeek: true,
                        openTime: true,
                        closeTime: true,
                        isClosed: true,
                    }
                }
            }
        });

        if (!store) {
            return res.status(404).json({
                success: false,
                message: "Pharmacy store not found"
            });
        }

        res.json({
            success: true,
            message: "Pharmacy store retrieved successfully",
            data: formatStore(store)
        });
    } catch (error) {
        console.error("Get pharmacy store error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
        });
    }
});

module.exports = router;
