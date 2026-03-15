const prisma = require('../config/prisma');
const mlClient = require('../utils/ml_client');
const {
  validateLocationParams,
  getBoundingBox,
  filterVendorsByDistance,
} = require('../utils/vendor_distance_filter');
const { createScopedLogger } = require('../utils/logger');

const logger = createScopedLogger('service_hub_feed_service');

const FEED_ITEM_LIMIT = 50;
const FEED_SECTION_LIMIT = 10;
const FEED_RECOMMENDED_LIMIT = 20;

const CATEGORY_SELECT = {
  id: true,
  name: true,
  emoji: true,
  description: true,
  image: true,
  sortOrder: true,
  isActive: true,
};

const STORE_SELECT = {
  id: true,
  storeName: true,
  logo: true,
  isOpen: true,
  deliveryFee: true,
  minOrder: true,
  longitude: true,
  latitude: true,
  address: true,
  city: true,
  area: true,
};

const ITEM_INCLUDE = {
  category: {
    select: {
      id: true,
      name: true,
      emoji: true,
    },
  },
  store: {
    select: STORE_SELECT,
  },
};

const SERVICE_CONFIGS = {
  groceries: {
    categoryDelegate: prisma.groceryCategory,
    itemDelegate: prisma.groceryItem,
    storeDelegate: prisma.groceryStore,
    mlServiceType: 'grocery',
    baseOrderBy: [{ rating: 'desc' }, { orderCount: 'desc' }],
  },
  pharmacy: {
    categoryDelegate: prisma.pharmacyCategory,
    itemDelegate: prisma.pharmacyItem,
    storeDelegate: prisma.pharmacyStore,
    mlServiceType: 'pharmacy',
    baseOrderBy: [{ orderCount: 'desc' }, { rating: 'desc' }],
  },
  convenience: {
    categoryDelegate: prisma.grabMartCategory,
    itemDelegate: prisma.grabMartItem,
    storeDelegate: prisma.grabMartStore,
    mlServiceType: 'grabmart',
    baseOrderBy: [{ orderCount: 'desc' }, { rating: 'desc' }],
  },
};

const normalizeServiceId = (serviceId) => {
  if (serviceId === 'grabmart') return 'convenience';
  return serviceId;
};

const withLegacyId = (value) => {
  if (!value || typeof value !== 'object') return value;
  if (value._id) return value;
  return {
    ...value,
    _id: value.id,
  };
};

const formatFeedCategory = (category) => withLegacyId(category);

const formatFeedItem = (item) => {
  if (!item) return item;

  const store = item.store
    ? {
        ...withLegacyId(item.store),
        store_name: item.store.storeName,
      }
    : item.store;

  return {
    ...withLegacyId(item),
    category: item.category ? withLegacyId(item.category) : item.category,
    store,
  };
};

const buildEmptyFeed = (serviceId) => ({
  service: serviceId,
  categories: [],
  items: [],
  deals: [],
  popular: [],
  topRated: [],
  recommended: {
    items: [],
    page: 1,
    hasMore: false,
    total: 0,
  },
  fetchedAt: new Date().toISOString(),
});

async function getNearbyStoreIds(config, location) {
  if (!location) return null;

  const bbox = getBoundingBox(
    location.userLatitude,
    location.userLongitude,
    location.maxDistanceKm,
  );

  const nearbyStores = await config.storeDelegate.findMany({
    where: {
      latitude: { gte: bbox.minLat, lte: bbox.maxLat },
      longitude: { gte: bbox.minLng, lte: bbox.maxLng },
    },
    select: {
      id: true,
      latitude: true,
      longitude: true,
    },
  });

  const filteredStores = filterVendorsByDistance(
    nearbyStores,
    location.userLatitude,
    location.userLongitude,
    location.maxDistanceKm,
  );

  return filteredStores.map((store) => store.id);
}

async function getActiveCategoryIds(config, nearbyStoreIds) {
  if (!nearbyStoreIds) return null;
  if (nearbyStoreIds.length === 0) return [];

  const categoriesWithItems = await config.itemDelegate.findMany({
    where: {
      storeId: { in: nearbyStoreIds },
      isAvailable: true,
    },
    select: {
      categoryId: true,
    },
    distinct: ['categoryId'],
  });

  return categoriesWithItems
    .map((entry) => entry.categoryId)
    .filter(Boolean);
}

