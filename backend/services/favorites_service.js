const prisma = require('../config/prisma');
const { normalizeRatingResponse } = require('../utils/rating_calculator');
const { isGrabGoExclusiveActive } = require('../utils/grabgo_exclusive');
const { isRestaurantOpen } = require('../utils/restaurant');
const { createScopedLogger } = require('../utils/logger');

const console = createScopedLogger('favorites_service');

const DAY_MAP = {
  0: 'sunday',
  1: 'monday',
  2: 'tuesday',
  3: 'wednesday',
  4: 'thursday',
  5: 'friday',
  6: 'saturday',
};

const formatOpeningHours = (openingHours) => {
  if (!Array.isArray(openingHours)) return null;

  return openingHours.reduce((acc, row) => {
    const key = DAY_MAP[row.dayOfWeek];
    if (!key) return acc;
    acc[key] = {
      open: row.openTime ?? '09:00',
      close: row.closeTime ?? '21:00',
      isClosed: Boolean(row.isClosed),
    };
    return acc;
  }, {});
};

/**
 * Favorites Service (Prisma)
 *
 * Supports all current service domains:
 * - Vendor favorites: restaurant, grocery store, pharmacy store, grabmart store
 * - Item favorites: food, grocery item, pharmacy item, grabmart item
 */

const FAVORITES_SELECT = {
  favoriteRestaurants: {
    include: {
      restaurant: {
        select: {
          id: true,
          restaurantName: true,
          logo: true,
          bannerImages: true,
          description: true,
          foodType: true,
          address: true,
          city: true,
          area: true,
          status: true,
          isOpen: true,
          isAcceptingOrders: true,
          isVerified: true,
          featured: true,
          lastOnlineAt: true,
          deliveryFee: true,
          minOrder: true,
          rating: true,
          ratingCount: true,
          totalReviews: true,
          averageDeliveryTime: true,
          averagePreparationTime: true,
          isGrabGoExclusive: true,
          isGrabGoExclusiveUntil: true,
          openingHours: {
            select: {
              dayOfWeek: true,
              openTime: true,
              closeTime: true,
              isClosed: true,
            },
          },
        },
      },
    },
    orderBy: { addedAt: 'desc' },
  },
  favoriteStores: {
    include: {
      store: {
        select: {
          id: true,
          storeName: true,
          logo: true,
          description: true,
          storeType: true,
          address: true,
          city: true,
          area: true,
          status: true,
          isOpen: true,
          isAcceptingOrders: true,
          isVerified: true,
          featured: true,
          lastOnlineAt: true,
          deliveryFee: true,
          minOrder: true,
          rating: true,
          ratingCount: true,
          totalReviews: true,
          averageDeliveryTime: true,
          averagePreparationTime: true,
          isGrabGoExclusive: true,
          isGrabGoExclusiveUntil: true,
          openingHours: {
            select: {
              dayOfWeek: true,
              openTime: true,
              closeTime: true,
              isClosed: true,
            },
          },
        },
      },
    },
    orderBy: { addedAt: 'desc' },
  },
  favoritePharmacies: {
    include: {
      pharmacy: {
        select: {
          id: true,
          storeName: true,
          logo: true,
          bannerImages: true,
          description: true,
          address: true,
          city: true,
          area: true,
          status: true,
          isOpen: true,
          isAcceptingOrders: true,
          isVerified: true,
          featured: true,
          lastOnlineAt: true,
          deliveryFee: true,
          minOrder: true,
          rating: true,
          ratingCount: true,
          totalReviews: true,
          averageDeliveryTime: true,
          averagePreparationTime: true,
          emergencyService: true,
          prescriptionRequired: true,
          isGrabGoExclusive: true,
          isGrabGoExclusiveUntil: true,
          openingHours: {
            select: {
              dayOfWeek: true,
              openTime: true,
              closeTime: true,
              isClosed: true,
            },
          },
        },
      },
    },
    orderBy: { addedAt: 'desc' },
  },
  favoriteGrabMartStores: {
    include: {
      store: {
        select: {
          id: true,
          storeName: true,
          logo: true,
          bannerImages: true,
          description: true,
          services: true,
          productTypes: true,
          address: true,
          city: true,
          area: true,
          status: true,
          isOpen: true,
          isAcceptingOrders: true,
          isVerified: true,
          featured: true,
          lastOnlineAt: true,
          deliveryFee: true,
          minOrder: true,
          rating: true,
          ratingCount: true,
          totalReviews: true,
          is24Hours: true,
          isGrabGoExclusive: true,
          isGrabGoExclusiveUntil: true,
        },
      },
    },
    orderBy: { addedAt: 'desc' },
  },
  favoriteFoods: {
    include: {
      food: {
        select: {
          id: true,
          name: true,
          price: true,
          foodImage: true,
          description: true,
          isAvailable: true,
          rating: true,
          totalReviews: true,
          discountPercentage: true,
          discountEndDate: true,
          orderCount: true,
          prepTimeMinutes: true,
          restaurant: {
            select: {
              id: true,
              restaurantName: true,
              logo: true,
              rating: true,
              ratingCount: true,
              totalReviews: true,
              isOpen: true,
              averageDeliveryTime: true,
            },
          },
        },
      },
    },
    orderBy: { addedAt: 'desc' },
  },
  favoriteGroceryItems: {
    include: {
      groceryItem: {
        select: {
          id: true,
          name: true,
          price: true,
          image: true,
          description: true,
          isAvailable: true,
          rating: true,
          reviewCount: true,
          discountPercentage: true,
          discountEndDate: true,
          orderCount: true,
          store: {
            select: {
              id: true,
              storeName: true,
              logo: true,
              isOpen: true,
            },
          },
        },
      },
    },
    orderBy: { addedAt: 'desc' },
  },
  favoritePharmacyItems: {
    include: {
      pharmacyItem: {
        select: {
          id: true,
          name: true,
          price: true,
          image: true,
          description: true,
          isAvailable: true,
          rating: true,
          reviewCount: true,
          discountPercentage: true,
          discountEndDate: true,
          orderCount: true,
          store: {
            select: {
              id: true,
              storeName: true,
              logo: true,
              isOpen: true,
            },
          },
        },
      },
    },
    orderBy: { addedAt: 'desc' },
  },
  favoriteGrabMartItems: {
    include: {
      grabMartItem: {
        select: {
          id: true,
          name: true,
          price: true,
          image: true,
          description: true,
          isAvailable: true,
          rating: true,
          reviewCount: true,
          discountPercentage: true,
          discountEndDate: true,
          orderCount: true,
          store: {
            select: {
              id: true,
              storeName: true,
              logo: true,
              isOpen: true,
            },
          },
        },
      },
    },
    orderBy: { addedAt: 'desc' },
  },
};

