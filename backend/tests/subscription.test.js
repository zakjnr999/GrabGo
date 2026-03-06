/**
 * GrabGo Pro — Subscription Service Tests
 */

// ── Mocks ───────────────────────────────────────────────────────────────────

const mockPrismaSubscription = {
  findFirst: jest.fn(),
  findUnique: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  updateMany: jest.fn(),
  count: jest.fn(),
  delete: jest.fn(),
};

const mockPrismaSubscriptionPayment = {
  findUnique: jest.fn(),
  create: jest.fn(),
  upsert: jest.fn(),
  aggregate: jest.fn(),
};

jest.mock('../config/prisma', () => ({
  subscription: mockPrismaSubscription,
  subscriptionPayment: mockPrismaSubscriptionPayment,
  $transaction: jest.fn((ops) => Promise.all(ops)),
}));

jest.mock('../services/paystack_service', () => ({
  verifyWebhookSignature: jest.fn(),
  extractWebhookReference: jest.fn(),
  extractWebhookEventId: jest.fn(),
}));

jest.mock('axios', () => {
  const instance = {
    get: jest.fn(),
    post: jest.fn(),
  };
  const axiosMock = { create: jest.fn(() => instance), _instance: instance };
  return axiosMock;
});

jest.mock('../config/feature_flags', () => ({
  isSubscriptionEnabled: true,
}));

let axios;
let featureFlags;
let subscriptionService;

beforeEach(() => {
  jest.clearAllMocks();
  jest.resetModules();

  axios = require('axios');
  featureFlags = require('../config/feature_flags');

  // Re-enable feature flag
  featureFlags.isSubscriptionEnabled = true;

  // Fresh import each time
  subscriptionService = require('../services/subscription_service');
});

// ── Plan Configuration ──────────────────────────────────────────────────────

describe('getPlans', () => {
  test('returns both subscription tiers with correct structure', () => {
    const plans = subscriptionService.getPlans();

    expect(plans).toHaveLength(2);

    const plus = plans.find((p) => p.tier === 'grabgo_plus');
    expect(plus).toBeDefined();
    expect(plus.price).toBe(30);
    expect(plus.name).toBe('GrabGo Plus');
    expect(plus.benefits.serviceFeeDiscount).toBe('5% off service fee');
    expect(plus.benefits.prioritySupport).toBe(false);

    const premium = plans.find((p) => p.tier === 'grabgo_premium');
    expect(premium).toBeDefined();
    expect(premium.price).toBe(60);
    expect(premium.name).toBe('GrabGo Premium');
    expect(premium.benefits.serviceFeeDiscount).toBe('10% off service fee');
    expect(premium.benefits.prioritySupport).toBe(true);
    expect(premium.benefits.exclusiveDeals).toBe(true);
  });

  test('Plus plan says free delivery on orders above GHS 30', () => {
    const plans = subscriptionService.getPlans();
    const plus = plans.find((p) => p.tier === 'grabgo_plus');
    expect(plus.benefits.freeDelivery).toContain('above');
    expect(plus.benefits.freeDelivery).toContain('30');
  });

  test('Premium plan says free delivery on all orders', () => {
    const plans = subscriptionService.getPlans();
    const premium = plans.find((p) => p.tier === 'grabgo_premium');
    expect(premium.benefits.freeDelivery).toContain('all orders');
  });
});

// ── Active Subscription Lookup ──────────────────────────────────────────────