async function fetchRecommendedSection({
  config,
  userId,
  nearbyStoreIds,
  page = 1,
  limit = FEED_RECOMMENDED_LIMIT,
}) {
  const locationWhere = nearbyStoreIds ? { storeId: { in: nearbyStoreIds } } : {};
  let mlSeedItems = [];

  if (userId) {
    try {
      const mlRecommendations = await mlClient.getStoreRecommendations(
        userId,
        config.mlServiceType,
        30,
      );
      const recommendedStoreIds = [
        ...new Set(
          (mlRecommendations || []).map((entry) => entry.id).filter(Boolean),
        ),
      ];

      if (recommendedStoreIds.length > 0) {
        const nearbySet = nearbyStoreIds ? new Set(nearbyStoreIds) : null;
        const eligibleStoreIds = nearbySet
          ? recommendedStoreIds.filter((id) => nearbySet.has(id))
          : recommendedStoreIds;

        if (eligibleStoreIds.length > 0) {
          const storeRank = new Map(
            eligibleStoreIds.map((id, index) => [id, index]),
          );
          const storeScore = new Map(
            (mlRecommendations || [])
              .filter((entry) => eligibleStoreIds.includes(entry.id))
              .map((entry) => [entry.id, Number(entry.score) || 0]),
          );

          const candidateItems = await config.itemDelegate.findMany({
            where: {
              isAvailable: true,
              storeId: { in: eligibleStoreIds },
            },
            include: ITEM_INCLUDE,
            take: 200,
          });

          if (candidateItems.length > 0) {
            const ranked = [...candidateItems].sort((a, b) => {
              const scoreDiff =
                (storeScore.get(b.storeId) || 0) -
                (storeScore.get(a.storeId) || 0);
              if (scoreDiff !== 0) return scoreDiff;

              const rankDiff =
                (storeRank.get(a.storeId) ?? Number.MAX_SAFE_INTEGER) -
                (storeRank.get(b.storeId) ?? Number.MAX_SAFE_INTEGER);
              if (rankDiff !== 0) return rankDiff;

              const popularityDiff = (b.orderCount || 0) - (a.orderCount || 0);
              if (popularityDiff !== 0) return popularityDiff;

              const ratingDiff = (b.rating || 0) - (a.rating || 0);
              if (ratingDiff !== 0) return ratingDiff;

              return (b.discountPercentage || 0) - (a.discountPercentage || 0);
            });

            const groupedByStore = new Map();
            for (const item of ranked) {
              const items = groupedByStore.get(item.storeId) || [];
              items.push(item);
              groupedByStore.set(item.storeId, items);
            }

            const diversified = [];
            let keepLooping = true;
            while (keepLooping && diversified.length < ranked.length) {
              keepLooping = false;
              for (const storeId of eligibleStoreIds) {
                const queue = groupedByStore.get(storeId) || [];
                if (queue.length > 0) {
                  diversified.push(queue.shift());
                  keepLooping = true;
                }
              }
            }

            const startIndex = (page - 1) * limit;
            const endIndex = startIndex + limit;
            const paginatedItems = diversified.slice(startIndex, endIndex);

            if (paginatedItems.length >= limit) {
              return {
                items: paginatedItems.map(formatFeedItem),
                page,
                hasMore: endIndex < diversified.length,
                total: diversified.length,
              };
            }

            if (paginatedItems.length > 0) {
              mlSeedItems = paginatedItems;
            }
          }
        }
      }
    } catch (error) {
      logger.warn('service_hub_ml_recommendation_failed', {
        service: config.mlServiceType,
        message: error.message,
      });
    }
  }

  const popularCount = Math.ceil(limit * 0.4);
  const ratedCount = Math.ceil(limit * 0.3);
  const dealsCount = Math.ceil(limit * 0.2);
  const randomCount = limit - (popularCount + ratedCount + dealsCount);
  const skip = (page - 1) * limit;

  const [popular, topRated, deals, random] = await Promise.all([
    config.itemDelegate.findMany({
      where: { isAvailable: true, ...locationWhere },
      orderBy: [{ orderCount: 'desc' }, { rating: 'desc' }],
      take: popularCount,
      skip: Math.floor(skip * 0.4),
      include: ITEM_INCLUDE,
    }),
    config.itemDelegate.findMany({
      where: {
        isAvailable: true,
        rating: { gte: 4.5 },
        ...locationWhere,
      },
      orderBy: [{ rating: 'desc' }, { reviewCount: 'desc' }],
      take: ratedCount,
      skip: Math.floor(skip * 0.3),
      include: ITEM_INCLUDE,
    }),
    config.itemDelegate.findMany({
      where: {
        isAvailable: true,
        discountPercentage: { gt: 0 },
        ...locationWhere,
      },
      orderBy: [{ discountPercentage: 'desc' }, { orderCount: 'desc' }],
      take: dealsCount,
      skip: Math.floor(skip * 0.2),
      include: ITEM_INCLUDE,
    }),
    config.itemDelegate.findMany({
      where: { isAvailable: true, ...locationWhere },
      orderBy: [{ createdAt: 'desc' }],
      take: Math.max(randomCount, 0),
      skip: Math.floor(skip * 0.1),
      include: ITEM_INCLUDE,
    }),
  ]);

  const combined = [...mlSeedItems, ...popular, ...topRated, ...deals, ...random];
  const uniqueItems = Array.from(
    new Map(combined.map((item) => [item.id, item])).values(),
  );

  uniqueItems.sort((a, b) => {
    const aScore =
      (a.orderCount || 0) * 3 +
      (a.rating || 0) * 20 +
      (a.discountPercentage || 0) * 2;
    const bScore =
      (b.orderCount || 0) * 3 +
      (b.rating || 0) * 20 +
      (b.discountPercentage || 0) * 2;
    return bScore - aScore;
  });

  let finalRecommendations = uniqueItems.slice(0, limit);

  if (finalRecommendations.length < limit) {
    const fillCount = limit - finalRecommendations.length;
    const fallbackPool = await config.itemDelegate.findMany({
      where: {
        isAvailable: true,
        ...locationWhere,
        id: { notIn: finalRecommendations.map((item) => item.id) },
      },
      include: ITEM_INCLUDE,
      orderBy: [{ orderCount: 'desc' }, { rating: 'desc' }, { createdAt: 'desc' }],
      take: fillCount,
    });

    finalRecommendations = [...finalRecommendations, ...fallbackPool];
  }

  return {
    items: finalRecommendations.map(formatFeedItem),
    page,
    hasMore: page < 5 && finalRecommendations.length === limit,
    total: finalRecommendations.length,
  };
}

