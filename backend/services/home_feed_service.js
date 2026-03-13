const prisma = require('../config/prisma');
const mlClient = require('../utils/ml_client');
const { FOOD_INCLUDE_RELATIONS, formatFoodResponse } = require('../utils/food_helpers');
const { validateLocationParams, getBoundingBox, filterVendorsByDistance } = require('../utils/vendor_distance_filter');
const { isRestaurantOpen } = require('../utils/restaurant');
const { normalizeRatingResponse } = require('../utils/rating_calculator');
const { isGrabGoExclusiveActive } = require('../utils/grabgo_exclusive');
const { createScopedLogger } = require('../utils/logger');

const console = createScopedLogger('home_feed_service');

const HOME_SECTION_LIMIT = 10;
const HOME_RECOMMENDED_LIMIT = 20;
const HOME_EXCLUSIVE_QUERY_LIMIT = 12;

const RESTAURANT_SELECT = {
  id: true,
  restaurantName: true,
  email: true,
  phone: true,
  logo: true,
  foodType: true,
  description: true,
  averageDeliveryTime: true,
  averagePreparationTime: true,
  deliveryFee: true,
  minOrder: true,
  paymentMethods: true,
  bannerImages: true,
  isVerified: true,
  verifiedAt: true,
  featured: true,
  featuredUntil: true,
  features: true,
  tags: true,
  whatsappNumber: true,
  totalReviews: true,
  isAcceptingOrders: true,
  isGrabGoExclusive: true,
  isGrabGoExclusiveUntil: true,
  lastOnlineAt: true,
  status: true,
  rating: true,
  ratingCount: true,
  isOpen: true,
  longitude: true,
  latitude: true,
  address: true,
  city: true,
  area: true,
  facebookUrl: true,
  instagramUrl: true,
  twitterUrl: true,
  websiteUrl: true,
  openingHours: {
    select: {
      dayOfWeek: true,
      openTime: true,
      closeTime: true,
      isClosed: true,
    },
  },
  createdAt: true,
  updatedAt: true,
};

const GROCERY_SELECT = {
  id: true,
  storeName: true,
  logo: true,
  description: true,
  phone: true,
  email: true,
  status: true,
  rating: true,
  ratingCount: true,
  isOpen: true,
  deliveryFee: true,
  averageDeliveryTime: true,
  averagePreparationTime: true,
  minOrder: true,
  longitude: true,
  latitude: true,
  address: true,
  city: true,
  area: true,
  facebookUrl: true,
  instagramUrl: true,
  twitterUrl: true,
  websiteUrl: true,
  storeType: true,
  isVerified: true,
  verifiedAt: true,
  featured: true,
  featuredUntil: true,
  features: true,
  tags: true,
  whatsappNumber: true,
  totalReviews: true,
  isAcceptingOrders: true,
  isGrabGoExclusive: true,
  isGrabGoExclusiveUntil: true,
  vendorType: true,
  lastOnlineAt: true,
  openingHours: {
    select: {
      dayOfWeek: true,
      openTime: true,
      closeTime: true,
      isClosed: true,
    },
  },
  createdAt: true,
  updatedAt: true,
};

const PHARMACY_SELECT = {
  id: true,
  storeName: true,
  logo: true,
  description: true,
  phone: true,
  email: true,
  status: true,
  rating: true,
  ratingCount: true,
  isOpen: true,
  deliveryFee: true,
  averageDeliveryTime: true,
  averagePreparationTime: true,
  minOrder: true,
  licenseNumber: true,
  pharmacistName: true,
  emergencyService: true,
  prescriptionRequired: true,
  operatingHoursString: true,
  bannerImages: true,
  longitude: true,
  latitude: true,
  address: true,
  city: true,
  area: true,
  pharmacistLicense: true,
  insuranceAccepted: true,
  isVerified: true,
  verifiedAt: true,
  featured: true,
  featuredUntil: true,
  features: true,
  tags: true,
  whatsappNumber: true,
  totalReviews: true,
  isAcceptingOrders: true,
  isGrabGoExclusive: true,
  isGrabGoExclusiveUntil: true,
  vendorType: true,
  lastOnlineAt: true,
  openingHours: {
    select: {
      dayOfWeek: true,
      openTime: true,
      closeTime: true,
      isClosed: true,
    },
  },
  createdAt: true,
  updatedAt: true,
};

