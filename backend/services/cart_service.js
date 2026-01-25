const prisma = require('../config/prisma');

/**
 * Get or create cart for user
 * @param {string} userId - User ID
 * @param {string} cartType - 'food', 'grocery', or 'pharmacy'
 * @returns {Promise<Object>} Cart object
 */
const getOrCreateCart = async (userId, cartType = 'food') => {
    let cart = await prisma.cart.findFirst({
        where: {
            userId,
            isActive: true,
            cartType
        },
        include: {
            items: {
                include: {
                    food: true,
                    groceryItem: true,
                    pharmacyItem: true
                }
            }
        }
    });

    if (!cart) {
        cart = await prisma.cart.create({
            data: {
                userId,
                cartType,
                items: {
                    create: []
                }
            },
            include: {
                items: true
            }
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
    const { itemId, itemType, quantity = 1, restaurantId, groceryStoreId, pharmacyStoreId } = itemData;

    // Validate quantity
    if (quantity < 1 || quantity > 100) {
        throw new Error('Quantity must be between 1 and 100');
    }

    // Validate item exists and get item details
    let item;
    let price;
    let itemName;
    let imageUrl;

    if (itemType === 'Food' || itemType === 'food') {
        item = await prisma.food.findUnique({ where: { id: itemId } });
        if (!item) throw new Error('Item not found');
        if (!item.isAvailable) throw new Error('Item is currently unavailable');
        price = item.price;
        itemName = item.name;
        imageUrl = item.foodImage;
    } else if (itemType === 'GroceryItem' || itemType === 'grocery') {
        item = await prisma.groceryItem.findUnique({ where: { id: itemId } });
        if (!item) throw new Error('Item not found');
        if (!item.isAvailable) throw new Error('Item is currently unavailable');
        price = item.price;
        itemName = item.name;
        imageUrl = item.image;
    } else if (itemType === 'PharmacyItem' || itemType === 'pharmacy') {
        item = await prisma.pharmacyItem.findUnique({ where: { id: itemId } });
        if (!item) throw new Error('Item not found');
        if (!item.isAvailable) throw new Error('Item is currently unavailable');
        price = item.price;
        itemName = item.name;
        imageUrl = item.image;
    } else {
        throw new Error('Invalid item type');
    }

    // Validate price
    if (isNaN(price) || price < 0) {
        throw new Error('Invalid item price');
    }

    // Determine cart type
    let cartType = 'food';
    if (itemType === 'GroceryItem' || itemType === 'grocery') cartType = 'grocery';
    if (itemType === 'PharmacyItem' || itemType === 'pharmacy') cartType = 'pharmacy';

    // Get or create cart
    let cart = await getOrCreateCart(userId, cartType);

    // Validate and check if switching restaurants/stores
    if (cartType === 'food' && restaurantId) {
        const restaurant = await prisma.restaurant.findUnique({
            where: { id: restaurantId }
        });
        if (!restaurant || restaurant.status !== 'approved') {
            throw new Error('Restaurant not found or inactive');
        }

        if (cart.restaurantId && cart.restaurantId !== restaurantId) {
            // Clear cart if switching restaurants
            await prisma.cartItem.deleteMany({
                where: { cartId: cart.id }
            });
        }

        await prisma.cart.update({
            where: { id: cart.id },
            data: { restaurantId }
        });
    } else if (cartType === 'grocery' && groceryStoreId) {
        const store = await prisma.groceryStore.findUnique({
            where: { id: groceryStoreId }
        });
        if (!store || store.status !== 'approved') {
            throw new Error('Grocery store not found or inactive');
        }

        if (cart.groceryStoreId && cart.groceryStoreId !== groceryStoreId) {
            // Clear cart if switching stores
            await prisma.cartItem.deleteMany({
                where: { cartId: cart.id }
            });
        }

        await prisma.cart.update({
            where: { id: cart.id },
            data: { groceryStoreId }
        });
    } else if (cartType === 'pharmacy' && pharmacyStoreId) {
        const store = await prisma.pharmacyStore.findUnique({
            where: { id: pharmacyStoreId }
        });
        if (!store || store.status !== 'approved') {
            throw new Error('Pharmacy store not found or inactive');
        }

        if (cart.pharmacyStoreId && cart.pharmacyStoreId !== pharmacyStoreId) {
            // Clear cart if switching stores
            await prisma.cartItem.deleteMany({
                where: { cartId: cart.id }
            });
        }

        await prisma.cart.update({
            where: { id: cart.id },
            data: { pharmacyStoreId }
        });
    }

    // Reload cart with items
    cart = await prisma.cart.findUnique({
        where: { id: cart.id },
        include: { items: true }
    });

    // Check if item already in cart
    const existingItem = cart.items.find(cartItem => {
        if (itemType === 'Food' || itemType === 'food') return cartItem.foodId === itemId;
        if (itemType === 'GroceryItem' || itemType === 'grocery') return cartItem.groceryItemId === itemId;
        if (itemType === 'PharmacyItem' || itemType === 'pharmacy') return cartItem.pharmacyItemId === itemId;
        return false;
    });

    if (existingItem) {
        // Update quantity with max limit check
        const newQuantity = existingItem.quantity + quantity;
        if (newQuantity > 100) {
            throw new Error('Maximum quantity per item is 100');
        }

        await prisma.cartItem.update({
            where: { id: existingItem.id },
            data: { quantity: newQuantity }
        });
    } else {
        // Add new item
        const itemTypeEnum = itemType === 'Food' || itemType === 'food' ? 'Food' :
            itemType === 'GroceryItem' || itemType === 'grocery' ? 'GroceryItem' : 'PharmacyItem';

        const createData = {
            cartId: cart.id,
            itemType: itemTypeEnum,
            name: itemName,
            price,
            quantity,
            imageUrl
        };

        if (itemTypeEnum === 'Food') createData.foodId = itemId;
        else if (itemTypeEnum === 'GroceryItem') createData.groceryItemId = itemId;
        else if (itemTypeEnum === 'PharmacyItem') createData.pharmacyItemId = itemId;

        await prisma.cartItem.create({ data: createData });
    }

    // Reset abandonment tracking
    await prisma.cart.update({
        where: { id: cart.id },
        data: {
            abandonmentNotificationSent: false,
            abandonmentNotificationSentAt: null,
            lastUpdatedAt: new Date()
        }
    });

    // Return updated cart
    return prisma.cart.findUnique({
        where: { id: cart.id },
        include: {
            items: {
                include: {
                    food: true,
                    groceryItem: true,
                    pharmacyItem: true
                }
            }
        }
    });
};

/**
 * Update item quantity in cart
 * @param {string} userId - User ID
 * @param {string} itemId - Cart Item ID
 * @param {number} quantity - New quantity
 * @returns {Promise<Object>} Updated cart
 */
const updateCartItem = async (userId, itemId, quantity) => {
    const cart = await prisma.cart.findFirst({
        where: { userId, isActive: true },
        include: { items: true }
    });

    if (!cart) {
        throw new Error('Cart not found');
    }

    const item = cart.items.find(i => i.id === itemId);

    if (!item) {
        throw new Error('Item not found in cart');
    }

    if (quantity <= 0) {
        // Remove item
        await prisma.cartItem.delete({
            where: { id: itemId }
        });
    } else {
        // Update quantity
        await prisma.cartItem.update({
            where: { id: itemId },
            data: { quantity }
        });
    }

    // Reset abandonment tracking
    await prisma.cart.update({
        where: { id: cart.id },
        data: {
            abandonmentNotificationSent: false,
            abandonmentNotificationSentAt: null,
            lastUpdatedAt: new Date()
        }
    });

    return prisma.cart.findUnique({
        where: { id: cart.id },
        include: {
            items: {
                include: {
                    food: true,
                    groceryItem: true,
                    pharmacyItem: true
                }
            }
        }
    });
};

/**
 * Remove item from cart
 * @param {string} userId - User ID
 * @param {string} itemId - Cart Item ID
 * @returns {Promise<Object>} Updated cart
 */
const removeFromCart = async (userId, itemId) => {
    console.log(`🗑️ Backend: Removing item ${itemId} from cart for user ${userId}`);

    // Find ALL active carts
    const carts = await prisma.cart.findMany({
        where: { userId, isActive: true },
        include: { items: true }
    });

    if (!carts || carts.length === 0) {
        console.log('❌ No active carts found');
        throw new Error('Cart not found');
    }

    // Find which cart contains the item
    let cart = null;
    for (const c of carts) {
        const hasItem = c.items.some(item => item.id === itemId);
        if (hasItem) {
            cart = c;
            break;
        }
    }

    if (!cart) {
        console.log('⚠️ Item not found in any cart');
        throw new Error('Item not found in cart');
    }

    console.log(`📋 Cart details BEFORE removal:`, {
        cartId: cart.id,
        cartType: cart.cartType,
        itemCount: cart.items.length
    });

    const initialLength = cart.items.length;

    // Delete the cart item
    await prisma.cartItem.delete({
        where: { id: itemId }
    });

    console.log(`📊 Items before: ${initialLength}, Items after: ${initialLength - 1}, Removed: 1`);

    // Reset abandonment tracking
    await prisma.cart.update({
        where: { id: cart.id },
        data: {
            abandonmentNotificationSent: false,
            abandonmentNotificationSentAt: null,
            lastUpdatedAt: new Date()
        }
    });

    console.log('✅ Cart saved successfully');

    return prisma.cart.findUnique({
        where: { id: cart.id },
        include: {
            items: {
                include: {
                    food: true,
                    groceryItem: true,
                    pharmacyItem: true
                }
            }
        }
    });
};

/**
 * Clear entire cart
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Empty cart
 */
const clearCart = async (userId) => {
    const cart = await prisma.cart.findFirst({
        where: { userId, isActive: true }
    });

    if (!cart) {
        throw new Error('Cart not found');
    }

    // Delete all cart items
    await prisma.cartItem.deleteMany({
        where: { cartId: cart.id }
    });

    // Update cart
    await prisma.cart.update({
        where: { id: cart.id },
        data: {
            restaurantId: null,
            groceryStoreId: null,
            pharmacyStoreId: null,
            abandonmentNotificationSent: false,
            abandonmentNotificationSentAt: null,
            lastUpdatedAt: new Date()
        }
    });

    return prisma.cart.findUnique({
        where: { id: cart.id },
        include: { items: true }
    });
};

/**
 * Get user's active cart
 * @param {string} userId - User ID
 * @param {string} cartType - 'food', 'grocery', or 'pharmacy'
 * @returns {Promise<Object>} Cart object
 */
const getUserCart = async (userId, cartType = null) => {
    const where = { userId, isActive: true };
    if (cartType) {
        where.cartType = cartType;
    }

    const cart = await prisma.cart.findFirst({
        where,
        include: {
            items: {
                include: {
                    food: {
                        include: {
                            restaurant: {
                                select: {
                                    id: true,
                                    restaurantName: true,
                                    logo: true
                                }
                            }
                        }
                    },
                    groceryItem: {
                        include: {
                            store: {
                                select: {
                                    id: true,
                                    storeName: true,
                                    logo: true
                                }
                            }
                        }
                    },
                    pharmacyItem: {
                        include: {
                            store: {
                                select: {
                                    id: true,
                                    storeName: true,
                                    logo: true
                                }
                            }
                        }
                    }
                }
            }
        }
    });

    // Filter out items with deleted references
    if (cart && cart.items) {
        const originalLength = cart.items.length;
        const validItems = cart.items.filter(item => {
            if (item.itemType === 'Food') return item.food !== null;
            if (item.itemType === 'GroceryItem') return item.groceryItem !== null;
            if (item.itemType === 'PharmacyItem') return item.pharmacyItem !== null;
            return false;
        });

        // If items were removed, update the cart
        if (validItems.length < originalLength) {
            const itemsToDelete = cart.items.filter(item => !validItems.includes(item));
            await prisma.cartItem.deleteMany({
                where: {
                    id: { in: itemsToDelete.map(i => i.id) }
                }
            });

            // If all items were removed, clear restaurant/store
            if (validItems.length === 0) {
                await prisma.cart.update({
                    where: { id: cart.id },
                    data: {
                        restaurantId: null,
                        groceryStoreId: null,
                        pharmacyStoreId: null
                    }
                });
            }

            cart.items = validItems;
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
    const cart = await prisma.cart.findFirst({
        where: { userId, isActive: true }
    });

    if (!cart) {
        throw new Error('Cart not found');
    }

    return prisma.cart.update({
        where: { id: cart.id },
        data: {
            convertedToOrder: true,
            orderId,
            isActive: false
        }
    });
};

/**
 * Find abandoned carts (for notification service)
 * @returns {Promise<Array>} Array of abandoned carts
 */
const findAbandonedCarts = async () => {
    const thirtyMinutesAgo = new Date(Date.now() - 30 * 60 * 1000);
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    console.log('🔍 Query criteria:');
    console.log(`   30 min ago: ${thirtyMinutesAgo}`);
    console.log(`   1 day ago: ${oneDayAgo}`);

    const carts = await prisma.cart.findMany({
        where: {
            isActive: true,
            convertedToOrder: false,
            lastUpdatedAt: { lt: thirtyMinutesAgo },
            itemCount: { gt: 0 },
            OR: [
                { abandonmentNotificationSent: false },
                {
                    AND: [
                        { abandonmentNotificationSent: true },
                        { abandonmentNotificationSentAt: { lt: oneDayAgo } }
                    ]
                }
            ]
        },
        include: {
            user: {
                select: {
                    id: true,
                    username: true,
                    email: true,
                    fcmTokens: true,
                    notificationSettings: true
                }
            }
        }
    });

    console.log(`🔍 Found ${carts.length} cart(s) matching criteria`);

    return carts;
};

/**
 * Mark cart as having had an abandonment notification sent
 * @param {string} cartId - Cart ID
 * @returns {Promise<Object>} Updated cart
 */
const markAbandonmentNotificationSent = async (cartId) => {
    return await prisma.cart.update({
        where: { id: cartId },
        data: {
            abandonmentNotificationSent: true,
            abandonmentNotificationSentAt: new Date()
        }
    });
};

module.exports = {
    getOrCreateCart,
    addToCart,
    updateCartItem,
    removeFromCart,
    clearCart,
    getUserCart,
    markCartAsConverted,
    findAbandonedCarts,
    markAbandonmentNotificationSent
};
