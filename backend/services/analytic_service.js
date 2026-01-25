const OrderTracking = require('../models/OrderTracking');
const DeliveryAnalytics = require('../models/DeliveryAnalytics');
const geolib = require('geolib');

class AnalyticsService {

  /**
   * Calculate delivery analytics when order is completed
   * This now uses the MongoDB OrderTracking record
   */
  async calculateDeliveryAnalytics(orderId) {
    try {
      // Find the tracking record in MongoDB
      const tracking = await OrderTracking.findOne({ orderId });

      if (!tracking || !tracking.locationHistory || tracking.locationHistory.length === 0) {
        console.log(`⚠️ Analytics: No tracking history found for order ${orderId}`);
        return;
      }

      // Determine pickup and delivery times
      const pickupTime = tracking.pickupTime || tracking.createdAt;
      const deliveryTime = tracking.lastUpdated || tracking.updatedAt;

      const totalDuration = Math.max(0, Math.floor((deliveryTime.getTime() - pickupTime.getTime()) / 1000)); // in seconds

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

      // Calculate ETA accuracy (percentage)
      let etaAccuracy = null;
      if (tracking.route?.duration) {
        const plannedDuration = tracking.route.duration; // in seconds
        etaAccuracy = Math.min(100, (plannedDuration / Math.max(1, totalDuration)) * 100);
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
            etaAccuracy,
            locationUpdatesCount: tracking.locationHistory.length,
            averageUpdateInterval: tracking.locationHistory.length > 0 ? totalDuration / tracking.locationHistory.length : 0,
            updatedAt: new Date()
          }
        },
        { upsert: true, new: true }
      );

      console.log(`📊 Delivery analytics calculated for order ${orderId} and saved to MongoDB`);

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