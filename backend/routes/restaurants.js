const express = require('express');
const { body, validationResult } = require('express-validator');
const Restaurant = require('../models/Restaurant');
const { protect, verifyApiKey, admin } = require('../middleware/auth');
const { uploadFields, getFileUrl, uploadMultipleToCloudinary } = require('../middleware/upload');

const router = express.Router();

// @route   GET /api/restaurants
// @desc    Get all restaurants
// @access  Public
router.get('/', async (req, res) => {
  try {
    const restaurants = await Restaurant.find({ status: 'approved' })
      .select('-password')
      .sort({ createdAt: -1 });

    res.json({
      success: true,
      message: 'Restaurants retrieved successfully',
      data: restaurants
    });
  } catch (error) {
    console.error('Get restaurants error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// @route   POST /api/restaurants/register
// @desc    Register a new restaurant
// @access  Public
// IMPORTANT: Multer must run BEFORE validation to parse multipart/form-data
router.post('/register', 
  uploadFields([
    { name: 'logo', maxCount: 1 },
    { name: 'business_id_photo', maxCount: 1 },
    { name: 'owner_photo', maxCount: 1 }
  ]), 
  uploadMultipleToCloudinary,
  // Validation runs AFTER multer has parsed the multipart data
  body('name').notEmpty().withMessage('Restaurant name is required'),
  body('email').isEmail().withMessage('Please provide a valid email'),
  body('phone').notEmpty().withMessage('Phone number is required'),
  body('address').notEmpty().withMessage('Address is required'),
  body('city').notEmpty().withMessage('City is required'),
  body('owner_full_name').notEmpty().withMessage('Owner full name is required'),
  body('owner_contact_number').notEmpty().withMessage('Owner contact number is required'),
  body('business_id_number').notEmpty().withMessage('Business ID number is required'),
  body('password').isLength({ min: 6 }).withMessage('Password must be at least 6 characters'),
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
      name,
      email,
      phone,
      address,
      city,
      owner_full_name,
      owner_contact_number,
      business_id_number,
      password
    } = req.body;

    // Check if restaurant exists
    const existingRestaurant = await Restaurant.findOne({
      $or: [{ email }, { business_id_number }]
    });

    if (existingRestaurant) {
      return res.status(400).json({
        success: false,
        message: 'Restaurant already exists with this email or business ID'
      });
    }

    // Handle file uploads (use Cloudinary URLs if available)
    const logo = req.files?.logo?.[0]?.cloudinaryUrl || 
                 (req.files?.logo?.[0] ? getFileUrl(req.files.logo[0].filename) : null);
    const businessIdPhoto = req.files?.['business_id_photo']?.[0]?.cloudinaryUrl ||
                           (req.files?.['business_id_photo']?.[0] 
                             ? getFileUrl(req.files['business_id_photo'][0].filename) 
                             : null);
    const ownerPhoto = req.files?.['owner_photo']?.[0]?.cloudinaryUrl ||
                      (req.files?.['owner_photo']?.[0] 
                        ? getFileUrl(req.files['owner_photo'][0].filename) 
                        : null);

    // Create restaurant
    const restaurant = await Restaurant.create({
      restaurant_name: name,
      email,
      phone,
      address,
      city,
      owner_full_name,
      owner_contact_number,
      business_id_number,
      password,
      logo,
      business_id_photo: businessIdPhoto,
      owner_photo: ownerPhoto,
      status: 'pending'
    });

    // Format response data - ensure all required fields are present
    const restaurantData = restaurant.toObject();
    
    // Format response data - ensure all required fields are present and non-null
    const formattedData = {
      _id: restaurantData._id.toString(),
      restaurant_name: restaurantData.restaurant_name || '',
      email: restaurantData.email || '',
      phone: restaurantData.phone || '',
      address: restaurantData.address || '',
      city: restaurantData.city || '',
      owner_full_name: restaurantData.owner_full_name || '',
      owner_contact_number: restaurantData.owner_contact_number || '',
      business_id_number: restaurantData.business_id_number || '',
      password: '', // Empty string instead of null for required field
      logo: restaurantData.logo || null,
      business_id_photo: restaurantData.business_id_photo || null,
      owner_photo: restaurantData.owner_photo || null,
      food_type: restaurantData.food_type || null,
      description: restaurantData.description || null,
      latitude: restaurantData.latitude || null,
      longitude: restaurantData.longitude || null,
      average_delivery_time: restaurantData.average_delivery_time || null,
      delivery_fee: restaurantData.delivery_fee || 0,
      min_order: restaurantData.min_order || 0,
      opening_hours: restaurantData.opening_hours || null,
      payment_methods: restaurantData.payment_methods || null,
      banner_images: restaurantData.banner_images || null,
      status: restaurantData.status || 'pending',
      rating: restaurantData.rating || 0,
      is_open: restaurantData.is_open || false,
      total_reviews: restaurantData.total_reviews || 0,
      created_at: restaurantData.createdAt ? restaurantData.createdAt.toISOString() : new Date().toISOString(),
      __v: restaurantData.__v || 0,
      socials: restaurantData.socials || null
    };

    res.status(201).json({
      success: true,
      message: 'Restaurant registered successfully. Waiting for approval.',
      data: [formattedData] // Wrap in array to match RestaurantResponse model
    });
  } catch (error) {
    console.error('Register restaurant error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// @route   PUT /api/restaurants/:restaurantId
// @desc    Update restaurant status (Admin only)
// @access  Private/Admin
router.put('/:restaurantId', protect, admin, verifyApiKey, async (req, res) => {
  try {
    const { restaurantId } = req.params;
    const { status } = req.body;

    if (!['pending', 'approved', 'rejected', 'suspended'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status'
      });
    }

    const restaurant = await Restaurant.findById(restaurantId);
    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: 'Restaurant not found'
      });
    }

    restaurant.status = status;
    await restaurant.save();

    const restaurantData = restaurant.toObject();
    delete restaurantData.password;

    res.json({
      success: true,
      message: 'Restaurant status updated successfully',
      data: restaurantData
    });
  } catch (error) {
    console.error('Update restaurant error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

// @route   GET /api/restaurants/:restaurantId
// @desc    Get restaurant by ID
// @access  Public
router.get('/:restaurantId', async (req, res) => {
  try {
    const restaurant = await Restaurant.findById(req.params.restaurantId)
      .select('-password');

    if (!restaurant) {
      return res.status(404).json({
        success: false,
        message: 'Restaurant not found'
      });
    }

    res.json({
      success: true,
      message: 'Restaurant retrieved successfully',
      data: restaurant
    });
  } catch (error) {
    console.error('Get restaurant error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message
    });
  }
});

module.exports = router;

