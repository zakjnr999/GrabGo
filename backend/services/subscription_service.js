/**
 * GrabGo Pro — Subscription Service
 *
 * Manages customer subscriptions (GrabGo Plus / GrabGo Premium).
 * Integrates with Paystack Plans & Subscriptions API for recurring billing.
 *
 * Tier Benefits:
 *   GrabGo Plus    (GHS 30/mo) — Free delivery on orders > GHS 30, 5% off service fee
 *   GrabGo Premium (GHS 60/mo) — Free delivery on all orders, 10% off service fee, priority support
 */

const prisma = require('../config/prisma');
const paystackService = require('./paystack_service');
const featureFlags = require('../config/feature_flags');
const axios = require('axios');

// ── Plan Configuration ──────────────────────────────────────────────────────
const PLANS = {
  grabgo_plus: {
    tier: 'grabgo_plus',
    name: 'GrabGo Plus',
    amount: parseFloat(process.env.GRABGO_PLUS_PRICE || '30'),      // GHS
    interval: 'monthly',
    description: 'Free delivery on orders > GHS 30, 5% off service fee',
    freeDeliveryMinOrder: parseFloat(process.env.GRABGO_PLUS_FREE_DELIVERY_MIN || '30'),
    serviceFeeDiscount: parseFloat(process.env.GRABGO_PLUS_SERVICE_DISCOUNT || '0.05'),
    hasPrioritySupport: false,
    hasExclusiveDeals: false,
  },
  grabgo_premium: {
    tier: 'grabgo_premium',
    name: 'GrabGo Premium',
    amount: parseFloat(process.env.GRABGO_PREMIUM_PRICE || '60'),   // GHS
    interval: 'monthly',
    description: 'Free delivery on all orders, 10% off service fee, priority support',
    freeDeliveryMinOrder: 0, // Free on ALL orders
    serviceFeeDiscount: parseFloat(process.env.GRABGO_PREMIUM_SERVICE_DISCOUNT || '0.10'),
    hasPrioritySupport: true,
    hasExclusiveDeals: true,
  },
};

// Paystack Plan codes — created once on first subscription, then cached
const PAYSTACK_PLAN_CODES = {};

const PAYSTACK_SECRET_KEY = process.env.PAYSTACK_SECRET_KEY;
const PAYSTACK_BASE_URL = process.env.PAYSTACK_BASE_URL || 'https://api.paystack.co';
const PAYSTACK_CURRENCY = process.env.PAYSTACK_CURRENCY || 'GHS';
const PAYSTACK_CALLBACK_URL = process.env.PAYSTACK_SUBSCRIPTION_CALLBACK_URL
  || process.env.PAYSTACK_CALLBACK_URL
  || 'https://standard.paystack.co/close';

const paystackClient = axios.create({
  baseURL: PAYSTACK_BASE_URL,
  headers: {
    Authorization: `Bearer ${PAYSTACK_SECRET_KEY || ''}`,
    'Content-Type': 'application/json',
  },
});

const addOneMonth = (date) => {
  const next = new Date(date);
  next.setMonth(next.getMonth() + 1);
  return next;
};

// ── Paystack Plan Management ────────────────────────────────────────────────

/**
 * Ensure a Paystack plan exists for the given tier, creating it if necessary.
 * Returns the Paystack plan_code.
 */
const ensurePaystackPlan = async (tier) => {
  if (PAYSTACK_PLAN_CODES[tier]) return PAYSTACK_PLAN_CODES[tier];

  const plan = PLANS[tier];
  if (!plan) throw new Error(`Unknown subscription tier: ${tier}`);

  // Try to find existing plan by name
  try {
    const { data } = await paystackClient.get('/plan', { params: { perPage: 100 } });
    const existing = data?.data?.find((p) => p.name === plan.name && p.amount === plan.amount * 100);
    if (existing?.plan_code) {
      PAYSTACK_PLAN_CODES[tier] = existing.plan_code;
      return existing.plan_code;
    }
  } catch (err) {
    console.warn(`⚠️ [SUBSCRIPTION] Failed to list Paystack plans: ${err.message}`);
  }

  // Create new plan
  const { data } = await paystackClient.post('/plan', {
    name: plan.name,
    amount: Math.round(plan.amount * 100), // Paystack expects pesewas/kobo
    interval: plan.interval,
    currency: PAYSTACK_CURRENCY,
    description: plan.description,
  });

  if (!data?.status || !data?.data?.plan_code) {
    throw new Error(data?.message || 'Failed to create Paystack plan');
  }

  PAYSTACK_PLAN_CODES[tier] = data.data.plan_code;
  console.log(`✅ [SUBSCRIPTION] Created Paystack plan: ${plan.name} → ${data.data.plan_code}`);
  return data.data.plan_code;
};

