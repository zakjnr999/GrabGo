const prisma = require('../config/prisma');
const { FOOD_INCLUDE_RELATIONS, formatFoodResponse } = require('../utils/food_helpers');
const { normalizeRatingResponse } = require('../utils/rating_calculator');
const {
  getBoundingBox,
  filterVendorsByDistance,
  validateLocationParams,
} = require('../utils/vendor_distance_filter');
const {
  formatRestaurantCard,
  formatStoreCard,
} = require('../utils/vendor_card_formatter');

const DEFAULT_ITEM_LIMIT = 18;
const DEFAULT_VENDOR_LIMIT = 8;
const DEFAULT_CATEGORY_LIMIT = 8;
const DEFAULT_SUGGESTION_LIMIT = 8;
const MAX_DISTANCE_KM = 25;
const SORTS = new Set([
  'relevance',
  'rating',
  'fastest',
  'price_low',
  'price_high',
  'newest',
]);
const DELIVERY_TIME_MAP = {
  'Under 20 min': 20,
  '20-30 min': 30,
  '30-45 min': 45,
};
const DISTANCE_MAP = {
  'Under 1 km': 1,
  '1-3 km': 3,
  '3-5 km': 5,
};
const NEW_ITEM_LOOKBACK_MS = 1000 * 60 * 60 * 24 * 14;

