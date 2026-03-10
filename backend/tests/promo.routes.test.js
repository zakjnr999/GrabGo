const express = require('express');
const request = require('supertest');

jest.mock('../middleware/auth', () => ({
  protect: (req, _res, next) => {
    req.user = {
      id: req.header('x-test-user-id') || 'customer-1',
      role: req.header('x-test-role') || 'customer',
    };
    return next();
  },
  authorize: (...roles) => (req, res, next) => {
    if (!roles.includes(req.user?.role)) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }
    return next();
  },
}));

jest.mock('../middleware/fraud_rate_limit', () => ({
  promoApplyRateLimit: (_req, _res, next) => next(),
}));

jest.mock('../services/fraud', () => ({
  ACTION_TYPES: {
    PROMO_APPLY: 'PROMO_APPLY',
  },
  buildFraudContextFromRequest: jest.fn(() => ({ requestId: 'req-1' })),
  fraudDecisionService: {
    evaluate: jest.fn().mockResolvedValue(null),
  },
  applyFraudDecision: jest.fn(() => ({ blocked: false, challenged: false })),
}));

jest.mock('../config/prisma', () => ({
  promoCode: {
    findUnique: jest.fn(),
  },
}));

jest.mock('../services/promo_service', () => ({
  validatePromoCode: jest.fn(),
  applyPromoCode: jest.fn(),
  createPromoCode: jest.fn(),
  getAvailablePromoCodes: jest.fn(),
  getMyPromoCodes: jest.fn(),
  getAllPromoCodes: jest.fn(),
  deactivatePromoCode: jest.fn(),
}));

jest.mock('../utils/logger', () => ({
  createScopedLogger: jest.fn(() => ({
    log: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  })),
}));

const prisma = require('../config/prisma');
const promoService = require('../services/promo_service');
const promoRoutes = require('../routes/promo');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/promo', promoRoutes);
  return app;
};

describe('Promo Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('returns validation failure when public promo code is inactive', async () => {
    prisma.promoCode.findUnique.mockResolvedValue(null);

    const response = await request(app).post('/api/promo/validate-public').send({
      code: 'SAVE10',
    });

    expect(response.statusCode).toBe(400);
    expect(response.body).toEqual({
      success: false,
      valid: false,
      error: 'Invalid or inactive promo code',
    });
  });

  test('returns validation success for protected promo validation', async () => {
    promoService.validatePromoCode.mockResolvedValue({
      valid: true,
      code: 'SAVE10',
      discount: 10,
      type: 'fixed',
      description: 'GHS 10 off',
      message: 'Promo applied',
    });

    const response = await request(app).post('/api/promo/validate').send({
      code: 'SAVE10',
      orderAmount: 50,
      orderType: 'food',
    });

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      valid: true,
      code: 'SAVE10',
      discount: 10,
      type: 'fixed',
      description: 'GHS 10 off',
      message: 'Promo applied',
    });
  });

  test('returns protected promo validation failure when service marks code invalid', async () => {
    promoService.validatePromoCode.mockResolvedValue({
      valid: false,
      error: 'Promo code expired',
    });

    const response = await request(app).post('/api/promo/validate').send({
      code: 'SAVE10',
      orderAmount: 50,
      orderType: 'food',
    });

    expect(response.statusCode).toBe(400);
    expect(response.body).toEqual({
      success: false,
      valid: false,
      error: 'Promo code expired',
    });
  });

  test('returns grouped promo codes for the current user', async () => {
    promoService.getMyPromoCodes.mockResolvedValue({
      available: [{ code: 'SAVE10' }],
      used: [],
      expired: [],
    });

    const response = await request(app).get('/api/promo/my-codes');

    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.available).toEqual([{ code: 'SAVE10' }]);
    expect(typeof response.body.data.fetchedAt).toBe('string');
  });

  test('returns safe 500 for unexpected promo fetch failures', async () => {
    promoService.getMyPromoCodes.mockRejectedValue(new Error('db timeout'));

    const response = await request(app).get('/api/promo/my-codes');

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      error: 'Failed to fetch promo codes',
    });
  });
});
