const express = require('express');
const request = require('supertest');

jest.mock('../middleware/auth', () => ({
  protect: (_req, _res, next) => next(),
}));

jest.mock('../config/feature_flags', () => ({
  isPaymentWebhookSourceOfTruthEnabled: true,
}));

jest.mock('../services/paystack_service', () => ({
  extractWebhookEventId: jest.fn(),
  extractWebhookReference: jest.fn(),
  verifyWebhookSignature: jest.fn(),
}));

jest.mock('../services/fraud', () => ({
  ACTION_TYPES: {
    PAYMENT_WEBHOOK_EVENT: 'PAYMENT_WEBHOOK_EVENT',
  },
  DECISIONS: {
    BLOCK: 'block',
    STEP_UP: 'step_up',
  },
  buildFraudContextFromRequest: jest.fn(() => ({ requestId: 'req-1' })),
  fraudDecisionService: {
    evaluate: jest.fn().mockResolvedValue(null),
  },
  applyFraudDecision: jest.fn(() => ({ blocked: false, challenged: false })),
}));

jest.mock('../utils/metrics', () => ({
  recordPaymentWebhookEvent: jest.fn(),
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

jest.mock('../config/prisma', () => ({
  paymentWebhookEvent: {
    create: jest.fn(),
    update: jest.fn(),
  },
  order: {
    findMany: jest.fn(),
  },
  payment: {
    findMany: jest.fn(),
    count: jest.fn(),
    update: jest.fn(),
  },
  $transaction: jest.fn(),
}));

const prisma = require('../config/prisma');
const paystackService = require('../services/paystack_service');
const metrics = require('../utils/metrics');
const paymentsRoutes = require('../routes/payments');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/payments', paymentsRoutes);
  return app;
};

describe('Payments Webhook Routes', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    paystackService.extractWebhookEventId.mockReturnValue('evt-1');
    paystackService.extractWebhookReference.mockReturnValue('ref-1');
    paystackService.verifyWebhookSignature.mockReturnValue(true);
    prisma.paymentWebhookEvent.create.mockResolvedValue({ id: 'webhook-1' });
    prisma.paymentWebhookEvent.update.mockResolvedValue({});
    prisma.order.findMany.mockResolvedValue([]);
    prisma.$transaction.mockImplementation(async (callback) =>
      callback({
        payment: {
          findFirst: jest.fn().mockResolvedValue(null),
          update: jest.fn().mockResolvedValue({}),
          create: jest.fn().mockResolvedValue({}),
        },
        order: {
          update: jest.fn().mockResolvedValue({}),
          findMany: jest.fn().mockResolvedValue([{ paymentStatus: 'paid' }]),
        },
        checkoutSession: {
          update: jest.fn().mockResolvedValue({}),
        },
        paymentWebhookEvent: {
          update: jest.fn().mockResolvedValue({}),
        },
      }),
    );
  });

  test('rejects invalid webhook signatures', async () => {
    paystackService.verifyWebhookSignature.mockReturnValue(false);

    const response = await request(app)
      .post('/api/payments/webhooks/paystack')
      .send({ event: 'charge.success', data: { reference: 'ref-1' } });

    expect(response.statusCode).toBe(401);
    expect(response.body).toEqual({
      success: false,
      message: 'Invalid webhook signature',
      reasonCode: 'PAYMENT_WEBHOOK_SIGNATURE_INVALID',
    });
    expect(metrics.recordPaymentWebhookEvent).toHaveBeenCalledWith(
      expect.objectContaining({ eventType: 'charge.success', result: 'signature_invalid' }),
    );
  });

  test('acknowledges duplicate webhook events', async () => {
    prisma.paymentWebhookEvent.create.mockResolvedValueOnce('duplicate');

    const response = await request(app)
      .post('/api/payments/webhooks/paystack')
      .send({ event: 'charge.success', data: { reference: 'ref-1' } });

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      message: 'Webhook already processed',
      data: { duplicate: true },
    });
    expect(metrics.recordPaymentWebhookEvent).toHaveBeenCalledWith(
      expect.objectContaining({ eventType: 'charge.success', result: 'duplicate' }),
    );
  });

  test('acknowledges webhooks when no order matches the payment reference', async () => {
    prisma.order.findMany.mockResolvedValue([]);

    const response = await request(app)
      .post('/api/payments/webhooks/paystack')
      .send({ event: 'charge.success', data: { reference: 'ref-1' } });

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      message: 'Webhook acknowledged',
      data: { processed: false, reason: 'order_not_found' },
    });
    expect(metrics.recordPaymentWebhookEvent).toHaveBeenCalledWith(
      expect.objectContaining({ eventType: 'charge.success', result: 'order_not_found' }),
    );
  });

  test('acknowledges unsupported webhook event types', async () => {
    prisma.order.findMany.mockResolvedValue([
      {
        id: 'order-1',
        customerId: 'customer-1',
        paymentReferenceId: 'ref-1',
        paymentMethod: 'card',
        paymentStatus: 'pending',
        totalAmount: 20,
        status: 'pending',
        fulfillmentMode: 'delivery',
        isScheduledOrder: false,
        scheduledReleasedAt: null,
      },
    ]);

    const response = await request(app)
      .post('/api/payments/webhooks/paystack')
      .send({ event: 'transfer.success', data: { reference: 'ref-1' } });

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      message: 'Webhook acknowledged',
      data: { processed: false, reason: 'unsupported_event' },
    });
    expect(metrics.recordPaymentWebhookEvent).toHaveBeenCalledWith(
      expect.objectContaining({ eventType: 'transfer.success', result: 'unsupported_event' }),
    );
  });

  test('processes successful payment webhooks', async () => {
    prisma.order.findMany.mockResolvedValue([
      {
        id: 'order-1',
        orderNumber: 'ORD-1',
        customerId: 'customer-1',
        checkoutSessionId: 'session-1',
        paymentMethod: 'card',
        paymentStatus: 'pending',
        paymentProvider: null,
        totalAmount: 20,
        status: 'pending',
        fulfillmentMode: 'delivery',
        riderId: null,
        isScheduledOrder: false,
        scheduledReleasedAt: null,
      },
    ]);

    const response = await request(app)
      .post('/api/payments/webhooks/paystack')
      .send({
        event: 'charge.success',
        data: { reference: 'ref-1', amount: 2000, status: 'success', metadata: {} },
      });

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      message: 'Webhook processed',
      data: {
        reference: 'ref-1',
        eventType: 'charge.success',
        paymentStatus: 'paid',
        orderCount: 1,
        sourceOfTruth: true,
      },
    });
    expect(metrics.recordPaymentWebhookEvent).toHaveBeenCalledWith(
      expect.objectContaining({ eventType: 'charge.success', result: 'processed' }),
    );
  });

  test('returns safe 500 for unexpected webhook failures', async () => {
    prisma.order.findMany.mockRejectedValue(new Error('db exploded'));

    const response = await request(app)
      .post('/api/payments/webhooks/paystack')
      .send({ event: 'charge.success', data: { reference: 'ref-1' } });

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Server error',
    });
    expect(metrics.recordPaymentWebhookEvent).toHaveBeenCalledWith(
      expect.objectContaining({ eventType: 'charge.success', result: 'failure' }),
    );
  });
});
