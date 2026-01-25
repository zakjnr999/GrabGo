const express = require('express');
const { body, query, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');
const { ipKeyGenerator } = require('express-rate-limit');
const prisma = require('../config/prisma');
const StatusService = require('../services/status_service');
const { protect, authorize } = require('../middleware/auth');
const { uploadSingle, uploadToCloudinary } = require('../middleware/upload');
const cache = require('../utils/cache');
const { getIO } = require('../utils/socket');
const Status = require('../models/Status');
const Comment = require('../models/Comment');
const Reaction = require('../models/Reaction');

const router = express.Router();

// Default status duration: 24 hours
const DEFAULT_STATUS_DURATION_HOURS = 24;

// Cache TTL for stories (60 seconds)
const STORIES_CACHE_TTL = 60;

// Helper to invalidate stories cache
const invalidateStoriesCache = async () => {
    await cache.delByPattern('grabgo:stories:*');
};

// ============================================================
// Rate Limiters (Omitted for brevity - same as before)
// ============================================================
const viewRateLimiter = rateLimit({ windowMs: 60 * 1000, max: 60, keyGenerator: (req) => req.user?.id || ipKeyGenerator(req) });
const likeRateLimiter = rateLimit({ windowMs: 60 * 1000, max: 30, keyGenerator: (req) => req.user?.id || ipKeyGenerator(req) });
const createStatusRateLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 10, keyGenerator: (req) => req.body?.restaurantId || req.user?.id || ipKeyGenerator(req) });
const commentRateLimiter = rateLimit({ windowMs: 60 * 60 * 1000, max: 20, keyGenerator: (req) => req.user?.id || ipKeyGenerator(req) });

// ============================================================
// Status Routes
// ============================================================

/**
 * @route   GET /api/statuses
 * @desc    Get all active statuses (Hybrid lookup)
 */
