const prisma = require('../config/prisma');
const featureFlags = require('../config/feature_flags');
const { isRestaurantOpen } = require('../utils/restaurant');
const { isVendorAcceptingScheduledOrders } = require('../utils/scheduled_orders');

/**
 * Get or create cart for user
 * @param {string} userId - User ID
 * @param {string} cartType - 'food', 'grocery', 'pharmacy', or 'grabmart'
 * @returns {Promise<Object>} Cart object
 */
const normalizeItemType = (itemType) => {
    if (!itemType) return null;
    const normalized = String(itemType).toLowerCase();
    if (normalized === 'food') return 'Food';
    if (normalized === 'groceryitem' || normalized === 'grocery') return 'GroceryItem';
    if (normalized === 'pharmacyitem' || normalized === 'pharmacy') return 'PharmacyItem';
    if (normalized === 'grabmartitem' || normalized === 'grabmart' || normalized === 'convenience') return 'GrabMartItem';
    return null;
};

const cartTypeFromItemType = (itemTypeEnum) => {
    if (itemTypeEnum === 'Food') return 'food';
    if (itemTypeEnum === 'GroceryItem') return 'grocery';
    if (itemTypeEnum === 'PharmacyItem') return 'pharmacy';
    if (itemTypeEnum === 'GrabMartItem') return 'grabmart';
    return 'food';
};

const buildProviderScopeKey = (cartType, vendorId) => {
    if (!cartType || !vendorId) return null;
    return `${cartType}:${vendorId}`;
};

const normalizeFulfillmentMode = (mode) => {
    if (!mode) return 'delivery';
    const normalized = String(mode).trim().toLowerCase();
    return normalized === 'pickup' ? 'pickup' : 'delivery';
};

const getVendorAvailabilityError = (vendor, label) => {
    if (!vendor || vendor.status !== 'approved' || vendor.isDeleted === true) {
        return `${label} not found or inactive`;
    }
    if (vendor.isAcceptingOrders === false) {
        return `${label} is not accepting orders`;
    }
    return null;
};

const parsePositiveIntEnv = (name, fallback, { min = 0, max = Number.MAX_SAFE_INTEGER } = {}) => {
    const raw = process.env[name];
    const parsed = Number.parseInt(String(raw), 10);
    if (!Number.isFinite(parsed) || parsed < min || parsed > max) return fallback;
    return parsed;
};

const SCHEDULED_ORDER_MIN_LEAD_MINUTES = parsePositiveIntEnv('SCHEDULED_ORDER_MIN_LEAD_MINUTES', 45, {
    min: 1,
    max: 24 * 60,
});
const SCHEDULED_ORDER_SLOT_MINUTES = parsePositiveIntEnv('SCHEDULED_ORDER_SLOT_MINUTES', 30, {
    min: 5,
    max: 4 * 60,
});
const SCHEDULED_ORDER_MAX_HORIZON_DAYS = parsePositiveIntEnv('SCHEDULED_ORDER_MAX_HORIZON_DAYS', 7, {
    min: 1,
    max: 30,
});

const sanitizeOpeningHours = (openingHours) => {
    if (!Array.isArray(openingHours)) return [];
    return openingHours
        .map((entry) => ({
            dayOfWeek: Number(entry?.dayOfWeek),
            openTime: typeof entry?.openTime === 'string' ? entry.openTime : null,
            closeTime: typeof entry?.closeTime === 'string' ? entry.closeTime : null,
            isClosed: entry?.isClosed === true,
        }))
        .filter((entry) => Number.isInteger(entry.dayOfWeek) && entry.dayOfWeek >= 0 && entry.dayOfWeek <= 6);
};

