const express = require('express');
const prisma = require('../config/prisma');
const { protect } = require('../middleware/auth');

const router = express.Router();

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
        order: { select: { orderNumber: true, totalAmount: true, status: true } },
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
    });

    const total = await prisma.payment.count({
      where: { customerId: req.user.id },
    });

    res.json({
      success: true,
      message: 'Payments retrieved successfully',
      data: payments,
      pagination: {
        currentPage: page,
        totalPages: Math.ceil(total / limit),
        totalItems: total,
        itemsPerPage: limit,
      },
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
      where: { id: paymentId },
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
      data: { status: 'cancelled' },
    });

    res.json({
      success: true,
      message: 'Payment cancelled successfully',
      data: {
        paymentId: updatedPayment.id,
        status: updatedPayment.status,
      },
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

module.exports = router;