async function fetchServiceHubFeed({
  serviceId,
  userId,
  userLat,
  userLng,
  maxDistance,
}) {
  const normalizedServiceId = normalizeServiceId(serviceId);
  const config = SERVICE_CONFIGS[normalizedServiceId];

  if (!config) {
    throw new Error(`Unsupported service hub feed service: ${serviceId}`);
  }

  const location = validateLocationParams(userLat, userLng, maxDistance);
  const nearbyStoreIds = await getNearbyStoreIds(config, location);

  if (location && nearbyStoreIds && nearbyStoreIds.length === 0) {
    return buildEmptyFeed(normalizedServiceId);
  }

  const locationWhere = nearbyStoreIds ? { storeId: { in: nearbyStoreIds } } : {};
  const activeCategoryIds = await getActiveCategoryIds(config, nearbyStoreIds);

  const categoryWhere = {
    isActive: true,
    ...(activeCategoryIds ? { id: { in: activeCategoryIds } } : {}),
  };

  const [categories, items, deals, popular, topRated, recommended] =
    await Promise.all([
      config.categoryDelegate.findMany({
        where: categoryWhere,
        orderBy: { sortOrder: 'asc' },
        select: CATEGORY_SELECT,
      }),
      config.itemDelegate.findMany({
        where: {
          isAvailable: true,
          ...locationWhere,
        },
        include: ITEM_INCLUDE,
        orderBy: config.baseOrderBy,
        take: FEED_ITEM_LIMIT,
      }),
      config.itemDelegate.findMany({
        where: {
          isAvailable: true,
          discountPercentage: { gt: 0 },
          OR: [{ discountEndDate: null }, { discountEndDate: { gte: new Date() } }],
          ...locationWhere,
        },
        include: ITEM_INCLUDE,
        orderBy: [{ discountPercentage: 'desc' }, { orderCount: 'desc' }],
        take: FEED_SECTION_LIMIT,
      }),
      config.itemDelegate.findMany({
        where: {
          isAvailable: true,
          ...locationWhere,
        },
        include: ITEM_INCLUDE,
        orderBy: [{ orderCount: 'desc' }, { rating: 'desc' }],
        take: FEED_SECTION_LIMIT,
      }),
      config.itemDelegate.findMany({
        where: {
          isAvailable: true,
          rating: { gte: 4.5 },
          ...locationWhere,
        },
        include: ITEM_INCLUDE,
        orderBy: [{ rating: 'desc' }, { reviewCount: 'desc' }],
        take: FEED_SECTION_LIMIT,
      }),
      fetchRecommendedSection({
        config,
        userId,
        nearbyStoreIds,
        page: 1,
        limit: FEED_RECOMMENDED_LIMIT,
      }),
    ]);

  return {
    service: normalizedServiceId,
    categories: categories.map(formatFeedCategory),
    items: items.map(formatFeedItem),
    deals: deals.map(formatFeedItem),
    popular: popular.map(formatFeedItem),
    topRated: topRated.map(formatFeedItem),
    recommended,
    fetchedAt: new Date().toISOString(),
  };
}

module.exports = {
  fetchServiceHubFeed,
};