describe('getActiveSubscription', () => {
  test('returns null for missing userId', async () => {
    const result = await subscriptionService.getActiveSubscription(null);
    expect(result).toBeNull();
  });

  test('returns null when no active subscription exists', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(null);
    const result = await subscriptionService.getActiveSubscription('user123');
    expect(result).toBeNull();
  });

  test('returns subscription with plan details when active', async () => {
    const mockSub = {
      id: 'sub1',
      userId: 'user123',
      tier: 'grabgo_plus',
      status: 'active',
      currentPeriodEnd: new Date(Date.now() + 86400000),
    };
    mockPrismaSubscription.findFirst.mockResolvedValue(mockSub);

    const result = await subscriptionService.getActiveSubscription('user123');

    expect(result).not.toBeNull();
    expect(result.id).toBe('sub1');
    expect(result.plan).toBeDefined();
    expect(result.plan.name).toBe('GrabGo Plus');
  });

  test('queries active and billable past_due subscriptions with future end date', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(null);
    await subscriptionService.getActiveSubscription('user123');

    expect(mockPrismaSubscription.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          userId: 'user123',
          currentPeriodEnd: { gte: expect.any(Date) },
          OR: expect.arrayContaining([
            expect.objectContaining({ status: 'active' }),
            expect.objectContaining({
              status: 'past_due',
              payments: expect.objectContaining({
                some: expect.objectContaining({ status: 'success' }),
              }),
            }),
          ]),
        }),
      })
    );
  });
});

// ── Subscribe / Retry Flow ────────────────────────────────────────────────

describe('subscribe', () => {
  test('allows retry for past_due subscription by cancelling then creating a new payment session', async () => {
    const future = new Date(Date.now() + 86400000);
    const existingPastDue = {
      id: 'sub_old',
      userId: 'user123',
      tier: 'grabgo_premium',
      status: 'past_due',
      currentPeriodEnd: future,
    };

    mockPrismaSubscription.findFirst
      .mockResolvedValueOnce(existingPastDue) // getActiveSubscription in subscribe()
      .mockResolvedValueOnce(existingPastDue) // find in cancelSubscription()
      .mockResolvedValueOnce(null); // existing pending attempt check

    mockPrismaSubscription.update.mockResolvedValue({
      ...existingPastDue,
      status: 'cancelled',
      cancelledAt: new Date(),
    });
    mockPrismaSubscription.create.mockResolvedValue({ id: 'sub_new' });
    mockPrismaSubscriptionPayment.create.mockResolvedValue({
      id: 'pay_new',
      subscriptionId: 'sub_new',
      status: 'pending',
    });

    axios._instance.get.mockResolvedValue({
      data: {
        data: [
          {
            name: 'GrabGo Premium',
            amount: 6000,
            plan_code: 'PLN_existing',
          },
        ],
      },
    });
    axios._instance.post.mockResolvedValue({
      data: {
        status: true,
        data: {
          authorization_url: 'https://paystack.test/authorize',
          access_code: 'ACCESS_test',
        },
      },
    });

    const result = await subscriptionService.subscribe({
      userId: 'user123',
      email: 'test@example.com',
      tier: 'grabgo_premium',
    });

    expect(result).toBeDefined();
    expect(result.subscriptionId).toBe('sub_new');
    expect(mockPrismaSubscription.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'sub_old' },
        data: expect.objectContaining({
          status: 'cancelled',
          cancelReason: expect.stringContaining('Retrying subscription'),
        }),
      }),
    );
  });
});

// ── Subscription Benefits Calculation ───────────────────────────────────────

