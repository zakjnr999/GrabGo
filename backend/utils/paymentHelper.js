const prisma = require('../config/prisma');
const mtnMomoService = require('../services/mtn_momo_service');

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

  if (!paymentData.phoneNumber) {
    errors.push('Phone number is required');
  } else if (!mtnMomoService.validateGhanaPhoneNumber(paymentData.phoneNumber)) {
    errors.push('Invalid Ghana phone number format');
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

/**
 * Retry failed payments that might have been network-related failures
 */
async function retryFailedPayments() {
  try {
    // Find failed payments from the last hour that might be retryable
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

    const retryablePayments = await prisma.payment.findMany({
      where: {
        status: 'failed',
        errorCode: { in: ['NETWORK_ERROR', 'TIMEOUT', 'SERVICE_UNAVAILABLE'] },
        createdAt: { gte: oneHourAgo }
      },
      include: {
        order: true
      }
    });

    console.log(`Found ${retryablePayments.length} potentially retryable payments`);

    const results = [];

    for (const payment of retryablePayments) {
      try {
        // Check if we still have the external reference to check status
        if (payment.externalReferenceId) {
          const statusCheck = await mtnMomoService.getPaymentStatus(payment.externalReferenceId);

          if (statusCheck.success) {
            if (statusCheck.status === 'SUCCESSFUL') {
              await prisma.$transaction([
                prisma.payment.update({
                  where: { id: payment.id },
                  data: {
                    status: 'completed',
                    financialTransactionId: statusCheck.financialTransactionId,
                    updatedAt: new Date()
                  }
                }),
                prisma.order.update({
                  where: { id: payment.orderId },
                  data: {
                    paymentStatus: 'paid',
                    status: 'confirmed'
                  }
                })
              ]);

              results.push({
                paymentId: payment.id,
                action: 'completed',
                status: 'successful'
              });
            } else if (statusCheck.status === 'FAILED') {
              // Confirm it's really failed
              results.push({
                paymentId: payment.id,
                action: 'confirmed_failed',
                status: 'failed'
              });
            } else {
              // Still pending, update status
              await prisma.payment.update({
                where: { id: payment.id },
                data: {
                  status: 'processing',
                  updatedAt: new Date()
                }
              });

              results.push({
                paymentId: payment.id,
                action: 'updated_to_processing',
                status: 'processing'
              });
            }
          }
        }
      } catch (error) {
        console.error(`Error retrying payment ${payment.id}:`, error);
        results.push({
          paymentId: payment.id,
          action: 'retry_failed',
          error: error.message
        });
      }
    }

    return {
      success: true,
      processedCount: retryablePayments.length,
      results
    };
  } catch (error) {
    console.error('Error retrying failed payments:', error);
    return {
      success: false,
      error: error.message
    };
  }
}

module.exports = {
  processExpiredPayments,
  validatePaymentData,
  getPaymentStatistics,
  retryFailedPayments
};
