const express = require('express');
const router = express.Router();
const prisma = require('../config/prisma');
const { protect } = require('../middleware/auth');
const { cacheMiddleware } = require('../middleware/cache');
const cache = require('../utils/cache');

/**
 * Helper to format GrabMart store for frontend compatibility
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
 * Helper to format GrabMart item for frontend compatibility
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
 * @route   GET /api/grabmart/stores
 * @desc    Get all GrabMart stores
 * @access  Public
 */
router.get("/stores", cacheMiddleware(cache.CACHE_KEYS.GRABMART + ':stores', 300), async (req, res) => {
    try {
        const { isOpen, is24Hours, minRating, limit = 20 } = req.query;

        const where = { status: 'approved' };

        if (isOpen !== undefined) {
            where.isOpen = isOpen === 'true';
        }

        if (is24Hours !== undefined) {
            where.is24Hours = is24Hours === 'true';
        }

        if (minRating) {
            const rating = parseFloat(minRating);
            if (!isNaN(rating)) {
                where.rating = { gte: rating };
            }
        }

        let limitValue = Math.min(parseInt(limit) || 20, 100);

        const stores = await prisma.grabMartStore.findMany({
            where,
            orderBy: [
                { rating: 'desc' },
                { ratingCount: 'desc' }
            ],
            take: limitValue
        });

        res.json({
            success: true,
            message: "GrabMart stores retrieved successfully",
            count: stores.length,
            data: stores.map(formatStore)
        });
    } catch (error) {
        console.error("Get GrabMart stores error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/grabmart/search
 * @desc    Search GrabMart stores
 * @access  Public
 */
router.get("/search", async (req, res) => {
    try {
        const { q, services, productTypes } = req.query;

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

        if (services) {
            where.services = { hasSome: services.split(',') };
        }

        if (productTypes) {
            where.productTypes = { hasSome: productTypes.split(',') };
        }

        const stores = await prisma.grabMartStore.findMany({
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
        console.error("Search GrabMart stores error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

// ==================== CATEGORIES ====================

/**
 * @route   GET /api/grabmart/categories
 * @desc    Get all GrabMart categories
 * @access  Public
 */
router.get("/categories", cacheMiddleware(cache.CACHE_KEYS.GRABMART + ':categories', 600), async (req, res) => {
    try {
        const categories = await prisma.grabMartCategory.findMany({
            where: { isActive: true },
            orderBy: { sortOrder: 'asc' }
        });

        res.json({
            success: true,
            message: "GrabMart categories retrieved successfully",
            count: categories.length,
            data: categories
        });
    } catch (error) {
        console.error("Get GrabMart categories error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

// ==================== ITEMS ====================

/**
 * @route   GET /api/grabmart/items
 * @desc    Get GrabMart items with optional filters
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
            const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
            const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

            const nearbyStores = await prisma.grabMartStore.findMany({
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

            if (storeIds.length === 0) {
                return res.json({
                    success: true,
                    message: "No GrabMart items available in your area",
                    data: []
                });
            }

            where.storeId = { in: storeIds };
        } else if (store) {
            where.storeId = store;
        }

        const items = await prisma.grabMartItem.findMany({
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

        res.json({
            success: true,
            message: "GrabMart items retrieved successfully",
            count: items.length,
            data: items.map(formatItem)
        });
    } catch (error) {
        console.error("Get GrabMart items error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/grabmart/24-hours
 * @desc    Get 24-hour GrabMart stores
 * @access  Public
 */
router.get("/24-hours", async (req, res) => {
    try {
        const stores = await prisma.grabMartStore.findMany({
            where: {
                is24Hours: true,
                isOpen: true,
                status: 'approved'
            },
            orderBy: { rating: 'desc' },
            take: 10
        });

        res.json({
            success: true,
            message: "24-hour GrabMart stores retrieved successfully",
            count: stores.length,
            data: stores.map(formatStore)
        });
    } catch (error) {
        console.error("Get 24-hour GrabMart stores error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/grabmart/with-services
 * @desc    Get GrabMart stores with specific services
 * @access  Public
 */
router.get("/with-services", async (req, res) => {
    try {
        const { services } = req.query;

        if (!services) {
            return res.status(400).json({
                success: false,
                message: "Services parameter is required"
            });
        }

        const stores = await prisma.grabMartStore.findMany({
            where: {
                services: { hasSome: services.split(',') },
                isOpen: true,
                status: 'approved'
            },
            orderBy: { rating: 'desc' },
            take: 20
        });

        res.json({
            success: true,
            message: "GrabMart stores with services retrieved successfully",
            count: stores.length,
            data: stores.map(formatStore)
        });
    } catch (error) {
        console.error("Get GrabMart stores with services error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/grabmart/nearby
 * @desc    Get nearby GrabMart stores using PostGIS
 * @access  Public
 */
router.get("/nearby", cacheMiddleware(cache.CACHE_KEYS.GRABMART + ':nearby', 180), async (req, res) => {
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
            FROM grabmart_stores
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
            message: "Nearby GrabMart stores retrieved successfully",
            count: nearbyStores.length,
            data: nearbyStores.map(store => ({
                ...formatStore(store),
                distance: store.distance
            }))
        });
    } catch (error) {
        console.error("Get nearby GrabMart stores error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/grabmart/payment-methods
 * @desc    Get GrabMart stores by payment methods
 * @access  Public
 */
router.get("/payment-methods", async (req, res) => {
    try {
        const { cash, card, mobileMoney } = req.query;

        const where = { isOpen: true, status: 'approved' };

        if (cash === 'true') {
            where.acceptsCash = true;
        }
        if (card === 'true') {
            where.acceptsCard = true;
        }
        if (mobileMoney === 'true') {
            where.acceptsMobileMoney = true;
        }

        const stores = await prisma.grabMartStore.findMany({
            where,
            orderBy: { rating: 'desc' },
            take: 20
        });

        res.json({
            success: true,
            message: "GrabMart stores retrieved successfully",
            count: stores.length,
            data: stores.map(formatStore)
        });
    } catch (error) {
        console.error("Get GrabMart stores by payment methods error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/grabmart/stores/:id
 * @desc    Get GrabMart store by ID
 * @access  Public
 */
router.get("/stores/:id", async (req, res) => {
    try {
        const store = await prisma.grabMartStore.findUnique({
            where: { id: req.params.id }
        });

        if (!store) {
            return res.status(404).json({
                success: false,
                message: "GrabMart store not found"
            });
        }

        res.json({
            success: true,
            message: "GrabMart store retrieved successfully",
            data: formatStore(store)
        });
    } catch (error) {
        console.error("Get GrabMart store error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

module.exports = router;
