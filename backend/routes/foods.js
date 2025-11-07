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

module.exports = router;
