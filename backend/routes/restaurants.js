const express = require("express");
const { body, validationResult } = require("express-validator");
const Restaurant = require("../models/Restaurant");
const { protect, verifyApiKey, admin } = require("../middleware/auth");
const {
  uploadFields,
  getFileUrl,
  uploadMultipleToCloudinary,
} = require("../middleware/upload");

const router = express.Router();

router.get("/", async (req, res, next) => {
  try {
    let isAdmin = false;
    if (
      req.headers.authorization &&
      req.headers.authorization.startsWith("Bearer")
    ) {
      try {
        const jwt = require("jsonwebtoken");
        const User = require("../models/User");
        const token = req.headers.authorization.split(" ")[1];
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await User.findById(decoded.id).select("-password");
        if (user && user.isAdmin) {
          isAdmin = true;
        }
      } catch (err) { }
    }

    const query = isAdmin ? {} : { status: "approved" };

    const restaurants = await Restaurant.find(query)
      .select("-password")
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      message: "Restaurants retrieved successfully",
      data: restaurants,
    });
  } catch (error) {
    console.error("Get restaurants error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

router.post(
  "/register",
  uploadFields([
    { name: "logo", maxCount: 1 },
    { name: "business_id_photo", maxCount: 1 },
    { name: "owner_photo", maxCount: 1 },
  ]),
  uploadMultipleToCloudinary,
  body("name").notEmpty().withMessage("Restaurant name is required"),
  body("email").isEmail().withMessage("Please provide a valid email"),
  body("phone").notEmpty().withMessage("Phone number is required"),
  body("address").notEmpty().withMessage("Address is required"),
  body("city").notEmpty().withMessage("City is required"),
  body("ownerFullName").notEmpty().withMessage("Owner full name is required"),
  body("ownerContactNumber")
    .notEmpty()
    .withMessage("Owner contact number is required"),
  body("businessIdNumber")
    .notEmpty()
    .withMessage("Business ID number is required"),
  body("password")
    .isLength({ min: 6 })
    .withMessage("Password must be at least 6 characters"),
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
        email,
        phone,
        address,
        city,
        area,
        ownerFullName,
        ownerContactNumber,
        businessIdNumber,
        password,
      } = req.body;

      const existingRestaurant = await Restaurant.findOne({
        $or: [{ email }, { business_id_number }],
      });

      if (existingRestaurant) {
        return res.status(400).json({
          success: false,
          message: "Restaurant already exists with this email or business ID",
        });
      }

      const logo =
        req.files?.logo?.[0]?.cloudinaryUrl ||
        (req.files?.logo?.[0] ? getFileUrl(req.files.logo[0].filename) : null);
      const businessIdPhoto =
        req.files?.["business_id_photo"]?.[0]?.cloudinaryUrl ||
        (req.files?.["business_id_photo"]?.[0]
          ? getFileUrl(req.files["business_id_photo"][0].filename)
          : null);
      const ownerPhoto =
        req.files?.["owner_photo"]?.[0]?.cloudinaryUrl ||
        (req.files?.["owner_photo"]?.[0]
          ? getFileUrl(req.files["owner_photo"][0].filename)
          : null);

      const restaurant = await Restaurant.create({
        restaurantName: name,
        email,
        phone,
        location: {
          type: "Point",
          coordinates: [
            req.body.lng ? parseFloat(req.body.lng) : 0,
            req.body.lat ? parseFloat(req.body.lat) : 0
          ],
          address,
          city,
          area: area || "",
        },
        ownerFullName,
        ownerContactNumber,
        businessIdNumber,
        password,
        logo,
        businessIdPhoto: businessIdPhoto,
        ownerPhoto: ownerPhoto,
        status: "pending",
        vendorType: "restaurant"
      });

      const restaurantData = restaurant.toObject();

      const formattedData = {
        _id: restaurantData._id.toString(),
        restaurantName: restaurantData.restaurantName || "",
        email: restaurantData.email || "",
        phone: restaurantData.phone || "",
        ownerFullName: restaurantData.ownerFullName || "",
        ownerContactNumber: restaurantData.ownerContactNumber || "",
        businessIdNumber: restaurantData.businessIdNumber || "",
        password: "",
        logo: restaurantData.logo || null,
        businessIdPhoto: restaurantData.businessIdPhoto || null,
        ownerPhoto: restaurantData.ownerPhoto || null,
        foodType: restaurantData.foodType || null,
        description: restaurantData.description || null,
        location: {
          coordinates: restaurantData.location?.coordinates || [0, 0],
          address: restaurantData.location?.address || "",
          city: restaurantData.location?.city || "",
          area: restaurantData.location?.area || "",
        },
        averageDeliveryTime: restaurantData.averageDeliveryTime || 30,
        averagePreparationTime: restaurantData.averagePreparationTime || 15,
        deliveryFee: restaurantData.deliveryFee || 0,
        minOrder: restaurantData.minOrder || 0,
        openingHours: restaurantData.openingHours || {},
        paymentMethods: restaurantData.paymentMethods || [],
        bannerImages: restaurantData.bannerImages || [],
        status: restaurantData.status || "pending",
        rating: restaurantData.rating || 0,
        isOpen: restaurantData.isOpen || false,
        totalReviews: restaurantData.totalReviews || 0,
        createdAt: restaurantData.createdAt
      };

      res.status(201).json({
        success: true,
        message: "Restaurant registered successfully. Waiting for approval.",
        data: [formattedData],
      });
    } catch (error) {
      console.error("Register restaurant error:", error);
      res.status(500).json({
        success: false,
        message: "Server error",
        error: error.message,
      });
    }
  }
);