const buildScheduleAvailability = (cart) => {
    if (!cart || !Array.isArray(cart.items) || cart.items.length === 0) return null;

    const defaults = {
        minLeadMinutes: SCHEDULED_ORDER_MIN_LEAD_MINUTES,
        slotMinutes: SCHEDULED_ORDER_SLOT_MINUTES,
        maxHorizonDays: SCHEDULED_ORDER_MAX_HORIZON_DAYS,
    };

    if (cart.cartType === 'food') {
        const restaurant = cart.items.find((item) => item.food?.restaurant)?.food?.restaurant;
        if (!restaurant) return null;
        return {
            ...defaults,
            vendorType: 'food',
            vendorId: restaurant.id,
            vendorName: restaurant.restaurantName || null,
            isOpen: restaurant.isOpen !== false,
            isAcceptingOrders: restaurant.isAcceptingOrders !== false,
            isAcceptingScheduledOrders: isVendorAcceptingScheduledOrders(restaurant),
            is24Hours: false,
            openingHours: sanitizeOpeningHours(restaurant.openingHours),
        };
    }

    if (cart.cartType === 'grocery') {
        const store = cart.items.find((item) => item.groceryItem?.store)?.groceryItem?.store;
        if (!store) return null;
        return {
            ...defaults,
            vendorType: 'grocery',
            vendorId: store.id,
            vendorName: store.storeName || null,
            isOpen: store.isOpen !== false,
            isAcceptingOrders: store.isAcceptingOrders !== false,
            isAcceptingScheduledOrders: isVendorAcceptingScheduledOrders(store),
            is24Hours: false,
            openingHours: sanitizeOpeningHours(store.openingHours),
        };
    }

    if (cart.cartType === 'pharmacy') {
        const store = cart.items.find((item) => item.pharmacyItem?.store)?.pharmacyItem?.store;
        if (!store) return null;
        return {
            ...defaults,
            vendorType: 'pharmacy',
            vendorId: store.id,
            vendorName: store.storeName || null,
            isOpen: store.isOpen !== false,
            isAcceptingOrders: store.isAcceptingOrders !== false,
            isAcceptingScheduledOrders: isVendorAcceptingScheduledOrders(store),
            is24Hours: false,
            openingHours: sanitizeOpeningHours(store.openingHours),
        };
    }

    if (cart.cartType === 'grabmart') {
        const store = cart.items.find((item) => item.grabMartItem?.store)?.grabMartItem?.store;
        if (!store) return null;
        return {
            ...defaults,
            vendorType: 'grabmart',
            vendorId: store.id,
            vendorName: store.storeName || null,
            isOpen: store.isOpen !== false,
            isAcceptingOrders: store.isAcceptingOrders !== false,
            isAcceptingScheduledOrders: isVendorAcceptingScheduledOrders(store),
            is24Hours: store.is24Hours === true,
            openingHours: [],
        };
    }

    return null;
};

const mutationCartInclude = {
    items: {
        include: {
            food: true,
            groceryItem: true,
            pharmacyItem: true,
            grabMartItem: true
        }
    }
};

const readInclude = {
    items: {
        include: {
            food: {
                include: {
                    restaurant: {
                        select: {
                            id: true,
                            restaurantName: true,
                            logo: true,
                            isOpen: true,
                            status: true,
                            isAcceptingOrders: true,
                            isDeleted: true,
                            features: true,
                            openingHours: {
                                select: {
                                    dayOfWeek: true,
                                    openTime: true,
                                    closeTime: true,
                                    isClosed: true
                                }
                            }
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
                            logo: true,
                            isOpen: true,
                            status: true,
                            isAcceptingOrders: true,
                            isDeleted: true,
                            features: true,
                            openingHours: {
                                select: {
                                    dayOfWeek: true,
                                    openTime: true,
                                    closeTime: true,
                                    isClosed: true
                                }
                            }
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
                            logo: true,
                            isOpen: true,
                            status: true,
                            isAcceptingOrders: true,
                            isDeleted: true,
                            features: true,
                            openingHours: {
                                select: {
                                    dayOfWeek: true,
                                    openTime: true,
                                    closeTime: true,
                                    isClosed: true
                                }
                            }
                        }
                    }
                }
            },
            grabMartItem: {
                include: {
                    store: {
                        select: {
                            id: true,
                            storeName: true,
                            logo: true,
                            isOpen: true,
                            status: true,
                            isAcceptingOrders: true,
                            isDeleted: true,
                            features: true,
                            is24Hours: true
                        }
                    }
                }
            }
        }
    }
};

