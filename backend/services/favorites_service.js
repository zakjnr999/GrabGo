const prisma = require('../config/prisma');

/**
 * Favorites Service (Prisma Version)
 * 
 * Manages user favorites for restaurants, stores, and items
 */

/**
 * Get all user favorites
 * @param {string} userId - User ID
 * @returns {Promise<Object>} User favorites
 */
const getUserFavorites = async (userId) => {
    try {
        const user = await prisma.user.findUnique({
            where: { id: userId },
            select: {
                favoriteRestaurants: {
                    include: {
                        restaurant: {
                            select: {
                                id: true,
                                restaurantName: true,
                                logo: true,
                                address: true
                            }
                        }
                    }
                },
                favoriteStores: {
                    include: {
                        store: {
                            select: {
                                id: true,
                                storeName: true,
                                logo: true,
                                address: true
                            }
                        }
                    }
                },
                favoriteFoods: {
                    include: {
                        food: {
                            select: {
                                id: true,
                                name: true,
                                price: true,
                                foodImage: true
                            }
                        }
                    }
                },
                favoriteGroceryItems: {
                    include: {
                        groceryItem: {
                            select: {
                                id: true,
                                name: true,
                                price: true,
                                image: true
                            }
                        }
                    }
                }
            }
        });

        if (!user) {
            throw new Error('User not found');
        }

        // Filter and format the output to match frontend expectations
        const favorites = {
            restaurants: (user.favoriteRestaurants || []).map(f => ({
                restaurantId: f.restaurant, // Frontend might expect the object here based on populate
                addedAt: f.addedAt
            })),
            groceryStores: (user.favoriteStores || []).map(f => ({
                storeId: f.store,
                addedAt: f.addedAt
            })),
            foodItems: (user.favoriteFoods || []).map(f => ({
                itemId: f.food,
                addedAt: f.addedAt
            })),
            groceryItems: (user.favoriteGroceryItems || []).map(f => ({
                itemId: f.groceryItem,
                addedAt: f.addedAt
            }))
        };

        return favorites;

    } catch (error) {
        console.error('Error getting user favorites:', error.message);
        throw error;
    }
};

/**
 * Add restaurant to favorites
 * @param {string} userId - User ID
 * @param {string} restaurantId - Restaurant ID
 * @returns {Promise<Object>} Updated favorites
 */
const addFavoriteRestaurant = async (userId, restaurantId) => {
    try {
        // Upsert behavior: ensure it exists without duplicates
        await prisma.userFavoriteRestaurant.upsert({
            where: {
                userId_restaurantId: {
                    userId,
                    restaurantId
                }
            },
            update: {}, // No update needed if exists
            create: {
                userId,
                restaurantId
            }
        });

        return await getUserFavorites(userId);
    } catch (error) {
        console.error('Error adding favorite restaurant:', error.message);
        throw error;
    }
};

/**
 * Remove restaurant from favorites
 * @param {string} userId - User ID
 * @param {string} restaurantId - Restaurant ID
 * @returns {Promise<Object>} Updated favorites
 */
const removeFavoriteRestaurant = async (userId, restaurantId) => {
    try {
        await prisma.userFavoriteRestaurant.deleteMany({
            where: {
                userId,
                restaurantId
            }
        });

        return await getUserFavorites(userId);
    } catch (error) {
        console.error('Error removing favorite restaurant:', error.message);
        throw error;
    }
};

/**
 * Add grocery store to favorites
 * @param {string} userId - User ID
 * @param {string} storeId - Store ID
 * @returns {Promise<Object>} Updated favorites
 */
const addFavoriteStore = async (userId, storeId) => {
    try {
        await prisma.userFavoriteStore.upsert({
            where: {
                userId_storeId: {
                    userId,
                    storeId
                }
            },
            update: {},
            create: {
                userId,
                storeId
            }
        });

        return await getUserFavorites(userId);
    } catch (error) {
        console.error('Error adding favorite store:', error.message);
        throw error;
    }
};

/**
 * Remove grocery store from favorites
 * @param {string} userId - User ID
 * @param {string} storeId - Store ID
 * @returns {Promise<Object>} Updated favorites
 */
const removeFavoriteStore = async (userId, storeId) => {
    try {
        await prisma.userFavoriteStore.deleteMany({
            where: {
                userId,
                storeId
            }
        });

        return await getUserFavorites(userId);
    } catch (error) {
        console.error('Error removing favorite store:', error.message);
        throw error;
    }
};

/**
 * Add food item to favorites
 * @param {string} userId - User ID
 * @param {string} foodId - Food ID
 * @returns {Promise<Object>} Updated favorites
 */
const addFavoriteFoodItem = async (userId, foodId) => {
    try {
        await prisma.userFavoriteFood.upsert({
            where: {
                userId_foodId: {
                    userId,
                    foodId
                }
            },
            update: {},
            create: {
                userId,
                foodId
            }
        });

        return await getUserFavorites(userId);
    } catch (error) {
        console.error('Error adding favorite food item:', error.message);
        throw error;
    }
};

