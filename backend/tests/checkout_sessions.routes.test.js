const express = require('express');
const request = require('supertest');

jest.mock('../middleware/auth', () => ({
  protect: (req, res, next) => {
    const role = req.header('x-test-role');
    const userId = req.header('x-test-user-id');

    if (!role || !userId) {
      return res.status(401).json({
        success: false,
        message: 'Not authorized',
      });
    }

    req.user = { id: userId, role };
    return next();
  },
}));

jest.mock('../middleware/fraud_rate_limit', () => ({
  paymentAttemptRateLimit: (_req, _res, next) => next(),
}));

jest.mock('../middleware/cache', () => ({
  invalidateCache: jest.fn(),
}));

jest.mock('../config/prisma', () => ({
  checkoutSession: {
    findUnique: jest.fn(),
  },
}));

jest.mock('../services/fraud', () => ({
  ACTION_TYPES: {
    PAYMENT_CLIENT_CONFIRM: 'PAYMENT_CLIENT_CONFIRM',
  },
  buildFraudContextFromRequest: jest.fn(() => ({ requestId: 'req-1' })),
  fraudDecisionService: {
    evaluate: jest.fn().mockResolvedValue({ decision: 'allow' }),
  },
  applyFraudDecision: jest.fn(() => ({ blocked: false, challenged: false })),
}));

jest.mock('../services/checkout_session_service', () => {
  class CheckoutSessionError extends Error {
    constructor(message, { code = 'CHECKOUT_SESSION_ERROR', status = 400, meta = null } = {}) {
      super(message);
      this.code = code;
      this.status = status;
      this.meta = meta;
    }
  }

  return {
    CheckoutSessionError,
    createCheckoutSession: jest.fn(),
    initializeCheckoutSessionPayment: jest.fn(),
    confirmCheckoutSessionPayment: jest.fn(),
    releaseCheckoutSessionCreditHolds: jest.fn(),
  };
});

jest.mock('../utils/metrics', () => ({
  recordCheckoutSessionEvent: jest.fn(),
}));

jest.mock('../utils/logger', () => ({
  error: jest.fn(),
}));

const prisma = require('../config/prisma');
const metrics = require('../utils/metrics');
const {
  CheckoutSessionError,
  createCheckoutSession,
  initializeCheckoutSessionPayment,
  confirmCheckoutSessionPayment,
} = require('../services/checkout_session_service');
const checkoutSessionRoutes = require('../routes/checkout_sessions');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/checkout-sessions', checkoutSessionRoutes);
  return app;
};

const withAuth = (req, role = 'customer', userId = 'customer-1') =>
  req.set('x-test-role', role).set('x-test-user-id', userId);

