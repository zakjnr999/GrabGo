const express = require('express');
const router = express.Router();
const GroceryStore = require('../models/GroceryStore');
const GroceryCategory = require('../models/GroceryCategory');
const GroceryItem = require('../models/GroceryItem');
const { protect } = require('../middleware/auth');

// ==================== STORES ====================

// Get all grocery stores
router.get("/stores", async (req, res) => {
    try {
        const stores = await GroceryStore.find({ isOpen: true })
            .sort({ rating: -1 })
            .limit(20);

        res.json({
            success: true,
            message: "Grocery stores retrieved successfully",
            data: stores
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

// Get store by ID
router.get("/stores/:id", async (req, res) => {
    try {
        const store = await GroceryStore.findById(req.params.id);

        if (!store) {
            return res.status(404).json({
                success: false,
                message: "Store not found"
            });
        }

        res.json({
            success: true,
            message: "Store retrieved successfully",
            data: store
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

// Get all grocery categories
router.get("/categories", async (req, res) => {
    try {
        const categories = await GroceryCategory.find({ isActive: true })
            .sort({ sortOrder: 1 });

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

// Get all grocery items (with filters)
router.get("/items", async (req, res) => {
    try {
        const { category, store, minPrice, maxPrice, tags } = req.query;

        let query = { isAvailable: true };

        // Filter by category
        if (category) {
            query.category = category;
        }

        // Filter by store
        if (store) {
            query.store = store;
        }

        // Filter by price range
        if (minPrice || maxPrice) {
            query.price = {};
            if (minPrice) query.price.$gte = parseFloat(minPrice);
            if (maxPrice) query.price.$lte = parseFloat(maxPrice);
        }

        // Filter by tags
        if (tags) {
            const tagArray = tags.split(',');
            query.tags = { $in: tagArray };
        }

        const items = await GroceryItem.find(query)
            .populate('category', 'name emoji')
            .populate('store', 'store_name logo')
            .sort({ rating: -1 })
            .limit(50);

        res.json({
            success: true,
            message: "Items retrieved successfully",
            data: items
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

// Get item by ID
router.get("/items/:id", async (req, res) => {
    try {
        const item = await GroceryItem.findById(req.params.id)
            .populate('category', 'name emoji')
            .populate('store', 'store_name logo address phone');

        if (!item) {
            return res.status(404).json({
                success: false,
                message: "Item not found"
            });
        }

        res.json({
            success: true,
            message: "Item retrieved successfully",
            data: item
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

// Search grocery items
router.get("/search", async (req, res) => {
    try {
        const { q } = req.query;

        if (!q) {
            return res.status(400).json({
                success: false,
                message: "Search query is required"
            });
        }

        const items = await GroceryItem.find({
            $text: { $search: q },
            isAvailable: true
        })
            .populate('category', 'name emoji')
            .populate('store', 'store_name logo')
            .limit(30);

        res.json({
            success: true,
            message: "Search results retrieved successfully",
            data: items
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

// Get deals (items with discounts)
router.get("/deals", async (req, res) => {
    try {
        const now = new Date();

        const deals = await GroceryItem.find({
            isAvailable: true,
            discountPercentage: { $gt: 0 },
            $or: [
                { discountEndDate: null },
                { discountEndDate: { $gte: now } }
            ]
        })
            .populate('category', 'name emoji')
            .populate('store', 'store_name logo')
            .sort({ discountPercentage: -1 })
            .limit(10);

        res.json({
            success: true,
            message: "Deals retrieved successfully",
            data: deals
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

// Get items from a specific store
router.get("/stores/:id/items", async (req, res) => {
    try {
        const items = await GroceryItem.find({
            store: req.params.id,
            isAvailable: true
        })
            .populate('category', 'name emoji')
            .sort({ name: 1 });

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
        const items = await GroceryItem.find({
            isAvailable: true,
            discountPercentage: { $gt: 0 },
            $or: [
                { discountEndDate: null },
                { discountEndDate: { $gte: now } }
            ]
        })
            .populate('store', 'store_name logo rating isOpen deliveryFee minOrder')
            .populate('category', 'name emoji')
            .sort({ discountPercentage: -1 })
            .limit(50);

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
                const storeId = item.store._id.toString();

                if (!storeMap.has(storeId)) {
                    storeMap.set(storeId, {
                        storeId: item.store._id,
                        storeName: item.store.store_name,
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
                items: store.items.slice(0, 10) // Limit to 10 items per store
            }))
            .filter(store => store.items.length > 0) // Only stores with items
            .sort((a, b) => b.items.length - a.items.length) // Sort by item count
            .slice(0, 5); // Limit to top 5 stores

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

// Get grocery order history for current user (for Buy Again section)
router.get("/order-history", protect, async (req, res) => {
    try {
        const Order = require('../models/Order');

        // For now, return empty array if no user authentication
        // In production, this should be protected with auth middleware
        if (!req.user && !req.headers['x-user-id']) {
            return res.status(200).json({
                success: true,
                count: 0,
                data: []
            });
        }

        const userId = req.user?._id || req.headers['x-user-id'];

        // Get completed grocery orders for the user
        const orders = await Order.find({
            customer: userId,
            orderType: 'grocery',
            status: 'delivered' // Only delivered orders (completed doesn't exist in enum)
        })
            .populate({
                path: 'items.groceryItem',
                model: 'GroceryItem',
                populate: [
                    { path: 'category', model: 'GroceryCategory' },
                    { path: 'store', model: 'GroceryStore' }
                ]
            })
            .sort({ deliveredDate: -1, orderDate: -1 })
            .limit(50);

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
                if (item.itemType === 'grocery' && item.groceryItem) {
                    const itemId = item.groceryItem._id.toString();

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
                        existing.totalQuantity += item.quantity; // FIX: was undefined totalQuantity
                        // Update last ordered if this order is more recent
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
            .slice(0, 20) // Return top 20 most recent items
            .map(({ item, lastOrdered, timesOrdered, totalQuantity }) => ({
                ...item.toObject(),
                lastOrderedAt: lastOrdered, // Renamed for frontend consistency
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

// Get popular items (sorted by order count)
router.get("/popular", async (req, res) => {
    try {
        // Validate and sanitize limit parameter
        let { limit = 10 } = req.query;
        limit = parseInt(limit);

        // Handle invalid input
        if (isNaN(limit) || limit < 1) {
            limit = 10;
        }
        // Cap at maximum 50 items
        if (limit > 50) {
            limit = 50;
        }

        const popularItems = await GroceryItem.find({ isAvailable: true })
            .sort({ orderCount: -1, rating: -1 }) // Sort by order count, then rating
            .limit(limit)
            .populate('category', 'name emoji')
            .populate('store', 'store_name logo rating');

        res.json({
            success: true,
            message: "Popular items retrieved successfully",
            data: popularItems
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

// Get top-rated grocery items (sorted by rating)
router.get("/top-rated", async (req, res) => {
    try {
        // Validate and sanitize limit parameter
        let { limit = 10, minRating = 4.5 } = req.query;
        limit = parseInt(limit);
        minRating = parseFloat(minRating);

        // Handle invalid input
        if (isNaN(limit) || limit < 1) {
            limit = 10;
        }
        // Cap at maximum 50 items
        if (limit > 50) {
            limit = 50;
        }
        // Validate minRating
        if (isNaN(minRating) || minRating < 0 || minRating > 5) {
            minRating = 4.5;
        }

        const topRatedItems = await GroceryItem.find({
            isAvailable: true,
            rating: { $gte: minRating }
        })
            .sort({ rating: -1, totalReviews: -1 }) // Sort by rating, then review count
            .limit(limit)
            .populate('category', 'name emoji')
            .populate('store', 'store_name logo rating');

        res.json({
            success: true,
            message: "Top rated items retrieved successfully",
            data: topRatedItems
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

