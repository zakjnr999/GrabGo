const Payment = require('../models/Payment');
const Order = require('../models/Order');
const mtnMomoService = require('../services/mtn_momo_service');

/**
 * Process expired payments periodically
 * This function should be called by a cron job or scheduled task
 */
async function processExpiredPayments() {
  try {
    const expiredPayments = await Payment.find({
      status: { $in: ['pending', 'processing'] },
      expiredAt: { $lt: new Date() }
    });

    console.log(`Found ${expiredPayments.length} expired payments to process`);

    for (const payment of expiredPayments) {
      await payment.markAsFailed('Payment expired', 'PAYMENT_EXPIRED');
      console.log(`Marked payment ${payment._id} as expired`);
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
    const matchStage = {
      createdAt: {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      }
    };

    const stats = await Payment.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 },
          totalAmount: { $sum: '$amount' }
        }
      }
    ]);

    const providerStats = await Payment.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: '$provider',
          count: { $sum: 1 },
          totalAmount: { $sum: '$amount' }
        }
      }
    ]);

    return {
      success: true,
      statusStats: stats,
      providerStats: providerStats
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
    
    const retryablePayments = await Payment.find({
      status: 'failed',
      errorCode: { $in: ['NETWORK_ERROR', 'TIMEOUT', 'SERVICE_UNAVAILABLE'] },
      createdAt: { $gte: oneHourAgo }
    }).populate('order');

    console.log(`Found ${retryablePayments.length} potentially retryable payments`);

    const results = [];
    
    for (const payment of retryablePayments) {
      try {
        // Check if we still have the external reference to check status
        if (payment.externalReferenceId) {
          const statusCheck = await mtnMomoService.getPaymentStatus(payment.externalReferenceId);
          
          if (statusCheck.success) {
            if (statusCheck.status === 'SUCCESSFUL') {
              await payment.markAsCompleted(statusCheck.financialTransactionId);
              
              // Update order
              const order = payment.order;
              if (order && order.paymentStatus !== 'paid') {
                order.paymentStatus = 'paid';
                order.status = 'confirmed';
                await order.save();
              }
              
              results.push({
                paymentId: payment._id,
                action: 'completed',
                status: 'successful'
              });
            } else if (statusCheck.status === 'FAILED') {
              // Confirm it's really failed
              results.push({
                paymentId: payment._id,
                action: 'confirmed_failed',
                status: 'failed'
              });
            } else {
              // Still pending, update status
              payment.status = 'processing';
              await payment.save();
              
              results.push({
                paymentId: payment._id,
                action: 'updated_to_processing',
                status: 'processing'
              });
            }
          }
        }
      } catch (error) {
        console.error(`Error retrying payment ${payment._id}:`, error);
        results.push({
          paymentId: payment._id,
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