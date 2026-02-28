const express = require('express');
const router = express.Router();
const prisma = require('../config/prisma');
const { protect } = require('../middleware/auth');
const { cacheMiddleware } = require('../middleware/cache');
const cache = require('../utils/cache');
const mlClient = require('../utils/ml_client');
const { normalizeRatingResponse } = require("../utils/rating_calculator");

/**
 * Helper to format grocery store for frontend compatibility
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
        // Legacy support mapping
        store_name: store.storeName,
        is_open: store.isOpen,
        delivery_fee: store.deliveryFee,
        min_order: store.minOrder,
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
 * Helper to format grocery item for frontend compatibility
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
 * @route   GET /api/groceries/stores
 * @desc    Get grocery stores
 * @access  Public
 */
router.get("/stores", cacheMiddleware(cache.CACHE_KEYS.GROCERY + ':stores', 300), async (req, res) => {
    try {
        const stores = await prisma.groceryStore.findMany({
            where: {
                isOpen: true,
                status: 'approved'
            },
            orderBy: {
                rating: 'desc'
            },
            take: 20
        });

        res.json({
            success: true,
            message: "Grocery stores retrieved successfully",
            count: stores.length,
            data: stores.map(formatStore)
        });
    } catch (error) {
        console.error("Get grocery stores error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/groceries/nearby
 * @desc    Get nearby grocery stores using PostGIS
 * @access  Public
 */
router.get("/nearby", cacheMiddleware(cache.CACHE_KEYS.GROCERY + ':nearby', 180), async (req, res) => {
    try {
        const { lat, lng, radius = 5 } = req.query;

        if (!lat || !lng) {
            return res.status(400).json({
                success: false,
                message: "Latitude and longitude are required"
            });
        }

        const latitude = parseFloat(lat);
        const longitude = parseFloat(lng);
        const radiusInKm = parseFloat(radius);

        // Raw query for PostGIS distance calculation and filtering
        const nearbyStores = await prisma.$queryRaw`
            SELECT *, 
            ST_Distance(
                ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
                ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
            ) AS distance
            FROM grocery_stores
            WHERE status = 'approved' AND "isOpen" = true
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
            message: "Nearby grocery stores retrieved successfully",
            count: nearbyStores.length,
            data: nearbyStores.map(store => ({
                ...formatStore(store),
                distance: store.distance
            }))
        });
    } catch (error) {
        console.error("Get nearby grocery stores error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/groceries/stores/:id
 * @desc    Get store by ID
 * @access  Public
 */
router.get("/stores/:id", async (req, res) => {
    try {
        const store = await prisma.groceryStore.findUnique({
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
                message: "Store not found"
            });
        }

        res.json({
            success: true,
            message: "Store retrieved successfully",
            data: formatStore(store)
        });
    } catch (error) {
        console.error("Get store error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

// ==================== CATEGORIES ====================

/**
 * @route   GET /api/groceries/categories
 * @desc    Get all grocery categories
 * @access  Public
 */
router.get("/categories", cacheMiddleware(cache.CACHE_KEYS.GROCERY + ':categories', 600), async (req, res) => {
    try {
        const { userLat, userLng, maxDistance = 15 } = req.query;
        const userLatitude = userLat ? parseFloat(userLat) : null;
        const userLongitude = userLng ? parseFloat(userLng) : null;
        const maxDistanceKm = parseFloat(maxDistance);

        let where = { isActive: true };

        // If location provided, only show categories that have items in nearby stores
        if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude)) {
            console.log('🌍 [GROCERY CATEGORIES] Location-based filtering enabled');

            const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
            const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

            const nearbyStores = await prisma.groceryStore.findMany({
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
                const categoriesWithItems = await prisma.groceryItem.findMany({
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
                    console.log('   ⚠️ No valid grocery categories nearby - returning 0 categories');
                    return res.json({
                        success: true,
                        message: "No grocery categories available in your area",
                        data: []
                    });
                }

                where.id = { in: activeCategoryIds };
                console.log(`   ✅ Filtered to ${activeCategoryIds.length} active categories nearby`);
            } else {
                console.log('   ⚠️ No stores nearby - returning 0 categories');
                return res.json({
                    success: true,
                    message: "No grocery categories available in your area",
                    data: []
                });
            }
        }

        const categories = await prisma.groceryCategory.findMany({
            where,
            orderBy: { sortOrder: 'asc' }
        });

        res.json({
            success: true,
            message: "Categories retrieved successfully",
            data: categories
        });
    } catch (error) {
        console.error("Get categories error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

// ==================== ITEMS ====================

/**
 * @route   GET /api/groceries/items
 * @desc    Get all grocery items with optional filters
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
            console.log('🌍 [GROCERY ITEMS] Location-based filtering enabled');
            console.log(`   📍 User location: (${userLatitude}, ${userLongitude})`);
            console.log(`   📏 Max distance: ${maxDistanceKm}km`);

            const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
            const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

            const nearbyStores = await prisma.groceryStore.findMany({
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
            if (filteredStores.length > 0) {
                console.log(`   📋 Store names: ${filteredStores.map(s => s.storeName).join(', ')}`);
            }

            const storeIds = filteredStores.map(s => s.id);

            if (storeIds.length === 0) {
                console.log('   ⚠️  No stores found in area - returning empty array');
                return res.json({
                    success: true,
                    message: "No grocery items available in your area",
                    data: []
                });
            }

            where.storeId = { in: storeIds };
        } else if (store) {
            console.log(`🏪 [GROCERY ITEMS] Filtering by specific store: ${store}`);
            where.storeId = store;
        } else if (!userLatitude || !userLongitude) {
            console.log('📍 [GROCERY ITEMS] No location provided - showing all items');
        }

        const items = await prisma.groceryItem.findMany({
            where,
            include: {
                category: { select: { name: true, emoji: true } },
                store: {
                    select: {
                        id: true,
                        storeName: true,
                        logo: true,
                        longitude: true,
                        latitude: true,
                        address: true,
                        city: true,
                        area: true,
                        isOpen: true,
                        deliveryFee: true,
                        minOrder: true
                    }
                }
            },
            orderBy: { rating: 'desc' },
            take: 50
        });

        console.log(`✅ [GROCERY ITEMS] Returning ${items.length} items to frontend`);

        res.json({
            success: true,
            message: "Items retrieved successfully",
            data: items.map(formatItem)
        });
    } catch (error) {
        console.error("Get items error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/groceries/items/:id
 * @desc    Get grocery item by ID
 * @access  Public
 */
router.get("/items/:id", async (req, res) => {
    try {
        const item = await prisma.groceryItem.findUnique({
            where: { id: req.params.id },
            include: {
                category: { select: { name: true, emoji: true } },
                store: {
                    select: {
                        id: true,
                        storeName: true,
                        logo: true,
                        longitude: true,
                        latitude: true,
                        address: true,
                        city: true,
                        area: true,
                        phone: true,
                        isOpen: true,
                        deliveryFee: true,
                        minOrder: true
                    }
                }
            }
        });

        if (!item) {
            return res.status(404).json({
                success: false,
                message: "Item not found"
            });
        }

        res.json({
            success: true,
            message: "Item retrieved successfully",
            data: formatItem(item)
        });
    } catch (error) {
        console.error("Get item error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/groceries/search
 * @desc    Search grocery items by name, description, brand, or tags
 * @access  Public
 */
router.get("/search", async (req, res) => {
    try {
        const { q } = req.query;

        if (!q) {
            return res.status(400).json({
                success: false,
                message: "Search query is required"
            });
        }

        const items = await prisma.groceryItem.findMany({
            where: {
                isAvailable: true,
                OR: [
                    { name: { contains: q, mode: 'insensitive' } },
                    { description: { contains: q, mode: 'insensitive' } },
                    { brand: { contains: q, mode: 'insensitive' } }
                ]
            },
            include: {
                category: { select: { name: true, emoji: true } },
                store: {
                    select: {
                        id: true,
                        storeName: true,
                        logo: true,
                        longitude: true,
                        latitude: true,
                        address: true,
                        city: true,
                        area: true,
                        isOpen: true,
                        deliveryFee: true,
                        minOrder: true
                    }
                }
            },
            take: 30
        });

        res.json({
            success: true,
            message: "Search results retrieved successfully",
            data: items.map(formatItem)
        });
    } catch (error) {
        console.error("Search error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/groceries/deals
 * @desc    Get grocery items with active discounts
 * @access  Public
 */
router.get("/deals", async (req, res) => {
    try {
        const { userLat, userLng, maxDistance = 15 } = req.query;
        const now = new Date();

        const userLatitude = userLat ? parseFloat(userLat) : null;
        const userLongitude = userLng ? parseFloat(userLng) : null;
        const maxDistanceKm = parseFloat(maxDistance);

        let where = {
            isAvailable: true,
            discountPercentage: { gt: 0 },
            OR: [
                { discountEndDate: null },
                { discountEndDate: { gte: now } }
            ]
        };

        // Filter by nearby stores if user location provided
        if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude)) {
            console.log('🌍 [GROCERY DEALS] Location-based filtering enabled');
            console.log(`   📍 User location: (${userLatitude}, ${userLongitude})`);

            const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
            const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

            const nearbyStores = await prisma.groceryStore.findMany({
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

            console.log(`   ✅ ${filteredStores.length} stores within ${maxDistanceKm}km`);

            const storeIds = filteredStores.map(s => s.id);

            if (storeIds.length === 0) {
                console.log('   ⚠️  No stores found - returning empty deals');
                return res.json({
                    success: true,
                    message: "No grocery deals available in your area",
                    data: []
                });
            }

            where.storeId = { in: storeIds };
        } else {
            console.log('📍 [GROCERY DEALS] No location - showing all deals');
        }

        const deals = await prisma.groceryItem.findMany({
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
            orderBy: { discountPercentage: 'desc' },
            take: 10
        });

        console.log(`✅ [GROCERY DEALS] Returning ${deals.length} deals to frontend`);

        res.json({
            success: true,
            message: "Deals retrieved successfully",
            data: deals.map(formatItem)
        });
    } catch (error) {
        console.error("Get deals error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/groceries/recommended
 * @desc    Get personalized grocery recommendations (ML-first with heuristic fallback)
 * @access  Public (Optional Auth)
 */
router.get(
    "/recommended",
    optionalAuth,
    cacheMiddleware(`${cache.CACHE_KEYS.GROCERY}:recommended`, 180, true),
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

                const nearbyStores = await prisma.groceryStore.findMany({
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
                    const mlRecommendations = await mlClient.getStoreRecommendations(userId, 'grocery', 30);
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

                            const candidateItems = await prisma.groceryItem.findMany({
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
                    console.error('🤖 Grocery ML recommendation failed, using fallback:', mlError.message);
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
                prisma.groceryItem.findMany({
                    where: { isAvailable: true, ...locationWhere },
                    orderBy: [{ orderCount: 'desc' }, { rating: 'desc' }],
                    take: popularCount,
                    skip: Math.floor(skip * 0.4),
                    include
                }),
                prisma.groceryItem.findMany({
                    where: { isAvailable: true, rating: { gte: 4.5 }, ...locationWhere },
                    orderBy: [{ rating: 'desc' }, { reviewCount: 'desc' }],
                    take: ratedCount,
                    skip: Math.floor(skip * 0.3),
                    include
                }),
                prisma.groceryItem.findMany({
                    where: { isAvailable: true, discountPercentage: { gt: 0 }, ...locationWhere },
                    orderBy: [{ discountPercentage: 'desc' }, { orderCount: 'desc' }],
                    take: dealsCount,
                    skip: Math.floor(skip * 0.2),
                    include
                }),
                prisma.groceryItem.findMany({
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
                const fallbackPool = await prisma.groceryItem.findMany({
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
            console.error('Get grocery recommended items error:', error);
            return res.status(500).json({
                success: false,
                message: 'Server error',
                error: error.message
            });
        }
    }
);

/**
 * @route   GET /api/groceries/stores/:id/items
 * @desc    Get all items from a specific store
 * @access  Public
 */
router.get("/stores/:id/items", async (req, res) => {
    try {
        const items = await prisma.groceryItem.findMany({
            where: {
                storeId: req.params.id,
                isAvailable: true
            },
            include: {
                category: { select: { name: true, emoji: true } }
            },
            orderBy: { name: 'asc' }
        });

        res.json({
            success: true,
            message: "Store items retrieved successfully",
            data: items
        });
    } catch (error) {
        console.error("Get store items error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

// ==================== STORE SPECIALS ====================

/**
 * @route   GET /api/groceries/store-specials
 * @desc    Get grocery items with active discounts, grouped by store
 * @access  Public
 */
router.get("/store-specials", async (req, res) => {
    try {
        const now = new Date();

        // Find items with active discounts
        const items = await prisma.groceryItem.findMany({
            where: {
                isAvailable: true,
                discountPercentage: { gt: 0 },
                OR: [
                    { discountEndDate: null },
                    { discountEndDate: { gte: now } }
                ]
            },
            include: {
                store: {
                    select: {
                        id: true,
                        storeName: true,
                        logo: true,
                        rating: true,
                        isOpen: true,
                        deliveryFee: true,
                        minOrder: true
                    }
                },
                category: { select: { name: true, emoji: true } }
            },
            orderBy: { discountPercentage: 'desc' },
            take: 100
        });

        if (!items || items.length === 0) {
            return res.status(200).json({
                success: true,
                count: 0,
                data: []
            });
        }

        // Group items by store
        const storeMap = new Map();

        items.forEach(item => {
            if (item.store) {
                const storeId = item.store.id;

                if (!storeMap.has(storeId)) {
                    storeMap.set(storeId, {
                        storeId: item.store.id,
                        storeName: item.store.storeName,
                        storeLogo: item.store.logo,
                        storeRating: item.store.rating,
                        isOpen: item.store.isOpen,
                        deliveryFee: item.store.deliveryFee,
                        minOrder: item.store.minOrder,
                        items: []
                    });
                }

                storeMap.get(storeId).items.push(item);
            }
        });

        // Convert map to array and limit items per store
        const storeSpecials = Array.from(storeMap.values())
            .map(store => ({
                ...store,
                items: store.items.slice(0, 10).map(formatItem)
            }))
            .filter(store => store.items.length > 0)
            .sort((a, b) => b.items.length - a.items.length)
            .slice(0, 5);

        res.status(200).json({
            success: true,
            count: storeSpecials.length,
            data: storeSpecials
        });

    } catch (error) {
        console.error('Get store specials error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

// ==================== ORDER HISTORY ====================

/**
 * @route   GET /api/groceries/order-history
 * @desc    Get user's grocery order history (Buy Again section)
 * @access  Private
 */
router.get("/order-history", protect, async (req, res) => {
    try {
        const userId = req.user.id;

        // Get completed grocery orders for the user
        const orders = await prisma.order.findMany({
            where: {
                customerId: userId,
                orderType: 'grocery',
                status: 'delivered'
            },
            include: {
                items: {
                    where: { itemType: 'GroceryItem' },
                    include: {
                        groceryItem: {
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
                            }
                        }
                    }
                }
            },
            orderBy: [
                { deliveredDate: 'desc' },
                { orderDate: 'desc' }
            ],
            take: 50
        });

        if (!orders || orders.length === 0) {
            return res.status(200).json({
                success: true,
                count: 0,
                data: []
            });
        }

        // Extract unique grocery items from orders
        const itemsMap = new Map();

        orders.forEach(order => {
            order.items.forEach(item => {
                if (item.groceryItem) {
                    const itemId = item.groceryItem.id;

                    if (!itemsMap.has(itemId)) {
                        itemsMap.set(itemId, {
                            item: item.groceryItem,
                            lastOrdered: order.deliveredDate || order.orderDate,
                            timesOrdered: 1,
                            totalQuantity: item.quantity
                        });
                    } else {
                        const existing = itemsMap.get(itemId);
                        existing.timesOrdered += 1;
                        existing.totalQuantity += item.quantity;
                        const orderDate = order.deliveredDate || order.orderDate;
                        if (orderDate > existing.lastOrdered) {
                            existing.lastOrdered = orderDate;
                        }
                    }
                }
            });
        });

        // Convert map to array and sort by last ordered date
        const buyAgainItems = Array.from(itemsMap.values())
            .sort((a, b) => b.lastOrdered - a.lastOrdered)
            .slice(0, 20)
            .map(({ item, lastOrdered, timesOrdered, totalQuantity }) => ({
                ...formatItem(item),
                lastOrderedAt: lastOrdered,
                timesOrdered,
                totalQuantity
            }));

        res.status(200).json({
            success: true,
            count: buyAgainItems.length,
            data: buyAgainItems
        });

    } catch (error) {
        console.error('Error fetching grocery order history:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to fetch order history',
            message: error.message
        });
    }
});

// ==================== POPULAR ITEMS ====================

/**
 * @route   GET /api/groceries/popular
 * @desc    Get popular grocery items
 * @access  Public
 */
router.get("/popular", async (req, res) => {
    try {
        let { limit = 10, userLat, userLng, maxDistance = 15 } = req.query;
        limit = Math.min(parseInt(limit) || 10, 50);

        const userLatitude = userLat ? parseFloat(userLat) : null;
        const userLongitude = userLng ? parseFloat(userLng) : null;
        const maxDistanceKm = parseFloat(maxDistance);

        let where = { isAvailable: true };

        // Filter by nearby stores if user location provided
        if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude)) {
            console.log('🌍 [GROCERY POPULAR] Location-based filtering enabled');
            console.log(`   📍 User location: (${userLatitude}, ${userLongitude})`);

            const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
            const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

            const nearbyStores = await prisma.groceryStore.findMany({
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

            console.log(`   ✅ ${filteredStores.length} stores within ${maxDistanceKm}km`);

            const storeIds = filteredStores.map(s => s.id);

            if (storeIds.length === 0) {
                console.log('   ⚠️  No stores found - returning empty popular items');
                return res.json({
                    success: true,
                    message: "No popular grocery items available in your area",
                    data: []
                });
            }

            where.storeId = { in: storeIds };
        } else {
            console.log('📍 [GROCERY POPULAR] No location - showing all popular items');
        }

        const popularItems = await prisma.groceryItem.findMany({
            where,
            orderBy: [
                { orderCount: 'desc' },
                { rating: 'desc' }
            ],
            take: limit,
            include: {
                category: { select: { name: true, emoji: true } },
                store: {
                    select: {
                        id: true,
                        storeName: true,
                        logo: true,
                        rating: true,
                        isOpen: true,
                        deliveryFee: true,
                        minOrder: true
                    }
                }
            }
        });

        console.log(`✅ [GROCERY POPULAR] Returning ${popularItems.length} popular items to frontend`);

        res.json({
            success: true,
            message: "Popular items retrieved successfully",
            data: popularItems.map(formatItem)
        });
    } catch (error) {
        console.error("Get popular items error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

// ==================== TOP RATED ITEMS ====================

/**
 * @route   GET /api/groceries/top-rated
 * @desc    Get top-rated grocery items
 * @access  Public
 */
router.get("/top-rated", async (req, res) => {
    try {
        let { limit = 10, minRating = 4.5 } = req.query;
        limit = Math.min(parseInt(limit) || 10, 50);
        minRating = parseFloat(minRating) || 4.5;

        const topRatedItems = await prisma.groceryItem.findMany({
            where: {
                isAvailable: true,
                rating: { gte: minRating }
            },
            orderBy: [
                { rating: 'desc' },
                { reviewCount: 'desc' }
            ],
            take: limit,
            include: {
                category: { select: { name: true, emoji: true } },
                store: {
                    select: {
                        id: true,
                        storeName: true,
                        logo: true,
                        rating: true,
                        isOpen: true,
                        deliveryFee: true,
                        minOrder: true
                    }
                }
            }
        });

        res.json({
            success: true,
            message: "Top rated items retrieved successfully",
            data: topRatedItems.map(formatItem)
        });
    } catch (error) {
        console.error("Get top rated items error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

module.exports = router;