router.get('/', async (req, res) => {
    try {
        const { category, restaurantId, recommended, limit = 50, page = 1 } = req.query;

        const query = {
            isActive: true,
            expiresAt: { $gt: new Date() }
        };

        if (category) query.category = category;
        if (restaurantId) query.restaurantId = restaurantId;
        if (recommended === 'true') query.isRecommended = true;

        const skip = (parseInt(page) - 1) * parseInt(limit);
        const take = Math.min(parseInt(limit) || 50, 100);

        const [statuses, total] = await Promise.all([
            Status.find(query).sort({ createdAt: -1 }).skip(skip).limit(take).lean(),
            Status.countDocuments(query)
        ]);

        // Manual Hydration: Get Restaurant and Food info from PostgreSQL
        const restaurantIds = [...new Set(statuses.map(s => s.restaurantId))];
        const foodIds = [...new Set(statuses.filter(s => s.linkedFoodId).map(s => s.linkedFoodId))];

        const [restaurants, foods] = await Promise.all([
            prisma.restaurant.findMany({
                where: { id: { in: restaurantIds } },
                select: { id: true, restaurantName: true, logo: true, address: true }
            }),
            prisma.food.findMany({
                where: { id: { in: foodIds } },
                select: { id: true, name: true, price: true, foodImage: true }
            })
        ]);

        const restaurantMap = restaurants.reduce((acc, r) => ({ ...acc, [r.id]: r }), {});
        const foodMap = foods.reduce((acc, f) => ({ ...acc, [f.id]: f }), {});

        const hydratedStatuses = statuses.map(s => ({
            ...s,
            id: s._id,
            restaurant: restaurantMap[s.restaurantId],
            linkedFood: s.linkedFoodId ? foodMap[s.linkedFoodId] : null
        }));

        res.json({
            success: true,
            data: hydratedStatuses,
            pagination: { currentPage: parseInt(page), totalPages: Math.ceil(total / take), totalItems: total }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * @route   GET /api/statuses/stories
 */
router.get('/stories', async (req, res) => {
    try {
        const { limit = 20, sortBy = 'recent' } = req.query;
        const limitNum = Math.min(parseInt(limit) || 20, 50);

        const cacheKey = cache.makeKey(cache.CACHE_KEYS.STORIES, `${sortBy}_${limitNum}`);
        const cachedStories = await cache.get(cacheKey);

        if (cachedStories) {
            return res.json({ success: true, data: cachedStories, cached: true });
        }

        const activeStatuses = await Status.find({ isActive: true, expiresAt: { $gt: new Date() } }).sort({ createdAt: -1 }).lean();

        // Manual story grouping
        const grouped = activeStatuses.reduce((acc, status) => {
            const rid = status.restaurantId;
            if (!acc[rid]) {
                acc[rid] = {
                    restaurantId: rid,
                    statusCount: 0,
                    categories: new Set(),
                    totalViews: 0,
                    totalLikes: 0,
                    totalEngagement: 0,
                    latestStatusAt: status.createdAt,
                    latestBlurHash: status.blurHash
                };
            }
            acc[rid].statusCount++;
            acc[rid].categories.add(status.category);
            acc[rid].totalViews += status.viewCount;
            acc[rid].totalLikes += status.likeCount;
            acc[rid].totalEngagement += status.engagementScore;
            return acc;
        }, {});

        // Hydrate restaurant names from Postgres
        const rids = Object.keys(grouped);
        const restaurants = await prisma.restaurant.findMany({
            where: { id: { in: rids } },
            select: { id: true, restaurantName: true, logo: true }
        });

        const stories = restaurants.map(r => ({
            ...grouped[r.id],
            restaurantName: r.restaurantName,
            logo: r.logo,
            categories: Array.from(grouped[r.id].categories)
        }));

        if (sortBy === 'engagement') stories.sort((a, b) => b.totalEngagement - a.totalEngagement);
        else stories.sort((a, b) => new Date(b.latestStatusAt) - new Date(a.latestStatusAt));

        const finalStories = stories.slice(0, limitNum);
        await cache.set(cacheKey, finalStories, STORIES_CACHE_TTL);

        res.json({ success: true, data: finalStories });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * @route   POST /api/statuses
 */
router.post('/', protect, authorize('restaurant', 'admin'), createStatusRateLimiter, uploadSingle('media'), uploadToCloudinary, async (req, res) => {
    try {
        const { restaurantId, category, title, description, mediaType, discountPercentage, promoCode, linkedFoodId, isRecommended, durationHours } = req.body;

        const mediaUrl = req.file?.cloudinaryUrl || req.body.mediaUrl;
        if (!mediaUrl) return res.status(400).json({ success: false, message: 'Media is required' });

        const duration = parseInt(durationHours) || DEFAULT_STATUS_DURATION_HOURS;
        const expiresAt = new Date();
        expiresAt.setHours(expiresAt.getHours() + duration);

        const status = new Status({
            restaurantId,
            category,
            title,
            description,
            mediaType: mediaType || 'image',
            mediaUrl,
            cloudinaryPublicId: req.file?.cloudinaryPublicId || req.body.cloudinaryPublicId,
            thumbnailUrl: req.body.thumbnailUrl,
            thumbnailCloudinaryId: req.body.thumbnailCloudinaryId,
            blurHash: req.file?.blurHash || req.body.blurHash,
            discountPercentage: discountPercentage ? parseInt(discountPercentage) : null,
            promoCode,
            linkedFoodId,
            isRecommended: isRecommended === 'true' || isRecommended === true,
            expiresAt
        });

        await status.save();
        invalidateStoriesCache();
        res.status(201).json({ success: true, data: status });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * @route   POST /api/statuses/:statusId/view
 */
router.post('/:statusId/view', protect, viewRateLimiter, async (req, res) => {
    try {
        const { duration = 0 } = req.body;
        const status = await StatusService.recordView(req.params.statusId, req.user.id, parseInt(duration));
        res.json({ success: true, data: { viewCount: status.viewCount, avgViewDuration: status.avgViewDuration } });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * @route   POST /api/statuses/:statusId/like
 */
router.post('/:statusId/like', protect, likeRateLimiter, async (req, res) => {
    try {
        const result = await StatusService.toggleLike(req.params.statusId, req.user.id);
        res.json({ success: true, data: result });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * @route   POST /api/statuses/:statusId/comments
 */
router.post('/:statusId/comments', protect, commentRateLimiter, async (req, res) => {
    try {
        const { text } = req.body;
        const comment = new Comment({
            statusId: req.params.statusId,
            user: req.user.id,
            text
        });

        await comment.save();

        res.status(201).json({
            success: true,
            comment: {
                ...comment.toObject(),
                user: { id: req.user.id, username: req.user.username, profileImage: req.user.profilePicture }
            }
        });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * @route   DELETE /api/statuses/comments/:commentId
 */
router.delete('/comments/:commentId', protect, async (req, res) => {
    try {
        const comment = await Comment.findById(req.params.commentId);
        if (!comment) return res.status(404).json({ success: false, message: 'Comment not found' });

        if (comment.user !== req.user.id && req.user.role !== 'admin') {
            return res.status(403).json({ success: false, message: 'Unauthorized' });
        }

        await comment.deleteOne();
        res.json({ success: true, message: 'Comment deleted' });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * @route   POST /api/statuses/comments/:commentId/react
 */
router.post('/comments/:commentId/react', protect, async (req, res) => {
    try {
        const { type } = req.body;
        const result = await StatusService.toggleReaction(req.params.commentId, req.user.id, type);
        const summary = await StatusService.getReactionSummary(req.params.commentId, req.user.id);
        res.json({ success: true, action: result.action, summary });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

module.exports = router;