describe('calculateSubscriptionBenefits', () => {
  const mockActiveSub = (tier) => ({
    id: 'sub1',
    userId: 'user123',
    tier,
    status: 'active',
    currentPeriodEnd: new Date(Date.now() + 86400000),
  });

  test('returns null when feature flag is disabled', async () => {
    featureFlags.isSubscriptionEnabled = false;
    const result = await subscriptionService.calculateSubscriptionBenefits('user123', {
      subtotal: 50, deliveryFee: 10, serviceFee: 5,
    });
    expect(result).toBeNull();
  });

  test('returns null for null userId', async () => {
    const result = await subscriptionService.calculateSubscriptionBenefits(null, {
      subtotal: 50, deliveryFee: 10, serviceFee: 5,
    });
    expect(result).toBeNull();
  });

  test('returns null when user has no subscription', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(null);
    const result = await subscriptionService.calculateSubscriptionBenefits('user123', {
      subtotal: 50, deliveryFee: 10, serviceFee: 5,
    });
    expect(result).toBeNull();
  });

  // GrabGo Plus tests
  test('Plus: waives delivery fee when subtotal >= 30', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(mockActiveSub('grabgo_plus'));

    const result = await subscriptionService.calculateSubscriptionBenefits('user123', {
      subtotal: 50, deliveryFee: 8, serviceFee: 5,
    });

    expect(result).not.toBeNull();
    expect(result.deliveryDiscount).toBe(8);        // Full delivery fee waived
    expect(result.serviceFeeDiscount).toBe(0.25);    // 5% of GHS 5
    expect(result.tier).toBe('grabgo_plus');
  });

  test('Plus: does NOT waive delivery fee when subtotal < 30', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(mockActiveSub('grabgo_plus'));

    const result = await subscriptionService.calculateSubscriptionBenefits('user123', {
      subtotal: 20, deliveryFee: 8, serviceFee: 5,
    });

    // Only service fee discount, no delivery discount
    expect(result).not.toBeNull();
    expect(result.deliveryDiscount).toBe(0);
    expect(result.serviceFeeDiscount).toBe(0.25);    // 5% of GHS 5
  });

  test('Plus: applies 5% service fee discount', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(mockActiveSub('grabgo_plus'));

    const result = await subscriptionService.calculateSubscriptionBenefits('user123', {
      subtotal: 100, deliveryFee: 10, serviceFee: 10,
    });

    expect(result.serviceFeeDiscount).toBe(0.5);     // 5% of GHS 10
  });

  // GrabGo Premium tests
  test('Premium: waives delivery fee on ALL orders (even small ones)', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(mockActiveSub('grabgo_premium'));

    const result = await subscriptionService.calculateSubscriptionBenefits('user123', {
      subtotal: 10, deliveryFee: 8, serviceFee: 3,
    });

    expect(result).not.toBeNull();
    expect(result.deliveryDiscount).toBe(8);         // Full delivery fee waived
    expect(result.tier).toBe('grabgo_premium');
  });

  test('Premium: applies 10% service fee discount', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(mockActiveSub('grabgo_premium'));

    const result = await subscriptionService.calculateSubscriptionBenefits('user123', {
      subtotal: 100, deliveryFee: 10, serviceFee: 10,
    });

    expect(result.serviceFeeDiscount).toBe(1.0);     // 10% of GHS 10
  });

  test('Premium: totalDiscount combines delivery + service discount', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(mockActiveSub('grabgo_premium'));

    const result = await subscriptionService.calculateSubscriptionBenefits('user123', {
      subtotal: 50, deliveryFee: 10, serviceFee: 8,
    });

    expect(result.deliveryDiscount).toBe(10);
    expect(result.serviceFeeDiscount).toBe(0.8);     // 10% of GHS 8
    expect(result.totalDiscount).toBe(10.8);
  });

  test('returns null when both discounts are 0', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(mockActiveSub('grabgo_plus'));

    const result = await subscriptionService.calculateSubscriptionBenefits('user123', {
      subtotal: 10, deliveryFee: 0, serviceFee: 0,
    });

    // Plus with subtotal < 30 and no fees → null (no benefit to apply)
    expect(result).toBeNull();
  });
});

// ── Preview Benefits ────────────────────────────────────────────────────────

