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
  paymentAttemptRateLimit: (_req, _res, next) => next(),
  parcelQuoteRateLimit: (_req, _res, next) => next(),
  parcelOrderCreateRateLimit: (_req, _res, next) => next(),
  parcelLifecycleRateLimit: (_req, _res, next) => next(),
  parcelDeliveryCodeRateLimit: (_req, _res, next) => next(),
}));

jest.mock('../services/parcel_service', () => ({
  getParcelConfig: jest.fn(),
  createQuote: jest.fn(),
  createParcelOrder: jest.fn(),
  listParcelOrdersForUser: jest.fn(),
  getParcelByIdForUser: jest.fn(),
  initializePaystackForParcel: jest.fn(),
  confirmParcelPayment: jest.fn(),
  cancelParcelOrder: jest.fn(),
  resendParcelDeliveryCode: jest.fn(),
  initiateReturnToSender: jest.fn(),
  confirmReturnToSender: jest.fn(),
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

const parcelService = require('../services/parcel_service');
const parcelRoutes = require('../routes/parcel');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/parcel', parcelRoutes);
  return app;
};

describe('Parcel Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('returns parcel config', async () => {
    parcelService.getParcelConfig.mockReturnValue({ maxWeightKg: 20 });

    const response = await request(app).get('/api/parcel/config');

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      message: 'Parcel config retrieved successfully',
      data: { maxWeightKg: 20 },
    });
  });

  test('returns parcel quote', async () => {
    parcelService.createQuote.mockResolvedValue({ distanceKm: 3.2, totalFee: 15 });

    const response = await request(app).post('/api/parcel/quote').send({
      pickupAddress: 'A',
      deliveryAddress: 'B',
    });

    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
    expect(response.body.data.totalFee).toBe(15);
  });

  test('validates parcel order creation input', async () => {
    const response = await request(app).post('/api/parcel/orders').send({});

    expect(response.statusCode).toBe(400);
    expect(response.body.success).toBe(false);
    expect(Array.isArray(response.body.errors)).toBe(true);
  });

  test('returns 404 when parcel order is not found for the user', async () => {
    parcelService.getParcelByIdForUser.mockResolvedValue(null);

    const response = await request(app).get('/api/parcel/orders/parcel-1');

    expect(response.statusCode).toBe(404);
    expect(response.body).toEqual({
      success: false,
      message: 'Parcel order not found',
    });
  });

  test('returns safe 500 for unexpected parcel payment initialization failures', async () => {
    parcelService.initializePaystackForParcel.mockRejectedValue(new Error('gateway timeout'));

    const response = await request(app).post('/api/parcel/orders/parcel-1/paystack/initialize');

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Failed to initialize parcel payment',
    });
  });
});
