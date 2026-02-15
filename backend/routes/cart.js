const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { calculateCartPricing } = require('../services/pricing_service');
const {
    normalizeFulfillmentMode,
    addToCart,
    updateCartItem,
    removeFromCart,
    clearCart,
    getUserCart
} = require('../services/cart_service');

const parseBoolean = (value) => {
    if (typeof value === 'boolean') return value;
    if (typeof value === 'number') return value !== 0;
    if (typeof value === 'string') {
        const normalized = value.trim().toLowerCase();
        if (['true', '1', 'yes', 'y', 'on'].includes(normalized)) return true;
        if (['false', '0', 'no', 'n', 'off'].includes(normalized)) return false;
    }
    return undefined;
};

/**
 * @route   GET /api/cart
 * @desc    Get user's active cart
 * @access  Private
 */
router.get('/', protect, async (req, res) => {
    try {
        const cartType = req.query.type || null; // 'food' or 'grocery'
        const fulfillmentMode = normalizeFulfillmentMode(req.query.fulfillmentMode);
        const cart = await getUserCart(req.user.id, cartType, fulfillmentMode);
        const lat = Number(req.query.lat);
        const lng = Number(req.query.lng);
        const deliveryLocation =
            Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : null;
        const useCredits = parseBoolean(req.query.useCredits);

        if (!cart) {
            return res.json({
                success: true,
                cart: {
                    items: [],
                    totalAmount: 0,
                    itemCount: 0,
                    pricing: {
                        subtotal: 0,
                        deliveryFee: 0,
                        serviceFee: 0,
                        tax: 0,
                        rainFee: 0,
                        total: 0,
                        itemCount: 0,
                        creditsApplied: 0,
                        totalAfterCredits: 0
                    }
                }
            });
        }

        const pricing = await calculateCartPricing(cart, { userId: req.user.id, deliveryLocation, useCredits });

        res.json({
            success: true,
            cart: { ...cart, pricing }
        });
    } catch (error) {
        console.error('Error fetching cart:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch cart',
            error: error.message
        });
    }
});

/**
 * @route   POST /api/cart/add
 * @desc    Add item to cart
 * @access  Private
 */
router.post('/add', protect, async (req, res) => {
    try {
        const { itemId, itemType, quantity, restaurantId, groceryStoreId, pharmacyStoreId, grabMartStoreId } = req.body;
        const fulfillmentMode = normalizeFulfillmentMode(req.query.fulfillmentMode ?? req.body.fulfillmentMode);
        const lat = Number(req.query.lat ?? req.body.lat);
        const lng = Number(req.query.lng ?? req.body.lng);
        const deliveryLocation =
            Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : null;
        const useCredits = parseBoolean(req.query.useCredits ?? req.body.useCredits);

        if (!itemId || !itemType) {
            return res.status(400).json({
                success: false,
                message: 'Item ID and type are required'
            });
        }

        if (!['Food', 'GroceryItem', 'PharmacyItem', 'GrabMartItem'].includes(itemType)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid item type. Must be Food, GroceryItem, PharmacyItem, or GrabMartItem'
            });
        }

        const cart = await addToCart(req.user.id, {
            itemId,
            itemType,
            quantity: quantity || 1,
            restaurantId,
            groceryStoreId,
            pharmacyStoreId,
            grabMartStoreId,
            fulfillmentMode
        });

        const pricing = await calculateCartPricing(cart, { userId: req.user.id, deliveryLocation, useCredits });

        res.json({
            success: true,
            message: 'Item added to cart',
            cart: { ...cart, pricing }
        });
    } catch (error) {
        console.error('Error adding to cart:', error);

        // Fix #8: Distinguish error types
        if (error.message.includes('not found') ||
            error.message.includes('unavailable') ||
            error.message.includes('inactive') ||
            error.message.includes('Quantity must be') ||
            error.message.includes('Maximum quantity') ||
            error.message.includes('Invalid')) {
            return res.status(400).json({
                success: false,
                message: error.message
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to add item to cart'
        });
    }
});

/**
 * @route   PATCH /api/cart/update/:itemId
 * @desc    Update item quantity in cart
 * @access  Private
 */
router.patch('/update/:itemId', protect, async (req, res) => {
    try {
        const { itemId } = req.params;
        const { quantity } = req.body;
        const fulfillmentMode = normalizeFulfillmentMode(req.query.fulfillmentMode ?? req.body.fulfillmentMode);
        const lat = Number(req.query.lat ?? req.body.lat);
        const lng = Number(req.query.lng ?? req.body.lng);
        const deliveryLocation =
            Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : null;
        const useCredits = parseBoolean(req.query.useCredits ?? req.body.useCredits);

        if (quantity === undefined || quantity < 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid quantity is required'
            });
        }

        const cart = await updateCartItem(req.user.id, itemId, quantity, fulfillmentMode);
        const pricing = await calculateCartPricing(cart, { userId: req.user.id, deliveryLocation, useCredits });

        res.json({
            success: true,
            message: quantity === 0 ? 'Item removed from cart' : 'Cart updated',
            cart: { ...cart, pricing }
        });
    } catch (error) {
        console.error('Error updating cart:', error);

        // Fix #8: Distinguish error types
        if (error.message.includes('not found') || error.message.includes('Invalid')) {
            return res.status(400).json({
                success: false,
                message: error.message
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to update cart'
        });
    }
});

/**
 * @route   DELETE /api/cart/remove/:itemId
 * @desc    Remove item from cart
 * @access  Private
 */
router.delete('/remove/:itemId', protect, async (req, res) => {
    try {
        const { itemId } = req.params;
        const fulfillmentMode = normalizeFulfillmentMode(req.query.fulfillmentMode ?? req.body?.fulfillmentMode);
        const lat = Number(req.query.lat ?? req.body?.lat);
        const lng = Number(req.query.lng ?? req.body?.lng);
        const deliveryLocation =
            Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : null;
        const useCredits = parseBoolean(req.query.useCredits ?? req.body?.useCredits);
        const cart = await removeFromCart(req.user.id, itemId, fulfillmentMode);
        const pricing = await calculateCartPricing(cart, { userId: req.user.id, deliveryLocation, useCredits });

        res.json({
            success: true,
            message: 'Item removed from cart',
            cart: { ...cart, pricing }
        });
    } catch (error) {
        console.error('Error removing from cart:', error);

        // Fix #8: Distinguish error types
        if (error.message.includes('not found')) {
            return res.status(400).json({
                success: false,
                message: error.message
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to remove item'
        });
    }
});

/**
 * @route   DELETE /api/cart/clear
 * @desc    Clear entire cart
 * @access  Private
 */
router.delete('/clear', protect, async (req, res) => {
    try {
        const fulfillmentMode = normalizeFulfillmentMode(req.query.fulfillmentMode ?? req.body?.fulfillmentMode);
        const lat = Number(req.query.lat ?? req.body?.lat);
        const lng = Number(req.query.lng ?? req.body?.lng);
        const deliveryLocation =
            Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : null;
        const useCredits = parseBoolean(req.query.useCredits ?? req.body?.useCredits);
        const cart = await clearCart(req.user.id, fulfillmentMode);
        const pricing = await calculateCartPricing(cart, { userId: req.user.id, deliveryLocation, useCredits });

        res.json({
            success: true,
            message: 'Cart cleared',
            cart: { ...cart, pricing }
        });
    } catch (error) {
        console.error('Error clearing cart:', error);

        // Fix #8: Distinguish error types
        if (error.message.includes('not found')) {
            return res.status(400).json({
                success: false,
                message: error.message
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to clear cart'
        });
    }
});

module.exports = router;
