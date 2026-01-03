const User = require('../models/User');
const Restaurant = require('../models/Restaurant');
const GroceryStore = require('../models/GroceryStore');
const Food = require('../models/Food');
const GroceryItem = require('../models/GroceryItem');

/**
 * Favorites Service
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
        const user = await User.findById(userId)
            .select('favorites')
            .populate('favorites.restaurants.restaurantId', 'restaurant_name logo address')
            .populate('favorites.groceryStores.storeId', 'name logo address')
            .populate('favorites.foodItems.itemId', 'name price image')
            .populate('favorites.groceryItems.itemId', 'name price image');

        if (!user) {
            throw new Error('User not found');
        }

        // Filter out any favorites where the populated ID is null (deleted items)
        const favorites = {
            restaurants: (user.favorites?.restaurants || []).filter(f => f.restaurantId !== null),
            groceryStores: (user.favorites?.groceryStores || []).filter(f => f.storeId !== null),
            foodItems: (user.favorites?.foodItems || []).filter(f => f.itemId !== null),
            groceryItems: (user.favorites?.groceryItems || []).filter(f => f.itemId !== null)
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
        // Validate restaurant exists
        const restaurant = await Restaurant.findById(restaurantId);
        if (!restaurant) {
            throw new Error('Restaurant not found');
        }

        // Add to favorites if not already present (Atomic operation)
        const result = await User.findOneAndUpdate(
            {
                _id: userId,
                'favorites.restaurants.restaurantId': { $ne: restaurantId }
            },
            {
                $push: {
                    'favorites.restaurants': {
                        restaurantId,
                        addedAt: new Date()
                    }
                }
            },
            { new: true }
        );

        if (!result) {
            // Either user not found or restaurant already favorited
            const user = await User.findById(userId);
            if (!user) throw new Error('User not found');

            const alreadyFavorited = user.favorites?.restaurants?.some(
                fav => fav.restaurantId.toString() === restaurantId
            );
            if (alreadyFavorited) throw new Error('Restaurant already in favorites');
        }

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
        await User.findByIdAndUpdate(userId, {
            $pull: {
                'favorites.restaurants': { restaurantId }
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
        // Validate store exists
        const store = await GroceryStore.findById(storeId);
        if (!store) {
            throw new Error('Grocery store not found');
        }

        // Add to favorites if not already present (Atomic operation)
        const result = await User.findOneAndUpdate(
            {
                _id: userId,
                'favorites.groceryStores.storeId': { $ne: storeId }
            },
            {
                $push: {
                    'favorites.groceryStores': {
                        storeId,
                        addedAt: new Date()
                    }
                }
            },
            { new: true }
        );

        if (!result) {
            const user = await User.findById(userId);
            if (!user) throw new Error('User not found');

            const alreadyFavorited = user.favorites?.groceryStores?.some(
                fav => fav.storeId.toString() === storeId
            );
            if (alreadyFavorited) throw new Error('Store already in favorites');
        }

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
        await User.findByIdAndUpdate(userId, {
            $pull: {
                'favorites.groceryStores': { storeId }
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
        // Validate food exists
        const food = await Food.findById(foodId);
        if (!food) {
            throw new Error('Food item not found');
        }

        // Add to favorites if not already present (Atomic operation)
        const result = await User.findOneAndUpdate(
            {
                _id: userId,
                'favorites.foodItems.itemId': { $ne: foodId }
            },
            {
                $push: {
                    'favorites.foodItems': {
                        itemId: foodId,
                        addedAt: new Date()
                    }
                }
            },
            { new: true }
        );

        if (!result) {
            const user = await User.findById(userId);
            if (!user) throw new Error('User not found');

            const alreadyFavorited = user.favorites?.foodItems?.some(
                fav => fav.itemId.toString() === foodId
            );
            if (alreadyFavorited) throw new Error('Food item already in favorites');
        }

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
        await User.findByIdAndUpdate(userId, {
            $pull: {
                'favorites.foodItems': { itemId: foodId }
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
        // Validate grocery item exists
        const grocery = await GroceryItem.findById(groceryId);
        if (!grocery) {
            throw new Error('Grocery item not found');
        }

        // Add to favorites if not already present (Atomic operation)
        const result = await User.findOneAndUpdate(
            {
                _id: userId,
                'favorites.groceryItems.itemId': { $ne: groceryId }
            },
            {
                $push: {
                    'favorites.groceryItems': {
                        itemId: groceryId,
                        addedAt: new Date()
                    }
                }
            },
            { new: true }
        );

        if (!result) {
            const user = await User.findById(userId);
            if (!user) throw new Error('User not found');

            const alreadyFavorited = user.favorites?.groceryItems?.some(
                fav => fav.itemId.toString() === groceryId
            );
            if (alreadyFavorited) throw new Error('Grocery item already in favorites');
        }

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
        await User.findByIdAndUpdate(userId, {
            $pull: {
                'favorites.groceryItems': { itemId: groceryId }
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
/**
 * Sync favorites from local storage
 * @param {string} userId - User ID
 * @param {Object} localFavorites - Favorites from local storage
 * @returns {Promise<Object>} Merged favorites
 */
