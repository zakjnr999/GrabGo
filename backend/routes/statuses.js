const express = require('express');
const { body, query, validationResult } = require('express-validator');
const rateLimit = require('express-rate-limit');
const { ipKeyGenerator } = require('express-rate-limit');
const Status = require('../models/Status');
const Comment = require('../models/Comment');
const Reaction = require('../models/Reaction');
const Restaurant = require('../models/Restaurant');
const Food = require('../models/Food');
const { protect, authorize } = require('../middleware/auth');
const { uploadSingle, uploadToCloudinary } = require('../middleware/upload');
const cache = require('../utils/cache');

const router = express.Router();

// Default status duration: 24 hours
const DEFAULT_STATUS_DURATION_HOURS = 24;

// Cache TTL for stories (60 seconds)
const STORIES_CACHE_TTL = 60;

// Helper to validate MongoDB ObjectId
const isValidObjectId = (id) => /^[0-9a-fA-F]{24}$/.test(id);

// Helper to invalidate stories cache
const invalidateStoriesCache = async () => {
    await cache.delByPattern('grabgo:stories:*');
};

// ============================================================
// Rate Limiters for engagement endpoints
// ============================================================

// Rate limiter for view endpoint: 60 views per minute per user
const viewRateLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 60, // 60 requests per window
    keyGenerator: (req) => req.user?._id?.toString() || ipKeyGenerator(req),
    message: {
        success: false,
        message: 'Too many view requests. Please slow down.',
        retryAfter: 60
    },
    standardHeaders: true,
    legacyHeaders: false,
    skipFailedRequests: true
});

// Rate limiter for like endpoint: 30 likes per minute per user
const likeRateLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 30, // 30 requests per window
    keyGenerator: (req) => req.user?._id?.toString() || ipKeyGenerator(req),
    message: {
        success: false,
        message: 'Too many like requests. Please slow down.',
        retryAfter: 60
    },
    standardHeaders: true,
    legacyHeaders: false,
    skipFailedRequests: true
});

// Rate limiter for status creation: 10 statuses per hour per restaurant
const createStatusRateLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 10, // 10 statuses per hour
    keyGenerator: (req) => req.body?.restaurant || req.user?._id?.toString() || ipKeyGenerator(req),
    message: {
        success: false,
        message: 'Too many statuses created. Please wait before creating more.',
        retryAfter: 3600
    },
    standardHeaders: true,
    legacyHeaders: false,
    skipFailedRequests: true
});

// Rate limiter for comment posting: 20 comments per hour per user
const commentRateLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 20, // 20 comments per hour
    keyGenerator: (req) => req.user?._id?.toString() || ipKeyGenerator(req),
    message: {
        success: false,
        message: 'Too many comments. Please wait before posting more.',
        retryAfter: 3600
    },
    standardHeaders: true,
    legacyHeaders: false,
    skipFailedRequests: true
});


// ============================================================
// IMPORTANT: Route order matters in Express!
// Static routes (e.g., /stories, /user/viewed, /cleanup) must be
// defined BEFORE dynamic routes (e.g., /:statusId) to avoid conflicts
// ============================================================

/**
 * @route   GET /api/statuses
 * @desc    Get all active statuses (with optional filters)
 * @access  Public
 */