describe('previewBenefits', () => {
  test('returns hasSubscription: false when no subscription', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(null);
    const result = await subscriptionService.previewBenefits('user123', 50);

    expect(result.hasSubscription).toBe(false);
    expect(result.benefits).toBeNull();
  });

  test('Plus: shows freeDelivery true when subtotal >= 30', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue({
      id: 'sub1', tier: 'grabgo_plus', status: 'active',
      currentPeriodEnd: new Date(Date.now() + 86400000),
    });

    const result = await subscriptionService.previewBenefits('user123', 50);

    expect(result.hasSubscription).toBe(true);
    expect(result.benefits.freeDelivery).toBe(true);
    expect(result.benefits.serviceFeeDiscountPercent).toBe(5);
  });

  test('Plus: shows freeDelivery false when subtotal < 30', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue({
      id: 'sub1', tier: 'grabgo_plus', status: 'active',
      currentPeriodEnd: new Date(Date.now() + 86400000),
    });

    const result = await subscriptionService.previewBenefits('user123', 15);
    expect(result.benefits.freeDelivery).toBe(false);
  });

  test('Premium: always shows freeDelivery true', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue({
      id: 'sub1', tier: 'grabgo_premium', status: 'active',
      currentPeriodEnd: new Date(Date.now() + 86400000),
    });

    const result = await subscriptionService.previewBenefits('user123', 5);
    expect(result.benefits.freeDelivery).toBe(true);
    expect(result.benefits.serviceFeeDiscountPercent).toBe(10);
    expect(result.benefits.prioritySupport).toBe(true);
  });
});

// ── Cancel Subscription ─────────────────────────────────────────────────────

describe('cancelSubscription', () => {
  test('throws when no active subscription', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue(null);

    await expect(subscriptionService.cancelSubscription('user123'))
      .rejects.toThrow('No active subscription found');
  });

  test('cancels and returns activeUntil date', async () => {
    const periodEnd = new Date(Date.now() + 86400000 * 15);
    mockPrismaSubscription.findFirst.mockResolvedValue({
      id: 'sub1', tier: 'grabgo_plus', status: 'active',
      currentPeriodEnd: periodEnd,
    });
    mockPrismaSubscription.update.mockResolvedValue({
      id: 'sub1', tier: 'grabgo_plus', status: 'cancelled',
      cancelledAt: new Date(), currentPeriodEnd: periodEnd,
    });

    const result = await subscriptionService.cancelSubscription('user123', 'Too expensive');

    expect(mockPrismaSubscription.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'sub1' },
        data: expect.objectContaining({
          status: 'cancelled',
          cancelReason: 'Too expensive',
        }),
      })
    );
    expect(result.activeUntil).toEqual(periodEnd);
    expect(result.message).toContain('cancelled');
  });
});

// ── Webhook Handling ────────────────────────────────────────────────────────

