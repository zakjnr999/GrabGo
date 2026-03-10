const express = require('express');
const { body, validationResult } = require('express-validator');
const prisma = require('../config/prisma');
const { protect, admin } = require('../middleware/auth');
const { createScopedLogger } = require('../utils/logger');

const router = express.Router();
const console = createScopedLogger('categories_route');

// GET /api/categories - Get all active categories
router.get('/', async (req, res) => {
  try {
    const { userLat, userLng, maxDistance = 15 } = req.query;

    const userLatitude = userLat ? parseFloat(userLat) : null;
    const userLongitude = userLng ? parseFloat(userLng) : null;
    const maxDistanceKm = parseFloat(maxDistance);

    let where = { isActive: true };

    // Filter by nearby restaurants if location is provided
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

      if (filteredRestaurants.length > 0) {
        const restaurantIds = filteredRestaurants.map(r => r.id);
        where.foods = {
          some: {
            restaurantId: { in: restaurantIds },
            isAvailable: true
          }
        };
      } else {
        // No restaurants nearby, return empty list of categories
        return res.json({
          success: true,
          message: 'No services available in your area',
          data: []
        });
      }
    }

    const categories = await prisma.category.findMany({
      where,
      orderBy: { sortOrder: 'asc' },
      include: {
        _count: {
          select: { foods: true }
        }
      }
    });

    res.json({
      success: true,
      message: 'Categories retrieved successfully',
      data: categories
    });
  } catch (error) {
    console.error('Get categories error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// POST /api/categories - Create new category (Admin only)
router.post('/', protect, admin, [
  body('name').notEmpty().withMessage('Category name is required'),
  body('emoji').optional()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({
        success: false,
        message: 'Validation failed',
        errors: errors.array()
      });
    }

    const { name, description, emoji, sortOrder, isActive } = req.body;

    const category = await prisma.category.create({
      data: {
        name,
        description: description || null,
        emoji: emoji || null,
        sortOrder: sortOrder || 0,
        isActive: isActive !== false
      }
    });

    res.status(201).json({
      success: true,
      message: 'Category created successfully',
      data: category
    });
  } catch (error) {
    console.error('Create category error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

// GET /api/categories/:categoryId - Get single category
router.get('/:categoryId', async (req, res) => {
  try {
    const category = await prisma.category.findUnique({
      where: { id: req.params.categoryId },
      include: {
        foods: {
          where: { isAvailable: true },
          take: 10,
          orderBy: { orderCount: 'desc' }
        },
        _count: {
          select: { foods: true }
        }
      }
    });

    if (!category) {
      return res.status(404).json({
        success: false,
        message: 'Category not found'
      });
    }

    res.json({
      success: true,
      message: 'Category retrieved successfully',
      data: category
    });
  } catch (error) {
    console.error('Get category error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error'
    });
  }
});

module.exports = router;