const dedupeIds = (values) => {
  const seen = new Set();
  const result = [];
  for (const value of values || []) {
    const id = String(value || '').trim();
    if (!id || seen.has(id)) continue;
    seen.add(id);
    result.push(id);
  }
  return result;
};

const filterExistingIds = async (delegate, ids) => {
  if (!Array.isArray(ids) || ids.length === 0) return [];
  const rows = await prisma[delegate].findMany({
    where: { id: { in: ids } },
    select: { id: true },
  });
  return rows.map((entry) => entry.id);
};

const assertTargetExists = async (delegate, id, label) => {
  const target = await prisma[delegate].findUnique({
    where: { id },
    select: { id: true },
  });

  if (!target) {
    throw new Error(`${label} not found`);
  }
};

const formatVendorFavorite = (entity, type) => {
  if (!entity) return null;

  const computedIsOpen =
    type === 'restaurant' && Array.isArray(entity.openingHours)
      ? isRestaurantOpen({ ...entity, openingHours: entity.openingHours })
      : entity.isOpen;

  const ratingMeta = normalizeRatingResponse({
    rating: entity.rating,
    ratingCount: entity.ratingCount,
    totalReviews: entity.totalReviews,
  });

  const categories = (() => {
    if (type === 'restaurant') {
      return entity.foodType ? [entity.foodType] : [];
    }
    if (type === 'groceryStore') {
      return entity.storeType ? [entity.storeType] : ['Grocery Store'];
    }
    if (type === 'pharmacyStore') {
      return ['Pharmacy'];
    }
    if (type === 'grabMartStore') {
      if (Array.isArray(entity.productTypes) && entity.productTypes.length > 0) {
        return entity.productTypes;
      }
      if (Array.isArray(entity.services) && entity.services.length > 0) {
        return entity.services;
      }
      return ['GrabMart'];
    }
    return [];
  })();

  return {
    ...entity,
    isOpen: computedIsOpen,
    rating: ratingMeta.rating,
    rawRating: ratingMeta.rawRating,
    weightedRating: ratingMeta.weightedRating,
    ratingCount: ratingMeta.ratingCount,
    totalReviews: ratingMeta.totalReviews,
    reviewCount: ratingMeta.reviewCount,
    categories,
    openingHours: formatOpeningHours(entity.openingHours),
    isGrabGoExclusiveActive: isGrabGoExclusiveActive(entity),
  };
};