// ── Core Subscription Methods ───────────────────────────────────────────────

/**
 * Get available subscription plans.
 */
const getPlans = () => {
  return Object.values(PLANS).map((plan) => ({
    tier: plan.tier,
    name: plan.name,
    price: plan.amount,
    currency: PAYSTACK_CURRENCY,
    interval: plan.interval,
    description: plan.description,
    benefits: {
      freeDelivery: plan.freeDeliveryMinOrder === 0
        ? 'Free delivery on all orders'
        : `Free delivery on orders above ${PAYSTACK_CURRENCY} ${plan.freeDeliveryMinOrder}`,
      serviceFeeDiscount: `${Math.round(plan.serviceFeeDiscount * 100)}% off service fee`,
      prioritySupport: plan.hasPrioritySupport,
      exclusiveDeals: plan.hasExclusiveDeals,
    },
  }));
};

/**
 * Get a user's active subscription, or null.
 */
const getActiveSubscription = async (userId) => {
  if (!userId) return null;

  const subscription = await prisma.subscription.findFirst({
    where: {
      userId,
      status: { in: ['active', 'past_due'] },
      currentPeriodEnd: { gte: new Date() },
    },
    orderBy: { createdAt: 'desc' },
  });

  if (!subscription) return null;

  const plan = PLANS[subscription.tier];
  return {
    ...subscription,
    plan: plan || null,
  };
};

/**
 * Initialize a new subscription.
 * Returns a Paystack authorization URL for the customer to complete payment.
 */
const subscribe = async ({ userId, email, tier }) => {
  if (!featureFlags.isSubscriptionEnabled) {
    throw new Error('Subscriptions are not currently available');
  }

  const plan = PLANS[tier];
  if (!plan) throw new Error(`Invalid subscription tier: ${tier}`);

  // Check for existing active subscription
  const existing = await getActiveSubscription(userId);
  if (existing) {
    if (existing.tier === tier) {
      throw new Error('You already have an active subscription to this plan');
    }
    // Upgrading/downgrading — cancel the old one first
    await cancelSubscription(userId, `Switching to ${plan.name}`);
  }

  // Ensure Paystack plan exists
  const planCode = await ensurePaystackPlan(tier);

  // Initialize a transaction that will create the subscription on success
  const reference = `sub_${tier}_${userId}_${Date.now()}`;

  const now = new Date();
  const periodEnd = addOneMonth(now);

  // Create pending subscription record
  const subscription = await prisma.subscription.create({
    data: {
      userId,
      tier,
      status: 'pending',
      currentPeriodStart: now,
      currentPeriodEnd: periodEnd,
    },
  });

  // Initialize Paystack transaction with plan
  const paystackPayload = {
    email,
    amount: Math.round(plan.amount * 100), // pesewas
    reference,
    currency: PAYSTACK_CURRENCY,
    callback_url: PAYSTACK_CALLBACK_URL,
    plan: planCode,
    metadata: {
      subscriptionId: subscription.id,
      userId,
      tier,
      type: 'subscription',
    },
  };

  const response = await paystackClient.post('/transaction/initialize', paystackPayload);
  const data = response?.data;

  if (!data?.status || !data?.data?.authorization_url) {
    // Roll back the subscription record
    await prisma.subscription.delete({ where: { id: subscription.id } }).catch(() => {});
    throw new Error(data?.message || 'Failed to initialize subscription payment');
  }

  // Record the initial payment attempt
  await prisma.subscriptionPayment.create({
    data: {
      subscriptionId: subscription.id,
      amount: plan.amount,
      currency: PAYSTACK_CURRENCY,
      paystackReference: reference,
      status: 'pending',
    },
  });

  return {
    subscriptionId: subscription.id,
    authorizationUrl: data.data.authorization_url,
    accessCode: data.data.access_code,
    reference,
    plan: {
      tier: plan.tier,
      name: plan.name,
      price: plan.amount,
      currency: PAYSTACK_CURRENCY,
    },
  };
};

