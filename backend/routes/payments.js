const express = require('express');
const { body, validationResult } = require('express-validator');
const Order = require('../models/Order');
const Payment = require('../models/Payment');
const mtnMomoService = require('../services/mtn_momo_service');
const { protect } = require('../middleware/auth');

const router = express.Router();

/**
 * Initiate MTN MOMO payment
 * POST /api/payments/mtn-momo/initiate
 */
router.post(
  '/mtn-momo/initiate',
  protect,
  [
    body('orderId').notEmpty().withMessage('Order ID is required'),
    body('phoneNumber')
      .notEmpty()
      .withMessage('Phone number is required')
      .isMobilePhone('en-GH')
      .withMessage('Please provide a valid Ghana phone number'),
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

      const { orderId, phoneNumber } = req.body;

      // Find the order
      const order = await Order.findById(orderId);
      if (!order) {
        return res.status(404).json({
          success: false,
          message: 'Order not found',
        });
      }

      // Verify the order belongs to the authenticated user
      if (order.customer.toString() !== req.user._id.toString()) {
        return res.status(403).json({
          success: false,
          message: 'Not authorized to pay for this order',
        });
      }

      // Check if order is in pending status
      if (order.status !== 'pending') {
        return res.status(400).json({
          success: false,
          message: 'Order cannot be paid for in its current status',
        });
      }

      // Check if there's already a successful or pending payment for this order
      const existingPayment = await Payment.findOne({
        order: orderId,
        status: { $in: ['pending', 'processing', 'successful'] }
      });

      if (existingPayment) {
        return res.status(400).json({
          success: false,
          message: 'A payment for this order is already in progress or completed',
          data: { paymentId: existingPayment._id, status: existingPayment.status }
        });
      }

      // Validate and format phone number
      if (!mtnMomoService.validateGhanaPhoneNumber(phoneNumber)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid Ghana phone number format',
        });
      }

      const formattedPhoneNumber = mtnMomoService.formatPhoneNumber(phoneNumber);

      // Create payment record
      const payment = await Payment.create({
        order: orderId,
        customer: req.user._id,
        paymentMethod: 'mobile_money',
        provider: 'mtn_momo',
        amount: order.totalAmount,
        currency: 'GHS',
        phoneNumber: formattedPhoneNumber,
        payerMessage: `Payment for GrabGo order ${order.orderNumber}`,
        payeeNote: 'GrabGo food delivery payment',
        status: 'pending'
      });

      // Request payment from MTN MOMO
      const paymentRequest = await mtnMomoService.requestToPay({
        amount: order.totalAmount,
        currency: 'GHS',
        phoneNumber: formattedPhoneNumber,
        externalId: payment.referenceId,
        payerMessage: payment.payerMessage,
        payeeNote: payment.payeeNote
      });

      if (!paymentRequest.success) {
        // Update payment status to failed
        await payment.markAsFailed(paymentRequest.error, paymentRequest.code);
        
        return res.status(400).json({
          success: false,
          message: 'Payment request failed',
          error: paymentRequest.error,
          code: paymentRequest.code
        });
      }

      // Update payment with MTN MOMO reference ID
      payment.externalReferenceId = paymentRequest.referenceId;
      payment.status = 'processing';
      await payment.save();

      // Update order with payment information
      order.paymentProvider = 'mtn_momo';
      order.paymentReferenceId = payment.referenceId;
      await order.save();

      res.status(200).json({
        success: true,
        message: 'Payment request initiated successfully',
        data: {
          paymentId: payment._id,
          referenceId: payment.referenceId,
          externalReferenceId: payment.externalReferenceId,
          status: payment.status,
          amount: payment.amount,
          currency: payment.currency,
          phoneNumber: payment.phoneNumber
        }
      });

    } catch (error) {
      console.error('MTN MOMO payment initiation error:', error);
      res.status(500).json({
        success: false,
        message: 'Server error',
        error: error.message,
      });
    }
  }
);

/**
 * Check MTN MOMO payment status
 * GET /api/payments/mtn-momo/status/:paymentId
 */
