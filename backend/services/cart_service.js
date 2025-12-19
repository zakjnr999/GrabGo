const Cart = require('../models/Cart');
const Food = require('../models/Food');
const GroceryItem = require('../models/GroceryItem');

/**
 * Get or create cart for user
 * @param {string} userId - User ID
 * @param {string} cartType - 'food' or 'grocery'
 * @returns {Promise<Object>} Cart object
 */
const getOrCreateCart = async (userId, cartType = 'food') => {
    let cart = await Cart.findOne({
        user: userId,
        isActive: true,
        cartType
    }).populate('items.itemId');

    if (!cart) {
        cart = await Cart.create({
            user: userId,
            cartType,
            items: []
        });
    }

    return cart;
};

/**
 * Add item to cart
 * @param {string} userId - User ID
 * @param {Object} itemData - Item data
 * @returns {Promise<Object>} Updated cart
 */
const addToCart = async (userId, itemData) => {
    const { itemId, itemType, quantity = 1, restaurantId, groceryStoreId } = itemData;

    // Validate quantity (Fix #3)
    if (quantity < 1 || quantity > 100) {
        throw new Error('Quantity must be between 1 and 100');
    }

    // Validate item exists
    const ItemModel = itemType === 'Food' ? Food : GroceryItem;
    const item = await ItemModel.findById(itemId);

    if (!item) {
        throw new Error('Item not found');
    }

    // Check if item is available (Fix #4)
    if (item.isActive === false || item.isAvailable === false) {
        throw new Error('Item is currently unavailable');
    }

    // Validate price (Fix #7)
    const price = parseFloat(item.price);
    if (isNaN(price) || price < 0) {
        throw new Error('Invalid item price');
    }

    // Determine cart type
    const cartType = itemType === 'Food' ? 'food' : 'grocery';

    // Get or create cart
    let cart = await getOrCreateCart(userId, cartType);

    // Validate and check if switching restaurants/stores (Fix #5)
    if (cartType === 'food' && restaurantId) {
        const Restaurant = require('../models/Restaurant');
        const restaurant = await Restaurant.findById(restaurantId);
        if (!restaurant || restaurant.isActive === false) {
            throw new Error('Restaurant not found or inactive');
        }

        if (cart.restaurant && cart.restaurant.toString() !== restaurantId) {
            // Clear cart if switching restaurants
            cart.items = [];
        }
        cart.restaurant = restaurantId;
    } else if (cartType === 'grocery' && groceryStoreId) {
        const GroceryStore = require('../models/GroceryStore');
        const store = await GroceryStore.findById(groceryStoreId);
        if (!store || store.isActive === false) {
            throw new Error('Grocery store not found or inactive');
        }

        if (cart.groceryStore && cart.groceryStore.toString() !== groceryStoreId) {
            // Clear cart if switching stores
            cart.items = [];
        }
        cart.groceryStore = groceryStoreId;
    }

    // Check if item already in cart
    const existingItemIndex = cart.items.findIndex(
        cartItem => cartItem.itemId.toString() === itemId
    );

    if (existingItemIndex > -1) {
        // Update quantity with max limit check (Fix #3)
        const newQuantity = cart.items[existingItemIndex].quantity + quantity;
        if (newQuantity > 100) {
            throw new Error('Maximum quantity per item is 100');
        }
        cart.items[existingItemIndex].quantity = newQuantity;
    } else {
        // Add new item with validated price (Fix #7)
        cart.items.push({
            itemId,
            itemType,
            name: item.name,
            price: price, // Use validated price
            quantity,
            imageUrl: item.imageUrl || item.image || null
        });
    }

    // Reset abandonment tracking
    cart.abandonmentNotificationSent = false;
    cart.abandonmentNotificationSentAt = null;

    await cart.save();
    return cart;
};

/**
 * Update item quantity in cart
 * @param {string} userId - User ID
 * @param {string} itemId - Item ID
 * @param {number} quantity - New quantity
 * @returns {Promise<Object>} Updated cart
 */
