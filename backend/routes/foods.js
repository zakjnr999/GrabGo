const express = require("express");
const { body, validationResult } = require("express-validator");
const Food = require("../models/Food");
const Category = require("../models/Category");
const Restaurant = require("../models/Restaurant");
const { protect } = require("../middleware/auth");
const {
  uploadSingle,
  getFileUrl,
  uploadToCloudinary,
} = require("../middleware/upload");

const router = express.Router();

router.get("/", async (req, res) => {
  try {
    const { restaurant, category, isAvailable } = req.query;
    let query = {};

    if (restaurant) {
      query.restaurant = restaurant;
    }
    if (category) {
      query.category = category;
    }
    if (isAvailable !== undefined) {
      query.isAvailable = isAvailable === "true";
    }

    const foods = await Food.find(query)
      .populate("category", "name")
      .populate("restaurant", "restaurant_name logo")
      .sort({ createdAt: -1 });

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
router.get("/deals", async (req, res) => {
  try {
    const now = new Date();

    const deals = await Food.find({
      isAvailable: true,
      discountPercentage: { $gt: 0 },
      $or: [
        { discountEndDate: null },
        { discountEndDate: { $gte: now } }
      ]
    })
      .populate("category", "name")
      .populate("restaurant", "restaurant_name logo")
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

// ==================== POPULAR ITEMS ====================

// Get popular food items (sorted by order count)
// IMPORTANT: This must come BEFORE /:foodId route
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

    const popularItems = await Food.find({ isAvailable: true })
      .sort({ orderCount: -1, rating: -1 }) // Sort by order count, then rating
      .limit(limit)
      .populate('category', 'name')
      .populate('restaurant', 'restaurant_name logo rating');

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

// Get top-rated food items (sorted by rating)
// IMPORTANT: This must come BEFORE /:foodId route
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

    const topRatedItems = await Food.find({
      isAvailable: true,
      rating: { $gte: minRating }
    })
      .sort({ rating: -1, totalReviews: -1 }) // Sort by rating, then review count
      .limit(limit)
      .populate('category', 'name')
      .populate('restaurant', 'restaurant_name logo rating');

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

      const categoryDoc = await Category.findById(category);
      if (!categoryDoc) {
        return res.status(404).json({
          success: false,
          message: "Category not found",
        });
      }

      const restaurantDoc = await Restaurant.findById(restaurant);
      if (!restaurantDoc) {
        return res.status(404).json({
          success: false,
          message: "Restaurant not found",
        });
      }

      const food_image =
        req.file?.cloudinaryUrl ||
        (req.file ? getFileUrl(req.file.filename) : null);

      const food = await Food.create({
        name,
        description,
        price: parseFloat(price),
        category,
        restaurant,
        food_image,
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
      });

      await food.populate("category", "name");
      await food.populate("restaurant", "restaurant_name logo");

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

router.get("/:foodId", async (req, res) => {
  try {
    const food = await Food.findById(req.params.foodId)
      .populate("category", "name")
      .populate("restaurant", "restaurant_name logo address phone");

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

router.put(
  "/:foodId",
  protect,
  uploadSingle("food_image"),
  uploadToCloudinary,
  async (req, res) => {
    try {
      const food = await Food.findById(req.params.foodId);
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

      if (name) food.name = name;
      if (description !== undefined) food.description = description;
      if (price) food.price = parseFloat(price);
      if (category) food.category = category;
      if (isAvailable !== undefined)
        food.isAvailable = isAvailable === "true" || isAvailable === true;
      if (ingredients !== undefined)
        food.ingredients = Array.isArray(ingredients)
          ? ingredients
          : [ingredients];
      if (rating !== undefined) food.rating = parseFloat(rating);
      if (totalReviews !== undefined)
        food.totalReviews = parseInt(totalReviews);
      if (req.file) {
        if (food.food_image && food.food_image.includes("cloudinary.com")) {
          try {
            const { deleteFromCloudinary } = require("../config/cloudinary");
            const oldPublicId = food.food_image.split("/").pop().split(".")[0];
            await deleteFromCloudinary(`grabgo/foods/${oldPublicId}`);
          } catch (error) {
            console.error("Error deleting old food image:", error);
          }
        }
        food.food_image =
          req.file.cloudinaryUrl || getFileUrl(req.file.filename);
      }

      await food.save();
      await food.populate("category", "name");
      await food.populate("restaurant", "restaurant_name logo");

      res.json({
        success: true,
        message: "Food updated successfully",
        data: food,
      });
    } catch (error) {
      console.error("Update food error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);

// ==================== ORDER HISTORY ====================

/**
 * @route   GET /api/foods/order-history
 * @desc    Get food order history for current user (for Order Again section)
 * @access  Protected
 */
router.get("/order-history", protect, async (req, res) => {
  try {
    const Order = require('../models/Order');

    // Return empty array if no user authentication
    if (!req.user && !req.headers['x-user-id']) {
      return res.status(200).json({
        success: true,
        count: 0,
        data: []
      });
    }

    const userId = req.user?._id || req.headers['x-user-id'];

    // Get completed food orders for the user
    const orders = await Order.find({
      customer: userId,
      orderType: 'food',
      status: 'delivered'
    })
      .populate({
        path: 'items.food',
        model: Food,
        populate: [
          { path: 'category', model: Category },
          { path: 'restaurant', model: Restaurant }
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

    // Extract unique food items from orders
    const itemsMap = new Map();

    orders.forEach(order => {
      order.items.forEach(item => {
        if (item.itemType === 'food' && item.food) {
          const itemId = item.food._id.toString();

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
        ...item.toObject(),
        lastOrderedAt: lastOrdered, // Renamed for frontend consistency
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

// ==================== POPULAR ITEMS ====================

// Get popular food items (sorted by order count)
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

    const popularItems = await Food.find({ isAvailable: true })
      .sort({ orderCount: -1, rating: -1 }) // Sort by order count, then rating
      .limit(limit)
      .populate('category', 'name')
      .populate('restaurant', 'restaurant_name logo rating');

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

module.exports = router;