describe('handleWebhook', () => {
  test('subscription.create activates the subscription', async () => {
    mockPrismaSubscription.update.mockResolvedValue({ id: 'sub1', status: 'active' });

    const result = await subscriptionService.handleWebhook('subscription.create', {
      data: {
        subscription_code: 'SUB_abc123',
        customer: { customer_code: 'CUS_xyz' },
        email_token: 'tok_123',
        plan: { plan_code: 'PLN_test' },
        metadata: { subscriptionId: 'sub1' },
      },
    });

    expect(result).toBeDefined();
    expect(mockPrismaSubscription.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'sub1' },
        data: expect.objectContaining({
          status: 'active',
          paystackSubscriptionCode: 'SUB_abc123',
          paystackCustomerCode: 'CUS_xyz',
        }),
      })
    );
  });

  test('subscription.not_renew cancels the subscription', async () => {
    mockPrismaSubscription.findFirst.mockResolvedValue({
      id: 'sub1', paystackSubscriptionCode: 'SUB_abc123',
    });
    mockPrismaSubscription.update.mockResolvedValue({ id: 'sub1', status: 'cancelled' });

    const result = await subscriptionService.handleWebhook('subscription.not_renew', {
      data: { subscription_code: 'SUB_abc123' },
    });

    expect(result).toBeDefined();
    expect(mockPrismaSubscription.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'cancelled' }),
      })
    );
  });

  test('charge.success with type=subscription records payment', async () => {
    mockPrismaSubscription.findUnique.mockResolvedValue({
      id: 'sub1', currentPeriodEnd: new Date(),
    });

    await subscriptionService.handleWebhook('charge.success', {
      data: {
        reference: 'ref_123',
        amount: 3000,
        metadata: { subscriptionId: 'sub1', type: 'subscription' },
      },
    });

    expect(mockPrismaSubscription.findUnique).toHaveBeenCalled();
  });

  test('charge.success without type=subscription is ignored', async () => {
    const result = await subscriptionService.handleWebhook('charge.success', {
      data: {
        reference: 'ref_regular',
        amount: 5000,
        metadata: { type: 'order' },
      },
    });

    expect(result).toBeNull();
    expect(mockPrismaSubscription.findUnique).not.toHaveBeenCalled();
  });

  test('invoice.payment_failed marks active subscription as past_due', async () => {
    mockPrismaSubscription.findUnique.mockResolvedValue({
      id: 'sub1',
      status: 'active',
    });

    await subscriptionService.handleWebhook('invoice.payment_failed', {
      data: {
        reference: 'ref_fail',
        amount: 3000,
        metadata: { subscriptionId: 'sub1' },
        gateway_response: 'Insufficient funds',
      },
    });

    expect(mockPrismaSubscription.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'sub1' },
        data: expect.objectContaining({ status: 'past_due' }),
      }),
    );
  });

  test('invoice.payment_failed cancels pending initial subscription attempt', async () => {
    mockPrismaSubscription.findUnique.mockResolvedValue({
      id: 'sub_pending',
      status: 'pending',
    });

    await subscriptionService.handleWebhook('invoice.payment_failed', {
      data: {
        reference: 'ref_pending_fail',
        amount: 3000,
        metadata: { subscriptionId: 'sub_pending' },
        gateway_response: 'Insufficient funds',
      },
    });

    expect(mockPrismaSubscription.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'sub_pending' },
        data: expect.objectContaining({
          status: 'cancelled',
          cancelledAt: expect.any(Date),
        }),
      }),
    );
  });

  test('unknown events return null gracefully', async () => {
    const result = await subscriptionService.handleWebhook('unknown.event', {});
    expect(result).toBeNull();
  });
});

// ── Expiry Job ──────────────────────────────────────────────────────────────

describe('expireStaleSubscriptions', () => {
  test('marks expired subscriptions', async () => {
    mockPrismaSubscription.updateMany.mockResolvedValue({ count: 3 });

    const count = await subscriptionService.expireStaleSubscriptions();

    expect(count).toBe(3);
    expect(mockPrismaSubscription.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: { in: ['active', 'past_due'] },
          currentPeriodEnd: { lt: expect.any(Date) },
        }),
        data: { status: 'expired' },
      })
    );
  });

  test('returns 0 when nothing to expire', async () => {
    mockPrismaSubscription.updateMany.mockResolvedValue({ count: 0 });
    const count = await subscriptionService.expireStaleSubscriptions();
    expect(count).toBe(0);
  });
});

// ── Subscription Stats ──────────────────────────────────────────────────────

describe('getSubscriptionStats', () => {
  test('returns aggregated stats', async () => {
    mockPrismaSubscription.count
      .mockResolvedValueOnce(100)   // activePlus
      .mockResolvedValueOnce(40)    // activePremium
      .mockResolvedValueOnce(5);    // pastDue — 4th call
    mockPrismaSubscriptionPayment.aggregate.mockResolvedValue({
      _sum: { amount: 8400 },
    });

    const stats = await subscriptionService.getSubscriptionStats();

    expect(stats.totalActive).toBe(140);
    expect(stats.activePlus).toBe(100);
    expect(stats.activePremium).toBe(40);
    expect(stats.mrr).toBe(100 * 30 + 40 * 60); // 3000 + 2400 = 5400
    expect(stats.totalRevenue).toBe(8400);
    expect(stats.currency).toBe('GHS');
  });
});
