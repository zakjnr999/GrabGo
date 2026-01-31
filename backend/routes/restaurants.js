const express = require("express");
const { body, validationResult } = require("express-validator");
const prisma = require("../config/prisma");
const { protect, verifyApiKey, admin } = require("../middleware/auth");
const {
  uploadFields,
  getFileUrl,
  uploadMultipleToCloudinary,
} = require("../middleware/upload");

const router = express.Router();

// Helper function to format restaurant for frontend compatibility
const formatRestaurant = (restaurant) => {
  if (!restaurant) return null;
  return {
    ...restaurant,
    location: {
      type: 'Point',
      coordinates: [restaurant.longitude, restaurant.latitude],
      lat: restaurant.latitude,
      lng: restaurant.longitude,
      address: restaurant.address || '',
      city: restaurant.city || '',
      area: restaurant.area || '',
    },
    // Map back some fields for legacy support
    restaurant_name: restaurant.restaurantName,
    is_open: restaurant.isOpen,
    delivery_fee: restaurant.deliveryFee,
    min_order: restaurant.minOrder,
    totalReviews: restaurant.ratingCount || 0,
  };
};

// Helper function to check if user is admin
async function checkIsAdmin(req) {
  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith("Bearer")
  ) {
    try {
      const jwt = require("jsonwebtoken");
      const token = req.headers.authorization.split(" ")[1];
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await prisma.user.findUnique({
        where: { id: decoded.id },
        select: { isAdmin: true }
      });
      return user?.isAdmin || false;
    } catch (err) {
      return false;
    }
  }
  return false;
}