const formatFavoriteItem = (item, sourceType) => {
  if (!item) return null;

  const ratingMeta = normalizeRatingResponse({
    rating: item.rating,
    reviewCount: item.reviewCount,
    totalReviews: item.totalReviews,
  });

  const vendor = item.restaurant || item.store || null;
  const base = {
    ...item,
    rating: ratingMeta.rating,
    rawRating: ratingMeta.rawRating,
    weightedRating: ratingMeta.weightedRating,
    reviewCount: ratingMeta.reviewCount,
    ratingCount: ratingMeta.ratingCount,
    totalReviews: ratingMeta.totalReviews,
    favoriteItemType: sourceType,
    sellerName:
      vendor?.restaurantName ||
      vendor?.storeName ||
      item.sellerName ||
      'Unknown Vendor',
    sellerId: vendor?.id || item.restaurantId || item.storeId || '',
    restaurantId: vendor?.id || item.restaurantId || item.storeId || '',
    restaurantImage: vendor?.logo || item.restaurantImage || '',
    estimatedDeliveryTime:
      vendor?.averageDeliveryTime != null
        ? `${vendor.averageDeliveryTime}-${vendor.averageDeliveryTime + 10} min`
        : item.estimatedDeliveryTime || '25-30 min',
    isRestaurantOpen:
      typeof vendor?.isOpen === 'boolean'
        ? vendor.isOpen
        : item.isRestaurantOpen ?? true,
  };

  return base;
};

const mapFavoritesResponse = (user) => {
  const restaurants = (user.favoriteRestaurants || []).map((entry) => ({
    id: entry.restaurant?.id || null,
    addedAt: entry.addedAt,
    restaurant: formatVendorFavorite(entry.restaurant, 'restaurant'),
  }));

  const groceryStores = (user.favoriteStores || []).map((entry) => ({
    id: entry.store?.id || null,
    addedAt: entry.addedAt,
    store: formatVendorFavorite(entry.store, 'groceryStore'),
  }));

  const pharmacies = (user.favoritePharmacies || []).map((entry) => ({
    id: entry.pharmacy?.id || null,
    addedAt: entry.addedAt,
    pharmacy: formatVendorFavorite(entry.pharmacy, 'pharmacyStore'),
  }));

  const grabMartStores = (user.favoriteGrabMartStores || []).map((entry) => ({
    id: entry.store?.id || null,
    addedAt: entry.addedAt,
    store: formatVendorFavorite(entry.store, 'grabMartStore'),
  }));

  const foodItems = (user.favoriteFoods || []).map((entry) => ({
    id: entry.food?.id || null,
    addedAt: entry.addedAt,
    item: formatFavoriteItem(entry.food, 'food'),
  }));

  const groceryItems = (user.favoriteGroceryItems || []).map((entry) => ({
    id: entry.groceryItem?.id || null,
    addedAt: entry.addedAt,
    item: formatFavoriteItem(entry.groceryItem, 'grocery'),
  }));

  const pharmacyItems = (user.favoritePharmacyItems || []).map((entry) => ({
    id: entry.pharmacyItem?.id || null,
    addedAt: entry.addedAt,
    item: formatFavoriteItem(entry.pharmacyItem, 'pharmacy_item'),
  }));

  const grabMartItems = (user.favoriteGrabMartItems || []).map((entry) => ({
    id: entry.grabMartItem?.id || null,
    addedAt: entry.addedAt,
    item: formatFavoriteItem(entry.grabMartItem, 'grabmart_item'),
  }));

  const counts = {
    restaurants: restaurants.length,
    groceryStores: groceryStores.length,
    pharmacies: pharmacies.length,
    grabMartStores: grabMartStores.length,
    foodItems: foodItems.length,
    groceryItems: groceryItems.length,
    pharmacyItems: pharmacyItems.length,
    grabMartItems: grabMartItems.length,
  };

  return {
    // Flat keys kept for compatibility with current/legacy clients.
    restaurants,
    groceryStores,
    pharmacies,
    grabMartStores,
    foodItems,
    groceryItems,
    pharmacyItems,
    grabMartItems,
    // Grouped keys for cleaner future clients.
    vendors: {
      restaurants,
      groceryStores,
      pharmacies,
      grabMartStores,
    },
    items: {
      foodItems,
      groceryItems,
      pharmacyItems,
      grabMartItems,
    },
    counts,
    totalCount:
      counts.restaurants +
      counts.groceryStores +
      counts.pharmacies +
      counts.grabMartStores +
      counts.foodItems +
      counts.groceryItems +
      counts.pharmacyItems +
      counts.grabMartItems,
  };
};

