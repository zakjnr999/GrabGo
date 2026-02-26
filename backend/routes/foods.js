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

const { FOOD_INCLUDE_RELATIONS, formatFoodResponse } = require('../utils/food_helpers');

// Get all foods with caching (5 minutes)
router.get("/", cacheMiddleware(cache.CACHE_KEYS.FOOD_CATEGORIES, 300), async (req, res) => {
  try {
    const { restaurant, category, isAvailable, userLat, userLng, maxDistance = 15 } = req.query;

    const userLatitude = userLat ? parseFloat(userLat) : null;
    const userLongitude = userLng ? parseFloat(userLng) : null;
    const maxDistanceKm = parseFloat(maxDistance);

    const where = {};

    if (category) {
      where.categoryId = category;
    }
    if (isAvailable !== undefined) {
      where.isAvailable = isAvailable === "true";
    }

    // If user location provided, filter by nearby restaurants
    if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude)) {
      // Step 1: Get bounding box for quick pre-filter
      const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
      const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

      // Step 2: Fetch restaurants within bounding box
      const nearbyRestaurants = await prisma.restaurant.findMany({
        where: {
          latitude: { gte: bbox.minLat, lte: bbox.maxLat },
          longitude: { gte: bbox.minLng, lte: bbox.maxLng }
        },
        select: { id: true, latitude: true, longitude: true }
      });

      // Step 3: Apply precise Haversine filter
      const filteredRestaurants = filterVendorsByDistance(
        nearbyRestaurants,
        userLatitude,
        userLongitude,
        maxDistanceKm
      );

      const restaurantIds = filteredRestaurants.map(r => r.id);

      if (restaurantIds.length === 0) {
        // No restaurants nearby
        return res.json({
          success: true,
          message: "No foods available in your area",
          data: []
        });
      }

      // Add restaurant filter
      where.restaurantId = { in: restaurantIds };
    } else if (restaurant) {
      // Specific restaurant requested
      where.restaurantId = restaurant;
    }

    const foods = await prisma.food.findMany({
      where,
      include: FOOD_INCLUDE_RELATIONS,
      orderBy: { createdAt: 'desc' }
    });

    res.json({
      success: true,
      message: "Foods retrieved successfully",
      data: formatFoodResponse(foods, req.query.userLat, req.query.userLng),
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

    // Filter by nearby restaurants if user location provided
    if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude)) {
      const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
      const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

      const nearbyRestaurants = await prisma.restaurant.findMany({
        where: {
          latitude: { gte: bbox.minLat, lte: bbox.maxLat },
          longitude: { gte: bbox.minLng, lte: bbox.maxLng }
        },
        select: { id: true, latitude: true, longitude: true }
      });

      const filteredRestaurants = filterVendorsByDistance(
        nearbyRestaurants,
        userLatitude,
        userLongitude,
        maxDistanceKm
      );

      const restaurantIds = filteredRestaurants.map(r => r.id);

      if (restaurantIds.length === 0) {
        return res.json({
          success: true,
          message: "No deals available in your area",
          data: []
        });
      }

      where.restaurantId = { in: restaurantIds };
    }

    const deals = await prisma.food.findMany({
      where,
      include: FOOD_INCLUDE_RELATIONS,
      orderBy: { discountPercentage: 'desc' },
      take: 10
    });

    res.json({
      success: true,
      message: "Deals retrieved successfully",
      data: formatFoodResponse(deals, req.query.userLat, req.query.userLng)
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
 * @access  Public (Optional Auth)
 */
router.get("/recommended", (req, res, next) => {
  // Try to authenticate if token exists, but don't block if it doesn't
  if (req.headers.authorization) {
    return protect(req, res, next);
  }
  next();
}, cacheMiddleware(cache.CACHE_KEYS.FOOD_RECOMMENDED, 180, true), async (req, res) => {
  try {
    const userId = req.user?.id || req.headers['x-user-id'];
    let { limit = 10, page = 1, userLat, userLng, maxDistance = 15 } = req.query;

    limit = parseInt(limit);
    if (isNaN(limit) || limit < 1) limit = 10;
    if (limit > 50) limit = 50;

    page = parseInt(page);
    if (isNaN(page) || page < 1) page = 1;

    const userLatitude = userLat ? parseFloat(userLat) : null;
    const userLongitude = userLng ? parseFloat(userLng) : null;
    const maxDistanceKm = parseFloat(maxDistance);

    // 1. Try ML-based recommendations first
    if (userId) {
      try {
        // Request more items from ML to support pagination (up to 50)
        const mlLimit = 50;
        const mlRecommendations = await mlClient.getFoodRecommendations(userId, mlLimit);

        if (mlRecommendations && mlRecommendations.length > 0) {
          // Apply pagination to ML results
          const startIndex = (page - 1) * limit;
          const endIndex = startIndex + limit;
          const paginatedResults = mlRecommendations.slice(startIndex, endIndex);

          console.log(`🤖 Homepage AI: Providing ${paginatedResults.length} ML-sourced recommendations (page ${page}/${Math.ceil(mlRecommendations.length / limit)}, total: ${mlRecommendations.length})`);

          // Fetch full food details for the paginated ML results
          const foodIds = paginatedResults.map(rec => rec.food_id || rec.id);
          const foods = await prisma.food.findMany({
            where: { id: { in: foodIds }, isAvailable: true },
            include: FOOD_INCLUDE_RELATIONS
          });

          // Filter by nearby restaurants if user location provided
          let filteredFoods = foods;
          if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude)) {
            const { filterVendorsByDistance } = require('../utils/vendor_distance_filter');

            // Extract unique restaurants from foods
            const restaurants = [...new Map(
              foods.map(f => [f.restaurant.id, f.restaurant])
            ).values()];

            const nearbyRestaurants = filterVendorsByDistance(
              restaurants,
              userLatitude,
              userLongitude,
              maxDistanceKm
            );

            const nearbyRestaurantIds = new Set(nearbyRestaurants.map(r => r.id));
            filteredFoods = foods.filter(f => nearbyRestaurantIds.has(f.restaurantId));
          }

          // Sort foods according to ML order and format response
          const sortedFoods = foodIds.map(id => filteredFoods.find(f => f.id === id)).filter(f => !!f);
          const foodsWithStatus = formatFoodResponse(sortedFoods, userLat, userLng);

          return res.json({
            success: true,
            source: 'ml',
            page: page,
            limit: limit,
            total: mlRecommendations.length,
            hasMore: endIndex < mlRecommendations.length,
            data: foodsWithStatus
          });
        }
      } catch (mlError) {
        console.error("🤖 ML Recommendation attempt failed, falling back to heuristics:", mlError.message);
      }
    }

    // 2. Fallback: Heuristic-based logic with pagination
    if (userId) {
      console.log(`⚡ Homepage Fallback: ML service returned no specific results for user ${userId}, using standard logic (page ${page})`);
    } else {
      console.log(`⚡ Homepage Fallback: No User ID found, providing general guest recommendations (page ${page})`);
    }

    const popularCount = Math.ceil(limit * 0.4);
    const ratedCount = Math.ceil(limit * 0.3);
    const dealsCount = Math.ceil(limit * 0.2);
    const randomCount = limit - (popularCount + ratedCount + dealsCount);

    // Calculate skip for pagination
    const skip = (page - 1) * limit;

    // Build where clause for location filtering
    let locationWhere = {};
    if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude)) {
      const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
      const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

      const nearbyRestaurants = await prisma.restaurant.findMany({
        where: {
          latitude: { gte: bbox.minLat, lte: bbox.maxLat },
          longitude: { gte: bbox.minLng, lte: bbox.maxLng }
        },
        select: { id: true, latitude: true, longitude: true }
      });

      const filteredRestaurants = filterVendorsByDistance(
        nearbyRestaurants,
        userLatitude,
        userLongitude,
        maxDistanceKm
      );

      const restaurantIds = filteredRestaurants.map(r => r.id);

      if (restaurantIds.length === 0) {
        return res.json({
          success: true,
          source: 'heuristic',
          page: page,
          limit: limit,
          hasMore: false,
          data: []
        });
      }

      locationWhere.restaurantId = { in: restaurantIds };
    }

    const [popular, topRated, deals, random] = await Promise.all([
      prisma.food.findMany({
        where: { isAvailable: true, ...locationWhere },
        orderBy: { orderCount: 'desc' },
        take: popularCount,
        skip: Math.floor(skip * 0.4),
        include: FOOD_INCLUDE_RELATIONS
      }),
      prisma.food.findMany({
        where: { isAvailable: true, rating: { gte: 4.5 }, ...locationWhere },
        orderBy: { rating: 'desc' },
        take: ratedCount,
        skip: Math.floor(skip * 0.3),
        include: FOOD_INCLUDE_RELATIONS
      }),
      prisma.food.findMany({
        where: { isAvailable: true, discountPercentage: { gt: 0 }, ...locationWhere },
        orderBy: { discountPercentage: 'desc' },
        take: dealsCount,
        skip: Math.floor(skip * 0.2),
        include: FOOD_INCLUDE_RELATIONS
      }),
      prisma.food.findMany({
        where: { isAvailable: true, ...locationWhere },
        take: randomCount,
        skip: Math.floor(skip * 0.1),
        include: FOOD_INCLUDE_RELATIONS
      })
    ]);

    const combined = [...popular, ...topRated, ...deals, ...random];

    // Shuffle and deduplicate
    const uniqueMap = new Map();
    combined.forEach(food => uniqueMap.set(food.id, food));
    const uniqueFoods = Array.from(uniqueMap.values());

    // Shuffle for variety
    for (let i = uniqueFoods.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [uniqueFoods[i], uniqueFoods[j]] = [uniqueFoods[j], uniqueFoods[i]];
    }

    const finalRecommendations = uniqueFoods.slice(0, limit);
    const finalWithStatus = formatFoodResponse(finalRecommendations, userLat, userLng);

    res.json({
      success: true,
      source: 'heuristic',
      page: page,
      limit: limit,
      hasMore: page < 5, // Rough estimate - heuristic can provide ~5 pages
      data: finalWithStatus
    });
  } catch (error) {
    console.error("Get recommended items error:", error);
    console.error("Error stack:", error.stack);
    res.status(500).json({ success: false, message: "Server error", error: error.message });
  }
});


