router.get('/performance/:riderId', auth, async (req, res) => {
  try {
    const { riderId } = req.params;
    const { days = 30 } = req.query;
    
    const performance = await analyticsService.getRiderPerformance(riderId, days);
    
    res.json({
      success: true,
      data: {
        totalDeliveries: performance.totalDeliveries || 0,
        averageDeliveryTime: Math.round(performance.avgDuration / 60), // minutes
        averageDistance: Math.round(performance.avgDistance / 1000), // km
        etaAccuracy: Math.round(performance.avgEtaAccuracy),
        totalDistanceCovered: Math.round(performance.totalDistance / 1000),
        rating: 4.5 // From separate ratings system
      }
    });
    
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});