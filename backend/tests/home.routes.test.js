const express = require('express');
const request = require('supertest');

jest.mock('../middleware/cache', () => ({
  cacheMiddleware: () => (req, res, next) => next(),
}));

jest.mock('../services/home_feed_service', () => ({
  fetchFoodHomeFeed: jest.fn(),
}));

const homeRoutes = require('../routes/home');
const { fetchFoodHomeFeed } = require('../services/home_feed_service');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/home', homeRoutes);
  return app;
};

describe('Home Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /api/home/food-feed', () => {
    test('returns food home feed including freeDeliveryNearbyVendors', async () => {
      const payload = {
        categories: [],
        deals: [],
        orderHistory: [],
        popular: [],
        topRated: [],
        recommended: {
          items: [],
          page: 1,
          hasMore: false,
        },
        promoBanners: [],
        nearbyVendors: [{ id: 'vendor-1', restaurantName: 'Cafe Moka' }],
        freeDeliveryNearbyVendors: [
          { id: 'vendor-2', restaurantName: 'Sushi Zen', deliveryFee: 0 },
        ],
        exclusiveVendors: [],
        fetchedAt: '2026-03-13T00:00:00.000Z',
      };
      fetchFoodHomeFeed.mockResolvedValue(payload);

      const response = await request(app)
        .get('/api/home/food-feed')
        .query({ userLat: '5.6037', userLng: '-0.1870' });

      expect(response.statusCode).toBe(200);
      expect(response.body).toEqual({
        success: true,
        message: 'Food home feed retrieved successfully',
        data: payload,
      });
      expect(fetchFoodHomeFeed).toHaveBeenCalledWith(
        expect.objectContaining({
          userLat: '5.6037',
          userLng: '-0.1870',
        }),
      );
    });

    test('returns 500 when the home feed fetch fails', async () => {
      fetchFoodHomeFeed.mockRejectedValue(new Error('redis down'));

      const response = await request(app).get('/api/home/food-feed');

      expect(response.statusCode).toBe(500);
      expect(response.body).toEqual({
        success: false,
        message: 'Server error',
      });
    });
  });
});
