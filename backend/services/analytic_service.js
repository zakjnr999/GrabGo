const OrderTracking = require('../models/OrderTracking');
const DeliveryAnalytics = require('../models/DeliveryAnalytics');
const geolib = require('geolib');
const prisma = require('../config/prisma');

class AnalyticsService {

  /**
   * Calculate delivery analytics when order is completed
   * This now uses the MongoDB OrderTracking record and initial ETA from Order
   * Also tracks on-time status for rider performance
   */
  async calculateDeliveryAnalytics(orderId) {
    try {
      // Find the tracking record in MongoDB
      const tracking = await OrderTracking.findOne({ orderId });

      if (!tracking || !tracking.locationHistory || tracking.locationHistory.length === 0) {
        console.log(`⚠️ Analytics: No tracking history found for order ${orderId}`);
        return;
      }

      // Get order from PostgreSQL for initial ETA data
      const order = await prisma.order.findUnique({
        where: { id: orderId },
        select: {
          initialETASeconds: true,
          riderAssignedAt: true,
          deliveredDate: true,
          deliveryWindowMin: true,
          deliveryWindowMax: true
        }
      });

      // Determine pickup and delivery times
      const pickupTime = tracking.pickupTime || tracking.createdAt;
      const deliveryTime = tracking.lastUpdated || tracking.updatedAt;

      const totalDuration = Math.max(0, Math.floor((deliveryTime.getTime() - pickupTime.getTime()) / 1000)); // in seconds

      // Calculate actual delivery time from rider assignment (more accurate for ETA comparison)
      let actualDeliveryTimeFromAssignment = totalDuration;
      if (order?.riderAssignedAt && (order?.deliveredDate || deliveryTime)) {
        const endTime = order.deliveredDate || deliveryTime;
        actualDeliveryTimeFromAssignment = Math.floor((endTime.getTime() - order.riderAssignedAt.getTime()) / 1000);
      }

      // Calculate total distance from location history using geolib
      let totalDistance = 0;
      for (let i = 1; i < tracking.locationHistory.length; i++) {
        const prev = tracking.locationHistory[i - 1];
        const curr = tracking.locationHistory[i];

        // Ensure coordinates exist in [long, lat] format from schema
        if (prev.coordinates?.length === 2 && curr.coordinates?.length === 2) {
          totalDistance += geolib.getDistance(
            { latitude: prev.coordinates[1], longitude: prev.coordinates[0] },
            { latitude: curr.coordinates[1], longitude: curr.coordinates[0] }
          );
        }
      }

      // Calculate ETA accuracy using initial ETA from order (more accurate)
      let etaAccuracy = null;
      let initialETA = order?.initialETASeconds || tracking.route?.duration;
      
      if (initialETA && actualDeliveryTimeFromAssignment > 0) {
        // How close was our estimate?
        // 100% = perfect, >100% = delivered faster than expected, <100% = delivered slower
        etaAccuracy = Math.round((initialETA / actualDeliveryTimeFromAssignment) * 100);
        
        // Cap at reasonable bounds (50% - 150%)
        etaAccuracy = Math.min(150, Math.max(50, etaAccuracy));
      }

      // Calculate on-time status
      let wasOnTime = true;
      let minutesLate = null;
      const deliveryWindowMin = order?.deliveryWindowMin;
      const deliveryWindowMax = order?.deliveryWindowMax;

      if (deliveryWindowMax && order?.riderAssignedAt) {
        const actualMinutes = Math.ceil(actualDeliveryTimeFromAssignment / 60);
        
        if (actualMinutes > deliveryWindowMax) {
          wasOnTime = false;
          minutesLate = actualMinutes - deliveryWindowMax;
        }
      }

      // Update or create analytics in MongoDB
      await DeliveryAnalytics.findOneAndUpdate(
        { orderId },
        {
          $set: {
            riderId: tracking.riderId,
            pickupTime,
            deliveryTime,
            totalDuration,
            totalDistance,
            initialETA: initialETA || null,
            actualDeliveryTime: actualDeliveryTimeFromAssignment,
            etaAccuracy,
            deliveryWindowMin,
            deliveryWindowMax,
            wasOnTime,
            minutesLate,
            locationUpdatesCount: tracking.locationHistory.length,
            averageUpdateInterval: tracking.locationHistory.length > 0 ? totalDuration / tracking.locationHistory.length : 0,
            updatedAt: new Date()
          }
        },
        { upsert: true, new: true }
      );

      // Clear delivery monitor tracking for this order
      try {
        const { clearOrderTracking } = require('../jobs/delivery_monitor');
        clearOrderTracking(orderId);
      } catch (e) {
        // Ignore if delivery monitor not loaded
      }

      console.log(`📊 Delivery analytics calculated for order ${orderId}:`);
      console.log(`   Initial ETA: ${initialETA ? Math.ceil(initialETA / 60) + ' mins' : 'N/A'}`);
      console.log(`   Actual Time: ${Math.ceil(actualDeliveryTimeFromAssignment / 60)} mins`);
      console.log(`   ETA Accuracy: ${etaAccuracy ? etaAccuracy + '%' : 'N/A'}`);
      console.log(`   On Time: ${wasOnTime ? '✅ Yes' : `❌ No (${minutesLate} mins late)`}`);

    } catch (error) {
      console.error('❌ Error calculating analytics:', error);
    }
  }

  /**
   * Get rider performance metrics using MongoDB Aggregation
   */
  async getRiderPerformance(riderId, days = 30) {
    try {
      const startDate = new Date();
      startDate.setDate(startDate.getDate() - days);

      const stats = await DeliveryAnalytics.aggregate([
        {
          $match: {
            riderId: riderId,
            createdAt: { $gte: startDate }
          }
        },
        {
          $group: {
            _id: null,
            totalDeliveries: { $sum: 1 },
            avgDuration: { $avg: '$totalDuration' },
            avgDistance: { $avg: '$totalDistance' },
            avgEtaAccuracy: { $avg: '$etaAccuracy' },
            totalDistance: { $sum: '$totalDistance' }
          }
        }
      ]);

      if (stats.length === 0) {
        return {
          totalDeliveries: 0,
          avgDuration: 0,
          avgDistance: 0,
          avgEtaAccuracy: 100,
          totalDistance: 0
        };
      }

      const result = stats[0];
      return {
        totalDeliveries: result.totalDeliveries,
        avgDuration: Math.round(result.avgDuration),
        avgDistance: Math.round(result.avgDistance),
        avgEtaAccuracy: Math.round(result.avgEtaAccuracy),
        totalDistance: Math.round(result.totalDistance)
      };
    } catch (error) {
      console.error('❌ Error getting rider performance:', error);
      return {
        totalDeliveries: 0,
        avgDuration: 0,
        avgDistance: 0,
        avgEtaAccuracy: 0,
        totalDistance: 0
      };
    }
  }
}

module.exports = new AnalyticsService();