const getUserFavorites = async (userId) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: FAVORITES_SELECT,
    });

    if (!user) {
      throw new Error('User not found');
    }

    return mapFavoritesResponse(user);
  } catch (error) {
    console.error('Error getting user favorites:', error.message);
    throw error;
  }
};

const addFavoriteRestaurant = async (userId, restaurantId) => {
  try {
    await assertTargetExists('restaurant', restaurantId, 'Restaurant');
    await prisma.userFavoriteRestaurant.upsert({
      where: { userId_restaurantId: { userId, restaurantId } },
      update: {},
      create: { userId, restaurantId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error adding favorite restaurant:', error.message);
    throw error;
  }
};

const removeFavoriteRestaurant = async (userId, restaurantId) => {
  try {
    await prisma.userFavoriteRestaurant.deleteMany({
      where: { userId, restaurantId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error removing favorite restaurant:', error.message);
    throw error;
  }
};

const addFavoriteStore = async (userId, storeId) => {
  try {
    await assertTargetExists('groceryStore', storeId, 'Grocery store');
    await prisma.userFavoriteStore.upsert({
      where: { userId_storeId: { userId, storeId } },
      update: {},
      create: { userId, storeId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error adding favorite store:', error.message);
    throw error;
  }
};

const removeFavoriteStore = async (userId, storeId) => {
  try {
    await prisma.userFavoriteStore.deleteMany({
      where: { userId, storeId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error removing favorite store:', error.message);
    throw error;
  }
};

const addFavoritePharmacy = async (userId, pharmacyId) => {
  try {
    await assertTargetExists('pharmacyStore', pharmacyId, 'Pharmacy store');
    await prisma.userFavoritePharmacy.upsert({
      where: { userId_pharmacyId: { userId, pharmacyId } },
      update: {},
      create: { userId, pharmacyId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error adding favorite pharmacy store:', error.message);
    throw error;
  }
};

const removeFavoritePharmacy = async (userId, pharmacyId) => {
  try {
    await prisma.userFavoritePharmacy.deleteMany({
      where: { userId, pharmacyId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error removing favorite pharmacy store:', error.message);
    throw error;
  }
};

const addFavoriteGrabMartStore = async (userId, storeId) => {
  try {
    await assertTargetExists('grabMartStore', storeId, 'GrabMart store');
    await prisma.userFavoriteGrabMartStore.upsert({
      where: { userId_storeId: { userId, storeId } },
      update: {},
      create: { userId, storeId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error adding favorite GrabMart store:', error.message);
    throw error;
  }
};

const removeFavoriteGrabMartStore = async (userId, storeId) => {
  try {
    await prisma.userFavoriteGrabMartStore.deleteMany({
      where: { userId, storeId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error removing favorite GrabMart store:', error.message);
    throw error;
  }
};

const addFavoriteFoodItem = async (userId, foodId) => {
  try {
    await assertTargetExists('food', foodId, 'Food item');
    await prisma.userFavoriteFood.upsert({
      where: { userId_foodId: { userId, foodId } },
      update: {},
      create: { userId, foodId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error adding favorite food item:', error.message);
    throw error;
  }
};

const removeFavoriteFoodItem = async (userId, foodId) => {
  try {
    await prisma.userFavoriteFood.deleteMany({
      where: { userId, foodId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error removing favorite food item:', error.message);
    throw error;
  }
};

const addFavoriteGroceryItem = async (userId, groceryId) => {
  try {
    await assertTargetExists('groceryItem', groceryId, 'Grocery item');
    await prisma.userFavoriteGroceryItem.upsert({
      where: { userId_groceryItemId: { userId, groceryItemId: groceryId } },
      update: {},
      create: { userId, groceryItemId: groceryId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error adding favorite grocery item:', error.message);
    throw error;
  }
};

const removeFavoriteGroceryItem = async (userId, groceryId) => {
  try {
    await prisma.userFavoriteGroceryItem.deleteMany({
      where: { userId, groceryItemId: groceryId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error removing favorite grocery item:', error.message);
    throw error;
  }
};

const addFavoritePharmacyItem = async (userId, pharmacyItemId) => {
  try {
    await assertTargetExists('pharmacyItem', pharmacyItemId, 'Pharmacy item');
    await prisma.userFavoritePharmacyItem.upsert({
      where: { userId_pharmacyItemId: { userId, pharmacyItemId } },
      update: {},
      create: { userId, pharmacyItemId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error adding favorite pharmacy item:', error.message);
    throw error;
  }
};

const removeFavoritePharmacyItem = async (userId, pharmacyItemId) => {
  try {
    await prisma.userFavoritePharmacyItem.deleteMany({
      where: { userId, pharmacyItemId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error removing favorite pharmacy item:', error.message);
    throw error;
  }
};

const addFavoriteGrabMartItem = async (userId, grabMartItemId) => {
  try {
    await assertTargetExists('grabMartItem', grabMartItemId, 'GrabMart item');
    await prisma.userFavoriteGrabMartItem.upsert({
      where: { userId_grabMartItemId: { userId, grabMartItemId } },
      update: {},
      create: { userId, grabMartItemId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error adding favorite GrabMart item:', error.message);
    throw error;
  }
};

const removeFavoriteGrabMartItem = async (userId, grabMartItemId) => {
  try {
    await prisma.userFavoriteGrabMartItem.deleteMany({
      where: { userId, grabMartItemId },
    });
    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error removing favorite GrabMart item:', error.message);
    throw error;
  }
};

const clearAllFavorites = async (userId) => {
  try {
    await prisma.$transaction([
      prisma.userFavoriteRestaurant.deleteMany({ where: { userId } }),
      prisma.userFavoriteStore.deleteMany({ where: { userId } }),
      prisma.userFavoritePharmacy.deleteMany({ where: { userId } }),
      prisma.userFavoriteGrabMartStore.deleteMany({ where: { userId } }),
      prisma.userFavoriteFood.deleteMany({ where: { userId } }),
      prisma.userFavoriteGroceryItem.deleteMany({ where: { userId } }),
      prisma.userFavoritePharmacyItem.deleteMany({ where: { userId } }),
      prisma.userFavoriteGrabMartItem.deleteMany({ where: { userId } }),
    ]);

    return await getUserFavorites(userId);
  } catch (error) {
    console.error('Error clearing favorites:', error.message);
    throw error;
  }
};

const syncFavorites = async (userId, localFavorites) => {
  try {
    const payload = localFavorites || {};
    const restaurantIds = dedupeIds(payload.restaurants || []);
    const groceryStoreIds = dedupeIds([...(payload.stores || []), ...(payload.groceryStores || [])]);
    const pharmacyStoreIds = dedupeIds([...(payload.pharmacies || []), ...(payload.pharmacyStores || [])]);
    const grabMartStoreIds = dedupeIds(payload.grabMartStores || []);
    const foodItemIds = dedupeIds(payload.foodItems || []);
    const groceryItemIds = dedupeIds(payload.groceryItems || []);
    const pharmacyItemIds = dedupeIds(payload.pharmacyItems || []);
    const grabMartItemIds = dedupeIds([...(payload.grabMartItems || []), ...(payload.grabmartItems || [])]);

    const [
      validRestaurantIds,
      validGroceryStoreIds,
      validPharmacyStoreIds,
      validGrabMartStoreIds,
      validFoodItemIds,
      validGroceryItemIds,
      validPharmacyItemIds,
      validGrabMartItemIds,
    ] = await Promise.all([
      filterExistingIds('restaurant', restaurantIds),
      filterExistingIds('groceryStore', groceryStoreIds),
      filterExistingIds('pharmacyStore', pharmacyStoreIds),
      filterExistingIds('grabMartStore', grabMartStoreIds),
      filterExistingIds('food', foodItemIds),
      filterExistingIds('groceryItem', groceryItemIds),
      filterExistingIds('pharmacyItem', pharmacyItemIds),
      filterExistingIds('grabMartItem', grabMartItemIds),
    ]);

    const transactions = [];

    for (const restaurantId of validRestaurantIds) {
      transactions.push(
        prisma.userFavoriteRestaurant.upsert({
          where: { userId_restaurantId: { userId, restaurantId } },
          update: {},
          create: { userId, restaurantId },
        })
      );
    }

    for (const storeId of validGroceryStoreIds) {
      transactions.push(
        prisma.userFavoriteStore.upsert({
          where: { userId_storeId: { userId, storeId } },
          update: {},
          create: { userId, storeId },
        })
      );
    }

    for (const pharmacyId of validPharmacyStoreIds) {
      transactions.push(
        prisma.userFavoritePharmacy.upsert({
          where: { userId_pharmacyId: { userId, pharmacyId } },
          update: {},
          create: { userId, pharmacyId },
        })
      );
    }

    for (const storeId of validGrabMartStoreIds) {
      transactions.push(
        prisma.userFavoriteGrabMartStore.upsert({
          where: { userId_storeId: { userId, storeId } },
          update: {},
          create: { userId, storeId },
        })
      );
    }

    for (const foodId of validFoodItemIds) {
      transactions.push(
        prisma.userFavoriteFood.upsert({
          where: { userId_foodId: { userId, foodId } },
          update: {},
          create: { userId, foodId },
        })
      );
    }

    for (const groceryItemId of validGroceryItemIds) {
      transactions.push(
        prisma.userFavoriteGroceryItem.upsert({
          where: { userId_groceryItemId: { userId, groceryItemId } },
          update: {},
          create: { userId, groceryItemId },
        })
      );
    }

    for (const pharmacyItemId of validPharmacyItemIds) {
      transactions.push(
        prisma.userFavoritePharmacyItem.upsert({
          where: { userId_pharmacyItemId: { userId, pharmacyItemId } },
          update: {},
          create: { userId, pharmacyItemId },
        })
      );
    }

    for (const grabMartItemId of validGrabMartItemIds) {
      transactions.push(
        prisma.userFavoriteGrabMartItem.upsert({
          where: { userId_grabMartItemId: { userId, grabMartItemId } },
          update: {},
          create: { userId, grabMartItemId },
        })
      );
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

const isRestaurantFavorited = async (userId, restaurantId) => {
  const count = await prisma.userFavoriteRestaurant.count({ where: { userId, restaurantId } });
  return count > 0;
};

const isStoreFavorited = async (userId, storeId) => {
  const count = await prisma.userFavoriteStore.count({ where: { userId, storeId } });
  return count > 0;
};

const isPharmacyFavorited = async (userId, pharmacyId) => {
  const count = await prisma.userFavoritePharmacy.count({ where: { userId, pharmacyId } });
  return count > 0;
};

const isGrabMartStoreFavorited = async (userId, storeId) => {
  const count = await prisma.userFavoriteGrabMartStore.count({ where: { userId, storeId } });
  return count > 0;
};

const isFoodItemFavorited = async (userId, foodId) => {
  const count = await prisma.userFavoriteFood.count({ where: { userId, foodId } });
  return count > 0;
};

const isGroceryItemFavorited = async (userId, groceryId) => {
  const count = await prisma.userFavoriteGroceryItem.count({
    where: { userId, groceryItemId: groceryId },
  });
  return count > 0;
};

const isPharmacyItemFavorited = async (userId, pharmacyItemId) => {
  const count = await prisma.userFavoritePharmacyItem.count({
    where: { userId, pharmacyItemId },
  });
  return count > 0;
};

const isGrabMartItemFavorited = async (userId, grabMartItemId) => {
  const count = await prisma.userFavoriteGrabMartItem.count({
    where: { userId, grabMartItemId },
  });
  return count > 0;
};

module.exports = {
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
  syncFavorites,
  isRestaurantFavorited,
  isStoreFavorited,
  isPharmacyFavorited,
  isGrabMartStoreFavorited,
  isFoodItemFavorited,
  isGroceryItemFavorited,
  isPharmacyItemFavorited,
  isGrabMartItemFavorited,
};
