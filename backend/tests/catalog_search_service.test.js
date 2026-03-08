jest.mock('../config/prisma', () => ({
  restaurant: { findMany: jest.fn() },
  food: { findMany: jest.fn() },
  category: { findMany: jest.fn() },
  groceryStore: { findMany: jest.fn() },
  groceryItem: { findMany: jest.fn() },
  groceryCategory: { findMany: jest.fn() },
  pharmacyStore: { findMany: jest.fn() },
  pharmacyItem: { findMany: jest.fn() },
  pharmacyCategory: { findMany: jest.fn() },
  grabMartStore: { findMany: jest.fn() },
  grabMartItem: { findMany: jest.fn() },
  grabMartCategory: { findMany: jest.fn() },
}));

jest.mock('../utils/food_helpers', () => ({
  FOOD_INCLUDE_RELATIONS: { mocked: true },
  formatFoodResponse: jest.fn(),
}));

jest.mock('../utils/rating_calculator', () => ({
  normalizeRatingResponse: jest.fn(({ rating = 0, reviewCount, ratingCount, totalReviews }) => ({
    rating,
    rawRating: rating,
    weightedRating: rating,
    reviewCount: reviewCount ?? ratingCount ?? totalReviews ?? 0,
    ratingCount: ratingCount ?? reviewCount ?? totalReviews ?? 0,
    totalReviews: totalReviews ?? reviewCount ?? ratingCount ?? 0,
  })),
}));

jest.mock('../utils/vendor_distance_filter', () => ({
  getBoundingBox: jest.fn(() => ({ minLat: 0, maxLat: 10, minLng: 0, maxLng: 10 })),
  filterVendorsByDistance: jest.fn((entries) => entries),
  validateLocationParams: jest.fn(() => null),
}));

jest.mock('../utils/vendor_card_formatter', () => ({
  formatRestaurantCard: jest.fn((restaurant) => ({
    ...restaurant,
    vendorType: 'food',
    rating: restaurant.rating ?? 0,
    weightedRating: restaurant.rating ?? 0,
    deliveryFee: restaurant.deliveryFee ?? 0,
    averageDeliveryTime: restaurant.averageDeliveryTime ?? 9999,
  })),
  formatStoreCard: jest.fn((store, vendorType) => ({
    ...store,
    vendorType,
    rating: store.rating ?? 0,
    weightedRating: store.rating ?? 0,
    deliveryFee: store.deliveryFee ?? 0,
    averageDeliveryTime: store.averageDeliveryTime ?? 9999,
  })),
}));

const prisma = require('../config/prisma');
const { formatFoodResponse } = require('../utils/food_helpers');
const { validateLocationParams } = require('../utils/vendor_distance_filter');
const { formatRestaurantCard, formatStoreCard } = require('../utils/vendor_card_formatter');
const { searchCatalog } = require('../services/catalog_search_service');