const GRABMART_SELECT = {
  id: true,
  storeName: true,
  logo: true,
  description: true,
  phone: true,
  email: true,
  status: true,
  rating: true,
  ratingCount: true,
  isOpen: true,
  deliveryFee: true,
  minOrder: true,
  is24Hours: true,
  services: true,
  productTypes: true,
  bannerImages: true,
  longitude: true,
  latitude: true,
  address: true,
  city: true,
  area: true,
  facebookUrl: true,
  instagramUrl: true,
  twitterUrl: true,
  websiteUrl: true,
  paymentMethods: true,
  isVerified: true,
  verifiedAt: true,
  featured: true,
  featuredUntil: true,
  features: true,
  tags: true,
  whatsappNumber: true,
  totalReviews: true,
  isAcceptingOrders: true,
  isGrabGoExclusive: true,
  isGrabGoExclusiveUntil: true,
  vendorType: true,
  lastOnlineAt: true,
  createdAt: true,
  updatedAt: true,
};

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

const createLocation = (entity) => ({
  type: 'Point',
  coordinates: [entity.longitude, entity.latitude],
  lat: entity.latitude,
  lng: entity.longitude,
  address: entity.address || '',
  city: entity.city || '',
  area: entity.area || '',
});

const toDistanceKm = (entity) => {
  const rawDistance = entity.distance ?? entity._distance ?? null;
  if (rawDistance == null) return null;
  const numericDistance = Number(rawDistance);
  if (Number.isNaN(numericDistance)) return null;
  return numericDistance > 100 ? numericDistance / 1000 : numericDistance;
};

const formatRestaurantCard = (restaurant) => {
  if (!restaurant) return null;
  const { openingHours, ...rest } = restaurant;
  const computedIsOpen = Array.isArray(openingHours)
    ? isRestaurantOpen({ ...restaurant, openingHours })
    : restaurant.isOpen;
  const ratingMeta = normalizeRatingResponse({
    rating: restaurant.rating,
    ratingCount: restaurant.ratingCount,
    totalReviews: restaurant.totalReviews,
  });

  return {
    ...rest,
    vendorType: 'food',
    rating: ratingMeta.rating,
    rawRating: ratingMeta.rawRating,
    weightedRating: ratingMeta.weightedRating,
    ratingCount: ratingMeta.ratingCount,
    totalReviews: ratingMeta.totalReviews,
    reviewCount: ratingMeta.reviewCount,
    isOpen: computedIsOpen,
    location: createLocation(restaurant),
    restaurant_name: restaurant.restaurantName,
    is_open: computedIsOpen,
    delivery_fee: restaurant.deliveryFee,
    min_order: restaurant.minOrder,
    openingHours: formatOpeningHours(openingHours),
    isGrabGoExclusiveActive: isGrabGoExclusiveActive(rest),
    distance: toDistanceKm(restaurant),
  };
};

const formatStoreCard = (store, vendorType) => {
  if (!store) return null;
  const ratingMeta = normalizeRatingResponse({
    rating: store.rating,
    ratingCount: store.ratingCount,
    totalReviews: store.totalReviews,
  });

  return {
    ...store,
    vendorType,
    rating: ratingMeta.rating,
    rawRating: ratingMeta.rawRating,
    weightedRating: ratingMeta.weightedRating,
    ratingCount: ratingMeta.ratingCount,
    totalReviews: ratingMeta.totalReviews,
    reviewCount: ratingMeta.reviewCount,
    openingHours: formatOpeningHours(store.openingHours),
    isGrabGoExclusiveActive: isGrabGoExclusiveActive(store),
    store_name: store.storeName,
    is_open: store.isOpen,
    delivery_fee: store.deliveryFee,
    min_order: store.minOrder,
    operatingHours: store.operatingHoursString || 'Scheduled',
    location: createLocation(store),
    distance: toDistanceKm(store),
  };
};

