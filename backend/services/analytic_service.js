const DeliveryAnalytics = require('../models/DeliveryAnalytics');
const OrderTracking = require('../models/OrderTracking');

class AnalyticsService {
  
  /**
   * Calculate delivery analytics when order is completed
   */
  async calculateDeliveryAnalytics(orderId) {
    try {
      const tracking = await OrderTracking.findOne({ orderId });
      if (!tracking) return;
      
      const pickupTime = tracking.locationHistory.find(
        loc => tracking.status === 'picked_up'
      )?.timestamp;
      
      const deliveryTime = tracking.updatedAt;
      
      const totalDuration = deliveryTime - pickupTime;
      
      // Calculate total distance from location history
      let totalDistance = 0;
      for (let i = 1; i < tracking.locationHistory.length; i++) {
        const prev = tracking.locationHistory[i - 1];
        const curr = tracking.locationHistory[i];
        
        totalDistance += geolib.getDistance(
          { latitude: prev.coordinates[1], longitude: prev.coordinates[0] },
          { latitude: curr.coordinates[1], longitude: curr.coordinates[0] }
        );
      }
      
      // Calculate ETA accuracy
      const initialETA = tracking.estimatedArrival;
      const etaAccuracy = Math.abs(
        (deliveryTime - initialETA) / initialETA * 100
      );
      
      const analytics = new DeliveryAnalytics({
        orderId,
        riderId: tracking.riderId,
        pickupTime,
        deliveryTime,
        totalDuration,
        totalDistance,
        etaAccuracy,
        locationUpdatesCount: tracking.locationHistory.length,
        averageUpdateInterval: totalDuration / tracking.locationHistory.length
      });
      
      await analytics.save();
      
    } catch (error) {
      console.error('Error calculating analytics:', error);
    }
  }
  
  /**
   * Get rider performance metrics
   */
  async getRiderPerformance(riderId, days = 30) {
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    
    const analytics = await DeliveryAnalytics.aggregate([
      {
        $match: {
          riderId: mongoose.Types.ObjectId(riderId),
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
    
    return analytics[0] || {};
  }
}

module.exports = new AnalyticsService();