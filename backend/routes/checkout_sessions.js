const express = require('express');
const { body, validationResult } = require('express-validator');
const { protect } = require('../middleware/auth');
const prisma = require('../config/prisma');
const { invalidateCache } = require('../middleware/cache');
const { paymentAttemptRateLimit } = require('../middleware/fraud_rate_limit');
const cache = require('../utils/cache');
const logger = require('../utils/logger');
const metrics = require('../utils/metrics');
const {
  ACTION_TYPES,
  buildFraudContextFromRequest,
  fraudDecisionService,
  applyFraudDecision,
} = require('../services/fraud');
const {
  CheckoutSessionError,
  createCheckoutSession,
  initializeCheckoutSessionPayment,
  confirmCheckoutSessionPayment,
  releaseCheckoutSessionCreditHolds,
} = require('../services/checkout_session_service');

const router = express.Router();

const invalidateFoodOrderHistoryCaches = async () => {
  await invalidateCache([
    `${cache.CACHE_KEYS.FOOD_ITEM}:history`,
    `${cache.CACHE_KEYS.FOOD_ITEM}:recent`,
  ]);
};

const handleCheckoutSessionError = (res, error, action = 'unknown') => {
  if (error instanceof CheckoutSessionError) {
    metrics.recordCheckoutSessionEvent({ action, result: error.code || 'business_error' });
    return res.status(error.status || 400).json({
      success: false,
      message: error.message,
      code: error.code,
      ...(error.meta ? { data: error.meta } : {}),
    });
  }

  logger.error('checkout_session_route_failed', { error });
  metrics.recordCheckoutSessionEvent({ action, result: 'failure' });
  return res.status(500).json({
    success: false,
    message: 'Server error',
  });
};

router.post(
  '/',
  protect,
  [
    body('fulfillmentMode').optional().isIn(['delivery', 'pickup']).withMessage('Invalid fulfillment mode'),
    body('paymentMethod').optional().isString().withMessage('paymentMethod must be a string'),
    body('useCredits').optional({ nullable: true }).isBoolean().withMessage('useCredits must be a boolean'),
    body('notes').optional({ nullable: true }).isString().withMessage('notes must be a string'),
    body('isGiftOrder').optional({ nullable: true }).isBoolean().withMessage('isGiftOrder must be a boolean'),
    body('deliveryTimeType').optional({ nullable: true }).isString().withMessage('deliveryTimeType must be a string'),
    body('scheduledForAt').optional({ nullable: true }).isString().withMessage('scheduledForAt must be a string'),
    body('promoCode').optional({ nullable: true }).isString().withMessage('promoCode must be a string'),
    body('deliveryAddress').isObject().withMessage('deliveryAddress is required'),
    body('deliveryAddress.street').isString().withMessage('deliveryAddress.street is required'),
    body('deliveryAddress.city').isString().withMessage('deliveryAddress.city is required'),
    body('deliveryAddress.state').optional({ nullable: true }).isString().withMessage('deliveryAddress.state must be a string'),
    body('deliveryAddress.zipCode').optional({ nullable: true }).isString().withMessage('deliveryAddress.zipCode must be a string'),
    body('deliveryAddress.latitude').optional({ nullable: true }).isFloat().withMessage('deliveryAddress.latitude must be a number'),
    body('deliveryAddress.longitude').optional({ nullable: true }).isFloat().withMessage('deliveryAddress.longitude must be a number'),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: 'Validation failed',
          errors: errors.array(),
        });
      }

      if (req.user.role !== 'customer') {
        return res.status(403).json({
          success: false,
          message: 'Only customers can create checkout sessions',
        });
      }

      const requestedPromoCode = req.body?.promoCode
        ? String(req.body.promoCode).trim()
        : '';
      if (requestedPromoCode) {
        return res.status(400).json({
          success: false,
          message: 'Promo codes are currently available for single-vendor carts only.',
          code: 'PROMO_MIXED_CHECKOUT_NOT_SUPPORTED',
        });
      }

      const result = await createCheckoutSession({
        customer: req.user,
        payload: req.body,
      });
      metrics.recordCheckoutSessionEvent({ action: 'create', result: 'success' });

      return res.status(201).json({
        success: true,
        message: 'Checkout session created successfully',
        data: {
          session: result.session,
          childOrders: result.childOrders,
          summary: result.summary,
        },
      });
    } catch (error) {
      return handleCheckoutSessionError(res, error, 'create');
    }
  }
);

