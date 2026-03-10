const express = require('express');
const request = require('supertest');

jest.mock('../middleware/auth', () => ({
  protect: (req, res, next) => {
    const role = req.header('x-test-role');
    const userId = req.header('x-test-user-id');
    const email = req.header('x-test-email') || 'customer@example.com';

    if (!role || !userId) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized',
      });
    }

    req.user = { id: userId, role, email };
    return next();
  },
}));

jest.mock('../services/paystack_service', () => ({
  verifyWebhookSignature: jest.fn(),
}));

jest.mock('../services/subscription_service', () => ({
  getPlans: jest.fn(),
  getActiveSubscription: jest.fn(),
  getLatestPendingSubscription: jest.fn(),
  subscribe: jest.fn(),
  cancelSubscription: jest.fn(),
  confirmPayment: jest.fn(),
  previewBenefits: jest.fn(),
  handleWebhook: jest.fn(),
  getStats: jest.fn(),
}));

jest.mock('../config/feature_flags', () => ({
  isSubscriptionEnabled: true,
}));

jest.mock('../utils/logger', () => ({
  error: jest.fn(),
}));

const featureFlags = require('../config/feature_flags');
const subscriptionService = require('../services/subscription_service');
const subscriptionRoutes = require('../routes/subscriptions');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/subscriptions', subscriptionRoutes);
  return app;
};

const withAuth = (req, role = 'customer', userId = 'customer-1') =>
  req
    .set('x-test-role', role)
    .set('x-test-user-id', userId)
    .set('x-test-email', 'customer@example.com');

describe('Subscription Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    featureFlags.isSubscriptionEnabled = true;
  });

  describe('POST /api/subscriptions/subscribe', () => {
    test('returns 400 for recognized business errors', async () => {
      subscriptionService.subscribe.mockRejectedValue(
        new Error('You already have an active subscription')
      );

      const response = await withAuth(request(app).post('/api/subscriptions/subscribe')).send({
        tier: 'grabgo_plus',
      });

      expect(response.statusCode).toBe(400);
      expect(response.body).toEqual({
        success: false,
        message: 'You already have an active subscription',
      });
    });

    test('returns safe 500 for unexpected thrown objects', async () => {
      subscriptionService.subscribe.mockRejectedValue({ code: 'BROKEN' });

      const response = await withAuth(request(app).post('/api/subscriptions/subscribe')).send({
        tier: 'grabgo_plus',
      });

      expect(response.statusCode).toBe(500);
      expect(response.body).toEqual({
        success: false,
        message: 'Server error',
      });
    });
  });

  describe('POST /api/subscriptions/cancel', () => {
    test('returns 404 when no active subscription exists', async () => {
      subscriptionService.cancelSubscription.mockRejectedValue(
        new Error('No active subscription')
      );

      const response = await withAuth(request(app).post('/api/subscriptions/cancel')).send({});

      expect(response.statusCode).toBe(404);
      expect(response.body).toEqual({
        success: false,
        message: 'No active subscription',
      });
    });
  });

  describe('POST /api/subscriptions/confirm-payment', () => {
    test('returns mapped 404 for not-found payment confirmation errors', async () => {
      subscriptionService.confirmPayment.mockRejectedValue(
        new Error('subscription not found')
      );

      const response = await withAuth(
        request(app).post('/api/subscriptions/confirm-payment')
      ).send({
        reference: 'ref_123',
      });

      expect(response.statusCode).toBe(404);
      expect(response.body).toEqual({
        success: false,
        message: 'subscription not found',
      });
    });

    test('returns safe 500 for unexpected thrown objects', async () => {
      subscriptionService.confirmPayment.mockRejectedValue({ code: 'BROKEN' });

      const response = await withAuth(
        request(app).post('/api/subscriptions/confirm-payment')
      ).send({
        reference: 'ref_123',
      });

      expect(response.statusCode).toBe(500);
      expect(response.body).toEqual({
        success: false,
        message: 'Server error',
      });
    });
  });
});
