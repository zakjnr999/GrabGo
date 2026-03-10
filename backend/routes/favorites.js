const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
    getUserFavorites,
    addFavoriteRestaurant,
    removeFavoriteRestaurant,
    addFavoriteStore,
    removeFavoriteStore,
    addFavoritePharmacy,
    removeFavoritePharmacy,
    addFavoriteGrabMartStore,
    removeFavoriteGrabMartStore,
    addFavoriteFoodItem,
    removeFavoriteFoodItem,
    addFavoriteGroceryItem,
    removeFavoriteGroceryItem,
    addFavoritePharmacyItem,
    removeFavoritePharmacyItem,
    addFavoriteGrabMartItem,
    removeFavoriteGrabMartItem,
    clearAllFavorites,
    syncFavorites
} = require('../services/favorites_service');
const { createScopedLogger } = require('../utils/logger');

const console = createScopedLogger('favorites_route');

const getErrorStatus = (error) => {
    const message = String(error?.message || '').toLowerCase();
    if (message.includes('not found')) return 404;
    return 500;
};

const sendFavoritesError = (res, error, fallbackMessage) => {
    const status = getErrorStatus(error);
    return res.status(status).json({
        success: false,
        message: status >= 500 ? fallbackMessage : (error?.message || fallbackMessage)
    });
};

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
        sendFavoritesError(res, error, 'Failed to get favorites');
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
        sendFavoritesError(res, error, 'Failed to add restaurant to favorites');
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
        sendFavoritesError(res, error, 'Failed to remove restaurant from favorites');
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
        sendFavoritesError(res, error, 'Failed to add store to favorites');
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
        sendFavoritesError(res, error, 'Failed to remove store from favorites');
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
        sendFavoritesError(res, error, 'Failed to add food item to favorites');
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
        sendFavoritesError(res, error, 'Failed to remove food item from favorites');
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
        sendFavoritesError(res, error, 'Failed to add grocery item to favorites');
    }
});

/**
 * @route   POST /api/favorites/pharmacy/:pharmacyId
 * @desc    Add pharmacy store to favorites
 * @access  Private
 */
