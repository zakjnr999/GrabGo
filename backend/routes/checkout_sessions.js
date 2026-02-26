const express = require('express');
const { body, validationResult } = require('express-validator');
const { protect } = require('../middleware/auth');
const { invalidateCache } = require('../middleware/cache');
const cache = require('../utils/cache');
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

const handleCheckoutSessionError = (res, error) => {
  if (error instanceof CheckoutSessionError) {
    return res.status(error.status || 400).json({
      success: false,
      message: error.message,
      code: error.code,
      ...(error.meta ? { data: error.meta } : {}),
    });
  }

  console.error('Checkout session route error:', error);
  return res.status(500).json({
    success: false,
    message: 'Server error',
    error: error.message,
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

      const result = await createCheckoutSession({
        customer: req.user,
        payload: req.body,
      });

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
      return handleCheckoutSessionError(res, error);
    }
  }
);

router.post('/:sessionId/paystack/initialize', protect, async (req, res) => {
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
    return handleCheckoutSessionError(res, error);
  }
});

router.post(
  '/:sessionId/confirm-payment',
  protect,
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

      const result = await confirmCheckoutSessionPayment({
        sessionId: req.params.sessionId,
        customer: req.user,
        reference: req.body.reference,
        provider: req.body.provider,
      });

      await invalidateFoodOrderHistoryCaches().catch((cacheError) => {
        console.error('Food order-history cache invalidation error:', cacheError.message);
      });

      return res.json({
        success: true,
        message: result.alreadyPaid ? 'Payment already confirmed' : 'Payment confirmed',
        data: {
          session: result.session,
          childOrders: result.childOrders,
          paymentScope: result.paymentScope,
          externalPaymentAmount: result.externalPaymentAmount,
        },
      });
    } catch (error) {
      return handleCheckoutSessionError(res, error);
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