router.get('/', async (req, res) => {
    try {
        const {
            category,
            restaurant,
            recommended,
            limit = 50,
            page = 1
        } = req.query;

        // Validate category if provided
        const validCategories = ['daily_special', 'discount', 'new_item', 'video'];
        if (category && !validCategories.includes(category)) {
            return res.status(400).json({
                success: false,
                message: `Invalid category. Must be one of: ${validCategories.join(', ')}`
            });
        }

        // Validate restaurant ID if provided
        if (restaurant && !isValidObjectId(restaurant)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid restaurant ID format'
            });
        }

        const filter = {
            isActive: true,
            expiresAt: { $gt: new Date() }
        };

        if (category) {
            filter.category = category;
        }

        if (restaurant) {
            filter.restaurant = restaurant;
        }

        if (recommended === 'true') {
            filter.isRecommended = true;
        }

        const skip = (parseInt(page) - 1) * parseInt(limit);
        const limitNum = Math.min(parseInt(limit) || 50, 100); // Max 100 per page

        const statuses = await Status.find(filter)
            .populate('restaurant', 'restaurant_name logo address')
            .populate('linkedFood', 'name price food_image')
            .sort({ createdAt: -1 })
            .skip(skip)
            .limit(limitNum);

        const total = await Status.countDocuments(filter);

        res.json({
            success: true,
            message: 'Statuses retrieved successfully',
            data: statuses,
            pagination: {
                currentPage: parseInt(page),
                totalPages: Math.ceil(total / limitNum),
                totalItems: total,
                itemsPerPage: limitNum
            }
        });
    } catch (error) {
        console.error('Get statuses error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   GET /api/statuses/stories
 * @desc    Get restaurant stories (grouped by restaurant for story ring display)
 * @access  Public
 * @query   limit - Max number of stories (default: 20)
 * @query   sortBy - Sort by 'recent' (default) or 'engagement'
 */
router.get('/stories', async (req, res) => {
    const requestId = req.headers['x-request-id'] || `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    try {
        const { limit = 20, sortBy = 'recent' } = req.query;
        const limitNum = Math.min(parseInt(limit) || 20, 50);

        // Cache key includes sortBy and limit (stories are public, no user context needed)
        // User-specific data (viewed status) is handled client-side
        const cacheKey = cache.makeKey(cache.CACHE_KEYS.STORIES, `${sortBy}_${limitNum}`);
        const cachedStories = await cache.get(cacheKey);

        if (cachedStories) {
            return res.json({
                success: true,
                message: 'Stories retrieved successfully (cached)',
                data: cachedStories,
                cached: true,
                cacheType: cache.isRedisConnected() ? 'redis' : 'memory'
            });
        }

        // Determine sort field
        const sortField = sortBy === 'engagement'
            ? { totalEngagement: -1 }
            : { latestStatusAt: -1 };

        // Get active statuses grouped by restaurant
        const stories = await Status.aggregate([
            {
                $match: {
                    isActive: true,
                    expiresAt: { $gt: new Date() }
                }
            },
            {
                $sort: { createdAt: -1 }
            },
            {
                $group: {
                    _id: '$restaurant',
                    statusCount: { $sum: 1 },
                    latestStatus: { $first: '$$ROOT' },
                    categories: { $addToSet: '$category' },
                    totalViews: { $sum: '$viewCount' },
                    totalLikes: { $sum: '$likeCount' },
                    totalEngagement: { $sum: '$engagementScore' }
                }
            },
            {
                $lookup: {
                    from: 'restaurants',
                    localField: '_id',
                    foreignField: '_id',
                    as: 'restaurantInfo'
                }
            },
            {
                $unwind: '$restaurantInfo'
            },
            {
                $project: {
                    restaurantId: '$_id',
                    restaurantName: '$restaurantInfo.restaurant_name',
                    logo: '$restaurantInfo.logo',
                    statusCount: 1,
                    categories: 1,
                    totalViews: 1,
                    totalLikes: 1,
                    totalEngagement: 1,
                    latestStatusAt: '$latestStatus.createdAt',
                    latestCategory: '$latestStatus.category',
                    latestBlurHash: '$latestStatus.blurHash'
                }
            },
            {
                $sort: sortField
            },
            {
                $limit: limitNum
            }
        ]);

        // Cache the result
        await cache.set(cacheKey, stories, STORIES_CACHE_TTL);

        res.json({
            success: true,
            message: 'Stories retrieved successfully',
            data: stories,
            cached: false,
            cacheType: cache.isRedisConnected() ? 'redis' : 'memory'
        });
    } catch (error) {
        console.error('Get stories error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   GET /api/statuses/stories/:restaurantId
 * @desc    Get all statuses for a specific restaurant (for viewing stories)
 * @access  Public (with optional auth for view tracking)
 */
router.get('/stories/:restaurantId', async (req, res) => {
    // Validate restaurantId is a valid ObjectId
    if (!isValidObjectId(req.params.restaurantId)) {
        return res.status(400).json({
            success: false,
            message: 'Invalid restaurant ID format'
        });
    }
    try {
        const { restaurantId } = req.params;

        const statuses = await Status.find({
            restaurant: restaurantId,
            isActive: true,
            expiresAt: { $gt: new Date() }
        })
            .populate('restaurant', 'restaurant_name logo address')
            .populate('linkedFood', 'name price food_image description')
            .sort({ createdAt: -1 });

        if (statuses.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'No active statuses found for this restaurant'
            });
        }

        res.json({
            success: true,
            message: 'Restaurant statuses retrieved successfully',
            data: statuses
        });
    } catch (error) {
        console.error('Get restaurant stories error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   GET /api/statuses/user/viewed
 * @desc    Get statuses viewed by the current user
 * @access  Private
 */
router.get('/user/viewed', protect, async (req, res) => {
    try {
        const userId = req.user._id;

        const viewedStatuses = await Status.find({
            'viewedBy.user': userId,
            isActive: true,
            expiresAt: { $gt: new Date() }
        })
            .populate('restaurant', 'restaurant_name logo')
            .sort({ 'viewedBy.viewedAt': -1 })
            .limit(50);

        res.json({
            success: true,
            message: 'Viewed statuses retrieved successfully',
            data: viewedStatuses
        });
    } catch (error) {
        console.error('Get viewed statuses error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   GET /api/statuses/:statusId/comments
 * @desc    Get comments for a status (paginated)
 * @access  Public
 */
router.get('/:statusId/comments', async (req, res) => {
    try {
        // Validate statusId
        if (!isValidObjectId(req.params.statusId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid status ID format'
            });
        }

        const { page = 1, limit = 20 } = req.query;
        const pageNum = Math.max(1, parseInt(page));
        const limitNum = Math.min(Math.max(1, parseInt(limit)), 50); // Max 50 per page

        // Verify status exists
        const status = await Status.findById(req.params.statusId);
        if (!status) {
            return res.status(404).json({
                success: false,
                message: 'Status not found'
            });
        }

        const result = await Comment.getCommentsForStatus(req.params.statusId, pageNum, limitNum);

        res.json({
            success: true,
            message: 'Comments retrieved successfully',
            comments: result.comments,
            pagination: result.pagination
        });
    } catch (error) {
        console.error('Get comments error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   POST /api/statuses/:statusId/comments
 * @desc    Add a comment to a status
 * @access  Private
 * @rateLimit 20 comments per hour per user
 */
router.post(
    '/:statusId/comments',
    protect,
    commentRateLimiter,
    [
        body('text')
            .trim()
            .notEmpty()
            .withMessage('Comment text is required')
            .isLength({ min: 1, max: 500 })
            .withMessage('Comment must be between 1 and 500 characters')
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({
                    success: false,
                    message: 'Validation failed',
                    errors: errors.array()
                });
            }

            // Validate statusId
            if (!isValidObjectId(req.params.statusId)) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid status ID format'
                });
            }

            // Verify status exists and is active
            const status = await Status.findById(req.params.statusId);
            if (!status) {
                return res.status(404).json({
                    success: false,
                    message: 'Status not found'
                });
            }

            if (!status.isActive || status.expiresAt < new Date()) {
                return res.status(400).json({
                    success: false,
                    message: 'Cannot comment on expired status'
                });
            }

            const { text } = req.body;

            const comment = await Comment.create({
                status: req.params.statusId,
                user: req.user._id,
                text
            });

            // Populate user details
            await comment.populate('user', 'name email profileImage');

            res.status(201).json({
                success: true,
                message: 'Comment added successfully',
                comment
            });
        } catch (error) {
            console.error('Add comment error:', error);
            res.status(500).json({
                success: false,
                message: 'Server error',
                error: error.message
            });
        }
    }
);

/**
 * @route   DELETE /api/statuses/comments/:commentId
 * @desc    Delete a comment (own comments only)
 * @access  Private
 */
router.delete('/comments/:commentId', protect, async (req, res) => {
    try {
        // Validate commentId
        if (!isValidObjectId(req.params.commentId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid comment ID format'
            });
        }

        const comment = await Comment.findById(req.params.commentId);

        if (!comment) {
            return res.status(404).json({
                success: false,
                message: 'Comment not found'
            });
        }

        // Check ownership (only comment owner or admin can delete)
        if (!comment.isOwnedBy(req.user._id) && req.user.role !== 'admin') {
            return res.status(403).json({
                success: false,
                message: 'You can only delete your own comments'
            });
        }

        await comment.deleteOne();

        res.json({
            success: true,
            message: 'Comment deleted successfully'
        });
    } catch (error) {
        console.error('Delete comment error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   GET /api/statuses/:statusId
 * @desc    Get a single status by ID
 * @access  Public
 */
router.get('/:statusId', async (req, res) => {
    try {
        // Validate statusId is a valid ObjectId
        if (!isValidObjectId(req.params.statusId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid status ID format'
            });
        }

        const status = await Status.findById(req.params.statusId)
            .populate('restaurant', 'restaurant_name logo address phone')
            .populate('linkedFood', 'name price food_image description ingredients');

        if (!status) {
            return res.status(404).json({
                success: false,
                message: 'Status not found'
            });
        }

        res.json({
            success: true,
            message: 'Status retrieved successfully',
            data: status
        });
    } catch (error) {
        console.error('Get status error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   POST /api/statuses
 * @desc    Create a new status (restaurant only)
 * @access  Private (restaurant)
 * @rateLimit 10 statuses per hour per restaurant
 */
router.post(
    '/',
    protect,
    authorize('restaurant', 'admin'),
    createStatusRateLimiter,
    uploadSingle('media'),
    uploadToCloudinary,
    [
        body('category')
            .isIn(['daily_special', 'discount', 'new_item', 'video'])
            .withMessage('Invalid category'),
        body('restaurant')
            .notEmpty()
            .withMessage('Restaurant ID is required'),
        body('title')
            .optional()
            .isLength({ max: 100 })
            .withMessage('Title must be 100 characters or less'),
        body('description')
            .optional()
            .isLength({ max: 500 })
            .withMessage('Description must be 500 characters or less'),
        body('discountPercentage')
            .optional()
            .isFloat({ min: 0, max: 100 })
            .withMessage('Discount must be between 0 and 100'),
        body('durationHours')
            .optional()
            .isInt({ min: 1, max: 168 })
            .withMessage('Duration must be between 1 and 168 hours (7 days)')
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({
                    success: false,
                    message: 'Validation failed',
                    errors: errors.array()
                });
            }

            const {
                restaurant,
                category,
                title,
                description,
                mediaType,
                discountPercentage,
                promoCode,
                linkedFood,
                isRecommended,
                durationHours
            } = req.body;

            // Verify restaurant exists
            const restaurantDoc = await Restaurant.findById(restaurant);
            if (!restaurantDoc) {
                return res.status(404).json({
                    success: false,
                    message: 'Restaurant not found'
                });
            }

            // Verify restaurant ownership (skip for admin)
            if (req.user.role === 'restaurant') {
                // Check if user owns this restaurant (by email or user reference)
                const isOwner = restaurantDoc.email === req.user.email ||
                    restaurantDoc.user?.toString() === req.user._id.toString();
                if (!isOwner) {
                    return res.status(403).json({
                        success: false,
                        message: 'You can only create statuses for your own restaurant'
                    });
                }
            }

            // Verify linked food if provided
            if (linkedFood) {
                const foodDoc = await Food.findById(linkedFood);
                if (!foodDoc) {
                    return res.status(404).json({
                        success: false,
                        message: 'Linked food item not found'
                    });
                }
            }

            // Get media URL from upload
            if (!req.file && !req.body.mediaUrl) {
                return res.status(400).json({
                    success: false,
                    message: 'Media file or URL is required'
                });
            }

            const mediaUrl = req.file?.cloudinaryUrl || req.body.mediaUrl;
            const cloudinaryPublicId = req.file?.cloudinaryPublicId || req.body.cloudinaryPublicId || null;
            const thumbnailUrl = req.body.thumbnailUrl || null;
            const thumbnailCloudinaryId = req.body.thumbnailCloudinaryId || null;
            const blurHash = req.file?.blurHash || req.body.blurHash || null;

            // Calculate expiration time
            const duration = parseInt(durationHours) || DEFAULT_STATUS_DURATION_HOURS;
            const expiresAt = new Date();
            expiresAt.setHours(expiresAt.getHours() + duration);

            const status = await Status.create({
                restaurant,
                category,
                title,
                description,
                mediaType: mediaType || 'image',
                mediaUrl,
                cloudinaryPublicId,
                thumbnailUrl,
                thumbnailCloudinaryId,
                blurHash,
                discountPercentage: discountPercentage ? parseFloat(discountPercentage) : undefined,
                promoCode,
                linkedFood,
                isRecommended: isRecommended === 'true' || isRecommended === true,
                expiresAt
            });

            await status.populate('restaurant', 'restaurant_name logo');
            if (linkedFood) {
                await status.populate('linkedFood', 'name price food_image');
            }

            // Invalidate stories cache
            invalidateStoriesCache();

            res.status(201).json({
                success: true,
                message: 'Status created successfully',
                data: status
            });
        } catch (error) {
            console.error('Create status error:', error);
            res.status(500).json({
                success: false,
                message: 'Server error',
                error: error.message
            });
        }
    }
);

/**
 * @route   POST /api/statuses/views/batch
 * @desc    Record multiple views at once (for story swipe-through)
 * @access  Private
 * @rateLimit 60 requests per minute per user
 * @body    { views: [{ statusId: string, duration: number }] }
 */
router.post('/views/batch', protect, viewRateLimiter, async (req, res) => {
    const requestId = req.headers['x-request-id'] || `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    try {
        const { views } = req.body;

        if (!Array.isArray(views) || views.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Views array is required',
                requestId
            });
        }

        if (views.length > 20) {
            return res.status(400).json({
                success: false,
                message: 'Maximum 20 views per batch request',
                requestId
            });
        }

        // Validate all statusIds
        for (const view of views) {
            if (!view.statusId || !isValidObjectId(view.statusId)) {
                return res.status(400).json({
                    success: false,
                    message: `Invalid status ID: ${view.statusId}`,
                    requestId
                });
            }
        }

        // Use transaction for atomic batch updates
        const mongoose = require('mongoose');
        const session = await mongoose.startSession();
        let results = [];

        try {
            await session.withTransaction(async () => {
                results = await Status.recordBatchViewsWithSession(req.user._id, views, session);
            });
        } finally {
            await session.endSession();
        }

        res.json({
            success: true,
            message: 'Batch views recorded',
            requestId,
            data: {
                processed: results.length,
                results
            }
        });
    } catch (error) {
        console.error(`[${requestId}] Batch view error:`, error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message,
            requestId
        });
    }
});