describe('catalog_search_service.searchCatalog', () => {
  beforeEach(() => {
    jest.clearAllMocks();

    validateLocationParams.mockReturnValue(null);
    prisma.restaurant.findMany.mockResolvedValue([]);
    prisma.food.findMany.mockResolvedValue([]);
    prisma.category.findMany.mockResolvedValue([]);
    prisma.groceryStore.findMany.mockResolvedValue([]);
    prisma.groceryItem.findMany.mockResolvedValue([]);
    prisma.groceryCategory.findMany.mockResolvedValue([]);
    prisma.pharmacyStore.findMany.mockResolvedValue([]);
    prisma.pharmacyItem.findMany.mockResolvedValue([]);
    prisma.pharmacyCategory.findMany.mockResolvedValue([]);
    prisma.grabMartStore.findMany.mockResolvedValue([]);
    prisma.grabMartItem.findMany.mockResolvedValue([]);
    prisma.grabMartCategory.findMany.mockResolvedValue([]);
    formatFoodResponse.mockReturnValue([]);
  });

  it('returns food search results and falls back invalid sort to relevance', async () => {
    prisma.restaurant.findMany.mockResolvedValue([
      {
        id: 'rest1',
        restaurantName: 'Sushi Zen',
        rating: 4.6,
        ratingCount: 28,
        totalReviews: 28,
        averageDeliveryTime: 24,
        deliveryFee: 8,
        area: 'Airport',
        city: 'Accra',
      },
    ]);
    prisma.food.findMany.mockResolvedValue([{ id: 'food1' }]);
    prisma.category.findMany.mockResolvedValue([
      {
        id: 'cat1',
        name: 'Sushi',
        emoji: '🍣',
        foods: [{ id: 'food1' }, { id: 'food2' }],
      },
    ]);
    formatFoodResponse.mockReturnValue([
      {
        id: 'food1',
        name: 'Sushi Roll',
        sellerName: 'Sushi Zen',
        categoryName: 'Sushi',
        rating: 4.7,
        weightedRating: 4.7,
        price: 22,
        deliveryTimeMinutes: 24,
      },
    ]);

    const result = await searchCatalog({
      serviceType: 'food',
      q: 'sushi',
      sort: 'wrong-value',
      itemLimit: '2',
      vendorLimit: '1',
      categoryLimit: '1',
      suggestionLimit: '2',
    });

    expect(result.sort).toBe('relevance');
    expect(result.vendors).toHaveLength(1);
    expect(result.items).toHaveLength(1);
    expect(result.categories).toHaveLength(1);
    expect(result.categories[0]).toMatchObject({ name: 'Sushi', serviceType: 'food', itemCount: 2 });
    expect(result.suggestions).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ value: 'Sushi Roll', type: 'item' }),
        expect.objectContaining({ value: 'Sushi', type: 'category' }),
      ]),
    );
    expect(result.suggestions.length).toBeLessThanOrEqual(2);
    expect(formatRestaurantCard).toHaveBeenCalledTimes(1);
    expect(formatFoodResponse).toHaveBeenCalledTimes(1);
  });

  it('returns grocery vendor, item, and category results through the store resolver', async () => {
    prisma.groceryStore.findMany.mockResolvedValue([
      {
        id: 'store1',
        storeName: 'Fresh Mart',
        rating: 4.5,
        ratingCount: 18,
        totalReviews: 18,
        averageDeliveryTime: 18,
        deliveryFee: 5,
        isDeleted: false,
        area: 'Osu',
        city: 'Accra',
      },
    ]);
    prisma.groceryItem.findMany.mockResolvedValue([
      {
        id: 'item1',
        name: 'Apple Juice',
        description: 'Cold and fresh',
        brand: 'Fruit Farm',
        price: 12,
        rating: 4.8,
        reviewCount: 3,
        totalReviews: 3,
        category: { name: 'Drinks', emoji: '🥤' },
        store: {
          id: 'store1',
          storeName: 'Fresh Mart',
          rating: 4.5,
          ratingCount: 18,
          totalReviews: 18,
          averageDeliveryTime: 18,
          deliveryFee: 5,
          isDeleted: false,
        },
      },
    ]);
    prisma.groceryCategory.findMany.mockResolvedValue([
      {
        id: 'gcat1',
        name: 'Drinks',
        emoji: '🥤',
        items: [{ id: 'item1' }],
      },
    ]);

    const result = await searchCatalog({
      serviceType: 'groceries',
      q: 'juice',
      sort: 'rating',
    });

    expect(result.sort).toBe('rating');
    expect(result.vendors).toHaveLength(1);
    expect(result.vendors[0]).toMatchObject({ storeName: 'Fresh Mart', vendorType: 'grocery' });
    expect(result.items).toHaveLength(1);
    expect(result.items[0]).toMatchObject({ name: 'Apple Juice', categoryName: 'Drinks', storeName: 'Fresh Mart' });
    expect(result.items[0].store).toMatchObject({ storeName: 'Fresh Mart', vendorType: 'grocery' });
    expect(result.categories).toEqual([
      expect.objectContaining({ name: 'Drinks', serviceType: 'groceries', itemCount: 1 }),
    ]);
    expect(formatStoreCard).toHaveBeenCalledWith(expect.objectContaining({ storeName: 'Fresh Mart' }), 'grocery');
  });

  it('passes the resolved max distance into location validation', async () => {
    await searchCatalog({
      serviceType: 'food',
      q: 'sushi',
      userLat: '5.58',
      userLng: '-0.21',
      distance: 'Under 1 km',
      maxDistance: '4',
    });

    expect(validateLocationParams).toHaveBeenCalledWith('5.58', '-0.21', 4);
  });

  it('returns no suggestions for an empty query', async () => {
    prisma.restaurant.findMany.mockResolvedValue([
      {
        id: 'rest1',
        restaurantName: 'Cafe Moka',
        rating: 4.4,
        ratingCount: 8,
        totalReviews: 8,
        averageDeliveryTime: 22,
        deliveryFee: 6,
      },
    ]);

    const result = await searchCatalog({
      serviceType: 'food',
      q: '',
    });

    expect(result.suggestions).toEqual([]);
  });
});
