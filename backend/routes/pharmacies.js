const express = require('express');
const router = express.Router();
const prisma = require('../config/prisma');
const { protect } = require('../middleware/auth');
const { cacheMiddleware } = require('../middleware/cache');
const cache = require('../utils/cache');

/**
 * Helper to format Pharmacy store for frontend compatibility
 */
const formatStore = (store) => {
    if (!store) return null;
    const formatted = {
        ...store,
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
    const formatted = {
        ...item,
        // Ensure store is formatted if it exists and is an object
        store: (item.store && typeof item.store === 'object') ? formatStore(item.store) : item.store
    };
    return formatted;
};

// ==================== STORES ====================

/**
 * @route   GET /api/pharmacies/stores
 * @desc    Get all pharmacy stores
 * @access  Public
 */
router.get("/stores", cacheMiddleware(cache.CACHE_KEYS.PHARMACY + ':stores', 300), async (req, res) => {
    try {
        const { isOpen, minRating, limit = 20 } = req.query;

        const where = { status: 'approved' };

        if (isOpen !== undefined) {
            where.isOpen = isOpen === 'true';
        }

        if (minRating) {
            const rating = parseFloat(minRating);
            if (!isNaN(rating)) {
                where.rating = { gte: rating };
            }
        }

        let limitValue = Math.min(parseInt(limit) || 20, 100);

        const stores = await prisma.pharmacyStore.findMany({
            where,
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
            error: error.message
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
            error: error.message
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
            error: error.message
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
            error: error.message
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
            error: error.message
        });
    }
});

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
            error: error.message
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

        const nearbyStores = await prisma.$queryRaw`
            SELECT *, 
            ST_Distance(
                ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
                ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
            ) AS distance
            FROM pharmacy_stores
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
            error: error.message
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
            where: { id: req.params.id }
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
            error: error.message
        });
    }
});

module.exports = router;