/**
 * @route   POST /api/statuses/:statusId/view
 * @desc    Record a view on a status with optional duration
 * @access  Private
 * @rateLimit 60 requests per minute per user
 * @body    { duration: number } - Duration in milliseconds (optional)
 */
router.post('/:statusId/view', protect, viewRateLimiter, async (req, res) => {
    try {
        // Validate statusId
        if (!isValidObjectId(req.params.statusId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid status ID format'
            });
        }

        const { duration = 0 } = req.body;

        // Validate duration (max 5 minutes = 300000ms)
        const validDuration = Math.min(Math.max(parseInt(duration) || 0, 0), 300000);

        const status = await Status.findById(req.params.statusId);

        if (!status) {
            return res.status(404).json({
                success: false,
                message: 'Status not found'
            });
        }

        if (!status.isActive || status.expiresAt < new Date()) {
            return res.status(400).json({
                success: false,
                message: 'Status has expired'
            });
        }

        await status.recordView(req.user._id, validDuration);

        res.json({
            success: true,
            message: 'View recorded',
            data: {
                viewCount: status.viewCount,
                avgViewDuration: status.avgViewDuration
            }
        });
    } catch (error) {
        console.error('Record view error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   POST /api/statuses/:statusId/like
 * @desc    Like/unlike a status
 * @access  Private
 * @rateLimit 30 requests per minute per user
 */
router.post('/:statusId/like', protect, likeRateLimiter, async (req, res) => {
    try {
        // Validate statusId
        if (!isValidObjectId(req.params.statusId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid status ID format'
            });
        }

        const status = await Status.findById(req.params.statusId);

        if (!status) {
            return res.status(404).json({
                success: false,
                message: 'Status not found'
            });
        }

        if (!status.isActive || status.expiresAt < new Date()) {
            return res.status(400).json({
                success: false,
                message: 'Status has expired'
            });
        }

        const result = await status.toggleLike(req.user._id);

        res.json({
            success: true,
            message: result.isLiked ? 'Status liked' : 'Status unliked',
            data: result
        });
    } catch (error) {
        console.error('Like status error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   PUT /api/statuses/:statusId
 * @desc    Update a status (restaurant only)
 * @access  Private (restaurant, admin)
 */
router.put(
    '/:statusId',
    protect,
    authorize('restaurant', 'admin'),
    uploadSingle('media'),
    uploadToCloudinary,
    async (req, res) => {
        try {
            // Validate statusId
            if (!isValidObjectId(req.params.statusId)) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid status ID format'
                });
            }

            const status = await Status.findById(req.params.statusId)
                .populate('restaurant', 'email user');

            if (!status) {
                return res.status(404).json({
                    success: false,
                    message: 'Status not found'
                });
            }

            // Verify ownership (skip for admin)
            if (req.user.role === 'restaurant') {
                const isOwner = status.restaurant.email === req.user.email ||
                    status.restaurant.user?.toString() === req.user._id.toString();
                if (!isOwner) {
                    return res.status(403).json({
                        success: false,
                        message: 'You can only update your own statuses'
                    });
                }
            }

            const {
                title,
                description,
                discountPercentage,
                promoCode,
                linkedFood,
                isRecommended,
                isActive
            } = req.body;

            // Update fields
            if (title !== undefined) status.title = title;
            if (description !== undefined) status.description = description;
            if (discountPercentage !== undefined) {
                status.discountPercentage = parseFloat(discountPercentage);
            }
            if (promoCode !== undefined) status.promoCode = promoCode;
            if (linkedFood !== undefined) status.linkedFood = linkedFood || null;
            if (isRecommended !== undefined) {
                status.isRecommended = isRecommended === 'true' || isRecommended === true;
            }
            if (isActive !== undefined) {
                status.isActive = isActive === 'true' || isActive === true;
            }

            // Update media if new file uploaded
            if (req.file?.cloudinaryUrl) {
                status.mediaUrl = req.file.cloudinaryUrl;
                status.cloudinaryPublicId = req.file.cloudinaryPublicId || null;
                if (req.file.blurHash) {
                    status.blurHash = req.file.blurHash;
                }
            }

            await status.save();
            await status.populate('restaurant', 'restaurant_name logo');
            if (status.linkedFood) {
                await status.populate('linkedFood', 'name price food_image');
            }

            // Invalidate stories cache
            invalidateStoriesCache();

            res.json({
                success: true,
                message: 'Status updated successfully',
                data: status
            });
        } catch (error) {
            console.error('Update status error:', error);
            res.status(500).json({
                success: false,
                message: 'Server error',
                error: error.message
            });
        }
    }
);

/**
 * @route   DELETE /api/statuses/:statusId
 * @desc    Delete a status (soft delete by setting isActive to false)
 * @access  Private (restaurant, admin)
 */
router.delete(
    '/:statusId',
    protect,
    authorize('restaurant', 'admin'),
    async (req, res) => {
        try {
            // Validate statusId
            if (!isValidObjectId(req.params.statusId)) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid status ID format'
                });
            }

            const status = await Status.findById(req.params.statusId)
                .populate('restaurant', 'email user');

            if (!status) {
                return res.status(404).json({
                    success: false,
                    message: 'Status not found'
                });
            }

            // Verify ownership (skip for admin)
            if (req.user.role === 'restaurant') {
                const isOwner = status.restaurant.email === req.user.email ||
                    status.restaurant.user?.toString() === req.user._id.toString();
                if (!isOwner) {
                    return res.status(403).json({
                        success: false,
                        message: 'You can only delete your own statuses'
                    });
                }
            }

            // Soft delete
            status.isActive = false;
            await status.save();

            // Invalidate stories cache
            invalidateStoriesCache();

            res.json({
                success: true,
                message: 'Status deleted successfully'
            });
        } catch (error) {
            console.error('Delete status error:', error);
            res.status(500).json({
                success: false,
                message: 'Server error',
                error: error.message
            });
        }
    }
);

