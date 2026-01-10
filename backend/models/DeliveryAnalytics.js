const mongoose = require('mongoose');

const deliveryAnalyticsSchema = new mongoose.Schema({
  orderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Order', required: true },
  riderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  
  // Time metrics
  pickupTime: Date,
  deliveryTime: Date,
  totalDuration: Number, // in seconds
  
  // Distance metrics
  totalDistance: Number, // in meters
  straightLineDistance: Number,
  
  // ETA accuracy
  initialETA: Number,
  actualDeliveryTime: Number,
  etaAccuracy: Number, // percentage
  
  // Performance metrics
  averageSpeed: Number,
  stopsCount: Number,
  routeDeviation: Number, // how much rider deviated from optimal route
  
  // Location data
  locationUpdatesCount: Number,
  averageUpdateInterval: Number,
  
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('DeliveryAnalytics', deliveryAnalyticsSchema);