describe('Checkout Session Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.checkoutSession.findUnique.mockResolvedValue({
      id: 'session-1',
      customerId: 'customer-1',
      paymentReferenceId: 'ref-1',
      totalAmount: 42.5,
    });
  });

  test('creates a checkout session for a valid customer request', async () => {
    createCheckoutSession.mockResolvedValue({
      session: { id: 'session-1' },
      childOrders: [{ id: 'order-1' }],
      summary: { totalAmount: 42.5 },
    });

    const response = await withAuth(request(app).post('/api/checkout-sessions')).send({
      paymentMethod: 'card',
      deliveryAddress: {
        street: 'Oxford St',
        city: 'Accra',
      },
    });

    expect(response.statusCode).toBe(201);
    expect(response.body.success).toBe(true);
    expect(createCheckoutSession).toHaveBeenCalled();
  });

  test('rejects promo codes for grouped checkout sessions', async () => {
    const response = await withAuth(request(app).post('/api/checkout-sessions')).send({
      paymentMethod: 'card',
      promoCode: 'SAVE10',
      deliveryAddress: {
        street: 'Oxford St',
        city: 'Accra',
      },
    });

    expect(response.statusCode).toBe(400);
    expect(response.body.code).toBe('PROMO_MIXED_CHECKOUT_NOT_SUPPORTED');
    expect(createCheckoutSession).not.toHaveBeenCalled();
  });

  test('returns business error details from checkout session service', async () => {
    createCheckoutSession.mockRejectedValue(
      new CheckoutSessionError('Cart is empty', {
        code: 'CHECKOUT_SESSION_EMPTY_CART',
        status: 400,
      })
    );

    const response = await withAuth(request(app).post('/api/checkout-sessions')).send({
      paymentMethod: 'card',
      deliveryAddress: {
        street: 'Oxford St',
        city: 'Accra',
      },
    });

    expect(response.statusCode).toBe(400);
    expect(response.body).toEqual({
      success: false,
      message: 'Cart is empty',
      code: 'CHECKOUT_SESSION_EMPTY_CART',
    });
  });

  test('returns safe 500 for unexpected checkout session creation failures', async () => {
    createCheckoutSession.mockRejectedValue(new Error('db offline'));

    const response = await withAuth(request(app).post('/api/checkout-sessions')).send({
      paymentMethod: 'card',
      deliveryAddress: {
        street: 'Oxford St',
        city: 'Accra',
      },
    });

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Server error',
    });
    expect(metrics.recordCheckoutSessionEvent).toHaveBeenCalledWith({
      action: 'create',
      result: 'failure',
    });
  });

  test('initializes payment for a customer', async () => {
    initializeCheckoutSessionPayment.mockResolvedValue({
      alreadyPaid: false,
      session: { id: 'session-1', groupOrderNumber: 'GRP-1' },
      authorizationUrl: 'https://paystack.test/authorize',
      reference: 'ref-1',
      paymentAmount: 42.5,
      paymentScope: 'group',
    });

    const response = await withAuth(
      request(app).post('/api/checkout-sessions/session-1/paystack/initialize')
    );

    expect(response.statusCode).toBe(200);
    expect(response.body.success).toBe(true);
    expect(initializeCheckoutSessionPayment).toHaveBeenCalledWith({
      sessionId: 'session-1',
      customer: { id: 'customer-1', role: 'customer' },
    });
  });

  test('rejects payment initialization for non-customers', async () => {
    const response = await withAuth(
      request(app).post('/api/checkout-sessions/session-1/paystack/initialize'),
      'admin',
      'admin-1',
    );

    expect(response.statusCode).toBe(403);
    expect(response.body).toEqual({
      success: false,
      message: 'Only customers can initialize checkout-session payments',
    });
    expect(initializeCheckoutSessionPayment).not.toHaveBeenCalled();
  });

  test('returns safe 500 for unexpected payment initialization failures', async () => {
    initializeCheckoutSessionPayment.mockRejectedValue(new Error('gateway timeout'));

    const response = await withAuth(
      request(app).post('/api/checkout-sessions/session-1/paystack/initialize')
    );

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Server error',
    });
    expect(metrics.recordCheckoutSessionEvent).toHaveBeenCalledWith({
      action: 'initialize_payment',
      result: 'failure',
    });
  });

  test('returns 404 when checkout session is missing during payment confirmation', async () => {
    prisma.checkoutSession.findUnique.mockResolvedValue(null);

    const response = await withAuth(
      request(app).post('/api/checkout-sessions/session-1/confirm-payment')
    ).send({
      reference: 'ref-1',
    });

    expect(response.statusCode).toBe(404);
    expect(response.body.message).toBe('Checkout session not found');
    expect(confirmCheckoutSessionPayment).not.toHaveBeenCalled();
  });

  test('returns 403 when checkout session belongs to another customer', async () => {
    prisma.checkoutSession.findUnique.mockResolvedValue({
      id: 'session-1',
      customerId: 'other-customer',
      paymentReferenceId: 'ref-1',
      totalAmount: 42.5,
    });

    const response = await withAuth(
      request(app).post('/api/checkout-sessions/session-1/confirm-payment')
    ).send({
      reference: 'ref-1',
    });

    expect(response.statusCode).toBe(403);
    expect(response.body).toEqual({
      success: false,
      message: 'Not authorized for this checkout session',
    });
    expect(confirmCheckoutSessionPayment).not.toHaveBeenCalled();
  });

  test('returns safe 500 for unexpected payment confirmation failures', async () => {
    confirmCheckoutSessionPayment.mockRejectedValue(new Error('provider exploded'));

    const response = await withAuth(
      request(app).post('/api/checkout-sessions/session-1/confirm-payment')
    ).send({
      reference: 'ref-1',
    });

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Server error',
    });
    expect(metrics.recordCheckoutSessionEvent).toHaveBeenCalledWith({
      action: 'confirm_payment',
      result: 'failure',
    });
  });
});