/**
 * @route   GET /api/statuses/restaurant/:restaurantId/all
 * @desc    Get all statuses for a restaurant (including inactive, for restaurant dashboard)
 * @access  Private (restaurant, admin)
 */
router.get(
    '/restaurant/:restaurantId/all',
    protect,
    authorize('restaurant', 'admin'),
    async (req, res) => {
        // Validate restaurantId
        if (!isValidObjectId(req.params.restaurantId)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid restaurant ID format'
            });
        }
        try {
            const { restaurantId } = req.params;

            // Verify restaurant ownership (skip for admin)
            if (req.user.role === 'restaurant') {
                const restaurantDoc = await Restaurant.findById(restaurantId);
                if (!restaurantDoc) {
                    return res.status(404).json({
                        success: false,
                        message: 'Restaurant not found'
                    });
                }
                const isOwner = restaurantDoc.email === req.user.email ||
                    restaurantDoc.user?.toString() === req.user._id.toString();
                if (!isOwner) {
                    return res.status(403).json({
                        success: false,
                        message: 'You can only view statuses for your own restaurant'
                    });
                }
            }

            const { includeExpired = 'false' } = req.query;

            const filter = { restaurant: restaurantId };

            if (includeExpired !== 'true') {
                filter.expiresAt = { $gt: new Date() };
            }

            const statuses = await Status.find(filter)
                .populate('linkedFood', 'name price food_image')
                .sort({ createdAt: -1 });

            res.json({
                success: true,
                message: 'Restaurant statuses retrieved successfully',
                data: statuses
            });
        } catch (error) {
            console.error('Get restaurant statuses error:', error);
            res.status(500).json({
                success: false,
                message: 'Server error',
                error: error.message
            });
        }
    }
);

