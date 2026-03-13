const express = require('express');
const request = require('supertest');

jest.mock('../middleware/auth', () => ({
  protect: (req, res, next) => {
    req.user = { id: 'customer-1', role: 'customer' };
    next();
  },
}));

jest.mock('../config/feature_flags', () => ({
  isMixedCartEnabled: true,
  isPromoCheckoutEnabled: true,
}));

jest.mock('../services/pricing_service', () => ({
  calculateCartPricing: jest.fn(),
  calculateCartGroupsPricing: jest.fn(),
}));

jest.mock('../services/cart_service', () => ({
  normalizeFulfillmentMode: jest.fn((mode) => (String(mode || '').toLowerCase() === 'pickup' ? 'pickup' : 'delivery')),
  addToCart: jest.fn(),
  syncCartState: jest.fn(),
  updateCartItem: jest.fn(),
  removeFromCart: jest.fn(),
  clearCart: jest.fn(),
  getUserCart: jest.fn(),
  getUserCartGroups: jest.fn(),
}));

jest.mock('../utils/cache', () => ({
  get: jest.fn(),
  set: jest.fn(),
  acquireLock: jest.fn(),
  releaseLock: jest.fn(),
}));

jest.mock('../utils/logger', () => ({
  createScopedLogger: jest.fn(() => ({
    error: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
  })),
}));

const {
  calculateCartGroupsPricing,
} = require('../services/pricing_service');
const {
  syncCartState,
  getUserCartGroups,
} = require('../services/cart_service');
const cache = require('../utils/cache');
const cartRoutes = require('../routes/cart');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/cart', cartRoutes);
  return app;
};

describe('Cart Sync Route', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    cache.acquireLock.mockResolvedValue({ key: 'lock-1', value: 'value-1', isRedis: false });
    cache.releaseLock.mockResolvedValue(true);
    calculateCartGroupsPricing.mockResolvedValue({
      groups: [{ id: 'group-1', items: [] }],
      summary: { total: 10 },
    });
    syncCartState.mockResolvedValue([{ id: 'cart-1' }]);
    getUserCartGroups.mockResolvedValue([{ id: 'cart-1' }]);
  });

  test('syncs cart snapshot successfully', async () => {
    const response = await request(app)
      .put('/api/cart/sync')
      .send({
        clientCartVersion: 7,
        idempotencyKey: 'idem-1',
        items: [
          { itemId: 'food-1', itemType: 'Food', quantity: 2, providerId: 'rest-1', restaurantId: 'rest-1' },
        ],
      });

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      acceptedCartVersion: 7,
      groups: [{ id: 'group-1', items: [] }],
      summary: { total: 10 },
    });
    expect(syncCartState).toHaveBeenCalledWith('customer-1', expect.objectContaining({
      fulfillmentMode: 'delivery',
    }));
    expect(cache.set).toHaveBeenCalled();
  });

  test('returns cached idempotent response when available', async () => {
    cache.get.mockResolvedValueOnce({
      success: true,
      acceptedCartVersion: 9,
      groups: [{ id: 'cached-group' }],
      summary: { total: 22 },
    });

    const response = await request(app)
      .put('/api/cart/sync')
      .send({
        clientCartVersion: 9,
        idempotencyKey: 'idem-cached',
        items: [],
      });

    expect(response.statusCode).toBe(200);
    expect(response.body.groups).toEqual([{ id: 'cached-group' }]);
    expect(syncCartState).not.toHaveBeenCalled();
    expect(cache.acquireLock).not.toHaveBeenCalled();
  });

  test('returns authoritative cart snapshot on business rejection', async () => {
    syncCartState.mockRejectedValue(new Error('Item is currently unavailable'));

    const response = await request(app)
      .put('/api/cart/sync')
      .send({
        clientCartVersion: 5,
        items: [{ itemId: 'food-1', itemType: 'Food', quantity: 1, restaurantId: 'rest-1' }],
      });

    expect(response.statusCode).toBe(409);
    expect(response.body).toEqual({
      success: false,
      message: 'Item is currently unavailable',
      code: 'CART_SYNC_REJECTED',
      acceptedCartVersion: 5,
      groups: [{ id: 'group-1', items: [] }],
      summary: { total: 10 },
    });
    expect(getUserCartGroups).toHaveBeenCalledWith('customer-1', 'delivery');
  });

  test('rejects when cart sync lock cannot be acquired', async () => {
    cache.acquireLock.mockResolvedValue(null);

    const response = await request(app)
      .put('/api/cart/sync')
      .send({
        items: [],
      });

    expect(response.statusCode).toBe(409);
    expect(response.body.code).toBe('CART_SYNC_IN_PROGRESS');
  });

  test('validates items array presence', async () => {
    const response = await request(app)
      .put('/api/cart/sync')
      .send({
        clientCartVersion: 1,
      });

    expect(response.statusCode).toBe(400);
    expect(response.body.message).toBe('Cart items array is required');
  });
});
