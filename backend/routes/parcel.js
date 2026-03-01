const express = require('express');
const { body, validationResult } = require('express-validator');
const { protect, authorize } = require('../middleware/auth');
const parcelService = require('../services/parcel_service');

const router = express.Router();

const handleParcelError = (res, error, fallbackMessage = 'Server error') => {
  if (error?.status && error?.code) {
    return res.status(error.status).json({
      success: false,
      message: error.message,
      code: error.code,
      ...(Array.isArray(error.details) && error.details.length > 0 ? { errors: error.details } : {}),
      ...(error.meta ? error.meta : {}),
    });
  }

  console.error('Parcel route error:', error);
  return res.status(500).json({
    success: false,
    message: fallbackMessage,
    error: error?.message || 'Unexpected error',
  });
};

router.get('/config', async (_req, res) => {
  try {
    const config = parcelService.getParcelConfig();
    return res.json({
      success: true,
      message: 'Parcel config retrieved successfully',
      data: config,
    });
  } catch (error) {
    return handleParcelError(res, error);
  }
});

router.post('/quote', protect, async (req, res) => {
  try {
    const quote = parcelService.createQuote(req.body || {});
    return res.json({
      success: true,
      message: 'Parcel quote generated successfully',
      data: quote,
    });
  } catch (error) {
    return handleParcelError(res, error, 'Failed to generate parcel quote');
  }
});

router.post(
  '/orders',
  protect,
  [
    body('acceptParcelTerms').exists().withMessage('acceptParcelTerms is required'),
    body().custom((value) => {
      const bodyValue = value || {};
      const hasDeclaredValue =
        Object.prototype.hasOwnProperty.call(bodyValue, 'declaredValueGhs') ||
        Object.prototype.hasOwnProperty.call(bodyValue, 'declaredValue');
      if (!hasDeclaredValue) {
        throw new Error('declaredValueGhs (or declaredValue) is required');
      }
      return true;
    }),
    body('weightKg').exists().withMessage('weightKg is required'),
    body('prohibitedItemsAccepted').exists().withMessage('prohibitedItemsAccepted is required'),
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

      const parcelOrder = await parcelService.createParcelOrder({
        user: req.user,
        payload: req.body || {},
      });

      return res.status(201).json({
        success: true,
        message: 'Parcel order created successfully',
        data: parcelOrder,
      });
    } catch (error) {
      return handleParcelError(res, error, 'Failed to create parcel order');
    }
  }
);

router.get('/orders', protect, async (req, res) => {
  try {
    const limit = Number(req.query.limit || 30);
    const cursor = req.query.cursor ? String(req.query.cursor) : null;
    const orders = await parcelService.listParcelOrdersForUser({
      user: req.user,
      limit,
      cursor,
    });

    return res.json({
      success: true,
      message: 'Parcel orders retrieved successfully',
      data: orders,
    });
  } catch (error) {
    return handleParcelError(res, error, 'Failed to retrieve parcel orders');
  }
});

router.get('/orders/:parcelId', protect, async (req, res) => {
  try {
    const parcel = await parcelService.getParcelByIdForUser({
      user: req.user,
      parcelId: req.params.parcelId,
    });

    if (!parcel) {
      return res.status(404).json({
        success: false,
        message: 'Parcel order not found',
      });
    }

    return res.json({
      success: true,
      message: 'Parcel order retrieved successfully',
      data: parcel,
    });
  } catch (error) {
    return handleParcelError(res, error, 'Failed to retrieve parcel order');
  }
});

router.post('/orders/:parcelId/paystack/initialize', protect, async (req, res) => {
  try {
    const data = await parcelService.initializePaystackForParcel({
      user: req.user,
      parcelId: req.params.parcelId,
    });

    return res.json({
      success: true,
      message: 'Parcel payment initialized',
      data,
    });
  } catch (error) {
    return handleParcelError(res, error, 'Failed to initialize parcel payment');
  }
});

router.post(
  '/orders/:parcelId/confirm-payment',
  protect,
  [
    body('reference').optional().isString().withMessage('reference must be a string'),
    body('provider').optional().isString().withMessage('provider must be a string'),
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

      const data = await parcelService.confirmParcelPayment({
        user: req.user,
        parcelId: req.params.parcelId,
        reference: req.body?.reference,
        provider: req.body?.provider,
      });

      return res.json({
        success: true,
        message: data.alreadyPaid ? 'Payment already confirmed' : 'Parcel payment confirmed',
        data,
      });
    } catch (error) {
      return handleParcelError(res, error, 'Failed to confirm parcel payment');
    }
  }
);

router.post('/orders/:parcelId/cancel', protect, async (req, res) => {
  try {
    const data = await parcelService.cancelParcelOrder({
      user: req.user,
      parcelId: req.params.parcelId,
      reason: req.body?.reason,
    });

    return res.json({
      success: true,
      message: 'Parcel order cancelled successfully',
      data,
    });
  } catch (error) {
    return handleParcelError(res, error, 'Failed to cancel parcel order');
  }
});

router.post('/orders/:parcelId/delivery-code/resend', protect, async (req, res) => {
  try {
    const data = await parcelService.resendParcelDeliveryCode({
      user: req.user,
      parcelId: req.params.parcelId,
    });

    return res.json({
      success: true,
      message: 'Parcel delivery code resent successfully',
      data,
    });
  } catch (error) {
    return handleParcelError(res, error, 'Failed to resend parcel delivery code');
  }
});

router.post(
  '/orders/:parcelId/return-to-sender',
  protect,
  authorize('rider'),
  async (req, res) => {
    try {
      const data = await parcelService.initiateReturnToSender({
        riderId: req.user.id,
        parcelId: req.params.parcelId,
        reason: req.body?.reason,
      });

      return res.json({
        success: true,
        message: 'Return-to-sender initiated successfully',
        data,
      });
    } catch (error) {
      return handleParcelError(res, error, 'Failed to initiate return-to-sender');
    }
  }
);

router.post(
  '/orders/:parcelId/confirm-returned',
  protect,
  authorize('rider'),
  async (req, res) => {
    try {
      const data = await parcelService.confirmReturnToSender({
        riderId: req.user.id,
        parcelId: req.params.parcelId,
        notes: req.body?.notes,
      });

      return res.json({
        success: true,
        message: 'Parcel marked as returned to sender',
        data,
      });
    } catch (error) {
      return handleParcelError(res, error, 'Failed to confirm returned parcel');
    }
  }
);

module.exports = router;