// Get all restaurants
router.get("/", async (req, res, next) => {
  try {
    const isAdmin = await checkIsAdmin(req);
    const where = isAdmin ? {} : { status: "approved" };

    const restaurants = await prisma.restaurant.findMany({
      where,
      select: {
        id: true,
        restaurantName: true,
        email: true,
        phone: true,
        ownerFullName: true,
        ownerContactNumber: true,
        businessIdNumber: true,
        logo: true,
        businessIdPhoto: true,
        ownerPhoto: true,
        foodType: true,
        description: true,
        averageDeliveryTime: true,
        averagePreparationTime: true,
        deliveryFee: true,
        minOrder: true,
        paymentMethods: true,
        bannerImages: true,
        status: true,
        rating: true,
        ratingCount: true,
        isOpen: true,
        longitude: true,
        latitude: true,
        address: true,
        city: true,
        area: true,
        createdAt: true,
        updatedAt: true,
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json({
      success: true,
      message: "Restaurants retrieved successfully",
      count: restaurants.length,
      data: restaurants.map(formatRestaurant),
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

// Register new restaurant
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

      // Check if restaurant already exists
      const existingRestaurant = await prisma.restaurant.findFirst({
        where: {
          OR: [
            { email },
            { businessIdNumber }
          ]
        }
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

      const restaurant = await prisma.restaurant.create({
        data: {
          restaurantName: name,
          email,
          phone,
          longitude: req.body.lng ? parseFloat(req.body.lng) : 0,
          latitude: req.body.lat ? parseFloat(req.body.lat) : 0,
          address,
          city,
          area: area || "",
          ownerFullName,
          ownerContactNumber,
          businessIdNumber,
          password,
          logo,
          businessIdPhoto,
          ownerPhoto,
          status: "pending",
        }
      });

      const formattedData = {
        _id: restaurant.id,
        restaurantName: restaurant.restaurantName || "",
        email: restaurant.email || "",
        phone: restaurant.phone || "",
        ownerFullName: restaurant.ownerFullName || "",
        ownerContactNumber: restaurant.ownerContactNumber || "",
        businessIdNumber: restaurant.businessIdNumber || "",
        password: "",
        logo: restaurant.logo || null,
        businessIdPhoto: restaurant.businessIdPhoto || null,
        ownerPhoto: restaurant.ownerPhoto || null,
        foodType: restaurant.foodType || null,
        description: restaurant.description || null,
        location: {
          coordinates: [restaurant.longitude, restaurant.latitude],
          address: restaurant.address || "",
          city: restaurant.city || "",
          area: restaurant.area || "",
        },
        averageDeliveryTime: restaurant.averageDeliveryTime || 30,
        averagePreparationTime: restaurant.averagePreparationTime || 15,
        deliveryFee: restaurant.deliveryFee || 0,
        minOrder: restaurant.minOrder || 0,
        openingHours: {},
        paymentMethods: restaurant.paymentMethods || [],
        bannerImages: restaurant.bannerImages || [],
        status: restaurant.status || "pending",
        rating: restaurant.rating || 0,
        isOpen: restaurant.isOpen || false,
        totalReviews: restaurant.ratingCount || 0,
        createdAt: restaurant.createdAt
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

// Get all restaurants (alias for /)
router.get("/stores", async (req, res) => {
  try {
    const isAdmin = await checkIsAdmin(req);
    const where = isAdmin ? {} : { status: "approved", isOpen: true };

    const restaurants = await prisma.restaurant.findMany({
      where,
      select: {
        id: true,
        restaurantName: true,
        email: true,
        phone: true,
        logo: true,
        foodType: true,
        description: true,
        averageDeliveryTime: true,
        deliveryFee: true,
        minOrder: true,
        status: true,
        rating: true,
        ratingCount: true,
        isOpen: true,
        longitude: true,
        latitude: true,
        address: true,
        city: true,
        area: true,
      },
      orderBy: { rating: 'desc' },
      take: 20
    });

    // Format restaurants to include location object
    res.json({
      success: true,
      message: "Restaurants retrieved successfully",
      count: restaurants.length,
      data: restaurants.map(formatRestaurant),
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
    const restaurant = await prisma.restaurant.findUnique({
      where: { id: req.params.id },
      select: {
        id: true,
        restaurantName: true,
        email: true,
        phone: true,
        ownerFullName: true,
        ownerContactNumber: true,
        businessIdNumber: true,
        logo: true,
        businessIdPhoto: true,
        ownerPhoto: true,
        foodType: true,
        description: true,
        averageDeliveryTime: true,
        averagePreparationTime: true,
        deliveryFee: true,
        minOrder: true,
        paymentMethods: true,
        bannerImages: true,
        status: true,
        rating: true,
        ratingCount: true,
        isOpen: true,
        longitude: true,
        latitude: true,
        address: true,
        city: true,
        area: true,
        createdAt: true,
        updatedAt: true,
      }
    });

    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: "Restaurant not found",
      });
    }

    res.json({
      success: true,
      message: "Restaurant retrieved successfully",
      data: formatRestaurant(restaurant),
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

    let where = { status: "approved" };

    // Text search
    if (q) {
      where.OR = [
        { restaurantName: { contains: q, mode: 'insensitive' } },
        { description: { contains: q, mode: 'insensitive' } },
        { foodType: { contains: q, mode: 'insensitive' } },
        { address: { contains: q, mode: 'insensitive' } },
        { city: { contains: q, mode: 'insensitive' } },
        { area: { contains: q, mode: 'insensitive' } },
      ];
    }

    let restaurants;

    // Location-based search using raw SQL for geospatial query
    if (lat && lng) {
      const latitude = parseFloat(lat);
      const longitude = parseFloat(lng);
      const radiusInMeters = parseFloat(radius) * 1000;

      // Use raw SQL for PostGIS distance calculation
      const searchQuery = q ? `%${q}%` : '%';
      restaurants = await prisma.$queryRaw`
        SELECT 
          id, "restaurantName", email, phone, logo, "foodType", description,
          "averageDeliveryTime", "deliveryFee", "minOrder", status, rating,
          "ratingCount", "isOpen", longitude, latitude, address, city, area,
          ST_Distance(
            ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
            ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
          ) as distance
        FROM restaurants
        WHERE status = 'approved'
        AND (
          "restaurantName" ILIKE ${searchQuery}
          OR description ILIKE ${searchQuery}
          OR "foodType" ILIKE ${searchQuery}
          OR address ILIKE ${searchQuery}
          OR city ILIKE ${searchQuery}
          OR area ILIKE ${searchQuery}
        )
        AND ST_DWithin(
          ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
          ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography,
          ${radiusInMeters}
        )
        ORDER BY distance ASC
        LIMIT 50
      `;
    } else {
      restaurants = await prisma.restaurant.findMany({
        where,
        select: {
          id: true,
          restaurantName: true,
          email: true,
          phone: true,
          logo: true,
          foodType: true,
          description: true,
          averageDeliveryTime: true,
          deliveryFee: true,
          minOrder: true,
          status: true,
          rating: true,
          ratingCount: true,
          isOpen: true,
          longitude: true,
          latitude: true,
          address: true,
          city: true,
          area: true,
        },
      });
    }

    res.json({
      success: true,
      message: "Search results retrieved successfully",
      count: restaurants.length,
      data: restaurants.map(formatRestaurant),
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
    const radiusInMeters = parseFloat(radius) * 1000;

    // Use raw SQL for PostGIS geospatial query
    const restaurants = await prisma.$queryRaw`
      SELECT 
        id, "restaurantName", email, phone, logo, "foodType", description,
        "averageDeliveryTime", "deliveryFee", "minOrder", status, rating,
        "ratingCount", "isOpen", longitude, latitude, address, city, area,
        ST_Distance(
          ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
          ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography
        ) / 1000 as distance
      FROM restaurants
      WHERE status = 'approved'
      AND ST_DWithin(
        ST_SetSRID(ST_MakePoint(longitude, latitude), 4326)::geography,
        ST_SetSRID(ST_MakePoint(${longitude}, ${latitude}), 4326)::geography,
        ${radiusInMeters}
      )
      ORDER BY distance ASC
    `;

    res.json({
      success: true,
      message: "Nearby restaurants retrieved successfully",
      count: restaurants.length,
      data: restaurants.map(formatRestaurant),
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
    const categories = await prisma.category.findMany({
      orderBy: { sortOrder: 'asc' }
    });

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
    const { category, restaurant } = req.query;

    let where = {};
    if (category) where.categoryId = category;
    if (restaurant) where.restaurantId = restaurant;

    const items = await prisma.food.findMany({
      where,
      include: {
        restaurant: {
          select: { id: true, restaurantName: true, logo: true }
        },
        category: {
          select: { id: true, name: true, emoji: true }
        }
      },
      orderBy: { createdAt: 'desc' },
      take: 50
    });

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

// Update restaurant status
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

    const restaurant = await prisma.restaurant.findUnique({
      where: { id: restaurantId }
    });

    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: "Restaurant not found",
      });
    }

    const updatedRestaurant = await prisma.restaurant.update({
      where: { id: restaurantId },
      data: { status },
      select: {
        id: true,
        restaurantName: true,
        email: true,
        phone: true,
        ownerFullName: true,
        ownerContactNumber: true,
        businessIdNumber: true,
        logo: true,
        businessIdPhoto: true,
        ownerPhoto: true,
        foodType: true,
        description: true,
        averageDeliveryTime: true,
        averagePreparationTime: true,
        deliveryFee: true,
        minOrder: true,
        paymentMethods: true,
        bannerImages: true,
        status: true,
        rating: true,
        ratingCount: true,
        isOpen: true,
        longitude: true,
        latitude: true,
        address: true,
        city: true,
        area: true,
        createdAt: true,
        updatedAt: true,
      }
    });

    res.json({
      success: true,
      message: "Restaurant status updated successfully",
      data: updatedRestaurant,
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

// Get single restaurant
router.get("/:restaurantId", async (req, res) => {
  try {
    const restaurant = await prisma.restaurant.findUnique({
      where: { id: req.params.restaurantId },
      select: {
        id: true,
        restaurantName: true,
        email: true,
        phone: true,
        ownerFullName: true,
        ownerContactNumber: true,
        businessIdNumber: true,
        logo: true,
        businessIdPhoto: true,
        ownerPhoto: true,
        foodType: true,
        description: true,
        averageDeliveryTime: true,
        averagePreparationTime: true,
        deliveryFee: true,
        minOrder: true,
        paymentMethods: true,
        bannerImages: true,
        status: true,
        rating: true,
        ratingCount: true,
        isOpen: true,
        longitude: true,
        latitude: true,
        address: true,
        city: true,
        area: true,
        createdAt: true,
        updatedAt: true,
      }
    });

    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: "Restaurant not found",
      });
    }

    res.json({
      success: true,
      message: "Restaurant retrieved successfully",
      data: formatRestaurant(restaurant),
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