router.get('/mtn-momo/status/:paymentId', protect, async (req, res) => {
  try {
    const { paymentId } = req.params;

    // Find the payment
    const payment = await Payment.findById(paymentId).populate('order');
    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Payment not found',
      });
    }

    // Verify the payment belongs to the authenticated user
    if (payment.customer.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to check this payment',
      });
    }

    // If payment is already completed or failed, return current status
    if (['successful', 'failed', 'cancelled'].includes(payment.status)) {
      return res.json({
        success: true,
        message: 'Payment status retrieved',
        data: {
          paymentId: payment._id,
          status: payment.status,
          amount: payment.amount,
          currency: payment.currency,
          completedAt: payment.completedAt,
          errorMessage: payment.errorMessage
        }
      });
    }

    // Check if payment has expired
    if (payment.isExpired()) {
      await payment.markAsFailed('Payment expired', 'PAYMENT_EXPIRED');
      
      return res.json({
        success: true,
        message: 'Payment has expired',
        data: {
          paymentId: payment._id,
          status: 'failed',
          errorMessage: 'Payment expired'
        }
      });
    }

    // Check status with MTN MOMO if we have external reference ID
    if (payment.externalReferenceId) {
      const statusCheck = await mtnMomoService.getPaymentStatus(payment.externalReferenceId);
      
      if (statusCheck.success) {
        // Update payment status based on MTN MOMO response
        if (statusCheck.status === 'SUCCESSFUL') {
          await payment.markAsCompleted(statusCheck.financialTransactionId);
          
          // Update order payment status
          const order = await Order.findById(payment.order);
          if (order) {
            order.paymentStatus = 'paid';
            order.status = 'confirmed';
            await order.save();
          }
          
          return res.json({
            success: true,
            message: 'Payment completed successfully',
            data: {
              paymentId: payment._id,
              status: 'successful',
              amount: payment.amount,
              currency: payment.currency,
              financialTransactionId: payment.financialTransactionId,
              completedAt: payment.completedAt
            }
          });
        } else if (statusCheck.status === 'FAILED') {
          await payment.markAsFailed(statusCheck.reason, 'MTN_MOMO_FAILED');
          
          return res.json({
            success: true,
            message: 'Payment failed',
            data: {
              paymentId: payment._id,
              status: 'failed',
              errorMessage: statusCheck.reason || 'Payment failed'
            }
          });
        }
      }
    }

    // Return current status if still pending/processing
    res.json({
      success: true,
      message: 'Payment status retrieved',
      data: {
        paymentId: payment._id,
        status: payment.status,
        amount: payment.amount,
        currency: payment.currency,
        expiresAt: payment.expiredAt
      }
    });

  } catch (error) {
    console.error('Payment status check error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
});

/**
 * Get all payments for a user
 * GET /api/payments/my-payments
 */
router.get('/my-payments', protect, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const payments = await Payment.find({ customer: req.user._id })
      .populate('order', 'orderNumber totalAmount status')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    const total = await Payment.countDocuments({ customer: req.user._id });

    res.json({
      success: true,
      message: 'Payments retrieved successfully',
      data: payments,
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: limit
      }
    });

  } catch (error) {
    console.error('Get payments error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
});

/**
 * Cancel a pending payment
 * PUT /api/payments/:paymentId/cancel
 */
router.put('/:paymentId/cancel', protect, async (req, res) => {
  try {
    const { paymentId } = req.params;

    const payment = await Payment.findById(paymentId);
    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Payment not found',
      });
    }

    // Verify the payment belongs to the authenticated user
    if (payment.customer.toString() !== req.user._id.toString()) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to cancel this payment',
      });
    }

    // Check if payment can be cancelled
    if (!['pending', 'processing'].includes(payment.status)) {
      return res.status(400).json({
        success: false,
        message: 'Payment cannot be cancelled in its current status',
      });
    }

    // Update payment status
    payment.status = 'cancelled';
    await payment.save();

    res.json({
      success: true,
      message: 'Payment cancelled successfully',
      data: {
        paymentId: payment._id,
        status: payment.status
      }
    });

  } catch (error) {
    console.error('Cancel payment error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error',
      error: error.message,
    });
  }
});

/**
 * MTN MOMO Webhook for payment notifications
 * POST /api/payments/mtn-momo/webhook
 */
router.post('/mtn-momo/webhook', async (req, res) => {
  try {
    console.log('MTN MOMO Webhook received:', req.body);
    
    const { referenceId, status, financialTransactionId, reason } = req.body;
    
    if (!referenceId) {
      return res.status(400).json({
        success: false,
        message: 'Reference ID is required'
      });
    }

    // Find payment by external reference ID
    const payment = await Payment.findOne({ externalReferenceId: referenceId });
    
    if (!payment) {
      console.log(`Payment not found for reference ID: ${referenceId}`);
      return res.status(404).json({
        success: false,
        message: 'Payment not found'
      });
    }

    // Update payment based on webhook status
    if (status === 'SUCCESSFUL') {
      await payment.markAsCompleted(financialTransactionId);
      
      // Update order payment status
      const order = await Order.findById(payment.order);
      if (order && order.paymentStatus !== 'paid') {
        order.paymentStatus = 'paid';
        order.status = 'confirmed';
        await order.save();
        console.log(`Order ${order.orderNumber} payment confirmed via webhook`);
      }
      
    } else if (status === 'FAILED') {
      await payment.markAsFailed(reason || 'Payment failed', 'MTN_MOMO_WEBHOOK_FAILED');
      console.log(`Payment failed for reference ID: ${referenceId}, reason: ${reason}`);
    }

    res.status(200).json({
      success: true,
      message: 'Webhook processed successfully'
    });

  } catch (error) {
    console.error('MTN MOMO webhook error:', error);
    res.status(500).json({
      success: false,
      message: 'Webhook processing failed',
      error: error.message
    });
  }
});

module.exports = router;