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

jest.mock('../services/credit_service', () => ({
  getBalance: jest.fn(),
  getTransactionHistory: jest.fn(),
  calculateCreditApplication: jest.fn(),
  adminGrantCredits: jest.fn(),
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

const creditService = require('../services/credit_service');
const creditsRoutes = require('../routes/credits');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/credits', creditsRoutes);
  return app;
};

describe('Credits Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('returns the current customer credit balance', async () => {
    creditService.getBalance.mockResolvedValue(12.5);

    const response = await request(app).get('/api/credits/balance');

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      data: {
        balance: 12.5,
        currency: 'GHS',
        formatted: '₵12.50',
      },
    });
  });

  test('returns safe 500 when balance lookup fails unexpectedly', async () => {
    creditService.getBalance.mockRejectedValue(new Error('db offline'));

    const response = await request(app).get('/api/credits/balance');

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Failed to get credit balance',
    });
  });

  test('validates checkout credit calculation input', async () => {
    const response = await request(app).post('/api/credits/calculate').send({
      orderTotal: -2,
    });

    expect(response.statusCode).toBe(400);
    expect(response.body.success).toBe(false);
    expect(Array.isArray(response.body.errors)).toBe(true);
  });

  test('calculates checkout credits successfully', async () => {
    creditService.calculateCreditApplication.mockResolvedValue({
      creditsApplied: 5,
      remainingPayment: 10,
      creditBalance: 12.5,
      availableBalance: 8.5,
    });

    const response = await request(app).post('/api/credits/calculate').send({
      orderTotal: 15,
      useCredits: true,
    });

    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.formattedCreditsApplied).toBe('₵5.00');
  });

  test('blocks admin credit grants for non-admin users', async () => {
    const response = await request(app)
      .post('/api/credits/admin/grant')
      .send({ userId: 'user-1', amount: 10, reason: 'Test' });

    expect(response.statusCode).toBe(403);
    expect(response.body).toEqual({
      success: false,
      message: 'Forbidden',
    });
  });
});