/**
 * Cancel a subscription. Takes effect at end of current billing period.
 */
const cancelSubscription = async (userId, reason) => {
  const subscription = await prisma.subscription.findFirst({
    where: {
      userId,
      status: { in: ['active', 'past_due'] },
    },
    orderBy: { createdAt: 'desc' },
  });

  if (!subscription) {
    throw new Error('No active subscription found');
  }

  // Cancel on Paystack if we have a subscription code
  if (subscription.paystackSubscriptionCode && subscription.paystackEmailToken) {
    try {
      await paystackClient.post('/subscription/disable', {
        code: subscription.paystackSubscriptionCode,
        token: subscription.paystackEmailToken,
      });
    } catch (err) {
      console.warn(`⚠️ [SUBSCRIPTION] Paystack cancel failed: ${err.message}`);
      // Continue with local cancellation even if Paystack call fails
    }
  }

  const updated = await prisma.subscription.update({
    where: { id: subscription.id },
    data: {
      status: 'cancelled',
      cancelledAt: new Date(),
      cancelReason: reason || 'User requested cancellation',
    },
  });

  return {
    id: updated.id,
    tier: updated.tier,
    status: updated.status,
    cancelledAt: updated.cancelledAt,
    activeUntil: updated.currentPeriodEnd, // Benefits remain until end of period
    message: `Your ${PLANS[updated.tier]?.name || 'subscription'} has been cancelled. Benefits remain active until ${updated.currentPeriodEnd.toLocaleDateString()}.`,
  };
};

// ── Pricing Benefits ────────────────────────────────────────────────────────

/**
 * Calculate subscription benefits for an order.
 * Called by the pricing service during checkout.
 *
 * @param {string} userId - The customer's user ID
 * @param {number} subtotal - The order subtotal (before fees)
 * @param {number} originalDeliveryFee - The calculated delivery fee
 * @param {number} originalServiceFee - The calculated service fee
 * @returns {{ deliveryDiscount, serviceFeeDiscount, tier, subscriptionId } | null}
 */
const calculateSubscriptionBenefits = async (userId, { subtotal, deliveryFee, serviceFee }) => {
  if (!featureFlags.isSubscriptionEnabled) return null;
  if (!userId) return null;

  const subscription = await getActiveSubscription(userId);
  if (!subscription || !subscription.plan) return null;

  const plan = subscription.plan;
  let deliveryDiscount = 0;
  let serviceFeeDiscount = 0;

  // Delivery fee waiver
  if (plan.freeDeliveryMinOrder === 0) {
    // Premium: free delivery on ALL orders
    deliveryDiscount = deliveryFee;
  } else if (subtotal >= plan.freeDeliveryMinOrder) {
    // Plus: free delivery when subtotal >= threshold
    deliveryDiscount = deliveryFee;
  }

  // Service fee discount
  if (plan.serviceFeeDiscount > 0 && serviceFee > 0) {
    serviceFeeDiscount = Math.round((serviceFee * plan.serviceFeeDiscount + Number.EPSILON) * 100) / 100;
  }

  if (deliveryDiscount === 0 && serviceFeeDiscount === 0) return null;

  return {
    subscriptionId: subscription.id,
    tier: subscription.tier,
    tierName: plan.name,
    deliveryDiscount: Math.round((deliveryDiscount + Number.EPSILON) * 100) / 100,
    serviceFeeDiscount: Math.round((serviceFeeDiscount + Number.EPSILON) * 100) / 100,
    totalDiscount: Math.round((deliveryDiscount + serviceFeeDiscount + Number.EPSILON) * 100) / 100,
  };
};

