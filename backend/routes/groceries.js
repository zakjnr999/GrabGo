const express = require('express');
const router = express.Router();
const GroceryStore = require('../models/GroceryStore');
const GroceryCategory = require('../models/GroceryCategory');
const GroceryItem = require('../models/GroceryItem');

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

module.exports = router;