/**
 * Remove food item from favorites
 * @param {string} userId - User ID
 * @param {string} foodId - Food ID
 * @returns {Promise<Object>} Updated favorites
 */
const removeFavoriteFoodItem = async (userId, foodId) => {
    try {
        await prisma.userFavoriteFood.deleteMany({
            where: {
                userId,
                foodId
            }
        });

        return await getUserFavorites(userId);
    } catch (error) {
        console.error('Error removing favorite food item:', error.message);
        throw error;
    }
};

/**
 * Add grocery item to favorites
 * @param {string} userId - User ID
 * @param {string} groceryId - Grocery item ID
 * @returns {Promise<Object>} Updated favorites
 */
const addFavoriteGroceryItem = async (userId, groceryId) => {
    try {
        await prisma.userFavoriteGroceryItem.upsert({
            where: {
                userId_groceryItemId: {
                    userId,
                    groceryItemId: groceryId
                }
            },
            update: {},
            create: {
                userId,
                groceryItemId: groceryId
            }
        });

        return await getUserFavorites(userId);
    } catch (error) {
        console.error('Error adding favorite grocery item:', error.message);
        throw error;
    }
};

/**
 * Remove grocery item from favorites
 * @param {string} userId - User ID
 * @param {string} groceryId - Grocery item ID
 * @returns {Promise<Object>} Updated favorites
 */
const removeFavoriteGroceryItem = async (userId, groceryId) => {
    try {
        await prisma.userFavoriteGroceryItem.deleteMany({
            where: {
                userId,
                groceryItemId: groceryId
            }
        });

        return await getUserFavorites(userId);
    } catch (error) {
        console.error('Error removing favorite grocery item:', error.message);
        throw error;
    }
};

/**
 * Sync favorites from local storage
 * @param {string} userId - User ID
 * @param {Object} localFavorites - Favorites from local storage
 * @returns {Promise<Object>} Merged favorites
 */
const syncFavorites = async (userId, localFavorites) => {
    try {
        const { restaurants, stores, foodItems, groceryItems } = localFavorites;

        const transactions = [];

        if (restaurants && restaurants.length > 0) {
            restaurants.forEach(id => {
                transactions.push(prisma.userFavoriteRestaurant.upsert({
                    where: { userId_restaurantId: { userId, restaurantId: id } },
                    update: {},
                    create: { userId, restaurantId: id }
                }));
            });
        }

        if (stores && stores.length > 0) {
            stores.forEach(id => {
                transactions.push(prisma.userFavoriteStore.upsert({
                    where: { userId_storeId: { userId, storeId: id } },
                    update: {},
                    create: { userId, storeId: id }
                }));
            });
        }

        if (foodItems && foodItems.length > 0) {
            foodItems.forEach(id => {
                transactions.push(prisma.userFavoriteFood.upsert({
                    where: { userId_foodId: { userId, foodId: id } },
                    update: {},
                    create: { userId, foodId: id }
                }));
            });
        }

        if (groceryItems && groceryItems.length > 0) {
            groceryItems.forEach(id => {
                transactions.push(prisma.userFavoriteGroceryItem.upsert({
                    where: { userId_groceryItemId: { userId, groceryItemId: id } },
                    update: {},
                    create: { userId, groceryItemId: id }
                }));
            });
        }

        if (transactions.length > 0) {
            await prisma.$transaction(transactions);
        }

        return await getUserFavorites(userId);
    } catch (error) {
        console.error('Error syncing favorites:', error.message);
        throw error;
    }
};

/**
 * Check if restaurant is favorited
 */
const isRestaurantFavorited = async (userId, restaurantId) => {
    const count = await prisma.userFavoriteRestaurant.count({
        where: { userId, restaurantId }
    });
    return count > 0;
};

/**
 * Check if store is favorited
 */
const isStoreFavorited = async (userId, storeId) => {
    const count = await prisma.userFavoriteStore.count({
        where: { userId, storeId }
    });
    return count > 0;
};

/**
 * Check if food item is favorited
 */
const isFoodItemFavorited = async (userId, foodId) => {
    const count = await prisma.userFavoriteFood.count({
        where: { userId, foodId }
    });
    return count > 0;
};

/**
 * Check if grocery item is favorited
 */
const isGroceryItemFavorited = async (userId, groceryId) => {
    const count = await prisma.userFavoriteGroceryItem.count({
        where: { userId, groceryItemId: groceryId }
    });
    return count > 0;
};

module.exports = {
    getUserFavorites,
    addFavoriteRestaurant,
    removeFavoriteRestaurant,
    addFavoriteStore,
    removeFavoriteStore,
    addFavoriteFoodItem,
    removeFavoriteFoodItem,
    addFavoriteGroceryItem,
    removeFavoriteGroceryItem,
    syncFavorites,
    isRestaurantFavorited,
    isStoreFavorited,
    isFoodItemFavorited,
    isGroceryItemFavorited
};