const sortExclusiveVendors = (a, b) => {
  const aAvailable = a.isOpen === true && a.isAcceptingOrders !== false;
  const bAvailable = b.isOpen === true && b.isAcceptingOrders !== false;
  if (aAvailable !== bAvailable) {
    return Number(bAvailable) - Number(aAvailable);
  }

  const aDistance = a.distance ?? Number.POSITIVE_INFINITY;
  const bDistance = b.distance ?? Number.POSITIVE_INFINITY;
  if (aDistance !== bDistance) {
    return aDistance - bDistance;
  }

  const aRating = Number(a.weightedRating ?? a.rating ?? 0);
  const bRating = Number(b.weightedRating ?? b.rating ?? 0);
  if (aRating !== bRating) {
    return bRating - aRating;
  }

  if (Boolean(a.featured) !== Boolean(b.featured)) {
    return Number(Boolean(b.featured)) - Number(Boolean(a.featured));
  }

  const aName = (a.restaurantName || a.storeName || a.name || '').toLowerCase();
  const bName = (b.restaurantName || b.storeName || b.name || '').toLowerCase();
  return aName.localeCompare(bName);
};

const sortFreeDeliveryVendors = (a, b) => {
  const aFeatured = Boolean(a.featured);
  const bFeatured = Boolean(b.featured);
  if (aFeatured !== bFeatured) {
    return Number(bFeatured) - Number(aFeatured);
  }

  const aAvailable = a.isOpen === true && a.isAcceptingOrders !== false;
  const bAvailable = b.isOpen === true && b.isAcceptingOrders !== false;
  if (aAvailable !== bAvailable) {
    return Number(bAvailable) - Number(aAvailable);
  }

  const aOpen = a.isOpen === true;
  const bOpen = b.isOpen === true;
  if (aOpen !== bOpen) {
    return Number(bOpen) - Number(aOpen);
  }

  const aDistance = a.distance ?? Number.POSITIVE_INFINITY;
  const bDistance = b.distance ?? Number.POSITIVE_INFINITY;
  if (aDistance !== bDistance) {
    return aDistance - bDistance;
  }

  const aRating = Number(a.weightedRating ?? a.rating ?? 0);
  const bRating = Number(b.weightedRating ?? b.rating ?? 0);
  if (aRating !== bRating) {
    return bRating - aRating;
  }

  const aName = (a.restaurantName || a.storeName || a.name || '').toLowerCase();
  const bName = (b.restaurantName || b.storeName || b.name || '').toLowerCase();
  return aName.localeCompare(bName);
};