function normalizeText(value) {
  return String(value ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function parseCsv(value) {
  if (!value) return [];
  if (Array.isArray(value)) {
    return value.map((entry) => String(entry).trim()).filter(Boolean);
  }
  return String(value)
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
}

function parseBool(value) {
  if (value === true || value === false) return value;
  if (typeof value === 'string') return value.toLowerCase() === 'true';
  return false;
}

function parseNumber(value, fallback = null) {
  if (value === null || value === undefined || value === '') return fallback;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function clampPositiveInt(value, fallback, max) {
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(parsed, max);
}

function resolveMaxDistanceKm(distanceLabel, explicitMaxDistance) {
  const explicit = parseNumber(explicitMaxDistance, null);
  if (explicit != null && explicit > 0) return Math.min(explicit, MAX_DISTANCE_KM);
  if (distanceLabel && DISTANCE_MAP[distanceLabel]) return DISTANCE_MAP[distanceLabel];
  return 15;
}

function normalizeSort(sort) {
  return SORTS.has(sort) ? sort : 'relevance';
}

function scoreTextMatch(query, fields) {
  const normalizedQuery = normalizeText(query);
  if (!normalizedQuery) return 0;

  let score = 0;
  for (const field of fields) {
    const normalizedField = normalizeText(field);
    if (!normalizedField) continue;
    if (normalizedField === normalizedQuery) score += 220;
    else if (normalizedField.startsWith(normalizedQuery)) score += 170;
    else if (normalizedField.includes(normalizedQuery)) score += 120;
  }
  return score;
}

function applySort(items, sort, getters) {
  const {
    priceGetter,
    ratingGetter,
    speedGetter,
    createdAtGetter,
    relevanceGetter,
  } = getters;
  const sorted = [...items];
  sorted.sort((a, b) => {
    if (sort === 'rating') return ratingGetter(b) - ratingGetter(a);
    if (sort === 'fastest') return speedGetter(a) - speedGetter(b);
    if (sort === 'price_low') return priceGetter(a) - priceGetter(b);
    if (sort === 'price_high') return priceGetter(b) - priceGetter(a);
    if (sort === 'newest') return createdAtGetter(b) - createdAtGetter(a);
    const relevanceCompare = relevanceGetter(b) - relevanceGetter(a);
    if (relevanceCompare !== 0) return relevanceCompare;
    return ratingGetter(b) - ratingGetter(a);
  });
  return sorted;
}

function buildSuggestions({ query, categories, vendors, items, limit }) {
  const normalizedQuery = normalizeText(query);
  if (!normalizedQuery) return [];

  const candidates = [];
  for (const category of categories) {
    candidates.push({
      value: category.name,
      type: 'category',
      subtitle: `${category.itemCount} items`,
      score: scoreTextMatch(query, [category.name]),
    });
  }
  for (const vendor of vendors) {
    const vendorName =
      vendor.restaurantName || vendor.storeName || vendor.name || vendor.displayName;
    candidates.push({
      value: vendorName,
      type: 'vendor',
      subtitle: vendor.vendorType,
      score: scoreTextMatch(query, [vendorName, vendor.area, vendor.city]),
    });
  }
  for (const item of items) {
    candidates.push({
      value: item.name,
      type: 'item',
      subtitle:
        item.sellerName ||
        item.storeName ||
        item.categoryName ||
        item.category?.name ||
        '',
      score: scoreTextMatch(query, [
        item.name,
        item.sellerName,
        item.storeName,
        item.categoryName,
        item.category?.name,
      ]),
    });
  }

  const seen = new Set();
  return candidates
    .filter((candidate) => candidate.score > 0 && candidate.value)
    .sort((a, b) => b.score - a.score)
    .filter((candidate) => {
      const key = `${candidate.type}:${candidate.value.toLowerCase()}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    })
    .slice(0, limit)
    .map(({ value, type, subtitle }) => ({ value, type, subtitle }));
}

function categoryToResponse(category, serviceType, itemCount) {
  return {
    id: category.id,
    name: category.name,
    emoji: category.emoji || '',
    serviceType,
    isFood: serviceType === 'food',
    itemCount,
  };
}

function formatGenericStoreItem(item, storeFormatter) {
  const ratingMeta = normalizeRatingResponse({
    rating: item.rating,
    reviewCount: item.reviewCount,
    totalReviews: item.totalReviews,
  });

  return {
    ...item,
    rating: ratingMeta.rating,
    rawRating: ratingMeta.rawRating,
    weightedRating: ratingMeta.weightedRating,
    reviewCount: ratingMeta.reviewCount,
    ratingCount: ratingMeta.ratingCount,
    totalReviews: ratingMeta.totalReviews,
    categoryName: item.category?.name ?? null,
    categoryEmoji: item.category?.emoji ?? null,
    storeName: item.store?.storeName ?? null,
    storeLogo: item.store?.logo ?? null,
    store: item.store && typeof item.store === 'object'
      ? storeFormatter(item.store)
      : item.store,
  };
}

function createAndWhere(baseConditions = []) {
  return { AND: baseConditions.filter(Boolean) };
}

function buildFoodVendorWhere({ query, filters, nearbyRestaurantIds, deliveryLimit }) {
  const and = [{ status: 'approved' }];

  if (query) {
    and.push({
      OR: [
        { restaurantName: { contains: query, mode: 'insensitive' } },
        { description: { contains: query, mode: 'insensitive' } },
        { foodType: { contains: query, mode: 'insensitive' } },
        { address: { contains: query, mode: 'insensitive' } },
        { city: { contains: query, mode: 'insensitive' } },
        { area: { contains: query, mode: 'insensitive' } },
      ],
    });
  }

  if (filters.minRating != null) {
    and.push({ rating: { gte: filters.minRating } });
  }

  if (deliveryLimit != null) {
    and.push({ averageDeliveryTime: { lte: deliveryLimit } });
  }

  if (filters.fast) {
    and.push({ averageDeliveryTime: { lte: 30 } });
  }

  if (filters.selectedRestaurants.length) {
    and.push({
      OR: filters.selectedRestaurants.map((name) => ({
        restaurantName: { equals: name, mode: 'insensitive' },
      })),
    });
  }

  if (filters.selectedCategories.length || filters.onSale) {
    const foodWhere = { isAvailable: true };
    if (filters.selectedCategories.length) {
      foodWhere.categoryId = { in: filters.selectedCategories };
    }
    if (filters.onSale) {
      foodWhere.discountPercentage = { gt: 0 };
      foodWhere.OR = [
        { discountEndDate: null },
        { discountEndDate: { gte: new Date() } },
      ];
    }
    and.push({ foods: { some: foodWhere } });
  }

  if (nearbyRestaurantIds) {
    and.push({ id: { in: nearbyRestaurantIds.length ? nearbyRestaurantIds : ['__none__'] } });
  }

  return createAndWhere(and);
}

function buildFoodItemWhere({ query, filters, nearbyRestaurantIds, deliveryLimit }) {
  const and = [{ isAvailable: true }];

  if (query) {
    and.push({
      OR: [
        { name: { contains: query, mode: 'insensitive' } },
        { description: { contains: query, mode: 'insensitive' } },
        { category: { name: { contains: query, mode: 'insensitive' } } },
        { restaurant: { restaurantName: { contains: query, mode: 'insensitive' } } },
      ],
    });
  }

  if (filters.selectedCategories.length) {
    and.push({ categoryId: { in: filters.selectedCategories } });
  }

  if (filters.minPrice > 0 || filters.maxPrice < 10000) {
    and.push({ price: { gte: filters.minPrice, lte: filters.maxPrice } });
  }

  if (filters.minRating != null) {
    and.push({ rating: { gte: filters.minRating } });
  }

  if (filters.onSale) {
    and.push({
      discountPercentage: { gt: 0 },
      OR: [{ discountEndDate: null }, { discountEndDate: { gte: new Date() } }],
    });
  }

  if (filters.isNew) {
    and.push({ createdAt: { gte: new Date(Date.now() - NEW_ITEM_LOOKBACK_MS) } });
  }

  if (filters.dietary) {
    and.push({
      OR: [
        { name: { contains: filters.dietary, mode: 'insensitive' } },
        { description: { contains: filters.dietary, mode: 'insensitive' } },
        { ingredients: { has: filters.dietary } },
      ],
    });
  }

  const restaurantAnd = [{ status: 'approved' }];
  if (nearbyRestaurantIds) {
    restaurantAnd.push({ id: { in: nearbyRestaurantIds.length ? nearbyRestaurantIds : ['__none__'] } });
  }
  if (filters.selectedRestaurants.length) {
    restaurantAnd.push({
      OR: filters.selectedRestaurants.map((name) => ({
        restaurantName: { equals: name, mode: 'insensitive' },
      })),
    });
  }
  if (deliveryLimit != null) {
    restaurantAnd.push({ averageDeliveryTime: { lte: deliveryLimit } });
  }
  if (filters.fast) {
    restaurantAnd.push({ averageDeliveryTime: { lte: 30 } });
  }
  and.push({ restaurant: createAndWhere(restaurantAnd).AND.length === 1 ? restaurantAnd[0] : createAndWhere(restaurantAnd) });

  return createAndWhere(and);
}

async function resolveNearbyIds({ model, where, location }) {
  if (!location) return null;
  const bbox = getBoundingBox(
    location.userLatitude,
    location.userLongitude,
    location.maxDistanceKm,
  );
  const candidates = await model.findMany({
    where: {
      ...where,
      latitude: { gte: bbox.minLat, lte: bbox.maxLat },
      longitude: { gte: bbox.minLng, lte: bbox.maxLng },
    },
    select: { id: true, latitude: true, longitude: true },
  });
  return filterVendorsByDistance(
    candidates,
    location.userLatitude,
    location.userLongitude,
    location.maxDistanceKm,
  ).map((entry) => entry.id);
}

async function resolveFoodSearch({ query, filters, sort, itemLimit, vendorLimit, categoryLimit, userLat, userLng, maxDistanceKm }) {
  const location = validateLocationParams(userLat, userLng, maxDistanceKm);
  const nearbyRestaurantIds = await resolveNearbyIds({
    model: prisma.restaurant,
    where: { status: 'approved' },
    location,
  });
  const deliveryLimit = filters.deliveryTime
    ? DELIVERY_TIME_MAP[filters.deliveryTime] ?? null
    : null;

  const restaurants = await prisma.restaurant.findMany({
    where: buildFoodVendorWhere({ query, filters, nearbyRestaurantIds, deliveryLimit }),
    select: {
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
      totalReviews: true,
      isAcceptingOrders: true,
      isGrabGoExclusive: true,
      isGrabGoExclusiveUntil: true,
      lastOnlineAt: true,
      rating: true,
      ratingCount: true,
      isOpen: true,
      longitude: true,
      latitude: true,
      address: true,
      city: true,
      area: true,
      openingHours: {
        select: { dayOfWeek: true, openTime: true, closeTime: true, isClosed: true },
      },
      createdAt: true,
    },
    take: Math.max(vendorLimit * 3, 24),
  });

  let vendors = restaurants.map(formatRestaurantCard).filter(Boolean);
  if (location) {
    vendors = vendors.filter(
      (vendor) => (vendor.distance ?? Number.POSITIVE_INFINITY) <= location.maxDistanceKm,
    );
  }
  vendors = applySort(vendors, sort, {
    priceGetter: (vendor) => Number(vendor.deliveryFee ?? 0),
    ratingGetter: (vendor) => Number(vendor.weightedRating ?? vendor.rating ?? 0),
    speedGetter: (vendor) => Number(vendor.averageDeliveryTime ?? 9999),
    createdAtGetter: (vendor) => new Date(vendor.createdAt ?? 0).getTime(),
    relevanceGetter: (vendor) =>
      scoreTextMatch(query, [
        vendor.restaurantName,
        vendor.foodType,
        vendor.description,
        vendor.area,
        vendor.city,
      ]),
  }).slice(0, vendorLimit);

  let items = formatFoodResponse(
    await prisma.food.findMany({
      where: buildFoodItemWhere({ query, filters, nearbyRestaurantIds, deliveryLimit }),
      include: FOOD_INCLUDE_RELATIONS,
      take: Math.max(itemLimit * 4, 48),
    }),
    userLat,
    userLng,
  );

  if (filters.popular) {
    items = items.filter((item) => Number(item.orderCount ?? 0) > 0);
  }

  items = applySort(items, sort, {
    priceGetter: (item) => Number(item.price ?? 0),
    ratingGetter: (item) => Number(item.weightedRating ?? item.rating ?? 0),
    speedGetter: (item) => Number(item.deliveryTimeMinutes ?? item.restaurant?.averageDeliveryTime ?? 9999),
    createdAtGetter: (item) => new Date(item.createdAt ?? 0).getTime(),
    relevanceGetter: (item) =>
      scoreTextMatch(query, [
        item.name,
        item.description,
        item.sellerName,
        item.categoryName,
      ]),
  }).slice(0, itemLimit);

  const categories = (
    await prisma.category.findMany({
      where: {
        isActive: true,
        ...(query ? { name: { contains: query, mode: 'insensitive' } } : {}),
      },
      include: {
        foods: {
          where: {
            isAvailable: true,
            restaurant: createAndWhere([
              { status: 'approved' },
              nearbyRestaurantIds
                ? { id: { in: nearbyRestaurantIds.length ? nearbyRestaurantIds : ['__none__'] } }
                : null,
            ]),
          },
          select: { id: true },
        },
      },
      take: Math.max(categoryLimit * 3, 18),
    })
  )
    .map((category) => categoryToResponse(category, 'food', category.foods.length))
    .filter((category) => category.itemCount > 0)
    .sort((a, b) => b.itemCount - a.itemCount)
    .slice(0, categoryLimit);

  return { vendors, items, categories };
}

async function resolveStoreSearch({ serviceType, query, filters, sort, itemLimit, vendorLimit, categoryLimit, userLat, userLng, maxDistanceKm }) {
  const configs = {
    groceries: {
      vendorType: 'grocery',
      storeModel: prisma.groceryStore,
      itemModel: prisma.groceryItem,
      categoryModel: prisma.groceryCategory,
      statusField: 'status',
      nameField: 'storeName',
      relationField: 'store',
      formatStore: (store) => formatStoreCard(store, 'grocery'),
      hasOpeningHours: true,
      hasDeliveryTime: true,
    },
    pharmacy: {
      vendorType: 'pharmacy',
      storeModel: prisma.pharmacyStore,
      itemModel: prisma.pharmacyItem,
      categoryModel: prisma.pharmacyCategory,
      statusField: 'status',
      nameField: 'storeName',
      relationField: 'store',
      formatStore: (store) => formatStoreCard(store, 'pharmacy'),
      hasOpeningHours: true,
      hasDeliveryTime: true,
    },
    convenience: {
      vendorType: 'grabmart',
      storeModel: prisma.grabMartStore,
      itemModel: prisma.grabMartItem,
      categoryModel: prisma.grabMartCategory,
      statusField: 'status',
      nameField: 'storeName',
      relationField: 'store',
      formatStore: (store) => formatStoreCard(store, 'grabmart'),
      hasOpeningHours: false,
      hasDeliveryTime: false,
    },
  };

  const config = configs[serviceType];
  if (!config) {
    throw new Error(`Unsupported service type: ${serviceType}`);
  }

  const location = validateLocationParams(userLat, userLng, maxDistanceKm);
  const nearbyStoreIds = await resolveNearbyIds({
    model: config.storeModel,
    where: { [config.statusField]: 'approved', isDeleted: false },
    location,
  });
  const deliveryLimit = config.hasDeliveryTime && filters.deliveryTime
    ? DELIVERY_TIME_MAP[filters.deliveryTime] ?? null
    : null;

  const vendorAnd = [{ [config.statusField]: 'approved' }, { isDeleted: false }];
  if (query) {
    vendorAnd.push({
      OR: [
        { [config.nameField]: { contains: query, mode: 'insensitive' } },
        { description: { contains: query, mode: 'insensitive' } },
        { address: { contains: query, mode: 'insensitive' } },
        { city: { contains: query, mode: 'insensitive' } },
        { area: { contains: query, mode: 'insensitive' } },
      ],
    });
  }
  if (filters.minRating != null) vendorAnd.push({ rating: { gte: filters.minRating } });
  if (deliveryLimit != null) vendorAnd.push({ averageDeliveryTime: { lte: deliveryLimit } });
  if (config.hasDeliveryTime && filters.fast) vendorAnd.push({ averageDeliveryTime: { lte: 30 } });
  if (filters.selectedRestaurants.length) {
    vendorAnd.push({
      OR: filters.selectedRestaurants.map((name) => ({
        [config.nameField]: { equals: name, mode: 'insensitive' },
      })),
    });
  }
  if (filters.selectedCategories.length || filters.onSale) {
    const itemWhere = { isAvailable: true };
    if (filters.selectedCategories.length) {
      itemWhere.categoryId = { in: filters.selectedCategories };
    }
    if (filters.onSale) {
      itemWhere.discountPercentage = { gt: 0 };
      itemWhere.OR = [{ discountEndDate: null }, { discountEndDate: { gte: new Date() } }];
    }
    vendorAnd.push({ items: { some: itemWhere } });
  }
  if (nearbyStoreIds) vendorAnd.push({ id: { in: nearbyStoreIds.length ? nearbyStoreIds : ['__none__'] } });

  const storeInclude = {};
  if (config.hasOpeningHours) {
    storeInclude.openingHours = true;
  }
  if (filters.selectedCategories.length || filters.onSale) {
    const itemWhere = { isAvailable: true };
    if (filters.selectedCategories.length) {
      itemWhere.categoryId = { in: filters.selectedCategories };
    }
    if (filters.onSale) {
      itemWhere.discountPercentage = { gt: 0 };
      itemWhere.OR = [{ discountEndDate: null }, { discountEndDate: { gte: new Date() } }];
    }
    storeInclude.items = { where: itemWhere, select: { id: true } };
  }

  const stores = await config.storeModel.findMany({
    where: createAndWhere(vendorAnd),
    include: storeInclude,
    take: Math.max(vendorLimit * 3, 24),
  });

  let vendors = stores
    .filter((store) => !Array.isArray(store.items) || store.items.length > 0)
    .map(config.formatStore)
    .filter(Boolean);
  if (location) {
    vendors = vendors.filter(
      (vendor) => (vendor.distance ?? Number.POSITIVE_INFINITY) <= location.maxDistanceKm,
    );
  }
  vendors = applySort(vendors, sort, {
    priceGetter: (vendor) => Number(vendor.deliveryFee ?? 0),
    ratingGetter: (vendor) => Number(vendor.weightedRating ?? vendor.rating ?? 0),
    speedGetter: (vendor) => Number(vendor.averageDeliveryTime ?? 9999),
    createdAtGetter: (vendor) => new Date(vendor.createdAt ?? 0).getTime(),
    relevanceGetter: (vendor) => scoreTextMatch(query, [vendor.storeName, vendor.description, vendor.area, vendor.city]),
  }).slice(0, vendorLimit);

  const itemAnd = [{ isAvailable: true }];
  if (query) {
    itemAnd.push({
      OR: [
        { name: { contains: query, mode: 'insensitive' } },
        { description: { contains: query, mode: 'insensitive' } },
        { brand: { contains: query, mode: 'insensitive' } },
        { category: { name: { contains: query, mode: 'insensitive' } } },
        { store: { [config.nameField]: { contains: query, mode: 'insensitive' } } },
      ],
    });
  }
  if (filters.selectedCategories.length) itemAnd.push({ categoryId: { in: filters.selectedCategories } });
  if (filters.minPrice > 0 || filters.maxPrice < 10000) {
    itemAnd.push({ price: { gte: filters.minPrice, lte: filters.maxPrice } });
  }
  if (filters.minRating != null) itemAnd.push({ rating: { gte: filters.minRating } });
  if (filters.onSale) {
    itemAnd.push({
      discountPercentage: { gt: 0 },
      OR: [{ discountEndDate: null }, { discountEndDate: { gte: new Date() } }],
    });
  }
  if (filters.isNew) {
    itemAnd.push({ createdAt: { gte: new Date(Date.now() - NEW_ITEM_LOOKBACK_MS) } });
  }
  if (filters.dietary) {
    itemAnd.push({
      OR: [
        { name: { contains: filters.dietary, mode: 'insensitive' } },
        { description: { contains: filters.dietary, mode: 'insensitive' } },
        { tags: { has: filters.dietary } },
      ],
    });
  }

  const storeAnd = [{ [config.statusField]: 'approved' }, { isDeleted: false }];
  if (nearbyStoreIds) storeAnd.push({ id: { in: nearbyStoreIds.length ? nearbyStoreIds : ['__none__'] } });
  if (filters.selectedRestaurants.length) {
    storeAnd.push({
      OR: filters.selectedRestaurants.map((name) => ({
        [config.nameField]: { equals: name, mode: 'insensitive' },
      })),
    });
  }
  if (deliveryLimit != null) storeAnd.push({ averageDeliveryTime: { lte: deliveryLimit } });
  if (config.hasDeliveryTime && filters.fast) storeAnd.push({ averageDeliveryTime: { lte: 30 } });
  itemAnd.push({ [config.relationField]: createAndWhere(storeAnd) });

  const itemInclude = {
    category: { select: { name: true, emoji: true } },
    store: config.hasOpeningHours ? { include: { openingHours: true } } : true,
  };

  let items = (
    await config.itemModel.findMany({
      where: createAndWhere(itemAnd),
      include: itemInclude,
      take: Math.max(itemLimit * 4, 48),
    })
  ).map((item) => formatGenericStoreItem(item, config.formatStore));

  if (filters.popular) {
    items = items.filter((item) => Number(item.orderCount ?? 0) > 0);
  }

  items = applySort(items, sort, {
    priceGetter: (item) => Number(item.price ?? 0),
    ratingGetter: (item) => Number(item.weightedRating ?? item.rating ?? 0),
    speedGetter: (item) => Number(item.store?.averageDeliveryTime ?? 9999),
    createdAtGetter: (item) => new Date(item.createdAt ?? 0).getTime(),
    relevanceGetter: (item) =>
      scoreTextMatch(query, [
        item.name,
        item.description,
        item.brand,
        item.storeName,
        item.categoryName,
      ]),
  }).slice(0, itemLimit);

  const categoryWhere = {
    isActive: true,
    ...(query ? { name: { contains: query, mode: 'insensitive' } } : {}),
  };

  const categories = (
    await config.categoryModel.findMany({
      where: categoryWhere,
      include: {
        items: {
          where: {
            isAvailable: true,
            [config.relationField]: createAndWhere([
              { [config.statusField]: 'approved' },
              { isDeleted: false },
              nearbyStoreIds
                ? { id: { in: nearbyStoreIds.length ? nearbyStoreIds : ['__none__'] } }
                : null,
            ]),
          },
          select: { id: true },
        },
      },
      take: Math.max(categoryLimit * 3, 18),
    })
  )
    .map((category) => categoryToResponse(category, serviceType, category.items.length))
    .filter((category) => category.itemCount > 0)
    .sort((a, b) => b.itemCount - a.itemCount)
    .slice(0, categoryLimit);

  return { vendors, items, categories };
}

function parseFilters(raw) {
  return {
    minPrice: parseNumber(raw.minPrice, 0) ?? 0,
    maxPrice: parseNumber(raw.maxPrice, 10000) ?? 10000,
    minRating: parseNumber(raw.minRating, null),
    selectedCategories: parseCsv(raw.categoryIds),
    selectedRestaurants: parseCsv(raw.vendorNames),
    onSale: parseBool(raw.onSale),
    popular: parseBool(raw.popular),
    isNew: parseBool(raw.isNew),
    fast: parseBool(raw.fast),
    dietary: raw.dietary ? String(raw.dietary) : null,
    distance: raw.distance ? String(raw.distance) : null,
    deliveryTime: raw.deliveryTime ? String(raw.deliveryTime) : null,
  };
}

async function searchCatalog(rawOptions) {
  const query = String(rawOptions.q ?? '').trim();
  const serviceType = String(rawOptions.serviceType ?? 'food').trim() || 'food';
  const sort = normalizeSort(rawOptions.sort);
  const filters = parseFilters(rawOptions);
  const itemLimit = clampPositiveInt(rawOptions.itemLimit, DEFAULT_ITEM_LIMIT, 30);
  const vendorLimit = clampPositiveInt(rawOptions.vendorLimit, DEFAULT_VENDOR_LIMIT, 16);
  const categoryLimit = clampPositiveInt(rawOptions.categoryLimit, DEFAULT_CATEGORY_LIMIT, 16);
  const suggestionLimit = clampPositiveInt(rawOptions.suggestionLimit, DEFAULT_SUGGESTION_LIMIT, 12);
  const maxDistanceKm = resolveMaxDistanceKm(filters.distance, rawOptions.maxDistance);

  const resolver = serviceType === 'food' ? resolveFoodSearch : resolveStoreSearch;
  const result = await resolver({
    serviceType,
    query,
    filters,
    sort,
    itemLimit,
    vendorLimit,
    categoryLimit,
    userLat: rawOptions.userLat,
    userLng: rawOptions.userLng,
    maxDistanceKm,
  });

  const suggestions = buildSuggestions({
    query,
    categories: result.categories,
    vendors: result.vendors,
    items: result.items,
    limit: suggestionLimit,
  });

  return {
    ...result,
    suggestions,
    sort,
    fetchedAt: new Date().toISOString(),
  };
}

module.exports = {
  searchCatalog,
};
