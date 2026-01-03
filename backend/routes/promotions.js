const express = require("express");
const PromotionalBanner = require("../models/PromotionalBanner");
const { protect, authorize } = require("../middleware/auth");

const router = express.Router();

/**
 * @route   GET /api/promotions/banners/all
 * @desc    Get all promotional banners (including inactive)
 * @access  Admin only
 * NOTE: This route MUST come before /banners to avoid route matching issues
 */
router.get("/banners/all", protect, authorize("admin"), async (req, res) => {
    try {
        const banners = await PromotionalBanner.find()
            .sort({ createdAt: -1 });

        res.json({
            success: true,
            message: "All promotional banners retrieved successfully",
            data: banners
        });
    } catch (error) {
        console.error("Get all banners error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   GET /api/promotions/banners
 * @desc    Get active promotional banners
 * @access  Public
 */
router.get("/banners", async (req, res) => {
    try {
        const now = new Date();

        const banners = await PromotionalBanner.find({
            isActive: true,
            startDate: { $lte: now },
            endDate: { $gte: now }
        })
            .sort({ priority: -1, createdAt: -1 })
            .limit(10);

        res.json({
            success: true,
            message: "Promotional banners retrieved successfully",
            data: banners
        });
    } catch (error) {
        console.error("Get banners error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   POST /api/promotions/banners
 * @desc    Create promotional banner
 * @access  Admin only
 */
router.post("/banners", protect, authorize("admin"), async (req, res) => {
    try {
        // Validate required fields
        const { title, imageUrl, startDate, endDate } = req.body;

        if (!title || !imageUrl || !startDate || !endDate) {
            return res.status(400).json({
                success: false,
                message: "Missing required fields",
                required: ["title", "imageUrl", "startDate", "endDate"]
            });
        }

        // Validate dates
        const start = new Date(startDate);
        const end = new Date(endDate);

        if (isNaN(start.getTime()) || isNaN(end.getTime())) {
            return res.status(400).json({
                success: false,
                message: "Invalid date format"
            });
        }

        if (end <= start) {
            return res.status(400).json({
                success: false,
                message: "End date must be after start date"
            });
        }

        const banner = await PromotionalBanner.create(req.body);

        res.status(201).json({
            success: true,
            message: "Promotional banner created successfully",
            data: banner
        });
    } catch (error) {
        console.error("Create banner error:", error);

        // Handle validation errors
        if (error.name === 'ValidationError') {
            const errors = Object.values(error.errors).map(e => e.message);
            return res.status(400).json({
                success: false,
                message: "Validation failed",
                errors: errors
            });
        }

        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   PUT /api/promotions/banners/:id
 * @desc    Update promotional banner
 * @access  Admin only
 */
router.put("/banners/:id", protect, authorize("admin"), async (req, res) => {
    try {
        // Validate dates if provided
        if (req.body.startDate && req.body.endDate) {
            const start = new Date(req.body.startDate);
            const end = new Date(req.body.endDate);

            if (end <= start) {
                return res.status(400).json({
                    success: false,
                    message: "End date must be after start date"
                });
            }
        }

        const banner = await PromotionalBanner.findByIdAndUpdate(
            req.params.id,
            req.body,
            { new: true, runValidators: true }
        );

        if (!banner) {
            return res.status(404).json({
                success: false,
                message: "Banner not found"
            });
        }

        res.json({
            success: true,
            message: "Banner updated successfully",
            data: banner
        });
    } catch (error) {
        console.error("Update banner error:", error);

        // Handle validation errors
        if (error.name === 'ValidationError') {
            const errors = Object.values(error.errors).map(e => e.message);
            return res.status(400).json({
                success: false,
                message: "Validation failed",
                errors: errors
            });
        }

        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

/**
 * @route   DELETE /api/promotions/banners/:id
 * @desc    Delete promotional banner
 * @access  Admin only
 */
router.delete("/banners/:id", protect, authorize("admin"), async (req, res) => {
    try {
        const banner = await PromotionalBanner.findByIdAndDelete(req.params.id);

        if (!banner) {
            return res.status(404).json({
                success: false,
                message: "Banner not found"
            });
        }

        res.json({
            success: true,
            message: "Banner deleted successfully"
        });
    } catch (error) {
        console.error("Delete banner error:", error);
        res.status(500).json({
            success: false,
            message: "Server error",
            error: error.message
        });
    }
});

module.exports = router;
