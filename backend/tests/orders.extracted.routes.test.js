const express = require('express');
const request = require('supertest');

jest.mock('../middleware/auth', () => ({
  protect: (req, res, next) => {
    const role = req.header('x-test-role');
    const userId = req.header('x-test-user-id');
    const email = req.header('x-test-email') || null;

    if (!role || !userId) {
      return res.status(401).json({ success: false, message: 'Not authorized' });
    }

    req.user = { id: userId, role, email };
    return next();
  },
  authorize: (...roles) => (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authorized' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Forbidden' });
    }
    return next();
  },
}));

jest.mock('../middleware/upload', () => ({
  uploadSingle: () => (_req, _res, next) => next(),
  uploadToCloudinary: (req, _res, next) => {
    req.file = req.file || { path: 'https://cdn.test/proof.jpg' };
    next();
  },
}));

jest.mock('../middleware/cache', () => ({
  cacheMiddleware: () => (_req, _res, next) => next(),
  invalidateCache: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../middleware/fraud_rate_limit', () => ({
  paymentAttemptRateLimit: (_req, _res, next) => next(),
}));

jest.mock('../utils/cache', () => ({
  CACHE_KEYS: {
    FOOD_ITEM: 'food_item',
  },
}));

jest.mock('../config/feature_flags', () => ({
  isPickupVendorOpsEnabled: true,
  isPickupOtpEnabled: true,
  codUpfrontIncludeRainFee: false,
  isConfirmedPredispatchEnabled: false,
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
  order: {
    findUnique: jest.fn(),
    update: jest.fn(),
  },
  orderActionAudit: {
    create: jest.fn(),
  },
  restaurant: {
    findFirst: jest.fn(),
  },
  groceryStore: {
    findFirst: jest.fn(),
  },
  pharmacyStore: {
    findFirst: jest.fn(),
  },
  grabMartStore: {
    findFirst: jest.fn(),
  },
  user: {
    findUnique: jest.fn(),
  },
  promoCode: {
    findUnique: jest.fn(),
    updateMany: jest.fn(),
  },
}));

jest.mock('../services/tracking_service', () => ({
  initializeTracking: jest.fn(),
  updateTrackingStatus: jest.fn(),
}));

jest.mock('../services/fcm_service', () => ({
  sendOrderNotification: jest.fn().mockResolvedValue(undefined),
  sendToUser: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../services/notification_service', () => ({
  createNotification: jest.fn().mockResolvedValue(undefined),
}));

jest.mock('../services/referral_service', () => ({
  completeReferral: jest.fn(),
}));

jest.mock('../services/credit_service', () => ({
  calculateCreditApplication: jest.fn(),
  applyCreditsToOrder: jest.fn(),
  createHold: jest.fn(),
  getActiveHoldForOrder: jest.fn(),
  captureHold: jest.fn(),
  releaseHold: jest.fn(),
}));

jest.mock('../services/pricing_service', () => ({
  calculateOrderPricing: jest.fn(),
}));

jest.mock('../services/paystack_service', () => ({
  initializeTransaction: jest.fn(),
}));

jest.mock('../utils/socket', () => ({
  getIO: jest.fn(() => null),
}));

jest.mock('../services/dispatch_service', () => ({
  dispatchOrder: jest.fn(),
}));

jest.mock('../services/dispatch_retry_service', () => ({
  isRecoverableDispatchFailure: jest.fn(() => false),
  enqueueDispatchRetry: jest.fn(),
  resetDispatchAttemptHistory: jest.fn(),
  markRetryResolved: jest.fn(),
}));

jest.mock('../utils/metrics', () => ({
  recordOrderEvent: jest.fn(),
}));

jest.mock('../services/otp_service', () => ({
  normalizeGhanaPhone: jest.fn((value) => ({ e164: value })),
}));

jest.mock('../services/delivery_verification_service', () => {
  class DeliveryVerificationError extends Error {
    constructor(message, { status = 400, code = null, meta = null } = {}) {
      super(message);
      this.status = status;
      this.code = code;
      this.meta = meta;
    }
  }

  return {
    DeliveryVerificationError,
    generateDeliveryCode: jest.fn(() => '654321'),
    hashDeliveryCode: jest.fn(() => 'hashed-code'),
    encryptDeliveryCode: jest.fn(() => 'encrypted-code'),
    decryptDeliveryCode: jest.fn(() => '654321'),
    getResendAvailability: jest.fn(() => ({ allowed: true })),
    sendDeliveryCodeSms: jest.fn().mockResolvedValue({ success: true, provider: 'hubtel' }),
    verifyDeliveryCodeOrThrow: jest.fn(),
  };
});

jest.mock('../services/scheduled_order_service', () => {
  class ScheduledOrderError extends Error {
    constructor(message, { status = 400, code = null } = {}) {
      super(message);
      this.status = status;
      this.code = code;
    }
  }

  return {
    ScheduledOrderError,
    validateScheduledDeliveryRequest: jest.fn(),
    validateScheduledVendorAvailability: jest.fn(),
    normalizeDeliveryTimeType: jest.fn((value) => value || 'asap'),
  };
});