const getLocationContext = async ({ userLat, userLng, maxDistance = 15 }) => {
  const location = validateLocationParams(userLat, userLng, maxDistance);
  if (!location) {
    return {
      userLatitude: null,
      userLongitude: null,
      maxDistanceKm: maxDistance,
      nearbyRestaurantIds: null,
      nearbyVendors: [],
      freeDeliveryNearbyVendors: [],
    };
  }

  const { userLatitude, userLongitude, maxDistanceKm } = location;
  const bbox = getBoundingBox(userLatitude, userLongitude, maxDistanceKm);

  const nearbyRestaurantCandidates = await prisma.restaurant.findMany({
    where: {
      status: 'approved',
      latitude: { gte: bbox.minLat, lte: bbox.maxLat },
      longitude: { gte: bbox.minLng, lte: bbox.maxLng },
    },
    select: RESTAURANT_SELECT,
  });

  const filteredRestaurants = filterVendorsByDistance(
    nearbyRestaurantCandidates,
    userLatitude,
    userLongitude,
    maxDistanceKm,
  );

  const formattedNearbyVendors = filteredRestaurants
    .map((restaurant) => formatRestaurantCard(restaurant))
    .filter(Boolean);
  const freeDeliveryNearbyVendors = formattedNearbyVendors
    .filter((vendor) => Number(vendor.deliveryFee ?? vendor.delivery_fee ?? Number.POSITIVE_INFINITY) <= 0)
    .sort(sortFreeDeliveryVendors)
    .slice(0, HOME_SECTION_LIMIT);

  console.info('home_feed_free_delivery_candidates', {
    userLatitude,
    userLongitude,
    maxDistanceKm,
    nearbyRestaurantCandidateCount: nearbyRestaurantCandidates.length,
    filteredNearbyRestaurantCount: filteredRestaurants.length,
    formattedNearbyVendorCount: formattedNearbyVendors.length,
    freeDeliveryVendorCount: freeDeliveryNearbyVendors.length,
    freeDeliveryVendorSamples: freeDeliveryNearbyVendors.slice(0, 5).map((vendor) => ({
      id: vendor.id,
      name: vendor.restaurantName || vendor.storeName || vendor.name,
      distance: vendor.distance,
      deliveryFee: vendor.deliveryFee ?? vendor.delivery_fee,
      isOpen: vendor.isOpen,
      isAcceptingOrders: vendor.isAcceptingOrders,
    })),
  });

  return {
    userLatitude,
    userLongitude,
    maxDistanceKm,
    nearbyRestaurantIds: filteredRestaurants.map((restaurant) => restaurant.id),
    nearbyVendors: formattedNearbyVendors.slice(0, HOME_SECTION_LIMIT),
    freeDeliveryNearbyVendors,
  };
};

const getCategoriesWithFoods = async ({ nearbyRestaurantIds, userLat, userLng }) => {
  const categoryWhere = { isActive: true };

  if (Array.isArray(nearbyRestaurantIds)) {
    if (nearbyRestaurantIds.length === 0) {
      return [];
    }

    categoryWhere.foods = {
      some: {
        restaurantId: { in: nearbyRestaurantIds },
        isAvailable: true,
      },
    };
  }

  const categories = await prisma.category.findMany({
    where: categoryWhere,
    orderBy: { sortOrder: 'asc' },
    include: {
      _count: {
        select: { foods: true },
      },
    },
  });

  if (categories.length === 0) {
    return [];
  }

  const categoryIds = categories.map((category) => category.id);
  const foodsWhere = {
    isAvailable: true,
    categoryId: { in: categoryIds },
  };

  if (Array.isArray(nearbyRestaurantIds)) {
    foodsWhere.restaurantId = { in: nearbyRestaurantIds };
  }

  const foods = await prisma.food.findMany({
    where: foodsWhere,
    include: FOOD_INCLUDE_RELATIONS,
    orderBy: [{ categoryId: 'asc' }, { createdAt: 'desc' }],
  });

  const foodsByCategoryId = new Map();
  for (const food of formatFoodResponse(foods, userLat, userLng)) {
    const bucket = foodsByCategoryId.get(food.categoryId) || [];
    bucket.push(food);
    foodsByCategoryId.set(food.categoryId, bucket);
  }

  return categories.map((category) => ({
    ...category,
    items: foodsByCategoryId.get(category.id) || [],
  }));
};

const getDeals = async ({ nearbyRestaurantIds, userLat, userLng }) => {
  const where = {
    isAvailable: true,
    discountPercentage: { gt: 0 },
    OR: [{ discountEndDate: null }, { discountEndDate: { gte: new Date() } }],
  };

  if (Array.isArray(nearbyRestaurantIds)) {
    if (nearbyRestaurantIds.length === 0) {
      return [];
    }
    where.restaurantId = { in: nearbyRestaurantIds };
  }

  const deals = await prisma.food.findMany({
    where,
    include: FOOD_INCLUDE_RELATIONS,
    orderBy: { discountPercentage: 'desc' },
    take: HOME_SECTION_LIMIT,
  });

  return formatFoodResponse(deals, userLat, userLng);
};

