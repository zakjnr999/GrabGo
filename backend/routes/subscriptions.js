/**
 * GrabGo Pro — Subscription Routes
 *
 * Endpoints:
 *   GET    /api/subscriptions/plans       — List available plans
 *   GET    /api/subscriptions/me          — Get current subscription
 *   POST   /api/subscriptions/subscribe   — Start a new subscription
 *   POST   /api/subscriptions/confirm-payment — Confirm a subscription payment
 *   POST   /api/subscriptions/cancel      — Cancel subscription
 *   GET    /api/subscriptions/benefits    — Preview benefits for an order
 *   POST   /api/subscriptions/webhook     — Paystack subscription webhooks
 *   GET    /api/subscriptions/stats       — Admin: subscription analytics
 */

const express = require('express');
const { body, query, validationResult } = require('express-validator');
const { protect } = require('../middleware/auth');
const paystackService = require('../services/paystack_service');
const subscriptionService = require('../services/subscription_service');
const featureFlags = require('../config/feature_flags');
const logger = require('../utils/logger');

const router = express.Router();

const getErrorMessage = (error) =>
  typeof error?.message === 'string' ? error.message : '';

// ── GET /plans — List available subscription plans ──────────────────────────
router.get('/plans', async (req, res) => {
  try {
    if (!featureFlags.isSubscriptionEnabled) {
      return res.status(404).json({ success: false, message: 'Subscriptions are not available' });
    }

    const plans = subscriptionService.getPlans();
    return res.json({ success: true, data: plans });
  } catch (error) {
    logger.error('subscription_plans_fetch_failed', { error });
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ── GET /me — Get current user's subscription ───────────────────────────────
router.get('/me', protect, async (req, res) => {
  try {
    if (!featureFlags.isSubscriptionEnabled) {
      return res.json({ success: true, data: null, message: 'Subscriptions are not available' });
    }

    const activeSubscription = await subscriptionService.getActiveSubscription(req.user.id);
    const pendingSubscription = activeSubscription
      ? null
      : await subscriptionService.getLatestPendingSubscription(req.user.id);
    const subscription = activeSubscription || pendingSubscription;

    if (!subscription) {
      return res.json({ success: true, data: null, message: 'No active subscription' });
    }

    return res.json({
      success: true,
      data: {
        id: subscription.id,
        tier: subscription.tier,
        tierName: subscription.plan?.name || subscription.tier,
        status: subscription.status,
        currentPeriodStart: subscription.currentPeriodStart,
        currentPeriodEnd: subscription.currentPeriodEnd,
        cancelledAt: subscription.cancelledAt,
        pendingPaymentReference: subscription.pendingPaymentReference || null,
        benefits: {
          freeDelivery: subscription.plan?.freeDeliveryMinOrder === 0
            ? 'All orders'
            : `Orders above GHS ${subscription.plan?.freeDeliveryMinOrder}`,
          serviceFeeDiscount: `${Math.round((subscription.plan?.serviceFeeDiscount || 0) * 100)}%`,
          prioritySupport: subscription.plan?.hasPrioritySupport || false,
          exclusiveDeals: subscription.plan?.hasExclusiveDeals || false,
        },
      },
    });
  } catch (error) {
    logger.error('subscription_current_fetch_failed', { error });
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

// ── POST /subscribe — Start a new subscription ─────────────────────────────
router.post(
  '/subscribe',
  protect,
  [
    body('tier')
      .isIn(['grabgo_plus', 'grabgo_premium'])
      .withMessage('Tier must be grabgo_plus or grabgo_premium'),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ success: false, errors: errors.array() });
      }

      if (!featureFlags.isSubscriptionEnabled) {
        return res.status(404).json({ success: false, message: 'Subscriptions are not available' });
      }

      // Only customers can subscribe
      if (req.user.role !== 'customer') {
        return res.status(403).json({ success: false, message: 'Only customers can subscribe' });
      }

      const result = await subscriptionService.subscribe({
        userId: req.user.id,
        email: req.user.email,
        tier: req.body.tier,
      });

      return res.status(201).json({
        success: true,
        message: `${result.plan.name} subscription initiated. Complete payment to activate.`,
        data: result,
      });
    } catch (error) {
      logger.error('subscription_subscribe_failed', { error });
      const errorMessage = getErrorMessage(error);

      if (errorMessage.includes('already have') || errorMessage.includes('Invalid')) {
        return res.status(400).json({ success: false, message: errorMessage });
      }

      return res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ── POST /cancel — Cancel subscription ──────────────────────────────────────
router.post(
  '/cancel',
  protect,
  [
    body('reason').optional().isString().trim().isLength({ max: 500 }),
  ],
  async (req, res) => {
    try {
      const result = await subscriptionService.cancelSubscription(
        req.user.id,
        req.body.reason
      );

      return res.json({
        success: true,
        message: result.message,
        data: result,
      });
    } catch (error) {
      logger.error('subscription_cancel_failed', { error });
      const errorMessage = getErrorMessage(error);

      if (errorMessage.includes('No active subscription')) {
        return res.status(404).json({ success: false, message: errorMessage });
      }

      return res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ── POST /confirm-payment — Verify and finalize subscription payment ───────
router.post(
  '/confirm-payment',
  protect,
  [
    body('reference')
      .isString()
      .trim()
      .notEmpty()
      .withMessage('Payment reference is required'),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ success: false, errors: errors.array() });
      }

      if (req.user.role !== 'customer') {
        return res.status(403).json({ success: false, message: 'Only customers can confirm payments' });
      }

      const result = await subscriptionService.confirmPayment({
        userId: req.user.id,
        reference: req.body.reference.trim(),
      });

      if (!result.confirmed) {
        return res.status(400).json({
          success: false,
          message: result.message || 'Payment not successful',
          data: result,
        });
      }

      return res.json({
        success: true,
        message: result.alreadyConfirmed ? 'Payment already confirmed' : 'Payment confirmed',
        data: result,
      });
    } catch (error) {
      logger.error('subscription_confirm_payment_failed', { error });
      const errorMessage = getErrorMessage(error);

      if (errorMessage.includes('not found')) {
        return res.status(404).json({ success: false, message: errorMessage });
      }
      if (errorMessage.includes('Not authorized')) {
        return res.status(403).json({ success: false, message: errorMessage });
      }
      if (errorMessage.includes('required')) {
        return res.status(400).json({ success: false, message: errorMessage });
      }

      return res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ── GET /benefits — Preview benefits for an order ───────────────────────────
router.get(
  '/benefits',
  protect,
  [
    query('subtotal').optional().isFloat({ min: 0 }),
  ],
  async (req, res) => {
    try {
      const subtotal = parseFloat(req.query.subtotal || '0');
      const result = await subscriptionService.previewBenefits(req.user.id, subtotal);

      return res.json({ success: true, data: result });
    } catch (error) {
      logger.error('subscription_benefits_preview_failed', { error });
      return res.status(500).json({ success: false, message: 'Server error' });
    }
  }
);

// ── POST /webhook — Paystack subscription webhooks ──────────────────────────
router.post('/webhook', async (req, res) => {
  try {
    // Parse body (raw buffer or parsed JSON)
    let payload;
    let rawBody;

    if (Buffer.isBuffer(req.body)) {
      rawBody = req.body;
      payload = JSON.parse(req.body.toString('utf-8'));
    } else {
      rawBody = JSON.stringify(req.body || {});
      payload = req.body;
    }

    // Verify Paystack signature
    const signature = req.headers['x-paystack-signature'];
    const isValid = paystackService.verifyWebhookSignature(rawBody, signature);

    if (!isValid) {
      logger.warn('subscription_webhook_invalid_signature');
      return res.status(401).json({ success: false, message: 'Invalid signature' });
    }

    const event = payload?.event;
    logger.info('subscription_webhook_received', { event });

    // Route to subscription handler
    const result = await subscriptionService.handleWebhook(event, payload);

    if (result) {
      logger.info('subscription_webhook_processed', { event });
    }

    // Always return 200 to Paystack
    return res.status(200).json({ success: true });
  } catch (error) {
    logger.error('subscription_webhook_failed', { error });
    // Return 200 anyway to prevent Paystack from retrying
    return res.status(200).json({ success: true });
  }
});

// ── GET /stats — Admin: subscription analytics ──────────────────────────────
router.get('/stats', protect, async (req, res) => {
  try {
    if (!req.user.isAdmin) {
      return res.status(403).json({ success: false, message: 'Admin access required' });
    }

    const stats = await subscriptionService.getSubscriptionStats();
    return res.json({ success: true, data: stats });
  } catch (error) {
    logger.error('subscription_stats_fetch_failed', { error });
    return res.status(500).json({ success: false, message: 'Server error' });
  }
});

module.exports = router;