// Standardized endpoints to match other vendor types

// Get all restaurants (alias for /)
router.get("/stores", async (req, res) => {
  try {
    let isAdmin = false;
    if (
      req.headers.authorization &&
      req.headers.authorization.startsWith("Bearer")
    ) {
      try {
        const jwt = require("jsonwebtoken");
        const User = require("../models/User");
        const token = req.headers.authorization.split(" ")[1];
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const user = await User.findById(decoded.id).select("-password");
        if (user && user.isAdmin) {
          isAdmin = true;
        }
      } catch (err) { }
    }

    const query = isAdmin ? {} : { status: "approved", isOpen: true };

    const restaurants = await Restaurant.find(query)
      .select("-password")
      .sort({ rating: -1 })
      .limit(20);

    res.json({
      success: true,
      message: "Restaurants retrieved successfully",
      data: restaurants,
    });
  } catch (error) {
    console.error("Get restaurants error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// Get restaurant by ID (alias for /:restaurantId)
router.get("/stores/:id", async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.id).select(
      "-password"
    );

    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: "Restaurant not found",
      });
    }

    res.json({
      success: true,
      message: "Restaurant retrieved successfully",
      data: restaurant,
    });
  } catch (error) {
    console.error("Get restaurant error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// Search restaurants
router.get("/search", async (req, res) => {
  try {
    const { q, lat, lng, radius = 5 } = req.query;

    let query = { status: "approved" };

    // Text search
    if (q) {
      query.$or = [
        { restaurantName: { $regex: q, $options: "i" } },
        { description: { $regex: q, $options: "i" } },
        { foodType: { $regex: q, $options: "i" } },
        { 'location.address': { $regex: q, $options: "i" } },
        { 'location.city': { $regex: q, $options: "i" } },
        { 'location.area': { $regex: q, $options: "i" } },
      ];
    }

    // Location-based search
    if (lat && lng) {
      const latitude = parseFloat(lat);
      const longitude = parseFloat(lng);
      const radiusInKm = parseFloat(radius);

      query['location.coordinates'] = {
        $near: {
          $geometry: {
            type: "Point",
            coordinates: [longitude, latitude],
          },
          $maxDistance: radiusInKm * 1000,
        },
      };
    }

    const restaurants = await Restaurant.find(query)
      .select("-password")
      .sort({ rating: -1 })
      .limit(50);

    res.json({
      success: true,
      message: "Search results retrieved successfully",
      data: restaurants,
    });
  } catch (error) {
    console.error("Search restaurants error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// Get nearby restaurants
router.get("/nearby", async (req, res) => {
  try {
    const { lat, lng, radius = 5 } = req.query;

    if (!lat || !lng) {
      return res.status(400).json({
        success: false,
        message: "Latitude and longitude are required",
      });
    }

    const latitude = parseFloat(lat);
    const longitude = parseFloat(lng);
    const radiusInKm = parseFloat(radius);

    // Use aggregation for $geoNear which provides the distance in the output
    const restaurants = await Restaurant.aggregate([
      {
        $geoNear: {
          near: { type: "Point", coordinates: [longitude, latitude] },
          distanceField: "distance",
          maxDistance: radiusInKm * 1000,
          query: { status: "approved" },
          spherical: true,
        },
      },
      {
        $project: {
          password: 0,
        },
      },
      {
        $addFields: {
          id: "$_id",
          // Convert distance from meters to kilometers
          distance: { $divide: ["$distance", 1000] },
        },
      },
    ]);

    res.json({
      success: true,
      message: "Nearby restaurants retrieved successfully",
      data: restaurants,
    });
  } catch (error) {
    console.error("Get nearby restaurants error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// Get food categories
router.get("/categories", async (req, res) => {
  try {
    const Category = require("../models/Category");
    const categories = await Category.find().sort({ sortOrder: 1 });

    res.json({
      success: true,
      message: "Categories retrieved successfully",
      data: categories,
    });
  } catch (error) {
    console.error("Get categories error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

// Get food items
router.get("/items", async (req, res) => {
  try {
    const Food = require("../models/Food");
    const { category, restaurant } = req.query;

    let query = {};
    if (category) query.category = category;
    if (restaurant) query.restaurant = restaurant;

    const items = await Food.find(query)
      .populate("restaurant", "restaurant_name logo")
      .populate("category", "name emoji")
      .sort({ createdAt: -1 })
      .limit(50);

    res.json({
      success: true,
      message: "Food items retrieved successfully",
      data: items,
    });
  } catch (error) {
    console.error("Get food items error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

router.put("/:restaurantId", protect, admin, verifyApiKey, async (req, res) => {
  try {
    const { restaurantId } = req.params;
    const { status } = req.body;

    if (!["pending", "approved", "rejected", "suspended"].includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Invalid status",
      });
    }

    const restaurant = await Restaurant.findById(restaurantId);
    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: "Restaurant not found",
      });
    }

    restaurant.status = status;
    await restaurant.save();

    const restaurantData = restaurant.toObject();
    delete restaurantData.password;

    res.json({
      success: true,
      message: "Restaurant status updated successfully",
      data: restaurantData,
    });
  } catch (error) {
    console.error("Update restaurant error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});

router.get("/:restaurantId", async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(
      req.params.restaurantId
    ).select("-password");

    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: "Restaurant not found",
      });
    }

    res.json({
      success: true,
      message: "Restaurant retrieved successfully",
      data: restaurant,
    });
  } catch (error) {
    console.error("Get restaurant error:", error);
    res.status(500).json({
      success: false,
      message: "Server error",
      error: error.message,
    });
  }
});


module.exports = router;