const getPopularItems = async ({ nearbyRestaurantIds, userLat, userLng }) => {
  const where = { isAvailable: true };

  if (Array.isArray(nearbyRestaurantIds)) {
    if (nearbyRestaurantIds.length === 0) {
      return [];
    }
    where.restaurantId = { in: nearbyRestaurantIds };
  }

  const items = await prisma.food.findMany({
    where,
    include: FOOD_INCLUDE_RELATIONS,
    orderBy: [{ orderCount: 'desc' }, { rating: 'desc' }],
    take: HOME_SECTION_LIMIT,
    distinct: ['name'],
  });

  return formatFoodResponse(items, userLat, userLng);
};

const getTopRatedItems = async ({ nearbyRestaurantIds, userLat, userLng }) => {
  const where = {
    isAvailable: true,
    rating: { gte: 4.5 },
  };

  if (Array.isArray(nearbyRestaurantIds)) {
    if (nearbyRestaurantIds.length === 0) {
      return [];
    }
    where.restaurantId = { in: nearbyRestaurantIds };
  }

  const items = await prisma.food.findMany({
    where,
    include: FOOD_INCLUDE_RELATIONS,
    orderBy: [{ rating: 'desc' }, { totalReviews: 'desc' }],
    take: HOME_SECTION_LIMIT,
    distinct: ['name'],
  });

  return formatFoodResponse(items, userLat, userLng);
};

const getRecommendedItems = async ({ userId, nearbyRestaurantIds, userLat, userLng, page = 1, limit = HOME_RECOMMENDED_LIMIT }) => {
  if (userId) {
    try {
      const mlLimit = 50;
      const mlRecommendations = await mlClient.getFoodRecommendations(userId, mlLimit);

      if (Array.isArray(mlRecommendations) && mlRecommendations.length > 0) {
        const startIndex = (page - 1) * limit;
        const endIndex = startIndex + limit;
        const paginatedResults = mlRecommendations.slice(startIndex, endIndex);
        const foodIds = paginatedResults.map((rec) => rec.food_id || rec.id).filter(Boolean);

        if (foodIds.length > 0) {
          const foods = await prisma.food.findMany({
            where: {
              id: { in: foodIds },
              isAvailable: true,
            },
            include: FOOD_INCLUDE_RELATIONS,
          });

          const filteredFoods = Array.isArray(nearbyRestaurantIds)
            ? foods.filter((food) => nearbyRestaurantIds.includes(food.restaurantId))
            : foods;
          const sortedFoods = foodIds
            .map((id) => filteredFoods.find((food) => food.id === id))
            .filter(Boolean);

          return {
            items: formatFoodResponse(sortedFoods, userLat, userLng),
            page,
            hasMore: endIndex < mlRecommendations.length,
          };
        }
      }
    } catch (error) {
      console.error('[HOME FEED] ML recommendation fallback:', error.message);
    }
  }

  if (Array.isArray(nearbyRestaurantIds) && nearbyRestaurantIds.length === 0) {
    return { items: [], page, hasMore: false };
  }

  const popularCount = Math.ceil(limit * 0.4);
  const ratedCount = Math.ceil(limit * 0.3);
  const dealsCount = Math.ceil(limit * 0.2);
  const randomCount = limit - (popularCount + ratedCount + dealsCount);
  const skip = (page - 1) * limit;
  const locationWhere = Array.isArray(nearbyRestaurantIds)
    ? { restaurantId: { in: nearbyRestaurantIds } }
    : {};

  const [popular, topRated, deals, random] = await Promise.all([
    prisma.food.findMany({
      where: { isAvailable: true, ...locationWhere },
      orderBy: { orderCount: 'desc' },
      take: popularCount,
      skip: Math.floor(skip * 0.4),
      include: FOOD_INCLUDE_RELATIONS,
    }),
    prisma.food.findMany({
      where: { isAvailable: true, rating: { gte: 4.5 }, ...locationWhere },
      orderBy: { rating: 'desc' },
      take: ratedCount,
      skip: Math.floor(skip * 0.3),
      include: FOOD_INCLUDE_RELATIONS,
    }),
    prisma.food.findMany({
      where: { isAvailable: true, discountPercentage: { gt: 0 }, ...locationWhere },
      orderBy: { discountPercentage: 'desc' },
      take: dealsCount,
      skip: Math.floor(skip * 0.2),
      include: FOOD_INCLUDE_RELATIONS,
    }),
    prisma.food.findMany({
      where: { isAvailable: true, ...locationWhere },
      take: randomCount,
      skip: Math.floor(skip * 0.1),
      include: FOOD_INCLUDE_RELATIONS,
    }),
  ]);

  const uniqueFoods = [];
  const seen = new Set();
  for (const food of [...popular, ...topRated, ...deals, ...random]) {
    if (!food || seen.has(food.id)) continue;
    seen.add(food.id);
    uniqueFoods.push(food);
  }

  for (let index = uniqueFoods.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    [uniqueFoods[index], uniqueFoods[swapIndex]] = [
      uniqueFoods[swapIndex],
      uniqueFoods[index],
    ];
  }

  return {
    items: formatFoodResponse(uniqueFoods.slice(0, limit), userLat, userLng),
    page,
    hasMore: page < 5,
  };
};