/**
 * Check what benefits a user would get for a given order.
 * Used by the app to show savings preview.
 */
const previewBenefits = async (userId, subtotal) => {
  if (!userId) return { hasSubscription: false, benefits: null };

  const subscription = await getActiveSubscription(userId);
  if (!subscription || !subscription.plan) {
    return { hasSubscription: false, benefits: null };
  }

  const plan = subscription.plan;

  return {
    hasSubscription: true,
    tier: subscription.tier,
    tierName: plan.name,
    status: subscription.status,
    expiresAt: subscription.currentPeriodEnd,
    benefits: {
      freeDelivery: plan.freeDeliveryMinOrder === 0
        ? true
        : (subtotal || 0) >= plan.freeDeliveryMinOrder,
      freeDeliveryMinOrder: plan.freeDeliveryMinOrder,
      serviceFeeDiscountPercent: Math.round(plan.serviceFeeDiscount * 100),
      prioritySupport: plan.hasPrioritySupport,
      exclusiveDeals: plan.hasExclusiveDeals,
    },
  };
};

// ── Webhook Handlers ────────────────────────────────────────────────────────

/**
 * Handle Paystack subscription.create webhook.
 * Activates the subscription and stores the Paystack subscription code.
 */
const handleSubscriptionCreated = async (payload) => {
  const subscriptionCode = payload?.data?.subscription_code;
  const customerCode = payload?.data?.customer?.customer_code;
  const emailToken = payload?.data?.email_token;
  const planCode = payload?.data?.plan?.plan_code;
  const meta = payload?.data?.metadata || {};

  if (!meta.subscriptionId) {
    console.warn('⚠️ [SUBSCRIPTION] Webhook missing subscriptionId in metadata');
    return null;
  }

  const updated = await prisma.subscription.update({
    where: { id: meta.subscriptionId },
    data: {
      status: 'active',
      paystackSubscriptionCode: subscriptionCode,
      paystackCustomerCode: customerCode,
      paystackEmailToken: emailToken,
    },
  });

  console.log(`✅ [SUBSCRIPTION] Activated: ${updated.id} (${updated.tier})`);
  return updated;
};

/**
 * Handle invoice.update / charge.success webhook for recurring payments.
 * Records the payment and extends the subscription period.
 */
const handlePaymentSuccess = async (payload) => {
  const reference = payload?.data?.reference;
  const amount = (payload?.data?.amount || 0) / 100; // pesewas → GHS
  const meta = payload?.data?.metadata || {};

  let paymentByReference = null;
  if (reference) {
    paymentByReference = await prisma.subscriptionPayment.findUnique({
      where: { paystackReference: reference },
      include: { subscription: true },
    });
  }

  if (paymentByReference?.status === 'success') {
    return paymentByReference.subscription;
  }

  // Find subscription by metadata or reference
  let subscription;

  if (meta.subscriptionId) {
    subscription = await prisma.subscription.findUnique({
      where: { id: meta.subscriptionId },
    });
  }

  if (!subscription && paymentByReference) {
    subscription = paymentByReference.subscription;
  }

  if (!subscription) {
    console.warn(`⚠️ [SUBSCRIPTION] Payment webhook — no matching subscription for ref: ${reference}`);
    return null;
  }

  const now = new Date();
  const isInitialPendingPayment = paymentByReference?.status === 'pending';

  const newPeriodStart = now;
  const newPeriodEnd = isInitialPendingPayment
    ? (subscription.currentPeriodEnd > now ? subscription.currentPeriodEnd : addOneMonth(now))
    : addOneMonth(new Date(Math.max(now.getTime(), subscription.currentPeriodEnd.getTime())));

  const operations = [
    prisma.subscription.update({
      where: { id: subscription.id },
      data: {
        status: 'active',
        currentPeriodStart: newPeriodStart,
        currentPeriodEnd: newPeriodEnd,
      },
    }),
  ];

  if (reference) {
    operations.push(
      prisma.subscriptionPayment.upsert({
        where: { paystackReference: reference },
        create: {
          subscriptionId: subscription.id,
          amount,
          currency: PAYSTACK_CURRENCY,
          paystackReference: reference,
          status: 'success',
          paidAt: now,
        },
        update: {
          status: 'success',
          paidAt: now,
        },
      })
    );
  } else {
    operations.push(
      prisma.subscriptionPayment.create({
        data: {
          subscriptionId: subscription.id,
          amount,
          currency: PAYSTACK_CURRENCY,
          status: 'success',
          paidAt: now,
        },
      })
    );
  }

  await prisma.$transaction(operations);

  console.log(`✅ [SUBSCRIPTION] Payment recorded for ${subscription.id}, extended to ${newPeriodEnd.toISOString()}`);
  return subscription;
};