const sanitizeCartAfterRead = async (cart) => {
    if (!cart) return null;

    if (Array.isArray(cart.items)) {
        for (const item of cart.items) {
            if (item.itemType !== 'Food' || !item.food || !item.food.restaurant) continue;
            const computedIsOpen = isRestaurantOpen(item.food.restaurant);
            item.food.isRestaurantOpen = computedIsOpen;
            item.food.restaurant.isRestaurantOpen = computedIsOpen;
            item.food.restaurant.isOpen = computedIsOpen;
        }
    }

    if (Array.isArray(cart.items)) {
        const originalLength = cart.items.length;
        const validItems = cart.items.filter((item) => {
            if (item.itemType === 'Food') return item.food !== null;
            if (item.itemType === 'GroceryItem') return item.groceryItem !== null;
            if (item.itemType === 'PharmacyItem') return item.pharmacyItem !== null;
            if (item.itemType === 'GrabMartItem') return item.grabMartItem !== null;
            return false;
        });

        if (validItems.length < originalLength) {
            const itemsToDelete = cart.items.filter((item) => !validItems.includes(item));
            await prisma.cartItem.deleteMany({
                where: {
                    id: { in: itemsToDelete.map((entry) => entry.id) }
                }
            });

            if (validItems.length === 0) {
                await prisma.cart.update({
                    where: { id: cart.id },
                    data: {
                        restaurantId: null,
                        groceryStoreId: null,
                        pharmacyStoreId: null,
                        grabMartStoreId: null,
                        providerScopeKey: null
                    }
                });
            }

            cart.items = validItems;
        }
    }

    cart.scheduleAvailability = buildScheduleAvailability(cart);
    return cart;
};

const refreshCartAggregates = async (cartId) => {
    const items = await prisma.cartItem.findMany({
        where: { cartId },
        select: {
            quantity: true,
            price: true
        }
    });

    const itemCount = items.reduce((sum, item) => sum + (item.quantity || 0), 0);
    const totalAmount = items.reduce((sum, item) => sum + ((item.price || 0) * (item.quantity || 0)), 0);

    const updateData = {
        itemCount,
        totalAmount,
        abandonmentNotificationSent: false,
        abandonmentNotificationSentAt: null,
        lastUpdatedAt: new Date()
    };

    if (itemCount === 0) {
        updateData.restaurantId = null;
        updateData.groceryStoreId = null;
        updateData.pharmacyStoreId = null;
        updateData.grabMartStoreId = null;
        updateData.providerScopeKey = null;
    }

    await prisma.cart.update({
        where: { id: cartId },
        data: updateData
    });
};