const updateCartItem = async (userId, itemId, quantity) => {
    const cart = await Cart.findOne({ user: userId, isActive: true });

    if (!cart) {
        throw new Error('Cart not found');
    }

    const itemIndex = cart.items.findIndex(
        item => item.itemId.toString() === itemId
    );

    if (itemIndex === -1) {
        throw new Error('Item not found in cart');
    }

    if (quantity <= 0) {
        // Remove item
        cart.items.splice(itemIndex, 1);
    } else {
        // Update quantity
        cart.items[itemIndex].quantity = quantity;
    }

    // Reset abandonment tracking
    cart.abandonmentNotificationSent = false;
    cart.abandonmentNotificationSentAt = null;

    await cart.save();
    return cart;
};

/**
 * Remove item from cart
 * @param {string} userId - User ID
 * @param {string} itemId - Item ID
 * @returns {Promise<Object>} Updated cart
 */
const removeFromCart = async (userId, itemId) => {
    const cart = await Cart.findOne({ user: userId, isActive: true });

    if (!cart) {
        throw new Error('Cart not found');
    }

    cart.items = cart.items.filter(
        item => item.itemId.toString() !== itemId
    );

    await cart.save();
    return cart;
};

/**
 * Clear entire cart
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Empty cart
 */
const clearCart = async (userId) => {
    const cart = await Cart.findOne({ user: userId, isActive: true });

    if (!cart) {
        throw new Error('Cart not found');
    }

    cart.items = [];
    cart.restaurant = null;
    cart.groceryStore = null;
    cart.abandonmentNotificationSent = false;
    cart.abandonmentNotificationSentAt = null;

    await cart.save();
    return cart;
};

/**
 * Get user's active cart
 * @param {string} userId - User ID
 * @param {string} cartType - 'food' or 'grocery'
 * @returns {Promise<Object>} Cart object
 */
const getUserCart = async (userId, cartType = null) => {
    const query = { user: userId, isActive: true };
    if (cartType) {
        query.cartType = cartType;
    }

    const cart = await Cart.findOne(query)
        .populate({
            path: 'items.itemId',
            options: { strictPopulate: false } // Fix #1: Don't fail on missing refs
        })
        .populate('restaurant', 'name imageUrl')
        .populate('groceryStore', 'name imageUrl');

    // Fix #1: Filter out items with deleted itemId
    if (cart && cart.items) {
        const originalLength = cart.items.length;
        cart.items = cart.items.filter(item => item.itemId !== null);

        // If all items were removed, clear restaurant/store
        if (cart.items.length === 0 && originalLength > 0) {
            cart.restaurant = null;
            cart.groceryStore = null;
            await cart.save();
        } else if (cart.items.length < originalLength) {
            // Some items were removed, save the cart
            await cart.save();
        }
    }

    return cart;
};

/**
 * Mark cart as converted to order
 * @param {string} userId - User ID
 * @param {string} orderId - Order ID
 * @returns {Promise<Object>} Updated cart
 */
const markCartAsConverted = async (userId, orderId) => {
    const cart = await Cart.findOne({ user: userId, isActive: true });

    if (!cart) {
        throw new Error('Cart not found');
    }

    cart.convertedToOrder = true;
    cart.orderId = orderId;
    cart.isActive = false;

    await cart.save();
    return cart;
};

/**
 * Find abandoned carts (for notification service)
 * @returns {Promise<Array>} Array of abandoned carts
 */
const findAbandonedCarts = async () => {
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const carts = await Cart.find({
        isActive: true,
        convertedToOrder: false,
        lastUpdatedAt: { $lt: thirtyMinutesAgo },
        itemCount: { $gt: 0 },
        $or: [
            { abandonmentNotificationSent: false },
            {
                abandonmentNotificationSent: true,
                abandonmentNotificationSentAt: { $lt: oneDayAgo } // Max 1 per day
            }
        ]
    }).populate('user', 'username email fcmTokens notificationSettings');

    return carts;
};

module.exports = {
    getOrCreateCart,
    addToCart,
    updateCartItem,
    removeFromCart,
    clearCart,
    getUserCart,
    markCartAsConverted,
    findAbandonedCarts
};
