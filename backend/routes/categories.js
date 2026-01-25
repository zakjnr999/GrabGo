const express = require('express');
const { body, validationResult } = require('express-validator');
const prisma = require('../config/prisma');
const { protect, admin } = require('../middleware/auth');

const router = express.Router();

// GET /api/categories - Get all active categories
router.get('/', async (req, res) => {
  try {
    const categories = await prisma.category.findMany({
      where: { isActive: true },
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
      message: 'Server error',
      error: error.message
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
      message: 'Server error',
      error: error.message
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
      message: 'Server error',
      error: error.message
    });
  }
});

module.exports = router;
