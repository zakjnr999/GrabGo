const express = require("express");
const prisma = require("../config/prisma");
const { protect, authorize } = require("../middleware/auth");

const router = express.Router();

/**
 * @route   GET /api/promotions/banners/all
 * @desc    Get all promotional banners (including inactive)
 * @access  Admin only
 */
router.get("/banners/all", protect, authorize("admin"), async (req, res) => {
    try {
        const banners = await prisma.promotionalBanner.findMany({
            orderBy: { createdAt: 'desc' }
        });

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

        const banners = await prisma.promotionalBanner.findMany({
            where: {
                isActive: true,
                AND: [
                    { startDate: { lte: now } },
                    { endDate: { gte: now } }
                ]
            },
            orderBy: [
                { priority: 'desc' },
                { createdAt: 'desc' }
            ],
            take: 10
        });

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
        const { title, imageUrl, startDate, endDate, linkType, linkValue, priority, isActive } = req.body;

        if (!title || !imageUrl || !startDate || !endDate) {
            return res.status(400).json({
                success: false,
                message: "Missing required fields"
            });
        }

        const banner = await prisma.promotionalBanner.create({
            data: {
                title,
                imageUrl,
                startDate: new Date(startDate),
                endDate: new Date(endDate),
                linkType,
                linkValue,
                priority: priority ? parseInt(priority) : 0,
                isActive: isActive !== undefined ? (isActive === 'true' || isActive === true) : true
            }
        });

        res.status(201).json({
            success: true,
            message: "Promotional banner created successfully",
            data: banner
        });
    } catch (error) {
        console.error("Create banner error:", error);
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
        const { title, imageUrl, startDate, endDate, linkType, linkValue, priority, isActive } = req.body;

        const data = {};
        if (title !== undefined) data.title = title;
        if (imageUrl !== undefined) data.imageUrl = imageUrl;
        if (startDate !== undefined) data.startDate = new Date(startDate);
        if (endDate !== undefined) data.endDate = new Date(endDate);
        if (linkType !== undefined) data.linkType = linkType;
        if (linkValue !== undefined) data.linkValue = linkValue;
        if (priority !== undefined) data.priority = parseInt(priority);
        if (isActive !== undefined) data.isActive = (isActive === 'true' || isActive === true);

        const banner = await prisma.promotionalBanner.update({
            where: { id: req.params.id },
            data
        });

        res.json({
            success: true,
            message: "Banner updated successfully",
            data: banner
        });
    } catch (error) {
        console.error("Update banner error:", error);
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
        await prisma.promotionalBanner.delete({
            where: { id: req.params.id }
        });

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
