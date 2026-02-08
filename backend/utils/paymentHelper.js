const prisma = require('../config/prisma');

/**
 * Process expired payments periodically
 * This function should be called by a cron job or scheduled task
 */
async function processExpiredPayments() {
  try {
    const now = new Date();
    const expiredPayments = await prisma.payment.findMany({
      where: {
        status: { in: ['pending', 'processing'] },
        expiredAt: { lt: now }
      }
    });

    console.log(`Found ${expiredPayments.length} expired payments to process`);

    for (const payment of expiredPayments) {
      await prisma.payment.update({
        where: { id: payment.id },
        data: {
          status: 'failed',
          failureReason: 'Payment expired',
          errorCode: 'PAYMENT_EXPIRED',
          updatedAt: now
        }
      });
      console.log(`Marked payment ${payment.id} as expired`);
    }

    return {
      success: true,
      processedCount: expiredPayments.length
    };
  } catch (error) {
    console.error('Error processing expired payments:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

/**
 * Validate payment data before processing
 */
function validatePaymentData(paymentData) {
  const errors = [];

  if (!paymentData.amount || paymentData.amount <= 0) {
    errors.push('Invalid amount');
  }

  if (!paymentData.orderId) {
    errors.push('Order ID is required');
  }

  return {
    isValid: errors.length === 0,
    errors
  };
}

/**
 * Get payment statistics for analytics
 */
async function getPaymentStatistics(startDate, endDate) {
  try {
    const start = new Date(startDate);
    const end = new Date(endDate);

    const statusStats = await prisma.payment.groupBy({
      by: ['status'],
      where: {
        createdAt: {
          gte: start,
          lte: end
        }
      },
      _count: {
        id: true
      },
      _sum: {
        amount: true
      }
    });

    const providerStats = await prisma.payment.groupBy({
      by: ['provider'],
      where: {
        createdAt: {
          gte: start,
          lte: end
        }
      },
      _count: {
        id: true
      },
      _sum: {
        amount: true
      }
    });

    return {
      success: true,
      statusStats: statusStats.map(s => ({
        _id: s.status,
        count: s._count.id,
        totalAmount: s._sum.amount
      })),
      providerStats: providerStats.map(p => ({
        _id: p.provider,
        count: p._count.id,
        totalAmount: p._sum.amount
      }))
    };
  } catch (error) {
    console.error('Error getting payment statistics:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

module.exports = {
  processExpiredPayments,
  validatePaymentData,
  getPaymentStatistics
};