const syncFavorites = async (userId, localFavorites) => {
    try {
        const user = await User.findById(userId);
        if (!user) throw new Error('User not found');

        const updates = {};
        const now = new Date();

        // Helper to filter and map new favorites, with local deduplication
        const getNewFavs = (localList, existingList, idField) => {
            if (!localList || localList.length === 0) return [];

            const existingIds = (existingList || []).map(f => f[idField].toString());
            // Deduplicate local list first
            const uniqueLocalIds = [...new Set(localList)];

            return uniqueLocalIds
                .filter(id => !existingIds.includes(id))
                .map(id => ({ [idField]: id, addedAt: now }));
        };

        // Sync Restaurants
        const newRestaurants = getNewFavs(localFavorites.restaurants, user.favorites?.restaurants, 'restaurantId');
        if (newRestaurants.length > 0) {
            updates['$push'] = updates['$push'] || {};
            updates['$push']['favorites.restaurants'] = { $each: newRestaurants };
        }

        // Sync Grocery Stores
        const newStores = getNewFavs(localFavorites.stores, user.favorites?.groceryStores, 'storeId');
        if (newStores.length > 0) {
            updates['$push'] = updates['$push'] || {};
            updates['$push']['favorites.groceryStores'] = { $each: newStores };
        }

        // Sync Food Items
        const newFoodItems = getNewFavs(localFavorites.foodItems, user.favorites?.foodItems, 'itemId');
        if (newFoodItems.length > 0) {
            updates['$push'] = updates['$push'] || {};
            updates['$push']['favorites.foodItems'] = { $each: newFoodItems };
        }

        // Sync Grocery Items
        const newGroceryItems = getNewFavs(localFavorites.groceryItems, user.favorites?.groceryItems, 'itemId');
        if (newGroceryItems.length > 0) {
            updates['$push'] = updates['$push'] || {};
            updates['$push']['favorites.groceryItems'] = { $each: newGroceryItems };
        }

        // Apply updates if any
        if (Object.keys(updates).length > 0) {
            await User.findByIdAndUpdate(userId, updates);
        }

        return await getUserFavorites(userId);

    } catch (error) {
        console.error('Error syncing favorites:', error.message);
        throw error;
    }
};

/**
 * Check if restaurant is favorited
 * @param {string} userId - User ID
 * @param {string} restaurantId - Restaurant ID
 * @returns {Promise<boolean>} True if favorited
 */
const isRestaurantFavorited = async (userId, restaurantId) => {
    try {
        const exists = await User.exists({
            _id: userId,
            'favorites.restaurants.restaurantId': restaurantId
        });
        return !!exists;
    } catch (error) {
        return false;
    }
};

/**
 * Check if store is favorited
 * @param {string} userId - User ID
 * @param {string} storeId - Store ID
 * @returns {Promise<boolean>} True if favorited
 */
const isStoreFavorited = async (userId, storeId) => {
    try {
        const exists = await User.exists({
            _id: userId,
            'favorites.groceryStores.storeId': storeId
        });
        return !!exists;
    } catch (error) {
        return false;
    }
};

/**
 * Check if food item is favorited
 * @param {string} userId - User ID
 * @param {string} foodId - Food ID
 * @returns {Promise<boolean>} True if favorited
 */
const isFoodItemFavorited = async (userId, foodId) => {
    try {
        const exists = await User.exists({
            _id: userId,
            'favorites.foodItems.itemId': foodId
        });
        return !!exists;
    } catch (error) {
        return false;
    }
};

/**
 * Check if grocery item is favorited
 * @param {string} userId - User ID
 * @param {string} groceryId - Grocery ID
 * @returns {Promise<boolean>} True if favorited
 */
const isGroceryItemFavorited = async (userId, groceryId) => {
    try {
        const exists = await User.exists({
            _id: userId,
            'favorites.groceryItems.itemId': groceryId
        });
        return !!exists;
    } catch (error) {
        return false;
    }
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