router.post('/:sessionId/paystack/initialize', protect, paymentAttemptRateLimit, async (req, res) => {
  try {
    if (req.user.role !== 'customer') {
      return res.status(403).json({
        success: false,
        message: 'Only customers can initialize checkout-session payments',
      });
    }

    const result = await initializeCheckoutSessionPayment({
      sessionId: req.params.sessionId,
      customer: req.user,
    });
    metrics.recordCheckoutSessionEvent({
      action: 'initialize_payment',
      result: result.alreadyPaid ? 'already_paid' : 'success',
    });

    return res.json({
      success: true,
      message: result.alreadyPaid ? 'Payment already confirmed' : 'Payment initialized',
      data: {
        sessionId: result.session.id,
        groupOrderNumber: result.session.groupOrderNumber,
        authorizationUrl: result.authorizationUrl,
        reference: result.reference,
        paymentAmount: result.paymentAmount,
        paymentScope: result.paymentScope,
      },
    });
  } catch (error) {
    return handleCheckoutSessionError(res, error, 'initialize_payment');
  }
});

router.post(
  '/:sessionId/confirm-payment',
  protect,
  paymentAttemptRateLimit,
  [
    body('reference').optional({ nullable: true }).isString().withMessage('reference must be a string'),
    body('provider').optional({ nullable: true }).isString().withMessage('provider must be a string'),
  ],
  async (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({
          success: false,
          message: 'Validation failed',
          errors: errors.array(),
        });
      }

      if (req.user.role !== 'customer') {
        return res.status(403).json({
          success: false,
          message: 'Only customers can confirm checkout-session payments',
        });
      }

      const sessionPreview = await prisma.checkoutSession.findUnique({
        where: { id: req.params.sessionId },
        select: {
          id: true,
          customerId: true,
          paymentReferenceId: true,
          totalAmount: true,
        },
      });

      if (!sessionPreview) {
        return res.status(404).json({
          success: false,
          message: 'Checkout session not found',
        });
      }

      if (sessionPreview.customerId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: 'Not authorized for this checkout session',
        });
      }

      const resolvedReference = req.body.reference || sessionPreview.paymentReferenceId || null;
      const resolvedAmount = Number(sessionPreview.totalAmount || req.body.amount || 0);

      const fraudContext = buildFraudContextFromRequest({
        req,
        actionType: ACTION_TYPES.PAYMENT_CLIENT_CONFIRM,
        actorType: req.user.role || 'customer',
        actorId: req.user.id,
        extras: {
          orderId: sessionPreview.id,
          paymentRef: resolvedReference,
          amount: resolvedAmount,
          currency: 'GHS',
          metadata: {
            checkoutSession: true,
          },
        },
      });

      const fraudDecision = await fraudDecisionService.evaluate({
        actionType: ACTION_TYPES.PAYMENT_CLIENT_CONFIRM,
        actorType: req.user.role || 'customer',
        actorId: req.user.id,
        context: fraudContext,
      });

      const fraudGate = applyFraudDecision({
        req,
        res,
        decision: fraudDecision,
        actionType: ACTION_TYPES.PAYMENT_CLIENT_CONFIRM,
      });
      if (fraudGate.blocked || fraudGate.challenged) return;

      const result = await confirmCheckoutSessionPayment({
        sessionId: req.params.sessionId,
        customer: req.user,
        reference: req.body.reference,
        provider: req.body.provider,
      });
      metrics.recordCheckoutSessionEvent({
        action: 'confirm_payment',
        result: result.alreadyConfirmed ? 'already_confirmed' : 'success',
      });

      await invalidateFoodOrderHistoryCaches().catch((cacheError) => {
        console.error('Food order-history cache invalidation error:', cacheError.message);
      });

      return res.json({
        success: true,
        message: result.alreadyPaid
          ? 'Payment already confirmed'
          : result.awaitingWebhook
          ? 'Payment verification received. Awaiting webhook confirmation.'
          : 'Payment confirmed',
        data: {
          session: result.session,
          childOrders: result.childOrders,
          paymentScope: result.paymentScope,
          externalPaymentAmount: result.externalPaymentAmount,
          webhookRequired: Boolean(result.awaitingWebhook),
        },
      });
    } catch (error) {
      return handleCheckoutSessionError(res, error, 'confirm_payment');
    }
  }
);

router.post('/:sessionId/release-credit-hold', protect, async (req, res) => {
  try {
    if (req.user.role !== 'customer') {
      return res.status(403).json({
        success: false,
        message: 'Only customers can release checkout-session credit holds',
      });
    }

    const result = await releaseCheckoutSessionCreditHolds({
      sessionId: req.params.sessionId,
      customer: req.user,
    });

    return res.json({
      success: true,
      message: 'Checkout-session credit holds released',
      data: result,
    });
  } catch (error) {
    return handleCheckoutSessionError(res, error);
  }
});

module.exports = router;