// ==================== POPULAR ITEMS ====================

router.get("/popular", cacheMiddleware(cache.CACHE_KEYS.FOOD_POPULAR, 300), async (req, res) => {
  try {
    let { limit = 10, userLat, userLng, maxDistance = 15 } = req.query;
    limit = parseInt(limit);

    if (isNaN(limit) || limit < 1) limit = 10;
    if (limit > 50) limit = 50;

    const userLatitude = userLat ? parseFloat(userLat) : null;
    const userLongitude = userLng ? parseFloat(userLng) : null;
    const maxDistanceKm = parseFloat(maxDistance);

    let where = { isAvailable: true };

    // Filter by nearby restaurants if user location provided
    if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude)) {
      const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
      const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

      const nearbyRestaurants = await prisma.restaurant.findMany({
        where: {
          latitude: { gte: bbox.minLat, lte: bbox.maxLat },
          longitude: { gte: bbox.minLng, lte: bbox.maxLng }
        },
        select: { id: true, latitude: true, longitude: true }
      });

      const filteredRestaurants = filterVendorsByDistance(
        nearbyRestaurants,
        userLatitude,
        userLongitude,
        maxDistanceKm
      );

      const restaurantIds = filteredRestaurants.map(r => r.id);

      if (restaurantIds.length === 0) {
        return res.json({
          success: true,
          message: "No popular items available in your area",
          data: []
        });
      }

      where.restaurantId = { in: restaurantIds };
    }

    const popularItems = await prisma.food.findMany({
      where,
      include: FOOD_INCLUDE_RELATIONS,
      orderBy: [
        { orderCount: 'desc' },
        { rating: 'desc' }
      ],
      take: limit,
      distinct: ['name']
    });

    res.json({
      success: true,
      message: "Popular items retrieved successfully",
      data: formatFoodResponse(popularItems, userLat, userLng)
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
    let { limit = 10, minRating = 4.5, userLat, userLng, maxDistance = 15 } = req.query;
    limit = parseInt(limit);
    minRating = parseFloat(minRating);

    if (isNaN(limit) || limit < 1) limit = 10;
    if (limit > 50) limit = 50;
    if (isNaN(minRating) || minRating < 0 || minRating > 5) minRating = 4.5;

    const userLatitude = userLat ? parseFloat(userLat) : null;
    const userLongitude = userLng ? parseFloat(userLng) : null;
    const maxDistanceKm = parseFloat(maxDistance);

    let where = {
      isAvailable: true,
      rating: { gte: minRating }
    };

    // Filter by nearby restaurants if user location provided
    if (userLatitude && userLongitude && !isNaN(userLatitude) && !isNaN(userLongitude)) {
      const { getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
      const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

      const nearbyRestaurants = await prisma.restaurant.findMany({
        where: {
          latitude: { gte: bbox.minLat, lte: bbox.maxLat },
          longitude: { gte: bbox.minLng, lte: bbox.maxLng }
        },
        select: { id: true, latitude: true, longitude: true }
      });

      const filteredRestaurants = filterVendorsByDistance(
        nearbyRestaurants,
        userLatitude,
        userLongitude,
        maxDistanceKm
      );

      const restaurantIds = filteredRestaurants.map(r => r.id);

      if (restaurantIds.length === 0) {
        return res.json({
          success: true,
          message: "No top rated items available in your area",
          data: []
        });
      }

      where.restaurantId = { in: restaurantIds };
    }

    const topRatedItems = await prisma.food.findMany({
      where,
      include: FOOD_INCLUDE_RELATIONS,
      orderBy: [
        { rating: 'desc' },
        { totalReviews: 'desc' }
      ],
      take: limit,
      distinct: ['name']
    });

    res.json({
      success: true,
      message: "Top rated items retrieved successfully",
      data: formatFoodResponse(topRatedItems, userLat, userLng)
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

router.get("/order-history", protect, cacheMiddleware(cache.CACHE_KEYS.FOOD_ITEM + ':history', 300, true), async (req, res) => {
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

    console.log(`\n🔍 [DEBUG] Fetching food order history for user: ${userId}`);

    // Get food orders across active lifecycle states so "Order Again"
    // can appear immediately after checkout.
    const orders = await prisma.order.findMany({
      where: {
        customerId: userId,
        orderType: 'food',
        OR: [
          { paymentMethod: 'cash' },
          { paymentStatus: { in: ['paid', 'successful'] } },
        ],
        status: {
          in: [
            'pending',
            'confirmed',
            'preparing',
            'ready',
            'picked_up',
            'on_the_way',
            'delivered',
          ],
        },
      },
      include: {
        items: {
          where: { itemType: 'Food' },
          include: {
            food: {
              include: FOOD_INCLUDE_RELATIONS
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

    console.log(`🍔 [DEBUG] Found ${orders.length} food orders`);
    if (orders.length > 0) {
      const totalItems = orders.reduce((sum, o) => sum + o.items.length, 0);
      console.log(`🍔 [DEBUG] Total food items in orders: ${totalItems}`);
    }

    if (!orders || orders.length === 0) {
      return res.status(200).json({
        success: true,
        count: 0,
        data: []
      });
    }

    // Extract unique food items from orders
    const itemsMap = new Map();

    let skippedCount = 0;
    let processedCount = 0;

    orders.forEach(order => {
      order.items.forEach(item => {
        if (item.itemType === 'Food') {
          if (!item.food) {
            skippedCount++;
            console.log(`⚠️ [DEBUG] Skipping item - foodId: ${item.foodId}, food relation: ${item.food ? 'exists' : 'NULL'}`);
            return;
          }

          processedCount++;
          const itemId = item.food.id;

          if (!itemsMap.has(itemId)) {
            const orderTimestamp = order.deliveredDate || order.orderDate || order.createdAt;
            itemsMap.set(itemId, {
              item: item.food,
              lastOrdered: orderTimestamp,
              timesOrdered: 1,
              totalQuantity: item.quantity
            });
          } else {
            const existing = itemsMap.get(itemId);
            existing.timesOrdered += 1;
            existing.totalQuantity += item.quantity;
            // Update last ordered if this order is more recent
            const orderTimestamp = order.deliveredDate || order.orderDate || order.createdAt;
            if (orderTimestamp > existing.lastOrdered) {
              existing.lastOrdered = orderTimestamp;
            }
          }
        }
      });
    });

    console.log(`📊 [DEBUG] Processed: ${processedCount}, Skipped: ${skippedCount} (null food relations)`);

    // Convert map to array and sort by last ordered date
    const uniqueFoodsList = Array.from(itemsMap.values())
      .sort((a, b) => b.lastOrdered - a.lastOrdered)
      .slice(0, 20); // Limit to 20 most recent items

    // Extract items for formatting
    const rawFoods = uniqueFoodsList.map(entry => entry.item);
    const formattedFoods = formatFoodResponse(rawFoods, req.query.userLat, req.query.userLng);

    // Re-attach metadata
    const orderHistory = formattedFoods.map((item, index) => {
      const entry = uniqueFoodsList[index];
      return {
        ...item,
        lastOrderedAt: entry.lastOrdered,
        timesOrdered: entry.timesOrdered,
        totalQuantity: entry.totalQuantity
      };
    });

    console.log(`✅ [DEBUG] Returning ${orderHistory.length} unique food items from history`);

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