jest.mock('../services/pickup_order_service', () => ({
  createOrderAudit: jest.fn().mockResolvedValue(undefined),
  reserveInventoryForOrder: jest.fn(),
  releaseInventoryHolds: jest.fn(),
  cancelPickupOrder: jest.fn(),
}));

jest.mock('../utils/scheduled_orders', () => ({
  isVendorAcceptingScheduledOrders: jest.fn(() => true),
}));

jest.mock('../services/cod_service', () => {
  class CodPolicyError extends Error {
    constructor(message, { status = 400, code = null } = {}) {
      super(message);
      this.status = status;
      this.code = code;
    }
  }

  return {
    CodPolicyError,
    COD_NO_SHOW_REASON: 'cod_no_show',
    isCodNoShowReason: jest.fn(() => false),
    getCodExternalPaymentAmount: jest.fn((order) => Number(order.deliveryFee || 0) + Number(order.rainFee || 0)),
    getCodRemainingCashAmount: jest.fn(() => 0),
    validateCodNoShowEvidence: jest.fn(),
    evaluateCodEligibility: jest.fn(),
    isCodDispatchAllowedStatus: jest.fn(() => true),
  };
});

jest.mock('../services/food_customization_service', () => ({
  resolveFoodCustomization: jest.fn(),
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

jest.mock('../services/vendor_rating_service', () => {
  class VendorRatingError extends Error {}
  return {
    VendorRatingError,
    decorateOrdersWithVendorRatingMeta: jest.fn(async (orders) => orders),
    submitVendorRating: jest.fn(),
  };
});

jest.mock('../services/item_review_service', () => {
  class ItemReviewError extends Error {}
  return {
    ItemReviewError,
    decorateOrdersWithItemReviewMeta: jest.fn(async (orders) => orders),
    submitItemReviews: jest.fn(),
  };
});

const prisma = require('../config/prisma');
const paystackService = require('../services/paystack_service');
const { sendDeliveryCodeSms } = require('../services/delivery_verification_service');
const ordersRoutes = require('../routes/orders');

const makeApp = () => {
  const app = express();
  app.use(express.json());
  app.use('/api/orders', ordersRoutes);
  return app;
};

const withAuth = (req, { role = 'customer', userId = 'user-1', email = 'user@example.com' } = {}) =>
  req.set('x-test-role', role).set('x-test-user-id', userId).set('x-test-email', email);

describe('Orders Routes - extracted flow regressions', () => {
  let app;

  beforeAll(() => {
    app = makeApp();
  });

  beforeEach(() => {
    jest.clearAllMocks();
    prisma.restaurant.findFirst.mockResolvedValue(null);
    prisma.groceryStore.findFirst.mockResolvedValue(null);
    prisma.pharmacyStore.findFirst.mockResolvedValue(null);
    prisma.grabMartStore.findFirst.mockResolvedValue(null);
    prisma.orderActionAudit.create.mockResolvedValue(undefined);
    prisma.user.findUnique.mockResolvedValue({ email: 'customer@example.com', phone: '+233200000000' });
    prisma.order.update.mockResolvedValue({ id: 'order-1', status: 'preparing', customerId: 'customer-1' });
    paystackService.initializeTransaction.mockResolvedValue({
      authorization_url: 'https://paystack.test/authorize',
      reference: 'paystack-ref-1',
      access_code: 'access-1',
    });
    sendDeliveryCodeSms.mockResolvedValue({ success: true, provider: 'hubtel' });
  });

  test('accepts a pickup order for the owning restaurant', async () => {
    prisma.restaurant.findFirst.mockResolvedValue({ id: 'rest-1' });
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-1',
      orderNumber: 'ORD-1',
      customerId: 'customer-1',
      status: 'confirmed',
      fulfillmentMode: 'pickup',
      restaurantId: 'rest-1',
      groceryStoreId: null,
      pharmacyStoreId: null,
      grabMartStoreId: null,
      acceptedAt: null,
      paymentStatus: 'pending',
    });
    prisma.order.update.mockResolvedValue({
      id: 'order-1',
      orderNumber: 'ORD-1',
      status: 'preparing',
      customerId: 'customer-1',
      paymentStatus: 'pending',
    });

    const response = await withAuth(
      request(app).post('/api/orders/order-1/pickup/accept'),
      { role: 'restaurant', userId: 'vendor-1', email: 'vendor@grabgo.test' }
    );

    expect(response.statusCode).toBe(200);
    expect(response.body).toMatchObject({
      success: true,
      message: 'Pickup order accepted',
      data: {
        id: 'order-1',
        status: 'preparing',
      },
    });
    expect(prisma.orderActionAudit.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        orderId: 'order-1',
        actorId: 'vendor-1',
        actorRole: 'restaurant',
        action: 'pickup_accept',
      }),
    });
  });

  test('rejects pickup acceptance when the restaurant does not own the order', async () => {
    prisma.restaurant.findFirst.mockResolvedValue({ id: 'rest-2' });
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-1',
      orderNumber: 'ORD-1',
      customerId: 'customer-1',
      status: 'confirmed',
      fulfillmentMode: 'pickup',
      restaurantId: 'rest-1',
      groceryStoreId: null,
      pharmacyStoreId: null,
      grabMartStoreId: null,
      acceptedAt: null,
      paymentStatus: 'pending',
    });

    const response = await withAuth(
      request(app).post('/api/orders/order-1/pickup/accept'),
      { role: 'restaurant', userId: 'vendor-1', email: 'vendor@grabgo.test' }
    );

    expect(response.statusCode).toBe(403);
    expect(response.body).toEqual({
      success: false,
      message: 'Not authorized to manage this order',
    });
  });

  test('resends a gift delivery code to the customer for an authorized customer actor', async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-2',
      orderNumber: 'ORD-2',
      customerId: 'customer-1',
      riderId: 'rider-1',
      status: 'picked_up',
      isGiftOrder: true,
      deliveryVerificationRequired: true,
      giftRecipientName: 'Kofi',
      giftRecipientPhone: '+233244444444',
      deliveryCodeEncrypted: 'encrypted-code',
      deliveryCodeResendCount: 0,
      deliveryCodeLastSentAt: null,
      deliveryCodeVerifiedAt: null,
      deliveryVerificationMethod: 'sms',
    });

    const response = await withAuth(
      request(app).post('/api/orders/order-2/delivery-code/resend').send({ target: 'customer' }),
      { role: 'customer', userId: 'customer-1', email: 'customer@example.com' }
    );

    expect(response.statusCode).toBe(200);
    expect(response.body).toMatchObject({
      success: true,
      message: 'Delivery code resent successfully',
      data: {
        orderId: 'order-2',
        target: 'customer',
        giftDeliveryCode: '654321',
      },
    });
    expect(sendDeliveryCodeSms).toHaveBeenCalledWith({
      phoneNumber: '+233200000000',
      orderNumber: 'ORD-2',
      code: '654321',
      audience: 'customer',
      recipientName: 'Kofi',
    });
  });

  test('rejects rider resend attempts when target is customer instead of recipient', async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-3',
      orderNumber: 'ORD-3',
      customerId: 'customer-1',
      riderId: 'rider-1',
      status: 'picked_up',
      isGiftOrder: true,
      deliveryVerificationRequired: true,
      giftRecipientName: 'Ama',
      giftRecipientPhone: '+233244444444',
      deliveryCodeEncrypted: 'encrypted-code',
      deliveryCodeResendCount: 0,
      deliveryCodeLastSentAt: null,
      deliveryCodeVerifiedAt: null,
      deliveryVerificationMethod: 'sms',
    });

    const response = await withAuth(
      request(app).post('/api/orders/order-3/delivery-code/resend').send({ target: 'customer' }),
      { role: 'rider', userId: 'rider-1', email: 'rider@example.com' }
    );

    expect(response.statusCode).toBe(403);
    expect(response.body).toEqual({
      success: false,
      message: 'Riders can only resend code to recipient',
    });
  });

  test('initializes paystack payment for an owned unpaid order', async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-4',
      customerId: 'customer-1',
      totalAmount: 58.25,
      deliveryFee: 8,
      rainFee: 1.5,
      paymentMethod: 'card',
      paymentStatus: 'pending',
      orderNumber: 'ORD-4',
    });
    prisma.user.findUnique.mockResolvedValue({ email: 'customer@example.com' });
    prisma.order.update.mockResolvedValue(undefined);

    const response = await withAuth(
      request(app).post('/api/orders/order-4/paystack/initialize'),
      { role: 'customer', userId: 'customer-1', email: 'customer@example.com' }
    );

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      success: true,
      message: 'Payment initialized',
      data: {
        authorizationUrl: 'https://paystack.test/authorize',
        reference: 'paystack-ref-1',
        accessCode: 'access-1',
        paymentAmount: 58.25,
        paymentScope: 'full_order_payment',
      },
    });
    expect(paystackService.initializeTransaction).toHaveBeenCalledWith(
      expect.objectContaining({
        email: 'customer@example.com',
        amount: 5825,
        metadata: {
          orderId: 'order-4',
          paymentScope: 'full_order_payment',
        },
      })
    );
  });

  test('returns a safe 500 when paystack initialization fails unexpectedly', async () => {
    prisma.order.findUnique.mockResolvedValue({
      id: 'order-5',
      customerId: 'customer-1',
      totalAmount: 20,
      deliveryFee: 5,
      rainFee: 0,
      paymentMethod: 'card',
      paymentStatus: 'pending',
      orderNumber: 'ORD-5',
    });
    prisma.user.findUnique.mockResolvedValue({ email: 'customer@example.com' });
    paystackService.initializeTransaction.mockRejectedValue(new Error('gateway offline'));

    const response = await withAuth(
      request(app).post('/api/orders/order-5/paystack/initialize'),
      { role: 'customer', userId: 'customer-1', email: 'customer@example.com' }
    );

    expect(response.statusCode).toBe(500);
    expect(response.body).toEqual({
      success: false,
      message: 'Server error',
    });
  });
});
