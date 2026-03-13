const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');
const { calculateCartPricing, calculateCartGroupsPricing } = require('../services/pricing_service');
const {
    normalizeFulfillmentMode,
    addToCart,
    syncCartState,
    updateCartItem,
    removeFromCart,
    clearCart,
    getUserCart,
    getUserCartGroups,
} = require('../services/cart_service');
const featureFlags = require('../config/feature_flags');
const { createScopedLogger } = require('../utils/logger');
const cache = require('../utils/cache');

const console = createScopedLogger('cart_route');
const CART_SYNC_IDEMPOTENCY_TTL_SECONDS = 5 * 60;

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

const normalizePromoCode = (value) => {
    if (!value) return null;
    const normalized = String(value).trim().toUpperCase();
    return normalized.length > 0 ? normalized : null;
};

const getErrorMessage = (error) => String(error?.message || '');

const isCartBusinessError = (message) => {
    const normalized = String(message || '').toLowerCase();
    return [
        'not found',
        'unavailable',
        'inactive',
        'closed',
        'accepting orders',
        'portion',
        'preference option',
        'customization',
        'out of stock',
        'not enough stock',
        'insufficient stock',
        'quantity must be',
        'maximum quantity',
        'invalid',
        'multiple vendors',
    ].some((fragment) => normalized.includes(fragment));
};

/**
 * @route   GET /api/cart/groups
 * @desc    Get grouped cart data (one group per vendor)
 * @access  Private
 */
router.get('/groups', protect, async (req, res) => {
    try {
        if (!featureFlags.isMixedCartEnabled) {
            return res.status(403).json({
                success: false,
                message: 'Mixed cart is currently unavailable',
                code: 'MIXED_CART_DISABLED',
            });
        }

        const fulfillmentMode = normalizeFulfillmentMode(req.query.fulfillmentMode);
        const carts = await getUserCartGroups(req.user.id, fulfillmentMode);
        const lat = Number(req.query.lat);
        const lng = Number(req.query.lng);
        const deliveryLocation =
            Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : null;
        const useCredits = parseBoolean(req.query.useCredits);
        const promoCode = featureFlags.isPromoCheckoutEnabled
            ? normalizePromoCode(req.query.promoCode)
            : null;

        const groupedPricing = await calculateCartGroupsPricing(carts, {
            userId: req.user.id,
            deliveryLocation,
            useCredits,
            fulfillmentMode,
            promoCode,
        });

        return res.json({
            success: true,
            mixedCartEnabled: featureFlags.isMixedCartEnabled,
            groups: groupedPricing.groups,
            summary: groupedPricing.summary,
        });
    } catch (error) {
        console.error('Error fetching grouped cart:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch grouped cart',
        });
    }
});

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
        const promoCode = featureFlags.isPromoCheckoutEnabled
            ? normalizePromoCode(req.query.promoCode)
            : null;

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
                        totalBeforePromo: 0,
                        totalBeforeCredits: 0,
                        total: 0,
                        promoCode: null,
                        promoType: null,
                        promoDiscount: 0,
                        promoValidationMessage: null,
                        itemCount: 0,
                        creditsApplied: 0,
                        totalAfterCredits: 0,
                        creditBalance: 0,
                        availableBalance: 0,
                        subscriptionTier: null,
                        subscriptionId: null,
                        subscriptionDeliveryDiscount: 0,
                        subscriptionServiceFeeDiscount: 0,
                        originalDeliveryFee: 0,
                        originalServiceFee: 0
                    }
                }
            });
        }

        const pricing = await calculateCartPricing(cart, { userId: req.user.id, deliveryLocation, useCredits, promoCode });

        res.json({
            success: true,
            cart: { ...cart, pricing }
        });
    } catch (error) {
        console.error('Error fetching cart:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch cart'
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
        const {
            itemId,
            itemType,
            quantity,
            restaurantId,
            groceryStoreId,
            pharmacyStoreId,
            grabMartStoreId,
            selectedPortionId,
            selectedPreferenceOptionIds,
            itemNote,
        } = req.body;
        const fulfillmentMode = normalizeFulfillmentMode(req.query.fulfillmentMode ?? req.body.fulfillmentMode);
        const lat = Number(req.query.lat ?? req.body.lat);
        const lng = Number(req.query.lng ?? req.body.lng);
        const deliveryLocation =
            Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : null;
        const useCredits = parseBoolean(req.query.useCredits ?? req.body.useCredits);
        const promoCode = featureFlags.isPromoCheckoutEnabled
            ? normalizePromoCode(req.query.promoCode ?? req.body.promoCode)
            : null;

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
            selectedPortionId,
            selectedPreferenceOptionIds,
            itemNote,
            fulfillmentMode
        });

        const pricing = await calculateCartPricing(cart, { userId: req.user.id, deliveryLocation, useCredits, promoCode });

        res.json({
            success: true,
            message: 'Item added to cart',
            cart: { ...cart, pricing }
        });
    } catch (error) {
        console.error('Error adding to cart:', error);
        const errorMessage = getErrorMessage(error);

        // Fix #8: Distinguish error types
        if (errorMessage.includes('not found') ||
            errorMessage.includes('unavailable') ||
            errorMessage.includes('inactive') ||
            errorMessage.includes('closed') ||
            errorMessage.includes('accepting orders') ||
            errorMessage.includes('portion') ||
            errorMessage.includes('preference option') ||
            errorMessage.includes('customization') ||
            errorMessage.includes('out of stock') ||
            errorMessage.includes('not enough stock') ||
            errorMessage.includes('insufficient stock') ||
            errorMessage.includes('Quantity must be') ||
            errorMessage.includes('Maximum quantity') ||
            errorMessage.includes('Invalid')) {
            return res.status(400).json({
                success: false,
                message: errorMessage
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to add item to cart'
        });
    }
});

