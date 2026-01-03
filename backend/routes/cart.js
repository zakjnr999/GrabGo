const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const {
    addToCart,
    updateCartItem,
    removeFromCart,
    clearCart,
    getUserCart
} = require('../services/cart_service');

/**
 * @route   GET /api/cart
 * @desc    Get user's active cart
 * @access  Private
 */
router.get('/', protect, async (req, res) => {
    try {
        const cartType = req.query.type || null; // 'food' or 'grocery'
        const cart = await getUserCart(req.user._id, cartType);

        if (!cart) {
            return res.json({
                success: true,
                cart: {
                    items: [],
                    totalAmount: 0,
                    itemCount: 0
                }
            });
        }

        res.json({
            success: true,
            cart
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
        const { itemId, itemType, quantity, restaurantId, groceryStoreId } = req.body;

        if (!itemId || !itemType) {
            return res.status(400).json({
                success: false,
                message: 'Item ID and type are required'
            });
        }

        if (!['Food', 'GroceryItem'].includes(itemType)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid item type. Must be Food or GroceryItem'
            });
        }

        const cart = await addToCart(req.user._id, {
            itemId,
            itemType,
            quantity: quantity || 1,
            restaurantId,
            groceryStoreId
        });

        res.json({
            success: true,
            message: 'Item added to cart',
            cart
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

        if (quantity === undefined || quantity < 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid quantity is required'
            });
        }

        const cart = await updateCartItem(req.user._id, itemId, quantity);

        res.json({
            success: true,
            message: quantity === 0 ? 'Item removed from cart' : 'Cart updated',
            cart
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
        const cart = await removeFromCart(req.user._id, itemId);

        res.json({
            success: true,
            message: 'Item removed from cart',
            cart
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
        const cart = await clearCart(req.user._id);

        res.json({
            success: true,
            message: 'Cart cleared',
            cart
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
