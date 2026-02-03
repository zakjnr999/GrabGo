/**
 * RiderStatus Model - MongoDB
 * 
 * Tracks real-time rider status including:
 * - Online/offline status
 * - Current location
 * - Availability for orders
 * - Performance metrics
 */

const mongoose = require('mongoose');

const riderStatusSchema = new mongoose.Schema({
  // Link to PostgreSQL User
  riderId: {
    type: String,
    required: true,
    unique: true,
    index: true
  },
  
  // Online status
  isOnline: {
    type: Boolean,
    default: false,
    index: true
  },
  
  // Current location
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point'
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      default: [0, 0]
    }
  },
  
  // Last known location update
  lastLocationUpdate: {
    type: Date,
    default: Date.now
  },
  
  // Last activity timestamp
  lastActiveAt: {
    type: Date,
    default: Date.now
  },
  
  // Is currently on a delivery
  isOnDelivery: {
    type: Boolean,
    default: false
  },
  
  // Current order being delivered
  currentOrderId: {
    type: String,
    default: null
  },
  
  // Performance metrics (cached for quick scoring)
  metrics: {
    rating: {
      type: Number,
      default: 5.0,
      min: 1,
      max: 5
    },
    totalDeliveries: {
      type: Number,
      default: 0
    },
    acceptanceRate: {
      type: Number,
      default: 100,
      min: 0,
      max: 100
    },
    avgResponseTime: {
      type: Number, // in seconds
      default: 5
    },
    todayEarnings: {
      type: Number,
      default: 0
    },
    todayDeliveries: {
      type: Number,
      default: 0
    }
  },
  
  // Preferred order types (for scoring)
  preferredOrderTypes: [{
    type: String,
    enum: ['food', 'grocery', 'pharmacy']
  }],
  
  // Recently declined orders (for penalty scoring)
  recentDeclines: [{
    orderId: String,
    declinedAt: Date
  }],
  
  // Socket connection ID
  socketId: {
    type: String,
    default: null
  },
  
  // Verification status from Rider profile
  isApproved: {
    type: Boolean,
    default: false
  },
  
  // Battery level (0-100) - sent by rider app
  batteryLevel: {
    type: Number,
    default: 100,
    min: 0,
    max: 100
  },
  
  // Is currently charging
  isCharging: {
    type: Boolean,
    default: false
  },
  
  // Vehicle type (synced from Rider profile)
  vehicleType: {
    type: String,
    enum: ['motorcycle', 'bicycle', 'car', 'scooter', null],
    default: null
  },
  
  // Auto-offline tracking
  autoOfflineReason: {
    type: String,
    enum: ['inactivity', 'low_battery', 'unresponsive', null],
    default: null
  },
  
  autoOfflineAt: {
    type: Date,
    default: null
  }
  
}, {
  timestamps: true
});

// Geospatial index for location-based queries
riderStatusSchema.index({ location: '2dsphere' });

// Compound index for finding available riders
riderStatusSchema.index({ isOnline: 1, isOnDelivery: 1, isApproved: 1 });

// Static method: Find available riders near a location
riderStatusSchema.statics.findAvailableNear = async function(longitude, latitude, radiusKm = 10) {
  const radiusInMeters = radiusKm * 1000;
  
  return this.find({
    isOnline: true,
    isOnDelivery: false,
    isApproved: true,
    location: {
      $near: {
        $geometry: {
          type: 'Point',
          coordinates: [longitude, latitude]
        },
        $maxDistance: radiusInMeters
      }
    }
  });
};

// Static method: Set rider online
riderStatusSchema.statics.goOnline = async function(riderId, longitude, latitude, isApproved = true, batteryLevel = 100, isCharging = false, vehicleType = null) {
  return this.findOneAndUpdate(
    { riderId },
    {
      $set: {
        isOnline: true,
        isApproved: isApproved,
        lastActiveAt: new Date(),
        'location.coordinates': [longitude, latitude],
        lastLocationUpdate: new Date(),
        batteryLevel: batteryLevel,
        isCharging: isCharging,
        vehicleType: vehicleType
      }
    },
    { upsert: true, new: true }
  );
};

// Static method: Set rider offline
riderStatusSchema.statics.goOffline = async function(riderId) {
  return this.findOneAndUpdate(
    { riderId },
    {
      $set: {
        isOnline: false,
        lastActiveAt: new Date(),
        socketId: null
      }
    },
    { new: true }
  );
};

// Static method: Update rider location
riderStatusSchema.statics.updateLocation = async function(riderId, longitude, latitude) {
  return this.findOneAndUpdate(
    { riderId },
    {
      $set: {
        'location.coordinates': [longitude, latitude],
        lastLocationUpdate: new Date(),
        lastActiveAt: new Date()
      }
    },
    { new: true }
  );
};

// Static method: Get or create rider status
riderStatusSchema.statics.getOrCreate = async function(riderId) {
  let status = await this.findOne({ riderId });
  if (!status) {
    status = await this.create({ riderId });
  }
  return status;
};

// Static method: Add decline to recent history
riderStatusSchema.statics.addDecline = async function(riderId, orderId) {
  // Keep only last 10 declines from the past hour
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  
  return this.findOneAndUpdate(
    { riderId },
    {
      $push: {
        recentDeclines: {
          $each: [{ orderId, declinedAt: new Date() }],
          $slice: -10 // Keep only last 10
        }
      },
      $pull: {
        recentDeclines: { declinedAt: { $lt: oneHourAgo } }
      }
    },
    { new: true }
  );
};

// Instance method: Calculate distance to a point (in km)
riderStatusSchema.methods.distanceTo = function(longitude, latitude) {
  const [riderLng, riderLat] = this.location.coordinates;
  
  // Haversine formula
  const R = 6371; // Earth's radius in km
  const dLat = (latitude - riderLat) * Math.PI / 180;
  const dLon = (longitude - riderLng) * Math.PI / 180;
  const a = 
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(riderLat * Math.PI / 180) * Math.cos(latitude * Math.PI / 180) * 
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  
  return R * c;
};

const RiderStatus = mongoose.model('RiderStatus', riderStatusSchema);

module.exports = RiderStatus;
