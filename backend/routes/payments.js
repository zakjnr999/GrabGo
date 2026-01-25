const express = require('express');
const { body, validationResult } = require('express-validator');
const prisma = require('../config/prisma');
const mtnMomoService = require('../services/mtn_momo_service');
const { protect } = require('../middleware/auth');

const router = express.Router();

/**
 * Payment Helpers to replace Mongoose model methods
 */
const markAsCompleted = async (paymentId, financialTransactionId = null) => {
  return await prisma.payment.update({
    where: { id: paymentId },
    data: {
      status: 'successful',
      completedAt: new Date(),
      financialTransactionId: financialTransactionId
    }
  });
};

const markAsFailed = async (paymentId, errorMessage = null, errorCode = null) => {
  return await prisma.payment.update({
    where: { id: paymentId },
    data: {
      status: 'failed',
      errorMessage: errorMessage,
      errorCode: errorCode
    }
  });
};

const isExpired = (payment) => {
  if (!payment.expiredAt) return false;
  return new Date() > new Date(payment.expiredAt);
};

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

      const order = await prisma.order.findUnique({
        where: { id: orderId }
      });

      if (!order) {
        return res.status(404).json({
          success: false,
          message: 'Order not found',
        });
      }

      if (order.customerId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: 'Not authorized to pay for this order',
        });
      }

      if (order.status !== 'pending') {
        return res.status(400).json({
          success: false,
          message: 'Order cannot be paid for in its current status',
        });
      }

      const existingPayment = await prisma.payment.findFirst({
        where: {
          orderId: orderId,
          status: { in: ['pending', 'processing', 'successful'] }
        }
      });

      if (existingPayment) {
        return res.status(400).json({
          success: false,
          message: 'A payment for this order is already in progress or completed',
          data: { paymentId: existingPayment.id, status: existingPayment.status }
        });
      }

      if (!mtnMomoService.validateGhanaPhoneNumber(phoneNumber)) {
        return res.status(400).json({
          success: false,
          message: 'Invalid Ghana phone number format',
        });
      }

      const formattedPhoneNumber = mtnMomoService.formatPhoneNumber(phoneNumber);

      // Generate reference ID
      const timestamp = Date.now();
      const random = Math.floor(Math.random() * 10000);
      const referenceId = `PAY-${timestamp}-${random}`;

      // Set expiration for mobile money
      const expiredAt = new Date(Date.now() + 5 * 60 * 1000);

      // Create payment record
      const payment = await prisma.payment.create({
        data: {
          referenceId,
          orderId: orderId,
          customerId: req.user.id,
          paymentMethod: 'mobile_money',
          provider: 'mtn_momo',
          amount: order.totalAmount,
          currency: 'GHS',
          phoneNumber: formattedPhoneNumber,
          payerMessage: `Payment for GrabGo order ${order.orderNumber}`,
          payeeNote: 'GrabGo food delivery payment',
          status: 'pending',
          expiredAt
        }
      });

      const paymentRequest = await mtnMomoService.requestToPay({
        amount: order.totalAmount,
        currency: 'GHS',
        phoneNumber: formattedPhoneNumber,
        externalId: payment.referenceId,
        payerMessage: payment.payerMessage,
        payeeNote: payment.payeeNote
      });

      if (!paymentRequest.success) {
        await markAsFailed(payment.id, paymentRequest.error, paymentRequest.code);

        return res.status(400).json({
          success: false,
          message: 'Payment request failed',
          error: paymentRequest.error,
          code: paymentRequest.code
        });
      }

      const updatedPayment = await prisma.payment.update({
        where: { id: payment.id },
        data: {
          externalReferenceId: paymentRequest.referenceId,
          status: 'processing'
        }
      });

      // Update order with payment information
      await prisma.order.update({
        where: { id: orderId },
        data: {
          paymentProvider: 'mtn_momo',
          paymentReferenceId: updatedPayment.referenceId
        }
      });

      res.status(200).json({
        success: true,
        message: 'Payment request initiated successfully',
        data: {
          paymentId: updatedPayment.id,
          referenceId: updatedPayment.referenceId,
          externalReferenceId: updatedPayment.externalReferenceId,
          status: updatedPayment.status,
          amount: updatedPayment.amount,
          currency: updatedPayment.currency,
          phoneNumber: updatedPayment.phoneNumber
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

    const payment = await prisma.payment.findUnique({
      where: { id: paymentId },
      include: { order: true }
    });

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Payment not found',
      });
    }

    if (payment.customerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to check this payment',
      });
    }

    if (['successful', 'failed', 'cancelled'].includes(payment.status)) {
      return res.json({
        success: true,
        message: 'Payment status retrieved',
        data: {
          paymentId: payment.id,
          status: payment.status,
          amount: payment.amount,
          currency: payment.currency,
          completedAt: payment.completedAt,
          errorMessage: payment.errorMessage
        }
      });
    }

    if (isExpired(payment)) {
      await markAsFailed(payment.id, 'Payment expired', 'PAYMENT_EXPIRED');

      return res.json({
        success: true,
        message: 'Payment has expired',
        data: {
          paymentId: payment.id,
          status: 'failed',
          errorMessage: 'Payment expired'
        }
      });
    }

    if (payment.externalReferenceId) {
      const statusCheck = await mtnMomoService.getPaymentStatus(payment.externalReferenceId);

      if (statusCheck.success) {
        if (statusCheck.status === 'SUCCESSFUL') {
          const finalPayment = await markAsCompleted(payment.id, statusCheck.financialTransactionId);

          await prisma.order.update({
            where: { id: payment.orderId },
            data: {
              paymentStatus: 'paid',
              status: 'confirmed'
            }
          });

          return res.json({
            success: true,
            message: 'Payment completed successfully',
            data: {
              paymentId: finalPayment.id,
              status: 'successful',
              amount: finalPayment.amount,
              currency: finalPayment.currency,
              financialTransactionId: finalPayment.financialTransactionId,
              completedAt: finalPayment.completedAt
            }
          });
        } else if (statusCheck.status === 'FAILED') {
          const finalPayment = await markAsFailed(payment.id, statusCheck.reason, 'MTN_MOMO_FAILED');

          return res.json({
            success: true,
            message: 'Payment failed',
            data: {
              paymentId: finalPayment.id,
              status: 'failed',
              errorMessage: statusCheck.reason || 'Payment failed'
            }
          });
        }
      }
    }

    res.json({
      success: true,
      message: 'Payment status retrieved',
      data: {
        paymentId: payment.id,
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
 */
router.get('/my-payments', protect, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    const payments = await prisma.payment.findMany({
      where: { customerId: req.user.id },
      include: {
        order: { select: { orderNumber: true, totalAmount: true, status: true } }
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit
    });

    const total = await prisma.payment.count({
      where: { customerId: req.user.id }
    });

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
 */
router.put('/:paymentId/cancel', protect, async (req, res) => {
  try {
    const { paymentId } = req.params;

    const payment = await prisma.payment.findUnique({
      where: { id: paymentId }
    });

    if (!payment) {
      return res.status(404).json({
        success: false,
        message: 'Payment not found',
      });
    }

    if (payment.customerId !== req.user.id) {
      return res.status(403).json({
        success: false,
        message: 'Not authorized to cancel this payment',
      });
    }

    if (!['pending', 'processing'].includes(payment.status)) {
      return res.status(400).json({
        success: false,
        message: 'Payment cannot be cancelled in its current status',
      });
    }

    const updatedPayment = await prisma.payment.update({
      where: { id: paymentId },
      data: { status: 'cancelled' }
    });

    res.json({
      success: true,
      message: 'Payment cancelled successfully',
      data: {
        paymentId: updatedPayment.id,
        status: updatedPayment.status
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

    const payment = await prisma.payment.findFirst({
      where: { externalReferenceId: referenceId }
    });

    if (!payment) {
      console.log(`Payment not found for reference ID: ${referenceId}`);
      return res.status(404).json({
        success: false,
        message: 'Payment not found'
      });
    }

    if (status === 'SUCCESSFUL') {
      await markAsCompleted(payment.id, financialTransactionId);

      const order = await prisma.order.findUnique({
        where: { id: payment.orderId }
      });

      if (order && order.paymentStatus !== 'paid') {
        await prisma.order.update({
          where: { id: order.id },
          data: {
            paymentStatus: 'paid',
            status: 'confirmed'
          }
        });
        console.log(`Order ${order.orderNumber} payment confirmed via webhook`);
      }

    } else if (status === 'FAILED') {
      await markAsFailed(payment.id, reason || 'Payment failed', 'MTN_MOMO_WEBHOOK_FAILED');
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
