const express = require("express");
const { body, validationResult } = require("express-validator");
const prisma = require("../config/prisma");
const { protect } = require("../middleware/auth");
const {
  uploadSingle,
  getFileUrl,
  uploadToCloudinary,
} = require("../middleware/upload");
const { cacheMiddleware, invalidateCache } = require("../middleware/cache");
const cache = require("../utils/cache");
const mlClient = require("../utils/ml_client");

const router = express.Router();

// Get all foods with caching (5 minutes)
router.get("/", cacheMiddleware(cache.CACHE_KEYS.FOOD_CATEGORIES, 300), async (req, res) => {
  try {
    const { restaurant, category, isAvailable } = req.query;
    const where = {};

    if (restaurant) {
      where.restaurantId = restaurant;
    }
    if (category) {
      where.categoryId = category;
    }
    if (isAvailable !== undefined) {
      where.isAvailable = isAvailable === "true";
    }

    const foods = await prisma.food.findMany({
      where,
      include: {
        category: {
          select: { id: true, name: true }
        },
        restaurant: {
          select: { id: true, restaurantName: true, logo: true, address: true, city: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json({
      success: true,
      message: "Foods retrieved successfully",
      data: foods,
    });
  } catch (error) {
    console.error("Get foods error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

/**
 * @route   GET /api/foods/deals
 * @desc    Get foods with active discounts
 * @access  Public
 */
router.get("/deals", cacheMiddleware(cache.CACHE_KEYS.FOOD_DEALS, 120), async (req, res) => {
  try {
    const now = new Date();

    const deals = await prisma.food.findMany({
      where: {
        isAvailable: true,
        discountPercentage: { gt: 0 },
        OR: [
          { discountEndDate: null },
          { discountEndDate: { gte: now } }
        ]
      },
      include: {
        category: {
          select: { id: true, name: true }
        },
        restaurant: {
          select: { id: true, restaurantName: true, logo: true, address: true, city: true }
        }
      },
      orderBy: { discountPercentage: 'desc' },
      take: 10
    });

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

/**
 * @route   GET /api/foods/recommended
 * @desc    Get AI-powered personalized food recommendations (with Heuristic Fallback)
 * @access  Public
 */
router.get("/recommended", cacheMiddleware(cache.CACHE_KEYS.FOOD_RECOMMENDED, 180), async (req, res) => {
  try {
    const userId = req.user?.id || req.headers['x-user-id'];
    let { limit = 10 } = req.query;
    limit = parseInt(limit);
    if (isNaN(limit) || limit < 1) limit = 10;
    if (limit > 50) limit = 50;

    const includeRelations = {
      category: { select: { id: true, name: true } },
      restaurant: { select: { id: true, restaurantName: true, logo: true, rating: true, address: true, city: true } }
    };

    // 1. Try ML Service First (Personalized Intelligence)
    try {
      const mlRecs = await mlClient.getFoodRecommendations(userId, limit);

      if (mlRecs && mlRecs.length > 0) {
        const foodIds = mlRecs.map(rec => rec.food_id || rec.id);
        const foods = await prisma.food.findMany({
          where: { id: { in: foodIds }, isAvailable: true },
          include: includeRelations
        });

        if (foods.length > 0) {
          const sortedFoods = foodIds.map(id => foods.find(f => f.id === id)).filter(f => !!f);
          console.log(`🤖 Homepage AI: Providing ${sortedFoods.length} ML-sourced recommendations`);
          return res.json({
            success: true,
            message: "AI Recommendations retrieved successfully",
            data: sortedFoods,
            using_ml: true
          });
        }
      }
    } catch (mlError) {
      console.error("🤖 ML Recommendation attempt failed, falling back to heuristics:", mlError.message);
    }

    // 2. Fallback: Heuristic-based logic (mix popular, rated, deals, random)
    console.log("⚡ Homepage Fallback: Using standard recommendation logic");

    const popularCount = Math.ceil(limit * 0.4);
    const ratedCount = Math.ceil(limit * 0.3);
    const dealsCount = Math.ceil(limit * 0.2);
    const randomCount = limit - popularCount - ratedCount - dealsCount;

    // Get popular items
    const popular = await prisma.food.findMany({
      where: { isAvailable: true },
      include: includeRelations,
      orderBy: { orderCount: 'desc' },
      take: popularCount
    });

    const popularIds = popular.map(f => f.id);

    // Get highly rated items
    const rated = await prisma.food.findMany({
      where: { isAvailable: true, rating: { gte: 4.5 }, id: { notIn: popularIds } },
      include: includeRelations,
      orderBy: [{ rating: 'desc' }, { totalReviews: 'desc' }],
      take: ratedCount
    });

    const selectedIds = [...popularIds, ...rated.map(f => f.id)];
    const now = new Date();

    // Get deals
    const deals = await prisma.food.findMany({
      where: {
        isAvailable: true,
        discountPercentage: { gt: 0 },
        id: { notIn: selectedIds },
        OR: [{ discountEndDate: null }, { discountEndDate: { gte: now } }]
      },
      include: includeRelations,
      orderBy: { discountPercentage: 'desc' },
      take: dealsCount
    });

    const allSelectedIds = [...selectedIds, ...deals.map(f => f.id)];

    // Get random items
    const totalCount = await prisma.food.count({
      where: { isAvailable: true, id: { notIn: allSelectedIds } }
    });

    let random = [];
    if (totalCount > 0 && randomCount > 0) {
      const skip = Math.max(0, Math.floor(Math.random() * (totalCount - randomCount)));
      random = await prisma.food.findMany({
        where: { isAvailable: true, id: { notIn: allSelectedIds } },
        include: includeRelations,
        skip,
        take: randomCount
      });
    }

    // Combine and shuffle
    const recommended = [...popular, ...rated, ...deals, ...random];
    for (let i = recommended.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [recommended[i], recommended[j]] = [recommended[j], recommended[i]];
    }

    res.json({
      success: true,
      message: "Recommended items retrieved successfully (Fallback)",
      data: recommended.slice(0, limit),
      using_ml: false
    });
  } catch (error) {
    console.error("Get recommended items error:", error);
    res.status(500).json({ success: false, message: "Server error", error: error.message });
  }
});

// ==================== POPULAR ITEMS ====================

router.get("/popular", cacheMiddleware(cache.CACHE_KEYS.FOOD_POPULAR, 300), async (req, res) => {
  try {
    let { limit = 10 } = req.query;
    limit = parseInt(limit);

    if (isNaN(limit) || limit < 1) limit = 10;
    if (limit > 50) limit = 50;

    const popularItems = await prisma.food.findMany({
      where: { isAvailable: true },
      include: {
        category: {
          select: { id: true, name: true }
        },
        restaurant: {
          select: { id: true, restaurantName: true, logo: true, address: true, city: true }
        }
      },
      orderBy: [
        { orderCount: 'desc' },
        { rating: 'desc' }
      ],
      take: limit,
      distinct: ['name']
    });

    // Add aliases for frontend compatibility
    const formattedItems = popularItems.map(item => ({
      ...item,
      food_image: item.foodImage,
      image: item.foodImage,
      restaurant: {
        ...item.restaurant,
        restaurant_name: item.restaurant.restaurantName,
        image: item.restaurant.logo
      }
    }));

    res.json({
      success: true,
      message: "Popular items retrieved successfully",
      data: formattedItems
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

router.get("/top-rated", cacheMiddleware(cache.CACHE_KEYS.FOOD_TOP_RATED, 600), async (req, res) => {
  try {
    let { limit = 10, minRating = 4.5 } = req.query;
    limit = parseInt(limit);
    minRating = parseFloat(minRating);

    if (isNaN(limit) || limit < 1) limit = 10;
    if (limit > 50) limit = 50;
    if (isNaN(minRating) || minRating < 0 || minRating > 5) minRating = 4.5;

    const topRatedItems = await prisma.food.findMany({
      where: {
        isAvailable: true,
        rating: { gte: minRating }
      },
      include: {
        category: {
          select: { id: true, name: true }
        },
        restaurant: {
          select: { id: true, restaurantName: true, logo: true, address: true, city: true }
        }
      },
      orderBy: [
        { rating: 'desc' },
        { totalReviews: 'desc' }
      ],
      take: limit,
      distinct: ['name']
    });

    // Add aliases for frontend compatibility
    const formattedItems = topRatedItems.map(item => ({
      ...item,
      food_image: item.foodImage,
      image: item.foodImage,
      restaurant: {
        ...item.restaurant,
        restaurant_name: item.restaurant.restaurantName,
        image: item.restaurant.logo
      }
    }));

    res.json({
      success: true,
      message: "Top rated items retrieved successfully",
      data: formattedItems
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

// ==================== ORDER HISTORY ====================

router.get("/order-history", protect, async (req, res) => {
  try {
    // Return empty array if no user authentication
    if (!req.user && !req.headers['x-user-id']) {
      return res.status(200).json({
        success: true,
        count: 0,
        data: []
      });
    }

    const userId = req.user?.id || req.headers['x-user-id'];

    // Get completed food orders for the user
    const orders = await prisma.order.findMany({
      where: {
        customerId: userId,
        orderType: 'food',
        status: 'delivered'
      },
      include: {
        items: {
          where: { itemType: 'Food' },
          include: {
            food: {
              include: {
                category: true,
                restaurant: true
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

    // Extract unique food items from orders
    const itemsMap = new Map();

    orders.forEach(order => {
      order.items.forEach(item => {
        if (item.itemType === 'Food' && item.food) {
          const itemId = item.food.id;

          if (!itemsMap.has(itemId)) {
            itemsMap.set(itemId, {
              item: item.food,
              lastOrdered: order.deliveredDate || order.orderDate,
              timesOrdered: 1,
              totalQuantity: item.quantity
            });
          } else {
            const existing = itemsMap.get(itemId);
            existing.timesOrdered += 1;
            existing.totalQuantity += item.quantity;
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
    const orderHistory = Array.from(itemsMap.values())
      .sort((a, b) => b.lastOrdered - a.lastOrdered)
      .slice(0, 20) // Limit to 20 most recent items
      .map(({ item, lastOrdered, timesOrdered, totalQuantity }) => ({
        ...item,
        lastOrderedAt: lastOrdered,
        timesOrdered,
        totalQuantity
      }));

    res.status(200).json({
      success: true,
      count: orderHistory.length,
      data: orderHistory
    });

  } catch (error) {
    console.error('Get food order history error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// Create new food
router.post(
  "/",
  protect,
  [
    body("name").notEmpty().withMessage("Food name is required"),
    body("price")
      .isFloat({ min: 0 })
      .withMessage("Price must be a positive number"),
    body("category").notEmpty().withMessage("Category is required"),
    body("restaurant").notEmpty().withMessage("Restaurant is required"),
  ],
  uploadSingle("food_image"),
  uploadToCloudinary,
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: "Validation failed",
          errors: errors.array(),
        });
      }

      const {
        name,
        description,
        price,
        category,
        restaurant,
        rating,
        totalReviews,
        isAvailable,
        ingredients,
      } = req.body;

      // Verify category exists
      const categoryDoc = await prisma.category.findUnique({
        where: { id: category }
      });
      if (!categoryDoc) {
        return res.status(404).json({
          success: false,
          message: "Category not found",
        });
      }

      // Verify restaurant exists
      const restaurantDoc = await prisma.restaurant.findUnique({
        where: { id: restaurant }
      });
      if (!restaurantDoc) {
        return res.status(404).json({
          success: false,
          message: "Restaurant not found",
        });
      }

      const foodImage =
        req.file?.cloudinaryUrl ||
        (req.file ? getFileUrl(req.file.filename) : null);

      const food = await prisma.food.create({
        data: {
          name,
          description: description || null,
          price: parseFloat(price),
          categoryId: category,
          restaurantId: restaurant,
          foodImage,
          isAvailable:
            isAvailable !== undefined
              ? isAvailable === "true" || isAvailable === true
              : true,
          ingredients: ingredients
            ? Array.isArray(ingredients)
              ? ingredients
              : [ingredients]
            : [],
          rating: rating ? parseFloat(rating) : 0,
          totalReviews: totalReviews ? parseInt(totalReviews) : 0,
        },
        include: {
          category: {
            select: { id: true, name: true }
          },
          restaurant: {
            select: { id: true, restaurantName: true, logo: true }
          }
        }
      });

      // Invalidate related caches
      await invalidateCache([
        cache.CACHE_KEYS.FOOD_CATEGORIES,
        cache.CACHE_KEYS.FOOD_POPULAR,
        cache.CACHE_KEYS.FOOD_DEALS,
      ]);

      res.status(201).json({
        success: true,
        message: "Food created successfully",
        data: food,
      });
    } catch (error) {
      console.error("Create food error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

// Get single food item with caching (10 minutes)
router.get("/:foodId", cacheMiddleware(cache.CACHE_KEYS.FOOD_ITEM, 600), async (req, res) => {
  try {
    const food = await prisma.food.findUnique({
      where: { id: req.params.foodId },
      include: {
        category: {
          select: { id: true, name: true }
        },
        restaurant: {
          select: { id: true, restaurantName: true, logo: true, address: true, city: true, phone: true }
        }
      }
    });

    if (!food) {
      return res.status(404).json({
        success: false,
        message: "Food not found",
      });
    }

    res.json({
      success: true,
      message: "Food retrieved successfully",
      data: food,
    });
  } catch (error) {
    console.error("Get food error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// Update food
router.put(
  "/:foodId",
  protect,
  uploadSingle("food_image"),
  uploadToCloudinary,
  async (req, res) => {
    try {
      const food = await prisma.food.findUnique({
        where: { id: req.params.foodId }
      });

      if (!food) {
        return res.status(404).json({
          success: false,
          message: "Food not found",
        });
      }

      const {
        name,
        description,
        price,
        category,
        isAvailable,
        rating,
        totalReviews,
        ingredients,
      } = req.body;

      const updateData = {};

      if (name) updateData.name = name;
      if (description !== undefined) updateData.description = description;
      if (price) updateData.price = parseFloat(price);
      if (category) updateData.categoryId = category;
      if (isAvailable !== undefined)
        updateData.isAvailable = isAvailable === "true" || isAvailable === true;
      if (ingredients !== undefined)
        updateData.ingredients = Array.isArray(ingredients)
          ? ingredients
          : [ingredients];
      if (rating !== undefined) updateData.rating = parseFloat(rating);
      if (totalReviews !== undefined)
        updateData.totalReviews = parseInt(totalReviews);

      if (req.file) {
        if (food.foodImage && food.foodImage.includes("cloudinary.com")) {
          try {
            const { deleteFromCloudinary } = require("../config/cloudinary");
            const oldPublicId = food.foodImage.split("/").pop().split(".")[0];
            await deleteFromCloudinary(`grabgo/foods/${oldPublicId}`);
          } catch (error) {
            console.error("Error deleting old food image:", error);
          }
        }
        updateData.foodImage =
          req.file.cloudinaryUrl || getFileUrl(req.file.filename);
      }

      const updatedFood = await prisma.food.update({
        where: { id: req.params.foodId },
        data: updateData,
        include: {
          category: {
            select: { id: true, name: true }
          },
          restaurant: {
            select: { id: true, restaurantName: true, logo: true, address: true, city: true }
          }
        }
      });

      // Invalidate all food caches
      await invalidateCache([
        cache.CACHE_KEYS.FOOD_CATEGORIES,
        cache.CACHE_KEYS.FOOD_ITEM,
        cache.CACHE_KEYS.FOOD_POPULAR,
        cache.CACHE_KEYS.FOOD_TOP_RATED,
        cache.CACHE_KEYS.FOOD_DEALS,
      ]);

      res.json({
        success: true,
        message: "Food updated successfully",
        data: updatedFood,
      });
    } catch (error) {
      console.error("Update food error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  });


module.exports = router;