const getOrderHistoryItems = async ({ userId, userLat, userLng }) => {
  if (!userId) {
    return [];
  }

  const orders = await prisma.order.findMany({
    where: {
      customerId: userId,
      orderType: 'food',
      OR: [{ paymentMethod: 'cash' }, { paymentStatus: { in: ['paid', 'successful'] } }],
      status: {
        in: ['pending', 'confirmed', 'preparing', 'ready', 'picked_up', 'on_the_way', 'delivered'],
      },
    },
    include: {
      items: {
        where: { itemType: 'Food' },
        include: {
          food: {
            include: FOOD_INCLUDE_RELATIONS,
          },
        },
      },
    },
    orderBy: [{ deliveredDate: 'desc' }, { orderDate: 'desc' }],
    take: 50,
  });

  if (!orders.length) {
    return [];
  }

  const itemsMap = new Map();
  for (const order of orders) {
    for (const item of order.items) {
      if (item.itemType !== 'Food' || !item.food) continue;
      const itemId = item.food.id;
      const orderTimestamp = order.deliveredDate || order.orderDate || order.createdAt;
      const existing = itemsMap.get(itemId);
      if (!existing) {
        itemsMap.set(itemId, {
          item: item.food,
          lastOrdered: orderTimestamp,
          timesOrdered: 1,
          totalQuantity: item.quantity,
        });
        continue;
      }

      existing.timesOrdered += 1;
      existing.totalQuantity += item.quantity;
      if (orderTimestamp > existing.lastOrdered) {
        existing.lastOrdered = orderTimestamp;
      }
    }
  }

  const orderedEntries = Array.from(itemsMap.values())
    .sort((a, b) => b.lastOrdered - a.lastOrdered)
    .slice(0, HOME_RECOMMENDED_LIMIT);
  const formattedFoods = formatFoodResponse(
    orderedEntries.map((entry) => entry.item),
    userLat,
    userLng,
  );

  return formattedFoods.map((item, index) => {
    const entry = orderedEntries[index];
    return {
      ...item,
      lastOrderedAt: entry.lastOrdered,
      timesOrdered: entry.timesOrdered,
      totalQuantity: entry.totalQuantity,
    };
  });
};

const getPromotionalBanners = async () => {
  const now = new Date();
  return prisma.promotionalBanner.findMany({
    where: {
      isActive: true,
      AND: [{ startDate: { lte: now } }, { endDate: { gte: now } }],
    },
    orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
    take: HOME_SECTION_LIMIT,
  });
};

const attachDistance = (vendor, userLatitude, userLongitude) => {
  if (userLatitude == null || userLongitude == null) {
    return vendor;
  }

  const [withDistance] = filterVendorsByDistance([vendor], userLatitude, userLongitude, 1000);
  if (!withDistance) {
    return vendor;
  }

  return withDistance;
};

