const { isRestaurantOpen } = require('./restaurant');
const { normalizeRatingResponse } = require('./rating_calculator');
const { isGrabGoExclusiveActive } = require('./grabgo_exclusive');

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

module.exports = {
  formatOpeningHours,
  createLocation,
  toDistanceKm,
  formatRestaurantCard,
  formatStoreCard,
};
