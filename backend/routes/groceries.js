const express = require('express');
const router = express.Router();
const prisma = require('../config/prisma');
const { protect } = require('../middleware/auth');
const { cacheMiddleware } = require('../middleware/cache');
const cache = require('../utils/cache');

/**
 * Helper to format grocery store for frontend compatibility
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
 * Helper to format grocery item for frontend compatibility
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
            where: { id: req.params.id }
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