const getExclusiveVendors = async ({
  userLatitude,
  userLongitude,
  maxDistanceKm,
}) => {
  const now = new Date();
  const exclusiveWhere = {
    status: 'approved',
    isGrabGoExclusive: true,
    OR: [{ isGrabGoExclusiveUntil: null }, { isGrabGoExclusiveUntil: { gt: now } }],
  };

  const [restaurants, groceries, pharmacies, grabmarts] = await Promise.all([
    prisma.restaurant.findMany({
      where: exclusiveWhere,
      select: RESTAURANT_SELECT,
      orderBy: [{ featured: 'desc' }, { rating: 'desc' }, { ratingCount: 'desc' }],
      take: HOME_EXCLUSIVE_QUERY_LIMIT,
    }),
    prisma.groceryStore.findMany({
      where: exclusiveWhere,
      select: GROCERY_SELECT,
      orderBy: [{ featured: 'desc' }, { rating: 'desc' }, { ratingCount: 'desc' }],
      take: HOME_EXCLUSIVE_QUERY_LIMIT,
    }),
    prisma.pharmacyStore.findMany({
      where: exclusiveWhere,
      select: PHARMACY_SELECT,
      orderBy: [{ featured: 'desc' }, { rating: 'desc' }, { ratingCount: 'desc' }],
      take: HOME_EXCLUSIVE_QUERY_LIMIT,
    }),
    prisma.grabMartStore.findMany({
      where: exclusiveWhere,
      select: GRABMART_SELECT,
      orderBy: [{ featured: 'desc' }, { rating: 'desc' }, { ratingCount: 'desc' }],
      take: HOME_EXCLUSIVE_QUERY_LIMIT,
    }),
  ]);

  let formatted = [
    ...restaurants.map((restaurant) => formatRestaurantCard(attachDistance(restaurant, userLatitude, userLongitude))),
    ...groceries.map((store) => formatStoreCard(attachDistance(store, userLatitude, userLongitude), 'grocery')),
    ...pharmacies.map((store) => formatStoreCard(attachDistance(store, userLatitude, userLongitude), 'pharmacy')),
    ...grabmarts.map((store) => formatStoreCard(attachDistance(store, userLatitude, userLongitude), 'grabmart')),
  ];

  if (userLatitude != null && userLongitude != null) {
    formatted = formatted.filter(
      (vendor) =>
          vendor.distance != null &&
          vendor.distance <= (maxDistanceKm ?? Number.POSITIVE_INFINITY),
    );
  }

  formatted.sort(sortExclusiveVendors);
  return formatted.slice(0, HOME_SECTION_LIMIT);
};

const fetchFoodHomeFeed = async ({ userId, userLat, userLng, maxDistance = 15 }) => {
  const locationContext = await getLocationContext({ userLat, userLng, maxDistance });
  const {
    nearbyRestaurantIds,
    nearbyVendors,
    freeDeliveryNearbyVendors,
    userLatitude,
    userLongitude,
    maxDistanceKm,
  } = locationContext;

  const [
    categories,
    deals,
    orderHistory,
    popular,
    topRated,
    recommended,
    promoBanners,
    exclusiveVendors,
  ] = await Promise.all([
    getCategoriesWithFoods({ nearbyRestaurantIds, userLat, userLng }),
    getDeals({ nearbyRestaurantIds, userLat, userLng }),
    getOrderHistoryItems({ userId, userLat, userLng }),
    getPopularItems({ nearbyRestaurantIds, userLat, userLng }),
    getTopRatedItems({ nearbyRestaurantIds, userLat, userLng }),
    getRecommendedItems({ userId, nearbyRestaurantIds, userLat, userLng }),
    getPromotionalBanners(),
    getExclusiveVendors({ userLatitude, userLongitude, maxDistanceKm }),
  ]);

  return {
    categories,
    deals,
    orderHistory,
    popular,
    topRated,
    recommended,
    promoBanners,
    nearbyVendors,
    freeDeliveryNearbyVendors,
    exclusiveVendors,
    fetchedAt: new Date().toISOString(),
  };
};

module.exports = {
  fetchFoodHomeFeed,
};