/**
 * Handle invoice.payment_failed webhook.
 * Marks the subscription as past_due.
 */
const handlePaymentFailed = async (payload) => {
  const meta = payload?.data?.metadata || {};
  const reference = payload?.data?.reference;
  const failureReason = payload?.data?.gateway_response || 'Payment failed';
  const amount = (payload?.data?.amount || 0) / 100;

  let paymentByReference = null;
  if (reference) {
    paymentByReference = await prisma.subscriptionPayment.findUnique({
      where: { paystackReference: reference },
      include: { subscription: true },
    });
  }

  if (paymentByReference?.status === 'success') {
    return paymentByReference.subscription;
  }

  let subscription;
  if (meta.subscriptionId) {
    subscription = await prisma.subscription.findUnique({ where: { id: meta.subscriptionId } });
  }

  if (!subscription && paymentByReference) {
    subscription = paymentByReference.subscription;
  }

  if (!subscription) return null;

  const operations = [
    prisma.subscription.update({
      where: { id: subscription.id },
      data: { status: 'past_due' },
    }),
  ];

  if (reference) {
    operations.push(
      prisma.subscriptionPayment.upsert({
        where: { paystackReference: reference },
        create: {
          subscriptionId: subscription.id,
          amount,
          currency: PAYSTACK_CURRENCY,
          paystackReference: reference,
          status: 'failed',
          failureReason,
        },
        update: {
          status: 'failed',
          failureReason,
        },
      })
    );
  } else {
    operations.push(
      prisma.subscriptionPayment.create({
        data: {
          subscriptionId: subscription.id,
          amount,
          currency: PAYSTACK_CURRENCY,
          status: 'failed',
          failureReason,
        },
      })
    );
  }

  await prisma.$transaction(operations);

  console.log(`⚠️ [SUBSCRIPTION] Payment failed for ${subscription.id}, marked as past_due`);
  return subscription;
};

/**
 * Explicitly confirm a subscription payment after client-side checkout.
 * This prevents stale "pending" rows when webhook delivery is delayed.
 */
const confirmPayment = async ({ userId, reference }) => {
  if (!userId) throw new Error('User is required');
  if (!reference) throw new Error('Payment reference is required');

  const payment = await prisma.subscriptionPayment.findUnique({
    where: { paystackReference: reference },
    include: { subscription: true },
  });

  if (!payment || !payment.subscription) {
    throw new Error('Subscription payment not found for this reference');
  }

  if (payment.subscription.userId !== userId) {
    throw new Error('Not authorized to confirm this subscription payment');
  }

  if (payment.status === 'success') {
    return {
      confirmed: true,
      alreadyConfirmed: true,
      status: 'success',
      reference,
      subscriptionId: payment.subscriptionId,
    };
  }

  const verified = await paystackService.verifyTransaction(reference);
  const paystackStatus = String(verified?.status || '').toLowerCase();

  if (paystackStatus !== 'success') {
    await handlePaymentFailed({
      data: {
        reference,
        amount: verified?.amount || 0,
        gateway_response: verified?.gateway_response || verified?.message || 'Payment not successful',
        metadata: {
          ...(verified?.metadata || {}),
          subscriptionId: payment.subscriptionId,
          type: 'subscription',
        },
      },
    });

    return {
      confirmed: false,
      alreadyConfirmed: false,
      status: paystackStatus || 'unknown',
      reference,
      subscriptionId: payment.subscriptionId,
      message: verified?.gateway_response || verified?.message || 'Payment not successful',
    };
  }

  await handlePaymentSuccess({
    data: {
      reference,
      amount: verified?.amount || 0,
      metadata: {
        ...(verified?.metadata || {}),
        subscriptionId: payment.subscriptionId,
        type: 'subscription',
      },
    },
  });

  const updated = await prisma.subscription.findUnique({
    where: { id: payment.subscriptionId },
  });

  return {
    confirmed: true,
    alreadyConfirmed: false,
    status: 'success',
    reference,
    subscriptionId: payment.subscriptionId,
    currentPeriodEnd: updated?.currentPeriodEnd || null,
  };
};