/**
 * @route   POST /api/statuses/cleanup
 * @desc    Clean up expired statuses and their Cloudinary images (admin only)
 * @access  Private (admin)
 */
router.post('/cleanup', protect, authorize('admin'), async (req, res) => {
    try {
        // Import cloudinary for cleanup
        const cloudinary = require('cloudinary').v2;

        const result = await Status.cleanupExpired(cloudinary);

        // Invalidate stories cache after cleanup
        invalidateStoriesCache();

        res.json({
            success: true,
            message: `Cleaned up ${result.statusesDeactivated} expired statuses`,
            data: result
        });
    } catch (error) {
        console.error('Cleanup statuses error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   GET /api/statuses/cache/stats
 * @desc    Get cache statistics (admin only)
 * @access  Private (admin)
 */
router.get('/cache/stats', protect, authorize('admin'), async (req, res) => {
    try {
        const stats = cache.getStats();

        res.json({
            success: true,
            message: 'Cache stats retrieved',
            data: stats
        });
    } catch (error) {
        console.error('Cache stats error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   POST /api/statuses/cache/clear
 * @desc    Clear all status caches (admin only)
 * @access  Private (admin)
 */
router.post('/cache/clear', protect, authorize('admin'), async (req, res) => {
    try {
        await invalidateStoriesCache();

        res.json({
            success: true,
            message: 'Cache cleared successfully'
        });
    } catch (error) {
        console.error('Cache clear error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

// ============================================================
// Comment Routes
// ============================================================

/**
 * @route   GET /api/statuses/:statusId/comments
 * @desc    Get comments for a status (paginated, top-level only)
 * @access  Public
 */
router.get('/:statusId/comments', async (req, res) => {
    try {
        const { page = 1, limit = 20 } = req.query;
        const pageNum = Math.max(1, parseInt(page));
        const limitNum = Math.min(Math.max(1, parseInt(limit)), 50);

        const result = await Comment.getCommentsForStatus(req.params.statusId, pageNum, limitNum);

        res.json({
            success: true,
            message: 'Comments retrieved successfully',
            comments: result.comments,
            pagination: result.pagination
        });
    } catch (error) {
        console.error('Get comments error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   POST /api/statuses/:statusId/comments
 * @desc    Add a comment to a status
 * @access  Private
 */
router.post(
    '/:statusId/comments',
    protect,
    commentRateLimiter,
    [
        body('text')
            .trim()
            .notEmpty()
            .withMessage('Comment text is required')
            .isLength({ min: 1, max: 500 })
            .withMessage('Comment must be between 1 and 500 characters')
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({
                    success: false,
                    message: 'Validation failed',
                    errors: errors.array()
                });
            }

            const status = await Status.findById(req.params.statusId);
            if (!status) {
                return res.status(404).json({
                    success: false,
                    message: 'Status not found'
                });
            }

            if (status.expiresAt < new Date()) {
                return res.status(400).json({
                    success: false,
                    message: 'Cannot comment on expired status'
                });
            }

            const { text } = req.body;

            const comment = await Comment.create({
                status: req.params.statusId,
                user: req.user._id,
                text
            });

            await comment.populate('user', 'name email profileImage');

            res.status(201).json({
                success: true,
                message: 'Comment added successfully',
                comment
            });
        } catch (error) {
            console.error('Add comment error:', error);
            res.status(500).json({
                success: false,
                message: 'Server error',
                error: error.message
            });
        }
    }
);

/**
 * @route   DELETE /api/statuses/comments/:commentId
 * @desc    Delete a comment
 * @access  Private
 */
router.delete('/comments/:commentId', protect, async (req, res) => {
    try {
        const comment = await Comment.findById(req.params.commentId);

        if (!comment) {
            return res.status(404).json({
                success: false,
                message: 'Comment not found'
            });
        }

        if (comment.user._id.toString() !== req.user._id.toString() && req.user.role !== 'admin') {
            return res.status(403).json({
                success: false,
                message: 'Not authorized to delete this comment'
            });
        }

        // Delete all replies if this is a parent comment
        if (!comment.parentComment) {
            await Comment.deleteMany({ parentComment: comment._id });
        }

        await comment.deleteOne();

        res.json({
            success: true,
            message: 'Comment deleted successfully'
        });
    } catch (error) {
        console.error('Delete comment error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

// ============================================================
// Reply Routes
// ============================================================

/**
 * @route   GET /api/statuses/comments/:commentId/replies
 * @desc    Get replies for a comment (paginated)
 * @access  Public
 */
router.get('/comments/:commentId/replies', async (req, res) => {
    try {
        const { page = 1, limit = 10 } = req.query;
        const pageNum = Math.max(1, parseInt(page));
        const limitNum = Math.min(Math.max(1, parseInt(limit)), 20);

        const result = await Comment.getReplies(req.params.commentId, pageNum, limitNum);

        res.json({
            success: true,
            message: 'Replies retrieved successfully',
            replies: result.replies,
            pagination: result.pagination
        });
    } catch (error) {
        console.error('Get replies error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

/**
 * @route   POST /api/statuses/comments/:commentId/replies
 * @desc    Add a reply to a comment
 * @access  Private
 */
router.post(
    '/comments/:commentId/replies',
    protect,
    commentRateLimiter,
    [
        body('text')
            .trim()
            .notEmpty()
            .withMessage('Reply text is required')
            .isLength({ min: 1, max: 500 })
            .withMessage('Reply must be between 1 and 500 characters')
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({
                    success: false,
                    message: 'Validation failed',
                    errors: errors.array()
                });
            }

            const parentComment = await Comment.findById(req.params.commentId);
            if (!parentComment) {
                return res.status(404).json({
                    success: false,
                    message: 'Parent comment not found'
                });
            }

            if (parentComment.parentComment) {
                return res.status(400).json({
                    success: false,
                    message: 'Cannot reply to a reply. Please reply to the parent comment.'
                });
            }

            const { text } = req.body;

            const reply = await Comment.create({
                status: parentComment.status,
                user: req.user._id,
                text,
                parentComment: req.params.commentId
            });

            await reply.populate('user', 'name email profileImage');

            // Send notifications (FCM + in-app) if not replying to own comment
            if (parentComment.user.toString() !== req.user._id.toString()) {
                try {
                    const { sendCommentReplyNotification } = require('../services/fcm_service');
                    const { createNotification } = require('../services/notification_service');

                    // Get status and restaurant info for navigation
                    const status = await Status.findById(parentComment.status).select('restaurant');
                    if (status) {
                        const restaurant = await Restaurant.findById(status.restaurant).select('name');

                        // FCM push notification
                        await sendCommentReplyNotification(
                            parentComment.user,
                            req.user.name,
                            text,
                            parentComment.status,
                            parentComment._id,
                            req.user._id,
                            req.user.profileImage,
                            status.restaurant,
                            restaurant?.name || 'Restaurant'
                        );

                        // In-app notification
                        await createNotification(
                            parentComment.user,
                            'comment_reply',
                            `${req.user.name} replied to your comment`,
                            `💬 ${text.length > 100 ? text.substring(0, 100) + '...' : text}`,
                            {
                                statusId: parentComment.status.toString(),
                                commentId: parentComment._id.toString(),
                                restaurantId: status.restaurant.toString(),
                                restaurantName: restaurant?.name || 'Restaurant',
                                actorId: req.user._id,
                                actorName: req.user.name,
                                actorAvatar: req.user.profileImage
                            }
                        );
                    }
                } catch (notificationError) {
                    console.error('Failed to send reply notification:', notificationError);
                    // Don't fail the reply if notification fails
                }
            }

            res.status(201).json({
                success: true,
                message: 'Reply added successfully',
                reply
            });
        } catch (error) {
            console.error('Add reply error:', error);
            res.status(500).json({
                success: false,
                message: 'Server error',
                error: error.message
            });
        }
    }
);

// ============================================================
// Reaction Routes
// ============================================================

/**
 * @route   POST /api/statuses/comments/:commentId/react
 * @desc    Toggle reaction on a comment
 * @access  Private
 */
router.post(
    '/comments/:commentId/react',
    protect,
    [
        body('type')
            .isIn(['like', 'love', 'haha', 'wow', 'sad', 'angry'])
            .withMessage('Invalid reaction type')
    ],
    async (req, res) => {
        try {
            const errors = validationResult(req);
            if (!errors.isEmpty()) {
                return res.status(400).json({
                    success: false,
                    message: 'Validation failed',
                    errors: errors.array()
                });
            }

            const comment = await Comment.findById(req.params.commentId);
            if (!comment) {
                return res.status(404).json({
                    success: false,
                    message: 'Comment not found'
                });
            }

            const { type } = req.body;
            const result = await Reaction.toggle(req.params.commentId, req.user._id, type);
            const summary = await Reaction.getSummary(req.params.commentId, req.user._id);

            // Send notification only when adding reaction (not removing) and not reacting to own comment
            if (result.action === 'added' && comment.user.toString() !== req.user._id.toString()) {
                try {
                    const { sendCommentReactionNotification } = require('../services/fcm_service');
                    const { createNotification } = require('../services/notification_service');

                    const reactionEmojis = { like: '👍', love: '❤️', haha: '😂', wow: '😮', sad: '😢', angry: '😠' };

                    // Get status and restaurant info for navigation
                    const status = await Status.findById(comment.status).select('restaurant');
                    if (status) {
                        const restaurant = await Restaurant.findById(status.restaurant).select('name');

                        // FCM push notification
                        await sendCommentReactionNotification(
                            comment.user,
                            req.user.name,
                            type,
                            comment.text,
                            comment.status,
                            comment._id,
                            req.user._id,
                            req.user.profileImage,
                            status.restaurant,
                            restaurant?.name || 'Restaurant'
                        );

                        // In-app notification
                        await createNotification(
                            comment.user,
                            'comment_reaction',
                            `${req.user.name} reacted to your comment`,
                            `${reactionEmojis[type]} "${comment.text.length > 50 ? comment.text.substring(0, 50) + '...' : comment.text}"`,
                            {
                                statusId: comment.status.toString(),
                                commentId: comment._id.toString(),
                                restaurantId: status.restaurant.toString(),
                                restaurantName: restaurant?.name || 'Restaurant',
                                actorId: req.user._id,
                                actorName: req.user.name,
                                actorAvatar: req.user.profileImage,
                                reactionType: type
                            }
                        );
                    }
                } catch (notificationError) {
                    console.error('Failed to send reaction notification:', notificationError);
                    // Don't fail the reaction if notification fails
                }
            }

            res.json({
                success: true,
                message: `Reaction ${result.action}`,
                data: {
                    action: result.action,
                    type: result.type,
                    reactions: summary
                }
            });
        } catch (error) {
            console.error('Toggle reaction error:', error);
            res.status(500).json({
                success: false,
                message: 'Server error',
                error: error.message
            });
        }
    }
);

/**
 * @route   GET /api/statuses/comments/:commentId/reactions
 * @desc    Get reaction summary for a comment
 * @access  Public
 */
router.get('/comments/:commentId/reactions', async (req, res) => {
    try {
        const userId = req.user?._id;
        const summary = await Reaction.getSummary(req.params.commentId, userId);

        res.json({
            success: true,
            message: 'Reactions retrieved successfully',
            reactions: summary
        });
    } catch (error) {
        console.error('Get reactions error:', error);
        res.status(500).json({
            success: false,
            message: 'Server error',
            error: error.message
        });
    }
});

// Export cache invalidation function for use in cron jobs
router.invalidateStoriesCache = invalidateStoriesCache;

module.exports = router;
