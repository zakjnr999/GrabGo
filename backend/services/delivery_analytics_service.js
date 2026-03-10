const DeliveryAnalytics = require('../models/DeliveryAnalytics');
const { createScopedLogger } = require('../utils/logger');
const console = createScopedLogger('delivery_analytics_service');

/**
 * Records a delivery analytics entry when an order is completed.
 *
 * Call this from every terminal-success path (food, grocery, pharmacy,
 * grabmart, parcel) so that the score engine has authoritative data.
 *
 * @param {Object} params
 * @param {string} params.riderId          - User ID of the rider
 * @param {string} params.orderId          - Order / parcel ID
 * @param {string} params.orderType        - 'food' | 'grocery' | 'pharmacy' | 'grabmart' | 'parcel'
 * @param {string} [params.vendorId]       - Vendor / store / sender ID
 * @param {Object} [params.customerLocation] - { latitude, longitude }
 * @param {Object} [params.vendorLocation]   - { latitude, longitude }
 * @param {number} [params.distanceKm]     - Delivery distance in km
 * @param {number} [params.riderEarnings]  - Amount credited to rider (GHS)
 * @param {Date}   [params.assignedAt]     - When rider was assigned / accepted
 * @param {Date}   [params.pickedUpAt]     - When rider picked up the order
 * @param {Date}   [params.deliveredAt]    - When delivery was completed
 * @param {number} [params.estimatedMinutes] - Original ETA in minutes
 * @param {number} [params.customerRating] - Rating given by customer (1-5, optional)
 * @param {string} [params.delayReason]    - Delay reason if late
 * @param {boolean} [params.isRiderFault]  - Whether delay was rider's fault
 */
const recordDeliveryAnalytics = async (params) => {
  const {
    riderId,
    orderId,
    orderType = 'food',
    vendorId,
    customerLocation,
    vendorLocation,
    distanceKm,
    riderEarnings,
    assignedAt,
    pickedUpAt,
    deliveredAt,
    estimatedMinutes,
    customerRating,
    delayReason,
    isRiderFault,
  } = params;

  const deliveredDate = deliveredAt || new Date();
  const assignedDate = assignedAt || deliveredDate;

  // Actual delivery duration in seconds
  const actualDeliveryTimeSeconds = pickedUpAt
    ? Math.round((deliveredDate.getTime() - new Date(pickedUpAt).getTime()) / 1000)
    : Math.round((deliveredDate.getTime() - new Date(assignedDate).getTime()) / 1000);

  // Total duration from assignment to delivery in seconds
  const totalDurationSeconds = Math.round(
    (deliveredDate.getTime() - new Date(assignedDate).getTime()) / 1000
  );

  // On-time determination: delivered within estimated time (with 5-min grace)
  const gracePeriodMinutes = 5;
  let wasOnTime = true;
  let minutesLate = null;

  if (estimatedMinutes != null && estimatedMinutes > 0) {
    const actualMinutes = totalDurationSeconds / 60;
    wasOnTime = actualMinutes <= estimatedMinutes + gracePeriodMinutes;
    if (!wasOnTime) {
      minutesLate = Math.round(actualMinutes - estimatedMinutes);
    }
  }

  try {
    // Check for existing entry (idempotency)
    const existing = await DeliveryAnalytics.findOne({ orderId });
    if (existing) {
      console.log(`[DeliveryAnalytics] Entry already exists for order=${orderId}, skipping`);
      return existing;
    }

    const analytics = new DeliveryAnalytics({
      riderId,
      orderId,
      orderType: orderType || 'food',

      // Time metrics
      pickupTime: pickedUpAt || null,
      deliveryTime: deliveredDate,
      totalDuration: totalDurationSeconds,
      actualDeliveryTime: actualDeliveryTimeSeconds,

      // Distance
      totalDistance: distanceKm ? distanceKm * 1000 : 0, // Convert to meters (existing schema uses meters)

      // ETA accuracy
      initialETA: estimatedMinutes ? estimatedMinutes * 60 : null, // Convert to seconds
      etaAccuracy: estimatedMinutes
        ? Math.round(((estimatedMinutes * 60) / Math.max(totalDurationSeconds, 1)) * 100)
        : null,

      // On-time tracking
      deliveryWindowMin: estimatedMinutes || null,
      deliveryWindowMax: estimatedMinutes ? estimatedMinutes + gracePeriodMinutes : null,
      wasOnTime,
      minutesLate,

      // Delay reason tracking (for fair penalty assessment)
      delayReason: delayReason || null,
      isRiderFault: isRiderFault != null ? isRiderFault : (wasOnTime ? false : null),

      // Rider earnings (new field for score engine)
      riderEarnings: riderEarnings || 0,

      // Status
      status: 'completed',

      createdAt: deliveredDate,
    });

    await analytics.save();
    console.log(
      `[DeliveryAnalytics] Recorded for order=${orderId} rider=${riderId} ` +
      `onTime=${wasOnTime} type=${orderType} earnings=${riderEarnings || 0}`
    );
    return analytics;
  } catch (error) {
    // Log but don't fail the delivery flow for analytics writes
    console.error(`[DeliveryAnalytics] Failed to record for order=${orderId}:`, error.message);
    return null;
  }
};

/**
 * Records a cancelled delivery for score engine completionRate calculation.
 *
 * @param {Object} params
 * @param {string} params.riderId      - Rider's user ID
 * @param {string} params.orderId      - Order ID
 * @param {string} [params.orderType]  - 'food' | 'grocery' | 'pharmacy' | 'grabmart' | 'parcel'
 * @param {string} params.fault        - 'rider' | 'vendor' | 'customer' | 'system'
 * @param {string} [params.reason]     - Free-text reason
 */
const recordDeliveryCancellation = async (params) => {
  const { riderId, orderId, orderType = 'food', fault, reason } = params;

  try {
    // Check for existing entry (idempotency)
    const existing = await DeliveryAnalytics.findOne({ orderId });
    if (existing) {
      console.log(`[DeliveryAnalytics] Entry already exists for order=${orderId}, skipping cancellation`);
      return existing;
    }

    const analytics = new DeliveryAnalytics({
      riderId,
      orderId,
      orderType: orderType || 'food',
      status: 'cancelled',
      wasOnTime: false,
      isRiderFault: fault === 'rider',
      delayReason: fault === 'rider' ? 'other' : (fault === 'vendor' ? 'vendor_delay' : null),
      delayReasonNote: reason || '',
      riderEarnings: 0,
      createdAt: new Date(),
    });

    await analytics.save();
    console.log(`[DeliveryAnalytics] Cancellation recorded order=${orderId} fault=${fault}`);
    return analytics;
  } catch (error) {
    console.error(`[DeliveryAnalytics] Failed to record cancellation for order=${orderId}:`, error.message);
    return null;
  }
};

module.exports = {
  recordDeliveryAnalytics,
  recordDeliveryCancellation,
};
