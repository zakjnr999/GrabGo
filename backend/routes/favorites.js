const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
    getUserFavorites,
    addFavoriteRestaurant,
    removeFavoriteRestaurant,
    addFavoriteStore,
    removeFavoriteStore,
    addFavoriteFoodItem,
    removeFavoriteFoodItem,
    addFavoriteGroceryItem,
    removeFavoriteGroceryItem,
    syncFavorites
} = require('../services/favorites_service');

/**
 * @route   GET /api/favorites
 * @desc    Get all user favorites
 * @access  Private
 */
router.get('/', protect, async (req, res) => {
    try {
        const favorites = await getUserFavorites(req.user.id);

        res.json({
            success: true,
            data: favorites
        });
    } catch (error) {
        console.error('Get favorites error:', error);
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to get favorites'
        });
    }
});

/**
 * @route   POST /api/favorites/restaurant/:restaurantId
 * @desc    Add restaurant to favorites
 * @access  Private
 */
router.post('/restaurant/:restaurantId', protect, async (req, res) => {
    try {
        const favorites = await addFavoriteRestaurant(req.user.id, req.params.restaurantId);

        res.json({
            success: true,
            message: 'Restaurant added to favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Add favorite restaurant error:', error);
        const statusCode = error.message.includes('not found') || error.message.includes('already') ? 400 : 500;
        res.status(statusCode).json({
            success: false,
            message: error.message || 'Failed to add restaurant to favorites'
        });
    }
});

/**
 * @route   DELETE /api/favorites/restaurant/:restaurantId
 * @desc    Remove restaurant from favorites
 * @access  Private
 */
router.delete('/restaurant/:restaurantId', protect, async (req, res) => {
    try {
        const favorites = await removeFavoriteRestaurant(req.user.id, req.params.restaurantId);

        res.json({
            success: true,
            message: 'Restaurant removed from favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Remove favorite restaurant error:', error);
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to remove restaurant from favorites'
        });
    }
});

/**
 * @route   POST /api/favorites/store/:storeId
 * @desc    Add grocery store to favorites
 * @access  Private
 */
router.post('/store/:storeId', protect, async (req, res) => {
    try {
        const favorites = await addFavoriteStore(req.user.id, req.params.storeId);

        res.json({
            success: true,
            message: 'Store added to favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Add favorite store error:', error);
        const statusCode = error.message.includes('not found') || error.message.includes('already') ? 400 : 500;
        res.status(statusCode).json({
            success: false,
            message: error.message || 'Failed to add store to favorites'
        });
    }
});

/**
 * @route   DELETE /api/favorites/store/:storeId
 * @desc    Remove grocery store from favorites
 * @access  Private
 */
router.delete('/store/:storeId', protect, async (req, res) => {
    try {
        const favorites = await removeFavoriteStore(req.user.id, req.params.storeId);

        res.json({
            success: true,
            message: 'Store removed from favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Remove favorite store error:', error);
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to remove store from favorites'
        });
    }
});

/**
 * @route   POST /api/favorites/food/:foodId
 * @desc    Add food item to favorites
 * @access  Private
 */
router.post('/food/:foodId', protect, async (req, res) => {
    try {
        const favorites = await addFavoriteFoodItem(req.user.id, req.params.foodId);

        res.json({
            success: true,
            message: 'Food item added to favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Add favorite food item error:', error);
        const statusCode = error.message.includes('not found') || error.message.includes('already') ? 400 : 500;
        res.status(statusCode).json({
            success: false,
            message: error.message || 'Failed to add food item to favorites'
        });
    }
});

/**
 * @route   DELETE /api/favorites/food/:foodId
 * @desc    Remove food item from favorites
 * @access  Private
 */
router.delete('/food/:foodId', protect, async (req, res) => {
    try {
        const favorites = await removeFavoriteFoodItem(req.user.id, req.params.foodId);

        res.json({
            success: true,
            message: 'Food item removed from favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Remove favorite food item error:', error);
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to remove food item from favorites'
        });
    }
});

/**
 * @route   POST /api/favorites/grocery/:groceryId
 * @desc    Add grocery item to favorites
 * @access  Private
 */
router.post('/grocery/:groceryId', protect, async (req, res) => {
    try {
        const favorites = await addFavoriteGroceryItem(req.user.id, req.params.groceryId);

        res.json({
            success: true,
            message: 'Grocery item added to favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Add favorite grocery item error:', error);
        const statusCode = error.message.includes('not found') || error.message.includes('already') ? 400 : 500;
        res.status(statusCode).json({
            success: false,
            message: error.message || 'Failed to add grocery item to favorites'
        });
    }
});

/**
 * @route   DELETE /api/favorites/grocery/:groceryId
 * @desc    Remove grocery item from favorites
 * @access  Private
 */
router.delete('/grocery/:groceryId', protect, async (req, res) => {
    try {
        const favorites = await removeFavoriteGroceryItem(req.user.id, req.params.groceryId);

        res.json({
            success: true,
            message: 'Grocery item removed from favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Remove favorite grocery item error:', error);
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to remove grocery item from favorites'
        });
    }
});

/**
 * @route   POST /api/favorites/sync
 * @desc    Sync local favorites to backend
 * @access  Private
 */
router.post('/sync', protect, async (req, res) => {
    try {
        const { restaurants, stores, foodItems, groceryItems } = req.body;

        const localFavorites = {
            restaurants: restaurants || [],
            stores: stores || [],
            foodItems: foodItems || [],
            groceryItems: groceryItems || []
        };

        const favorites = await syncFavorites(req.user.id, localFavorites);

        res.json({
            success: true,
            message: 'Favorites synced successfully',
            data: favorites
        });
    } catch (error) {
        console.error('Sync favorites error:', error);
        res.status(500).json({
            success: false,
            message: error.message || 'Failed to sync favorites'
        });
    }
});

module.exports = router;