/**
 * Handle subscription.not_renew webhook.
 * Customer or Paystack cancelled the subscription.
 */
const handleSubscriptionCancelled = async (payload) => {
  const subscriptionCode = payload?.data?.subscription_code;

  if (!subscriptionCode) return null;

  const subscription = await prisma.subscription.findFirst({
    where: { paystackSubscriptionCode: subscriptionCode },
  });

  if (!subscription) return null;

  await prisma.subscription.update({
    where: { id: subscription.id },
    data: {
      status: 'cancelled',
      cancelledAt: new Date(),
      cancelReason: 'Subscription not renewed (Paystack)',
    },
  });

  console.log(`❌ [SUBSCRIPTION] Cancelled via webhook: ${subscription.id}`);
  return subscription;
};

/**
 * Route a Paystack webhook event to the appropriate handler.
 */
const handleWebhook = async (event, payload) => {
  switch (event) {
    case 'subscription.create':
      return handleSubscriptionCreated(payload);
    case 'charge.success': {
      // Only handle subscription charges, not regular order payments
      const meta = payload?.data?.metadata || {};
      if (meta.type === 'subscription') {
        return handlePaymentSuccess(payload);
      }
      return null;
    }
    case 'invoice.update':
    case 'invoice.payment_succeeded':
      return handlePaymentSuccess(payload);
    case 'invoice.payment_failed':
      return handlePaymentFailed(payload);
    case 'subscription.not_renew':
    case 'subscription.disable':
      return handleSubscriptionCancelled(payload);
    default:
      return null;
  }
};

// ── Expiry Job ──────────────────────────────────────────────────────────────

/**
 * Mark expired subscriptions. Run periodically by a cron job.
 */
const expireStaleSubscriptions = async () => {
  const now = new Date();

  const expired = await prisma.subscription.updateMany({
    where: {
      status: { in: ['active', 'past_due'] },
      currentPeriodEnd: { lt: now },
    },
    data: { status: 'expired' },
  });

  if (expired.count > 0) {
    console.log(`🕐 [SUBSCRIPTION] Expired ${expired.count} subscription(s)`);
  }

  return expired.count;
};

// ── Admin / Analytics ───────────────────────────────────────────────────────

/**
 * Get subscription statistics for admin dashboard.
 */
const getSubscriptionStats = async () => {
  const [activePlus, activePremium, totalRevenue, pastDue] = await Promise.all([
    prisma.subscription.count({ where: { tier: 'grabgo_plus', status: 'active' } }),
    prisma.subscription.count({ where: { tier: 'grabgo_premium', status: 'active' } }),
    prisma.subscriptionPayment.aggregate({
      where: { status: 'success' },
      _sum: { amount: true },
    }),
    prisma.subscription.count({ where: { status: 'past_due' } }),
  ]);

  const totalActive = activePlus + activePremium;
  const mrr = (activePlus * PLANS.grabgo_plus.amount) + (activePremium * PLANS.grabgo_premium.amount);

  return {
    totalActive,
    activePlus,
    activePremium,
    pastDue,
    mrr,
    totalRevenue: totalRevenue._sum?.amount || 0,
    currency: PAYSTACK_CURRENCY,
  };
};

module.exports = {
  PLANS,
  getPlans,
  getActiveSubscription,
  subscribe,
  cancelSubscription,
  calculateSubscriptionBenefits,
  previewBenefits,
  confirmPayment,
  handleWebhook,
  expireStaleSubscriptions,
  getSubscriptionStats,
};