const getOrCreateCart = async (
    userId,
    cartType = 'food',
    fulfillmentMode = 'delivery',
    providerScopeKey = null,
    vendorField = null,
    vendorId = null
) => {
    const normalizedMode = normalizeFulfillmentMode(fulfillmentMode);
    const resolvedScopeKey = featureFlags.isMixedCartEnabled ? providerScopeKey : null;
    const where = {
        userId,
        isActive: true,
        cartType,
        fulfillmentMode: normalizedMode,
        ...(resolvedScopeKey ? { providerScopeKey: resolvedScopeKey } : {})
    };
    let cart = await prisma.cart.findFirst({
        where,
        include: {
            items: {
                include: {
                    food: true,
                    groceryItem: true,
                    pharmacyItem: true,
                    grabMartItem: true
                }
            }
        }
    });

    if (!cart && featureFlags.isMixedCartEnabled && resolvedScopeKey && vendorField && vendorId) {
        // Migration-safe fallback: reuse legacy vendor cart row that predates providerScopeKey.
        const legacyWhere = {
            userId,
            isActive: true,
            cartType,
            fulfillmentMode: normalizedMode,
            providerScopeKey: null,
            [vendorField]: vendorId
        };

        const legacyCart = await prisma.cart.findFirst({
            where: legacyWhere,
            include: {
                items: {
                    include: {
                        food: true,
                        groceryItem: true,
                        pharmacyItem: true,
                        grabMartItem: true
                    }
                }
            }
        });

        if (legacyCart) {
            cart = await prisma.cart.update({
                where: { id: legacyCart.id },
                data: { providerScopeKey: resolvedScopeKey },
                include: {
                    items: {
                        include: {
                            food: true,
                            groceryItem: true,
                            pharmacyItem: true,
                            grabMartItem: true
                        }
                    }
                }
            });
        }
    }

    if (!cart) {
        cart = await prisma.cart.create({
            data: {
                userId,
                cartType,
                fulfillmentMode: normalizedMode,
                providerScopeKey: resolvedScopeKey,
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
    const {
        itemId,
        itemType,
        quantity = 1,
        restaurantId,
        groceryStoreId,
        pharmacyStoreId,
        grabMartStoreId,
        fulfillmentMode = 'delivery'
    } = itemData;

    // Validate quantity
    if (quantity < 1 || quantity > 100) {
        throw new Error('Quantity must be between 1 and 100');
    }

    const itemTypeEnum = normalizeItemType(itemType);
    if (!itemTypeEnum) {
        throw new Error('Invalid item type');
    }

    // Validate item exists and get item details
    let item;
    let price;
    let itemName;
    let imageUrl;

    if (itemTypeEnum === 'Food') {
        item = await prisma.food.findUnique({ where: { id: itemId } });
        if (!item) throw new Error('Item not found');
        if (!item.isAvailable) throw new Error('Item is currently unavailable');
        price = item.price;
        itemName = item.name;
        imageUrl = item.foodImage;
    } else if (itemTypeEnum === 'GroceryItem') {
        item = await prisma.groceryItem.findUnique({ where: { id: itemId } });
        if (!item) throw new Error('Item not found');
        if (!item.isAvailable) throw new Error('Item is currently unavailable');
        price = item.price;
        itemName = item.name;
        imageUrl = item.image;
    } else if (itemTypeEnum === 'PharmacyItem') {
        item = await prisma.pharmacyItem.findUnique({ where: { id: itemId } });
        if (!item) throw new Error('Item not found');
        if (!item.isAvailable) throw new Error('Item is currently unavailable');
        price = item.price;
        itemName = item.name;
        imageUrl = item.image;
    } else if (itemTypeEnum === 'GrabMartItem') {
        item = await prisma.grabMartItem.findUnique({ where: { id: itemId } });
        if (!item) throw new Error('Item not found');
        if (!item.isAvailable) throw new Error('Item is currently unavailable');
        price = item.price;
        itemName = item.name;
        imageUrl = item.image;
    }

    // Validate price
    if (isNaN(price) || price < 0) {
        throw new Error('Invalid item price');
    }

    // Determine cart type
    const cartType = cartTypeFromItemType(itemTypeEnum);
    const normalizedMode = normalizeFulfillmentMode(fulfillmentMode);
    let resolvedVendorId = null;
    let vendorLabel = 'Vendor';
    let vendorField = null;
    let vendorDoc = null;

    if (cartType === 'food') {
        resolvedVendorId = restaurantId || item?.restaurantId;
        vendorLabel = 'Restaurant';
        vendorField = 'restaurantId';
        if (!resolvedVendorId) throw new Error('Restaurant not found or inactive');
        vendorDoc = await prisma.restaurant.findUnique({ where: { id: resolvedVendorId } });
    } else if (cartType === 'grocery') {
        resolvedVendorId = groceryStoreId || item?.storeId;
        vendorLabel = 'Grocery store';
        vendorField = 'groceryStoreId';
        if (!resolvedVendorId) throw new Error('Grocery store not found or inactive');
        vendorDoc = await prisma.groceryStore.findUnique({ where: { id: resolvedVendorId } });
    } else if (cartType === 'pharmacy') {
        resolvedVendorId = pharmacyStoreId || item?.storeId;
        vendorLabel = 'Pharmacy store';
        vendorField = 'pharmacyStoreId';
        if (!resolvedVendorId) throw new Error('Pharmacy store not found or inactive');
        vendorDoc = await prisma.pharmacyStore.findUnique({ where: { id: resolvedVendorId } });
    } else if (cartType === 'grabmart') {
        resolvedVendorId = grabMartStoreId || item?.storeId;
        vendorLabel = 'GrabMart store';
        vendorField = 'grabMartStoreId';
        if (!resolvedVendorId) throw new Error('GrabMart store not found or inactive');
        vendorDoc = await prisma.grabMartStore.findUnique({ where: { id: resolvedVendorId } });
    }

    const availabilityError = getVendorAvailabilityError(vendorDoc, vendorLabel);
    if (availabilityError) throw new Error(availabilityError);

    const providerScopeKey = buildProviderScopeKey(cartType, resolvedVendorId);

    // Get or create vendor-scoped cart when mixed cart is enabled.
    let cart = await getOrCreateCart(
        userId,
        cartType,
        normalizedMode,
        providerScopeKey,
        vendorField,
        resolvedVendorId
    );

    if (!featureFlags.isMixedCartEnabled && vendorField && cart[vendorField] && cart[vendorField] !== resolvedVendorId) {
        // Legacy behavior: clear cart when switching vendors.
        await prisma.cartItem.deleteMany({
            where: { cartId: cart.id }
        });
    }

    await prisma.cart.update({
        where: { id: cart.id },
        data: {
            [vendorField]: resolvedVendorId,
            providerScopeKey
        }
    });

    // Reload cart with items
    cart = await prisma.cart.findUnique({
        where: { id: cart.id },
        include: { items: true }
    });

    // Check if item already in cart
    const existingItem = cart.items.find(cartItem => {
        if (itemTypeEnum === 'Food') return cartItem.foodId === itemId;
        if (itemTypeEnum === 'GroceryItem') return cartItem.groceryItemId === itemId;
        if (itemTypeEnum === 'PharmacyItem') return cartItem.pharmacyItemId === itemId;
        if (itemTypeEnum === 'GrabMartItem') return cartItem.grabMartItemId === itemId;
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
        else if (itemTypeEnum === 'GrabMartItem') createData.grabMartItemId = itemId;

        await prisma.cartItem.create({ data: createData });
    }

    await refreshCartAggregates(cart.id);

    // Return updated cart
    return prisma.cart.findUnique({
        where: { id: cart.id },
        include: mutationCartInclude
    });
};

/**
 * Update item quantity in cart
 * @param {string} userId - User ID
 * @param {string} itemId - Cart Item ID
 * @param {number} quantity - New quantity
 * @returns {Promise<Object>} Updated cart
 */
const updateCartItem = async (userId, itemId, quantity, fulfillmentMode = 'delivery') => {
    const normalizedMode = normalizeFulfillmentMode(fulfillmentMode);
    const cartItem = await prisma.cartItem.findFirst({
        where: {
            id: itemId,
            cart: {
                userId,
                isActive: true,
                fulfillmentMode: normalizedMode
            }
        },
        select: {
            id: true,
            cartId: true
        }
    });

    if (!cartItem) {
        throw new Error('Item not found in cart');
    }

    if (quantity <= 0) {
        // Remove item
        await prisma.cartItem.delete({
            where: { id: cartItem.id }
        });
    } else {
        // Update quantity
        await prisma.cartItem.update({
            where: { id: cartItem.id },
            data: { quantity }
        });
    }

    await refreshCartAggregates(cartItem.cartId);

    return prisma.cart.findUnique({
        where: { id: cartItem.cartId },
        include: mutationCartInclude
    });
};

/**
 * Remove item from cart
 * @param {string} userId - User ID
 * @param {string} itemId - Cart Item ID
 * @returns {Promise<Object>} Updated cart
 */
const removeFromCart = async (userId, itemId, fulfillmentMode = 'delivery') => {
    const normalizedMode = normalizeFulfillmentMode(fulfillmentMode);
    const cartItem = await prisma.cartItem.findFirst({
        where: {
            id: itemId,
            cart: {
                userId,
                isActive: true,
                fulfillmentMode: normalizedMode
            }
        },
        select: {
            id: true,
            cartId: true
        }
    });

    if (!cartItem) {
        throw new Error('Item not found in cart');
    }

    await prisma.cartItem.delete({
        where: { id: cartItem.id }
    });

    await refreshCartAggregates(cartItem.cartId);

    return prisma.cart.findUnique({
        where: { id: cartItem.cartId },
        include: mutationCartInclude
    });
};

/**
 * Clear entire cart
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Empty cart
 */
const clearCart = async (userId, fulfillmentMode = 'delivery') => {
    const normalizedMode = normalizeFulfillmentMode(fulfillmentMode);
    const carts = await prisma.cart.findMany({
        where: { userId, isActive: true, fulfillmentMode: normalizedMode },
        select: { id: true },
        orderBy: { lastUpdatedAt: 'desc' }
    });

    if (!carts || carts.length === 0) {
        throw new Error('Cart not found');
    }

    const cartIds = carts.map((cart) => cart.id);
    await prisma.cartItem.deleteMany({
        where: { cartId: { in: cartIds } }
    });

    await prisma.cart.updateMany({
        where: { id: { in: cartIds } },
        data: {
            restaurantId: null,
            groceryStoreId: null,
            pharmacyStoreId: null,
            grabMartStoreId: null,
            providerScopeKey: null,
            totalAmount: 0,
            itemCount: 0,
            abandonmentNotificationSent: false,
            abandonmentNotificationSentAt: null,
            lastUpdatedAt: new Date()
        }
    });

    const primaryCartId = carts[0].id;
    return prisma.cart.findUnique({
        where: { id: primaryCartId },
        include: mutationCartInclude
    });
};

/**
 * Get user's active cart
 * @param {string} userId - User ID
 * @param {string} cartType - 'food', 'grocery', 'pharmacy', or 'grabmart'
 * @returns {Promise<Object>} Cart object
 */
const getUserCart = async (userId, cartType = null, fulfillmentMode = 'delivery') => {
    const where = { userId, isActive: true, fulfillmentMode: normalizeFulfillmentMode(fulfillmentMode) };
    if (cartType) {
        where.cartType = cartType;
    }

    let cart = null;
    if (cartType) {
        cart = await prisma.cart.findFirst({
            where,
            include: readInclude,
            orderBy: { lastUpdatedAt: 'desc' }
        });
    } else {
        const carts = await prisma.cart.findMany({
            where,
            include: readInclude,
            orderBy: { lastUpdatedAt: 'desc' }
        });
        cart = carts.find((entry) => Array.isArray(entry.items) && entry.items.length > 0) || carts[0] || null;
    }
    return sanitizeCartAfterRead(cart);
};

const getUserCartGroups = async (userId, fulfillmentMode = 'delivery') => {
    const where = {
        userId,
        isActive: true,
        fulfillmentMode: normalizeFulfillmentMode(fulfillmentMode)
    };

    const carts = await prisma.cart.findMany({
        where,
        include: readInclude,
        orderBy: { lastUpdatedAt: 'desc' }
    });

    const groups = [];
    for (const cart of carts) {
        const sanitized = await sanitizeCartAfterRead(cart);
        if (!sanitized || !Array.isArray(sanitized.items) || sanitized.items.length === 0) continue;
        groups.push(sanitized);
    }

    return groups;
};

/**
 * Mark cart as converted to order
 * @param {string} userId - User ID
 * @param {string} orderId - Order ID
 * @returns {Promise<Object>} Updated cart
 */
const markCartAsConverted = async (userId, orderId, fulfillmentMode = 'delivery') => {
    const cart = await prisma.cart.findFirst({
        where: { userId, isActive: true, fulfillmentMode: normalizeFulfillmentMode(fulfillmentMode) }
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
            items: {
                select: {
                    name: true,
                    itemType: true,
                    food: {
                        select: {
                            name: true
                        }
                    },
                    groceryItem: {
                        select: {
                            name: true
                        }
                    },
                    pharmacyItem: {
                        select: {
                            name: true
                        }
                    },
                    grabMartItem: {
                        select: {
                            name: true
                        }
                    }
                }
            },
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
    normalizeFulfillmentMode,
    buildProviderScopeKey,
    getOrCreateCart,
    addToCart,
    updateCartItem,
    removeFromCart,
    clearCart,
    getUserCart,
    getUserCartGroups,
    markCartAsConverted,
    findAbandonedCarts,
    markAbandonmentNotificationSent
};
