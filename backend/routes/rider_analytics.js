const express = require('express');
const router = express.Router();
const { protect, authorize } = require('../middleware/auth');
const { createScopedLogger } = require('../utils/logger');
const analyticsService = require('../services/analytic_service');
const DeliveryAnalytics = require('../models/DeliveryAnalytics');
const console = createScopedLogger('rider_analytics_route');

const sendRiderAnalyticsError = (res, error, fallbackMessage, fallbackStatus = 500) => {
  const explicitStatus = Number(error?.status);
  const status =
    Number.isInteger(explicitStatus) && explicitStatus >= 400 && explicitStatus < 600
      ? explicitStatus
      : fallbackStatus;

  return res.status(status).json({
    success: false,
    message: status >= 500 ? fallbackMessage : String(error?.message || fallbackMessage),
  });
};

/**
 * @route   GET /rider-analytics/performance/:riderId
 * @desc    Get rider performance metrics
 * @access  Private (Rider or Admin)
 */
router.get('/performance/:riderId', protect, async (req, res) => {
  try {
    const { riderId } = req.params;
    const { days = 30 } = req.query;
    
    // Verify user can access this data (own data or admin)
    if (req.user.id !== riderId && req.user.role !== 'admin') {
      return res.status(403).json({ 
        success: false, 
        message: 'Not authorized to view this rider\'s performance' 
      });
    }
    
    const performance = await analyticsService.getRiderPerformance(riderId, parseInt(days));
    
    res.json({
      success: true,
      data: {
        totalDeliveries: performance.totalDeliveries || 0,
        averageDeliveryTime: Math.round((performance.avgDuration || 0) / 60), // minutes
        averageDistance: Math.round((performance.avgDistance || 0) / 1000 * 10) / 10, // km
        etaAccuracy: Math.round(performance.avgEtaAccuracy || 100),
        totalDistanceCovered: Math.round((performance.totalDistance || 0) / 1000),
        periodDays: parseInt(days)
      }
    });
    
  } catch (error) {
    console.error('Rider performance error:', error);
    return sendRiderAnalyticsError(res, error, 'Failed to fetch rider performance');
  }
});

/**
 * @route   GET /rider-analytics/on-time-rate/:riderId
 * @desc    Get rider's on-time delivery rate
 * @access  Private (Rider or Admin)
 */
router.get('/on-time-rate/:riderId', protect, async (req, res) => {
  try {
    const { riderId } = req.params;
    
    // Verify user can access this data
    if (req.user.id !== riderId && req.user.role !== 'admin') {
      return res.status(403).json({ 
        success: false, 
        message: 'Not authorized to view this data' 
      });
    }
    
    const stats = await DeliveryAnalytics.getRiderOnTimeRate(riderId, 20);
    
    res.json({
      success: true,
      data: {
        onTimeRate: stats.onTimeRate,
        totalDeliveries: stats.totalDeliveries,
        onTimeCount: stats.onTimeCount,
        lateCount: stats.totalDeliveries - stats.onTimeCount,
        avgMinutesLate: stats.avgMinutesLate,
        avgEtaAccuracy: stats.avgEtaAccuracy,
        isReliable: stats.isReliable,
        minDeliveriesForReliable: 20
      }
    });
    
  } catch (error) {
    console.error('On-time rate error:', error);
    return sendRiderAnalyticsError(res, error, 'Failed to fetch rider on-time rate');
  }
});

/**
 * @route   GET /rider-analytics/summary/:riderId
 * @desc    Get complete rider performance summary
 * @access  Private (Rider or Admin)
 */
router.get('/summary/:riderId', protect, async (req, res) => {
  try {
    const { riderId } = req.params;
    const { days = 30 } = req.query;
    
    // Verify user can access this data
    if (req.user.id !== riderId && req.user.role !== 'admin') {
      return res.status(403).json({ 
        success: false, 
        message: 'Not authorized to view this data' 
      });
    }
    
    const summary = await DeliveryAnalytics.getRiderPerformanceSummary(riderId, parseInt(days));
    
    res.json({
      success: true,
      data: {
        ...summary,
        periodDays: parseInt(days),
        performanceLabel: getPerformanceLabel(summary.performanceRating)
      }
    });
    
  } catch (error) {
    console.error('Performance summary error:', error);
    return sendRiderAnalyticsError(res, error, 'Failed to fetch rider performance summary');
  }
});

/**
 * @route   GET /rider-analytics/my-performance
 * @desc    Get current rider's own performance (shortcut)
 * @access  Private (Rider only)
 */
router.get('/my-performance', protect, authorize('rider'), async (req, res) => {
  try {
    const riderId = req.user.id;
    const { days = 30 } = req.query;
    
    const [summary, onTimeStats] = await Promise.all([
      DeliveryAnalytics.getRiderPerformanceSummary(riderId, parseInt(days)),
      DeliveryAnalytics.getRiderOnTimeRate(riderId, 20)
    ]);
    
    res.json({
      success: true,
      data: {
        // Summary stats
        totalDeliveries: summary.totalDeliveries,
        onTimeRate: summary.onTimeRate,
        onTimeCount: summary.onTimeCount,
        lateCount: summary.lateCount,
        avgDeliveryTimeMinutes: summary.avgDeliveryTimeMinutes,
        avgDistanceKm: summary.avgDistanceKm,
        totalDistanceKm: summary.totalDistanceKm,
        avgEtaAccuracy: summary.avgEtaAccuracy,
        
        // Performance rating
        performanceRating: summary.performanceRating,
        performanceLabel: getPerformanceLabel(summary.performanceRating),
        
        // Reliability indicator
        isDataReliable: onTimeStats.isReliable,
        avgMinutesLate: onTimeStats.avgMinutesLate,
        
        // Period
        periodDays: parseInt(days)
      }
    });
    
  } catch (error) {
    console.error('My performance error:', error);
    return sendRiderAnalyticsError(res, error, 'Failed to fetch rider performance');
  }
});

/**
 * Helper function to get human-readable performance label
 */
function getPerformanceLabel(rating) {
  switch (rating) {
    case 'excellent': return '⭐ Excellent - Top Performer!';
    case 'good': return '👍 Good - Keep it up!';
    case 'average': return '📊 Average - Room for improvement';
    case 'needs_improvement': return '⚠️ Needs Improvement';
    case 'new': return '🆕 New Rider - Building history';
    default: return 'Unknown';
  }
}

module.exports = router;
