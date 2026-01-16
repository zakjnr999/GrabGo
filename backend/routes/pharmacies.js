const express = require('express');
const router = express.Router();
const PharmacyStore = require('../models/PharmacyStore');
const PharmacyCategory = require('../models/PharmacyCategory');
const PharmacyItem = require('../models/PharmacyItem');
const { protect } = require('../middleware/auth');

// ==================== STORES ====================

/**
 * @route   GET /api/pharmacies/stores
 * @desc    Get all pharmacy stores
 * @access  Public
 */
router.get("/stores", async (req, res) => {
    try {
        const { isOpen, minRating, limit = 20 } = req.query;

        let query = {};

        // Filter by open status
        if (isOpen !== undefined) {
            query.isOpen = isOpen === 'true';
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

        const stores = await PharmacyStore.find({ ...query, status: 'approved' })
            .sort({ rating: -1, totalReviews: -1 })
            .limit(limitValue);

        res.json({
            success: true,
            message: "Pharmacy stores retrieved successfully",
            count: stores.length,
            data: stores
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
 * NOTE: This route MUST come before /stores/:id to avoid route conflicts
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

        let query = {
            status: 'approved',
            $or: [
                { storeName: { $regex: q, $options: 'i' } },
                { description: { $regex: q, $options: 'i' } },
                { categories: { $in: [new RegExp(q, 'i')] } },
                { 'location.address': { $regex: q, $options: 'i' } },
                { 'location.city': { $regex: q, $options: 'i' } },
                { 'location.area': { $regex: q, $options: 'i' } }
            ]
        };

        // Filter for emergency services
        if (emergencyService === 'true') {
            query.emergencyService = true;
        }

        // Filter for prescription services
        if (prescriptionService === 'true') {
            query.prescriptionRequired = true;
        }

        const stores = await PharmacyStore.find(query)
            .sort({ rating: -1 })
            .limit(30);

        res.json({
            success: true,
            message: "Search results retrieved successfully",
            count: stores.length,
            data: stores
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
        const stores = await PharmacyStore.find({
            emergencyService: true,
            isOpen: true
        })
            .sort({ rating: -1 })
            .limit(10);

        res.json({
            success: true,
            message: "Emergency pharmacies retrieved successfully",
            count: stores.length,
            data: stores
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
router.get("/categories", async (req, res) => {
    try {
        const categories = await PharmacyCategory.find({ isActive: true })
            .sort({ sortOrder: 1 });

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

        const items = await PharmacyItem.find(query)
            .populate('category', 'name emoji')
            .populate('store', 'store_name logo')
            .sort({ orderCount: -1 })
            .limit(50);

        res.json({
            success: true,
            message: "Pharmacy items retrieved successfully",
            count: items.length,
            data: items
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
        const stores = await PharmacyStore.find({
            operatingHours: '24/7',
            isOpen: true
        })
            .sort({ rating: -1 })
            .limit(10);

        res.json({
            success: true,
            message: "24-hour pharmacies retrieved successfully",
            count: stores.length,
            data: stores
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
 * @desc    Get nearby pharmacies based on location
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

        // Use aggregation for $geoNear which provides the distance in the output
        const nearbyStores = await PharmacyStore.aggregate([
            {
                $geoNear: {
                    near: { type: "Point", coordinates: [longitude, latitude] },
                    distanceField: "distance",
                    maxDistance: radiusInKm * 1000,
                    query: { isOpen: true, status: 'approved' },
                    spherical: true
                }
            },
            { $limit: 20 },
            // Add _id back to id if frontend expects it, or use toObject in mapping
            {
                $addFields: {
                    id: "$_id",
                    // Convert distance from meters to kilometers
                    distance: { $divide: ["$distance", 1000] }
                }
            }
        ]);

        res.json({
            success: true,
            message: "Nearby pharmacies retrieved successfully",
            count: nearbyStores.length,
            data: nearbyStores
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
 * NOTE: This route MUST come after specific routes like /search, /emergency, etc.
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

        const store = await PharmacyStore.findById(req.params.id);

        if (!store) {
            return res.status(404).json({
                success: false,
                message: "Pharmacy store not found"
            });
        }

        res.json({
            success: true,
            message: "Pharmacy store retrieved successfully",
            data: store
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
