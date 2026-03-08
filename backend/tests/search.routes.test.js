const express = require('express');
const request = require('supertest');

jest.mock('../services/catalog_search_service', () => ({
  searchCatalog: jest.fn(),
}));

const searchRoutes = require('../routes/search');
const { searchCatalog } = require('../services/catalog_search_service');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/search', searchRoutes);
  return app;
};

describe('Search Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('GET /api/search/catalog', () => {
    test('returns 400 when serviceType is missing', async () => {
      const response = await request(app).get('/api/search/catalog');

      expect(response.statusCode).toBe(400);
      expect(response.body).toEqual({
        success: false,
        message: 'serviceType is required',
      });
      expect(searchCatalog).not.toHaveBeenCalled();
    });

    test('returns 400 when serviceType is unsupported', async () => {
      const response = await request(app)
        .get('/api/search/catalog')
        .query({ serviceType: 'parcel' });

      expect(response.statusCode).toBe(400);
      expect(response.body).toEqual({
        success: false,
        message: 'Unsupported serviceType',
      });
      expect(searchCatalog).not.toHaveBeenCalled();
    });

    test('returns catalog search data for supported service types', async () => {
      const payload = {
        vendors: [{ id: 'vendor-1', restaurantName: 'Sushi Zen' }],
        items: [{ id: 'food-1', name: 'Salmon Roll' }],
        categories: [{ id: 'cat-1', name: 'Sushi', itemCount: 9 }],
        suggestions: [{ value: 'Sushi Zen', type: 'vendor', subtitle: 'food' }],
        sort: 'relevance',
        fetchedAt: '2026-03-08T00:00:00.000Z',
      };
      searchCatalog.mockResolvedValue(payload);

      const response = await request(app)
        .get('/api/search/catalog')
        .query({
          serviceType: 'food',
          q: 'sushi',
          sort: 'rating',
          vendorLimit: 4,
        });

      expect(response.statusCode).toBe(200);
      expect(response.body).toEqual({
        success: true,
        data: payload,
      });
      expect(searchCatalog).toHaveBeenCalledWith(
        expect.objectContaining({
          serviceType: 'food',
          q: 'sushi',
          sort: 'rating',
          vendorLimit: '4',
        }),
      );
    });

    test('returns 500 when catalog search throws', async () => {
      searchCatalog.mockRejectedValue(new Error('db unavailable'));

      const response = await request(app)
        .get('/api/search/catalog')
        .query({ serviceType: 'groceries', q: 'bread' });

      expect(response.statusCode).toBe(500);
      expect(response.body).toEqual({
        success: false,
        message: 'Failed to search catalog',
      });
    });
  });
});