router.post('/pharmacy/:pharmacyId', protect, async (req, res) => {
    try {
        const favorites = await addFavoritePharmacy(req.user.id, req.params.pharmacyId);

        res.json({
            success: true,
            message: 'Pharmacy store added to favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Add favorite pharmacy store error:', error);
        sendFavoritesError(res, error, 'Failed to add pharmacy store to favorites');
    }
});

/**
 * @route   DELETE /api/favorites/pharmacy/:pharmacyId
 * @desc    Remove pharmacy store from favorites
 * @access  Private
 */
router.delete('/pharmacy/:pharmacyId', protect, async (req, res) => {
    try {
        const favorites = await removeFavoritePharmacy(req.user.id, req.params.pharmacyId);

        res.json({
            success: true,
            message: 'Pharmacy store removed from favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Remove favorite pharmacy store error:', error);
        sendFavoritesError(res, error, 'Failed to remove pharmacy store from favorites');
    }
});

/**
 * @route   POST /api/favorites/grabmart-store/:storeId
 * @desc    Add GrabMart store to favorites
 * @access  Private
 */
router.post('/grabmart-store/:storeId', protect, async (req, res) => {
    try {
        const favorites = await addFavoriteGrabMartStore(req.user.id, req.params.storeId);

        res.json({
            success: true,
            message: 'GrabMart store added to favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Add favorite GrabMart store error:', error);
        sendFavoritesError(res, error, 'Failed to add GrabMart store to favorites');
    }
});

/**
 * @route   DELETE /api/favorites/grabmart-store/:storeId
 * @desc    Remove GrabMart store from favorites
 * @access  Private
 */
router.delete('/grabmart-store/:storeId', protect, async (req, res) => {
    try {
        const favorites = await removeFavoriteGrabMartStore(req.user.id, req.params.storeId);

        res.json({
            success: true,
            message: 'GrabMart store removed from favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Remove favorite GrabMart store error:', error);
        sendFavoritesError(res, error, 'Failed to remove GrabMart store from favorites');
    }
});

/**
 * @route   POST /api/favorites/pharmacy-item/:pharmacyItemId
 * @desc    Add pharmacy item to favorites
 * @access  Private
 */
router.post('/pharmacy-item/:pharmacyItemId', protect, async (req, res) => {
    try {
        const favorites = await addFavoritePharmacyItem(req.user.id, req.params.pharmacyItemId);

        res.json({
            success: true,
            message: 'Pharmacy item added to favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Add favorite pharmacy item error:', error);
        sendFavoritesError(res, error, 'Failed to add pharmacy item to favorites');
    }
});

/**
 * @route   DELETE /api/favorites/pharmacy-item/:pharmacyItemId
 * @desc    Remove pharmacy item from favorites
 * @access  Private
 */
router.delete('/pharmacy-item/:pharmacyItemId', protect, async (req, res) => {
    try {
        const favorites = await removeFavoritePharmacyItem(req.user.id, req.params.pharmacyItemId);

        res.json({
            success: true,
            message: 'Pharmacy item removed from favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Remove favorite pharmacy item error:', error);
        sendFavoritesError(res, error, 'Failed to remove pharmacy item from favorites');
    }
});

/**
 * @route   POST /api/favorites/grabmart-item/:grabMartItemId
 * @desc    Add GrabMart item to favorites
 * @access  Private
 */
router.post('/grabmart-item/:grabMartItemId', protect, async (req, res) => {
    try {
        const favorites = await addFavoriteGrabMartItem(req.user.id, req.params.grabMartItemId);

        res.json({
            success: true,
            message: 'GrabMart item added to favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Add favorite GrabMart item error:', error);
        sendFavoritesError(res, error, 'Failed to add GrabMart item to favorites');
    }
});

/**
 * @route   DELETE /api/favorites/grabmart-item/:grabMartItemId
 * @desc    Remove GrabMart item from favorites
 * @access  Private
 */
router.delete('/grabmart-item/:grabMartItemId', protect, async (req, res) => {
    try {
        const favorites = await removeFavoriteGrabMartItem(req.user.id, req.params.grabMartItemId);

        res.json({
            success: true,
            message: 'GrabMart item removed from favorites',
            data: favorites
        });
    } catch (error) {
        console.error('Remove favorite GrabMart item error:', error);
        sendFavoritesError(res, error, 'Failed to remove GrabMart item from favorites');
    }
});

/**
 * @route   DELETE /api/favorites
 * @desc    Clear all favorites
 * @access  Private
 */
router.delete('/', protect, async (req, res) => {
    try {
        const favorites = await clearAllFavorites(req.user.id);

        res.json({
            success: true,
            message: 'All favorites cleared successfully',
            data: favorites
        });
    } catch (error) {
        console.error('Clear favorites error:', error);
        sendFavoritesError(res, error, 'Failed to clear favorites');
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
        sendFavoritesError(res, error, 'Failed to remove grocery item from favorites');
    }
});

/**
 * @route   POST /api/favorites/sync
 * @desc    Sync local favorites to backend
 * @access  Private
 */
router.post('/sync', protect, async (req, res) => {
    try {
        const payload = req.body || {};
        const {
            restaurants,
            stores,
            groceryStores,
            pharmacies,
            pharmacyStores,
            grabMartStores,
            foodItems,
            groceryItems,
            pharmacyItems,
            grabMartItems
        } = payload;

        const localFavorites = {
            restaurants: restaurants || [],
            stores: stores || groceryStores || [],
            pharmacies: pharmacies || pharmacyStores || [],
            grabMartStores: grabMartStores || [],
            foodItems: foodItems || [],
            groceryItems: groceryItems || [],
            pharmacyItems: pharmacyItems || [],
            grabMartItems: grabMartItems || []
        };

        const favorites = await syncFavorites(req.user.id, localFavorites);

        res.json({
            success: true,
            message: 'Favorites synced successfully',
            data: favorites
        });
    } catch (error) {
        console.error('Sync favorites error:', error);
        sendFavoritesError(res, error, 'Failed to sync favorites');
    }
});

module.exports = router;
