jest.mock('../config/prisma', () => ({
  checkoutSession: {
    findUnique: jest.fn(),
  },
  order: {
    findUnique: jest.fn(),
  },
}));

jest.mock('../config/feature_flags', () => ({
  isMixedCheckoutEnabled: false,
  isMixedCartEnabled: false,
  isConfirmedPredispatchEnabled: false,
}));

jest.mock('../services/credit_service', () => ({
  calculateCreditApplication: jest.fn(),
  getActiveHoldForOrder: jest.fn(),
  applyCreditsToOrder: jest.fn(),
  captureHold: jest.fn(),
  releaseHold: jest.fn(),
}));

jest.mock('../services/paystack_service', () => ({
  initializeTransaction: jest.fn(),
  verifyTransaction: jest.fn(),
}));

jest.mock('../services/dispatch_service', () => ({
  dispatchOrder: jest.fn(),
}));

jest.mock('../services/pickup_order_service', () => ({
  createOrderAudit: jest.fn(),
}));

jest.mock('../services/cart_service', () => ({
  getUserCartGroups: jest.fn(),
}));

jest.mock('../services/pricing_service', () => ({
  calculateCartGroupsPricing: jest.fn(),
}));

const featureFlags = require('../config/feature_flags');
const { getUserCartGroups } = require('../services/cart_service');
const {
  createCheckoutSession,
  CheckoutSessionError,
} = require('../services/checkout_session_service');

describe('checkout_session_service guardrails', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    featureFlags.isMixedCheckoutEnabled = false;
    featureFlags.isMixedCartEnabled = false;
    featureFlags.isConfirmedPredispatchEnabled = false;
  });

  it('rejects when mixed checkout feature flag is disabled', async () => {
    await expect(
      createCheckoutSession({
        customer: { id: 'user_1', role: 'customer', email: 'user@example.com' },
        payload: {
          fulfillmentMode: 'delivery',
          paymentMethod: 'card',
          deliveryAddress: { street: 'Osu', city: 'Accra' },
        },
      })
    ).rejects.toMatchObject({
      name: 'CheckoutSessionError',
      code: 'MIXED_CHECKOUT_DISABLED',
      status: 403,
    });
  });

  it('rejects when mixed cart feature flag is disabled', async () => {
    featureFlags.isMixedCheckoutEnabled = true;
    featureFlags.isMixedCartEnabled = false;

    await expect(
      createCheckoutSession({
        customer: { id: 'user_1', role: 'customer', email: 'user@example.com' },
        payload: {
          fulfillmentMode: 'delivery',
          paymentMethod: 'card',
          deliveryAddress: { street: 'Osu', city: 'Accra' },
        },
      })
    ).rejects.toMatchObject({
      name: 'CheckoutSessionError',
      code: 'MIXED_CART_DISABLED',
      status: 403,
    });
  });

  it('rejects mixed checkout when less than two vendor groups are present', async () => {
    featureFlags.isMixedCheckoutEnabled = true;
    featureFlags.isMixedCartEnabled = true;

    getUserCartGroups.mockResolvedValue([
      {
        id: 'cart_1',
        cartType: 'food',
        restaurantId: 'rest_1',
        items: [],
      },
    ]);

    await expect(
      createCheckoutSession({
        customer: { id: 'user_1', role: 'customer', email: 'user@example.com' },
        payload: {
          fulfillmentMode: 'delivery',
          paymentMethod: 'card',
          deliveryAddress: { street: 'Osu', city: 'Accra' },
        },
      })
    ).rejects.toMatchObject({
      name: 'CheckoutSessionError',
      code: 'MIXED_CHECKOUT_MIN_GROUPS_NOT_MET',
      status: 400,
    });
  });

  it('rejects non-card payment methods for mixed checkout', async () => {
    featureFlags.isMixedCheckoutEnabled = true;
    featureFlags.isMixedCartEnabled = true;

    await expect(
      createCheckoutSession({
        customer: { id: 'user_1', role: 'customer', email: 'user@example.com' },
        payload: {
          fulfillmentMode: 'delivery',
          paymentMethod: 'cash',
          deliveryAddress: { street: 'Osu', city: 'Accra' },
        },
      })
    ).rejects.toMatchObject({
      name: 'CheckoutSessionError',
      code: 'MIXED_CHECKOUT_CARD_ONLY',
      status: 400,
    });
  });

  it('exports CheckoutSessionError for structured route handling', () => {
    const err = new CheckoutSessionError('x', { code: 'TEST', status: 409 });
    expect(err.code).toBe('TEST');
    expect(err.status).toBe(409);
  });
});