/**
 * @route   PUT /api/cart/sync
 * @desc    Reconcile the full desired cart snapshot for the current user
 * @access  Private
 */
router.put('/sync', protect, async (req, res) => {
    const fulfillmentMode = normalizeFulfillmentMode(req.query.fulfillmentMode ?? req.body?.fulfillmentMode);
    const lat = Number(req.query.lat ?? req.body?.lat);
    const lng = Number(req.query.lng ?? req.body?.lng);
    const deliveryLocation =
        Number.isFinite(lat) && Number.isFinite(lng) ? { latitude: lat, longitude: lng } : null;
    const useCredits = parseBoolean(req.query.useCredits ?? req.body?.useCredits);
    const promoCode = featureFlags.isPromoCheckoutEnabled
        ? normalizePromoCode(req.query.promoCode ?? req.body?.promoCode)
        : null;
    const clientCartVersion = Number(req.body?.clientCartVersion);
    const acceptedCartVersion = Number.isFinite(clientCartVersion) ? clientCartVersion : null;
    const items = Array.isArray(req.body?.items) ? req.body.items : [];
    const idempotencyKey = String(
        req.headers['x-idempotency-key'] ||
        req.body?.idempotencyKey ||
        ''
    ).trim();

    if (!Array.isArray(req.body?.items)) {
        return res.status(400).json({
            success: false,
            message: 'Cart items array is required',
        });
    }

    const idemCacheKey = idempotencyKey
        ? `grabgo:cart:sync:idem:${req.user.id}:${fulfillmentMode}:${idempotencyKey}`
        : null;

    try {
        if (idemCacheKey) {
            const cachedResponse = await cache.get(idemCacheKey);
            if (cachedResponse) {
                return res.json(cachedResponse);
            }
        }

        const lock = await cache.acquireLock(`cart-sync:${req.user.id}:${fulfillmentMode}`, 15);
        if (!lock) {
            return res.status(409).json({
                success: false,
                message: 'Cart sync already in progress',
                code: 'CART_SYNC_IN_PROGRESS',
            });
        }

        try {
            if (idemCacheKey) {
                const cachedResponse = await cache.get(idemCacheKey);
                if (cachedResponse) {
                    return res.json(cachedResponse);
                }
            }

            const carts = await syncCartState(req.user.id, {
                items,
                fulfillmentMode,
            });
            const groupedPricing = await calculateCartGroupsPricing(carts, {
                userId: req.user.id,
                deliveryLocation,
                useCredits,
                fulfillmentMode,
                promoCode,
            });

            const payload = {
                success: true,
                acceptedCartVersion,
                groups: groupedPricing.groups,
                summary: groupedPricing.summary,
            };

            if (idemCacheKey) {
                await cache.set(idemCacheKey, payload, CART_SYNC_IDEMPOTENCY_TTL_SECONDS);
            }

            return res.json(payload);
        } finally {
            await cache.releaseLock(lock);
        }
    } catch (error) {
        console.error('Error syncing cart snapshot:', error);
        const errorMessage = getErrorMessage(error);

        if (isCartBusinessError(errorMessage)) {
            try {
                const carts = await getUserCartGroups(req.user.id, fulfillmentMode);
                const groupedPricing = await calculateCartGroupsPricing(carts, {
                    userId: req.user.id,
                    deliveryLocation,
                    useCredits,
                    fulfillmentMode,
                    promoCode,
                });

                return res.status(409).json({
                    success: false,
                    message: errorMessage,
                    code: 'CART_SYNC_REJECTED',
                    acceptedCartVersion,
                    groups: groupedPricing.groups,
                    summary: groupedPricing.summary,
                });
            } catch (snapshotError) {
                console.error('Error fetching authoritative cart after sync rejection:', snapshotError);
            }

            return res.status(409).json({
                success: false,
                message: errorMessage,
                code: 'CART_SYNC_REJECTED',
                acceptedCartVersion,
            });
        }

        return res.status(500).json({
            success: false,
            message: 'Failed to sync cart',
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
        const promoCode = featureFlags.isPromoCheckoutEnabled
            ? normalizePromoCode(req.query.promoCode ?? req.body.promoCode)
            : null;

        if (quantity === undefined || quantity < 0) {
            return res.status(400).json({
                success: false,
                message: 'Valid quantity is required'
            });
        }

        const cart = await updateCartItem(req.user.id, itemId, quantity, fulfillmentMode);
        const pricing = await calculateCartPricing(cart, { userId: req.user.id, deliveryLocation, useCredits, promoCode });

        res.json({
            success: true,
            message: quantity === 0 ? 'Item removed from cart' : 'Cart updated',
            cart: { ...cart, pricing }
        });
    } catch (error) {
        console.error('Error updating cart:', error);
        const errorMessage = getErrorMessage(error);

        // Fix #8: Distinguish error types
        if (errorMessage.includes('not found') || errorMessage.includes('Invalid')) {
            return res.status(400).json({
                success: false,
                message: errorMessage
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
        const promoCode = featureFlags.isPromoCheckoutEnabled
            ? normalizePromoCode(req.query.promoCode ?? req.body?.promoCode)
            : null;
        const cart = await removeFromCart(req.user.id, itemId, fulfillmentMode);
        const pricing = await calculateCartPricing(cart, { userId: req.user.id, deliveryLocation, useCredits, promoCode });

        res.json({
            success: true,
            message: 'Item removed from cart',
            cart: { ...cart, pricing }
        });
    } catch (error) {
        console.error('Error removing from cart:', error);
        const errorMessage = getErrorMessage(error);

        // Fix #8: Distinguish error types
        if (errorMessage.includes('not found')) {
            return res.status(400).json({
                success: false,
                message: errorMessage
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
        const promoCode = featureFlags.isPromoCheckoutEnabled
            ? normalizePromoCode(req.query.promoCode ?? req.body?.promoCode)
            : null;
        const cart = await clearCart(req.user.id, fulfillmentMode);
        const pricing = await calculateCartPricing(cart, { userId: req.user.id, deliveryLocation, useCredits, promoCode });

        res.json({
            success: true,
            message: 'Cart cleared',
            cart: { ...cart, pricing }
        });
    } catch (error) {
        console.error('Error clearing cart:', error);
        const errorMessage = getErrorMessage(error);

        // Fix #8: Distinguish error types
        if (errorMessage.includes('not found')) {
            return res.status(400).json({
                success: false,
                message: errorMessage
            });
        }

        res.status(500).json({
            success: false,
            message: 'Failed to clear cart'
        });
    }
});

module.exports = router;
