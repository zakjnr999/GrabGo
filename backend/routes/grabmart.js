const express = require('express');
const router = express.Router();
const GrabMartStore = require('../models/GrabMartStore');
const GrabMartCategory = require('../models/GrabMartCategory');
const GrabMartItem = require('../models/GrabMartItem');
const { protect } = require('../middleware/auth');

// ==================== STORES ====================

/**
 * @route   GET /api/grabmart/stores
 * @desc    Get all GrabMart stores
 * @access  Public
 */
router.get("/stores", async (req, res) => {
    try {
        const { isOpen, is24Hours, minRating, limit = 20 } = req.query;

        let query = {};

        // Filter by open status
        if (isOpen !== undefined) {
            query.isOpen = isOpen === 'true';
        }

        // Filter by 24-hour availability
        if (is24Hours !== undefined) {
            query.is24Hours = is24Hours === 'true';
        }

        // Filter by minimum rating
        if (minRating) {
            const rating = parseFloat(minRating);
            if (!isNaN(rating) && rating >= 0 && rating <= 5) {
                query.rating = { $gte: rating };
            }
        }

        // Validate and sanitize limit
        let limitValue = parseInt(limit);
        if (isNaN(limitValue) || limitValue < 1) {
            limitValue = 20;
        }
        if (limitValue > 100) {
            limitValue = 100;
        }

        const stores = await GrabMartStore.find(query)
            .sort({ rating: -1, totalReviews: -1 })
            .limit(limitValue);

        res.json({
            success: true,
            message: "GrabMart stores retrieved successfully",
            count: stores.length,
            data: stores
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
 * NOTE: This route MUST come before /stores/:id to avoid route conflicts
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

        let query = {
            $or: [
                { store_name: { $regex: q, $options: 'i' } },
                { description: { $regex: q, $options: 'i' } },
                { categories: { $in: [new RegExp(q, 'i')] } }
            ]
        };

        // Filter by services
        if (services) {
            const serviceArray = services.split(',');
            query.services = { $in: serviceArray };
        }

        // Filter by product types
        if (productTypes) {
            const productTypeArray = productTypes.split(',');
            query.productTypes = { $in: productTypeArray };
        }

        const stores = await GrabMartStore.find(query)
            .sort({ rating: -1 })
            .limit(30);

        res.json({
            success: true,
            message: "Search results retrieved successfully",
            count: stores.length,
            data: stores
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
router.get("/categories", async (req, res) => {
    try {
        const categories = await GrabMartCategory.find({ isActive: true })
            .sort({ sortOrder: 1 });

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

        const items = await GrabMartItem.find(query)
            .populate('category', 'name emoji')
            .populate('store', 'store_name logo')
            .sort({ orderCount: -1 })
            .limit(50);

        res.json({
            success: true,
            message: "GrabMart items retrieved successfully",
            count: items.length,
            data: items
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
        const stores = await GrabMartStore.find({
            is24Hours: true,
            isOpen: true
        })
            .sort({ rating: -1 })
            .limit(10);

        res.json({
            success: true,
            message: "24-hour GrabMart stores retrieved successfully",
            count: stores.length,
            data: stores
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

        const serviceArray = services.split(',');

        const stores = await GrabMartStore.find({
            services: { $in: serviceArray },
            isOpen: true
        })
            .sort({ rating: -1 })
            .limit(20);

        res.json({
            success: true,
            message: "GrabMart stores with services retrieved successfully",
            count: stores.length,
            data: stores
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
 * @desc    Get nearby GrabMart stores based on location
 * @access  Public
 */
router.get("/nearby", async (req, res) => {
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

        // Validate coordinates
        if (isNaN(latitude) || isNaN(longitude) || isNaN(radiusInKm)) {
            return res.status(400).json({
                success: false,
                message: "Invalid coordinates or radius"
            });
        }

        if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
            return res.status(400).json({
                success: false,
                message: "Latitude must be between -90 and 90, longitude between -180 and 180"
            });
        }

        if (radiusInKm <= 0 || radiusInKm > 100) {
            return res.status(400).json({
                success: false,
                message: "Radius must be between 0 and 100 km"
            });
        }

        // Get stores with valid coordinates
        const stores = await GrabMartStore.find({
            isOpen: true,
            latitude: { $exists: true, $ne: null, $ne: 0 },
            longitude: { $exists: true, $ne: null, $ne: 0 }
        });

        // Calculate distance and filter
        const nearbyStores = stores
            .map(store => {
                const distance = calculateDistance(
                    latitude,
                    longitude,
                    store.latitude,
                    store.longitude
                );
                return { ...store.toObject(), distance };
            })
            .filter(store => store.distance <= radiusInKm)
            .sort((a, b) => a.distance - b.distance)
            .slice(0, 20);

        res.json({
            success: true,
            message: "Nearby GrabMart stores retrieved successfully",
            count: nearbyStores.length,
            data: nearbyStores
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

        let query = { isOpen: true };

        if (cash === 'true') {
            query.acceptsCash = true;
        }
        if (card === 'true') {
            query.acceptsCard = true;
        }
        if (mobileMoney === 'true') {
            query.acceptsMobileMoney = true;
        }

        const stores = await GrabMartStore.find(query)
            .sort({ rating: -1 })
            .limit(20);

        res.json({
            success: true,
            message: "GrabMart stores retrieved successfully",
            count: stores.length,
            data: stores
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
 * NOTE: This route MUST come after specific routes like /search, /24-hours, etc.
 */
router.get("/stores/:id", async (req, res) => {
    try {
        // Validate MongoDB ObjectId format
        if (!req.params.id.match(/^[0-9a-fA-F]{24}$/)) {
            return res.status(400).json({
                success: false,
                message: "Invalid store ID format"
            });
        }

        const store = await GrabMartStore.findById(req.params.id);

        if (!store) {
            return res.status(404).json({
                success: false,
                message: "GrabMart store not found"
            });
        }

        res.json({
            success: true,
            message: "GrabMart store retrieved successfully",
            data: store
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

// Helper function to calculate distance between two coordinates (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
    const R = 6371; // Radius of the Earth in km
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLon = (lon2 - lon1) * Math.PI / 180;
    const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
        Math.sin(dLon / 2) * Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    const distance = R * c;
    return distance;
}

module.exports = router;
