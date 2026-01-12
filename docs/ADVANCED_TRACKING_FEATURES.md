# Advanced Live Tracking Features

> Additional features to enhance your live order tracking system beyond the basics

## 📋 Table of Contents

1. [Geofencing & Auto-Status Updates](#geofencing--auto-status-updates)
2. [Offline Support & Queue Management](#offline-support--queue-management)
3. [Multi-Delivery Route Optimization](#multi-delivery-route-optimization)
4. [Push Notifications & Alerts](#push-notifications--alerts)
5. [Analytics & Insights](#analytics--insights)
6. [Custom Markers & Animations](#custom-markers--animations)
7. [Battery Optimization](#battery-optimization)
8. [Rider Performance Tracking](#rider-performance-tracking)

---

## Geofencing & Auto-Status Updates

### Overview

Automatically update order status when rider enters specific geographic zones (restaurant, customer location).

### Backend Implementation

**File: `backend/services/geofence.service.js`**

```javascript
const geolib = require("geolib");
const OrderTracking = require("../models/OrderTracking");
const socketService = require("./socket.service");

class GeofenceService {
  // Geofence radiuses in meters
  static PICKUP_RADIUS = 50; // 50 meters from restaurant
  static DELIVERY_RADIUS = 100; // 100 meters from customer

  /**
   * Check if rider entered any geofence zones
   */
  async checkGeofences(orderId, riderLat, riderLng) {
    try {
      const tracking = await OrderTracking.findOne({ orderId });
      if (!tracking) return;

      const riderLocation = { latitude: riderLat, longitude: riderLng };

      // Check pickup geofence
      if (tracking.status === "preparing") {
        const pickupLocation = {
          latitude: tracking.pickupLocation.coordinates[1],
          longitude: tracking.pickupLocation.coordinates[0],
        };

        const distanceToPickup = geolib.getDistance(
          riderLocation,
          pickupLocation
        );

        if (distanceToPickup <= GeofenceService.PICKUP_RADIUS) {
          await this.triggerGeofenceEvent(tracking, "arrived_at_restaurant");
        }
      }

      // Check delivery geofence
      if (tracking.status === "in_transit") {
        const deliveryLocation = {
          latitude: tracking.destination.coordinates[1],
          longitude: tracking.destination.coordinates[0],
        };

        const distanceToDelivery = geolib.getDistance(
          riderLocation,
          deliveryLocation
        );

        if (distanceToDelivery <= GeofenceService.DELIVERY_RADIUS) {
          tracking.status = "nearby";
          await tracking.save();

          await this.triggerGeofenceEvent(tracking, "arrived_at_customer");
        }
      }
    } catch (error) {
      console.error("Error checking geofences:", error);
    }
  }

  /**
   * Trigger geofence event
   */
  async triggerGeofenceEvent(tracking, eventType) {
    // Notify customer
    socketService.emitToUser(tracking.customerId.toString(), "geofence_event", {
      orderId: tracking.orderId.toString(),
      eventType,
      status: tracking.status,
    });

    // Send push notification
    const notificationService = require("./notification.service");

    const messages = {
      arrived_at_restaurant: "Your rider has arrived at the restaurant",
      arrived_at_customer: "Your rider is arriving soon! Please be ready.",
    };

    await notificationService.sendPushNotification(
      tracking.customerId,
      "Order Update",
      messages[eventType]
    );
  }
}

module.exports = new GeofenceService();
```

**Update tracking service to use geofencing:**

```javascript
// In tracking.service.js, updateRiderLocation method
const geofenceService = require('./geofence.service');

async updateRiderLocation(orderId, latitude, longitude, speed = 0, accuracy = 0) {
  // ... existing code ...

  // Check geofences
  await geofenceService.checkGeofences(orderId, latitude, longitude);

  return tracking;
}
```

### Flutter Implementation

**File: `packages/grab_go_customer/lib/providers/order_tracking_provider.dart`**

```dart
void _handleGeofenceEvent(dynamic data) {
  final eventType = data['eventType'];

  // Show notification to user
  if (eventType == 'arrived_at_restaurant') {
    _showNotification('Rider has arrived at restaurant');
  } else if (eventType == 'arrived_at_customer') {
    _showNotification('Rider is arriving soon! 🎉');
    _playArrivalSound();
  }
}

// In startTracking method, add listener:
_socketService.socket?.on('geofence_event', (data) {
  _handleGeofenceEvent(data);
});
```

---

## Offline Support & Queue Management

### Overview

Queue location updates when offline and sync when connection is restored.

### Flutter Implementation

**File: `packages/grab_go_rider/lib/services/offline_location_queue.dart`**

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class OfflineLocationQueue {
  static const String QUEUE_KEY = 'location_update_queue';
  static const int MAX_QUEUE_SIZE = 100;

  final SharedPreferences _prefs;
  final ApiService _apiService;

  OfflineLocationQueue(this._prefs, this._apiService);

  /// Add location update to queue
  Future<void> queueLocationUpdate({
    required String orderId,
    required double latitude,
    required double longitude,
    required double speed,
    required double accuracy,
  }) async {
    final queue = await _getQueue();

    queue.add({
      'orderId': orderId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'accuracy': accuracy,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Keep only last MAX_QUEUE_SIZE items
    if (queue.length > MAX_QUEUE_SIZE) {
      queue.removeRange(0, queue.length - MAX_QUEUE_SIZE);
    }

    await _saveQueue(queue);
  }

  /// Sync queued updates when online
  Future<void> syncQueuedUpdates() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return; // Still offline
    }

    final queue = await _getQueue();
    if (queue.isEmpty) return;

    print('Syncing ${queue.length} queued location updates...');

    final failedUpdates = <Map<String, dynamic>>[];

    for (final update in queue) {
      try {
        await _apiService.post('/tracking/location', data: update);
      } catch (e) {
        print('Failed to sync update: $e');
        failedUpdates.add(update);
      }
    }

    // Keep only failed updates in queue
    await _saveQueue(failedUpdates);

    print('Sync complete. ${failedUpdates.length} updates failed.');
  }

  Future<List<Map<String, dynamic>>> _getQueue() async {
    final queueJson = _prefs.getString(QUEUE_KEY);
    if (queueJson == null) return [];

    final List<dynamic> decoded = jsonDecode(queueJson);
    return decoded.cast<Map<String, dynamic>>();
  }

  Future<void> _saveQueue(List<Map<String, dynamic>> queue) async {
    await _prefs.setString(QUEUE_KEY, jsonEncode(queue));
  }

  Future<void> clearQueue() async {
    await _prefs.remove(QUEUE_KEY);
  }
}
```

**Update LocationTrackingService:**

```dart
class LocationTrackingService {
  final OfflineLocationQueue _offlineQueue;

  Future<void> _sendLocationUpdate(Position position) async {
    if (_activeOrderId == null) return;

    try {
      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        // Offline - queue the update
        await _offlineQueue.queueLocationUpdate(
          orderId: _activeOrderId!,
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          accuracy: position.accuracy,
        );
        return;
      }

      // Online - send immediately
      final apiService = getIt<ApiService>();
      await apiService.post('/tracking/location', data: {
        'orderId': _activeOrderId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed,
        'accuracy': position.accuracy,
      });

      // Try to sync any queued updates
      await _offlineQueue.syncQueuedUpdates();

    } catch (e) {
      print('Error sending location update: $e');

      // Queue on error
      await _offlineQueue.queueLocationUpdate(
        orderId: _activeOrderId!,
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed,
        accuracy: position.accuracy,
      );
    }
  }
}
```

---

## Multi-Delivery Route Optimization

### Overview

Optimize route when rider has multiple deliveries to make.

### Backend Implementation

**File: `backend/services/route-optimization.service.js`**

```javascript
const { Client } = require("@googlemaps/google-maps-services-js");

class RouteOptimizationService {
  constructor() {
    this.googleMapsClient = new Client({});
  }

  /**
   * Optimize route for multiple deliveries
   */
  async optimizeMultiDeliveryRoute(riderLocation, deliveries) {
    try {
      // Build waypoints
      const waypoints = deliveries.map((delivery) => ({
        location: `${delivery.destination.latitude},${delivery.destination.longitude}`,
        orderId: delivery.orderId,
      }));

      // Call Google Maps Directions API with waypoint optimization
      const response = await this.googleMapsClient.directions({
        params: {
          origin: `${riderLocation.latitude},${riderLocation.longitude}`,
          destination: waypoints[waypoints.length - 1].location,
          waypoints: waypoints.slice(0, -1).map((w) => w.location),
          optimize: true, // This optimizes the waypoint order
          mode: "driving",
          key: process.env.GOOGLE_MAPS_API_KEY,
        },
      });

      if (response.data.routes.length === 0) {
        throw new Error("No route found");
      }

      const route = response.data.routes[0];

      // Get optimized order
      const optimizedOrder = route.waypoint_order || [];
      const optimizedDeliveries = optimizedOrder.map(
        (index) => deliveries[index]
      );

      // Add the last delivery
      optimizedDeliveries.push(deliveries[deliveries.length - 1]);

      return {
        optimizedDeliveries,
        totalDistance: route.legs.reduce(
          (sum, leg) => sum + leg.distance.value,
          0
        ),
        totalDuration: route.legs.reduce(
          (sum, leg) => sum + leg.duration.value,
          0
        ),
        polyline: route.overview_polyline.points,
      };
    } catch (error) {
      console.error("Error optimizing route:", error);
      // Return original order on error
      return {
        optimizedDeliveries: deliveries,
        totalDistance: 0,
        totalDuration: 0,
        polyline: null,
      };
    }
  }
}

module.exports = new RouteOptimizationService();
```

---

## Push Notifications & Alerts

### Backend Implementation

**File: `backend/services/tracking-notifications.service.js`**

```javascript
const admin = require("firebase-admin");
const User = require("../models/User");

class TrackingNotificationsService {
  /**
   * Send tracking-related push notification
   */
  async sendTrackingNotification(userId, title, body, data = {}) {
    try {
      const user = await User.findById(userId);
      if (!user || !user.fcmToken) {
        return;
      }

      const message = {
        notification: {
          title,
          body,
        },
        data: {
          type: "tracking_update",
          ...data,
        },
        token: user.fcmToken,
      };

      await admin.messaging().send(message);
    } catch (error) {
      console.error("Error sending tracking notification:", error);
    }
  }

  /**
   * Send notifications based on tracking events
   */
  async handleTrackingEvent(tracking, eventType) {
    const notifications = {
      rider_assigned: {
        title: "Rider Assigned",
        body: `${tracking.riderName} will deliver your order`,
      },
      rider_at_restaurant: {
        title: "Rider at Restaurant",
        body: "Your rider is picking up your order",
      },
      order_picked_up: {
        title: "Order Picked Up",
        body: "Your order is on the way!",
      },
      rider_nearby: {
        title: "Rider Nearby",
        body: "Your rider will arrive in 2 minutes",
      },
      order_delivered: {
        title: "Order Delivered",
        body: "Enjoy your meal! 🎉",
      },
    };

    const notification = notifications[eventType];
    if (notification) {
      await this.sendTrackingNotification(
        tracking.customerId,
        notification.title,
        notification.body,
        { orderId: tracking.orderId.toString() }
      );
    }
  }
}

module.exports = new TrackingNotificationsService();
```

---

## Analytics & Insights

### Backend Implementation

**File: `backend/models/DeliveryAnalytics.js`**

```javascript
const mongoose = require("mongoose");

const deliveryAnalyticsSchema = new mongoose.Schema({
  orderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "Order",
    required: true,
  },
  riderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
  },

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

  createdAt: { type: Date, default: Date.now },
});

module.exports = mongoose.model("DeliveryAnalytics", deliveryAnalyticsSchema);
```

**Analytics Service:**

```javascript
const DeliveryAnalytics = require("../models/DeliveryAnalytics");
const OrderTracking = require("../models/OrderTracking");

class AnalyticsService {
  /**
   * Calculate delivery analytics when order is completed
   */
  async calculateDeliveryAnalytics(orderId) {
    try {
      const tracking = await OrderTracking.findOne({ orderId });
      if (!tracking) return;

      const pickupTime = tracking.locationHistory.find(
        (loc) => tracking.status === "picked_up"
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
        ((deliveryTime - initialETA) / initialETA) * 100
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
        averageUpdateInterval: totalDuration / tracking.locationHistory.length,
      });

      await analytics.save();
    } catch (error) {
      console.error("Error calculating analytics:", error);
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
          createdAt: { $gte: startDate },
        },
      },
      {
        $group: {
          _id: null,
          totalDeliveries: { $sum: 1 },
          avgDuration: { $avg: "$totalDuration" },
          avgDistance: { $avg: "$totalDistance" },
          avgEtaAccuracy: { $avg: "$etaAccuracy" },
          totalDistance: { $sum: "$totalDistance" },
        },
      },
    ]);

    return analytics[0] || {};
  }
}

module.exports = new AnalyticsService();
```

---

## Custom Markers & Animations

### Flutter Implementation

**File: `packages/grab_go_customer/lib/widgets/custom_map_markers.dart`**

```dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CustomMapMarkers {

  /// Create custom rider marker with avatar
  static Future<BitmapDescriptor> createRiderMarker({
    required String imageUrl,
    required String riderName,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint();

    // Draw circle background
    paint.color = Colors.blue;
    canvas.drawCircle(Offset(50, 50), 40, paint);

    // Draw white border
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4;
    canvas.drawCircle(Offset(50, 50), 40, paint);

    // TODO: Load and draw rider image

    // Draw pointer at bottom
    final path = Path();
    path.moveTo(50, 90);
    path.lineTo(40, 100);
    path.lineTo(60, 100);
    path.close();

    paint.style = PaintingStyle.fill;
    paint.color = Colors.blue;
    canvas.drawPath(path, paint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(100, 110);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  /// Animate marker movement
  static void animateMarker({
    required GoogleMapController mapController,
    required MarkerId markerId,
    required LatLng from,
    required LatLng to,
    required Duration duration,
  }) {
    // Implement smooth marker animation
    // This requires custom implementation with Tween animations
  }
}
```

---

## Battery Optimization

### Flutter Implementation

**File: `packages/grab_go_rider/lib/services/adaptive_location_tracking.dart`**

```dart
class AdaptiveLocationTrackingService {
  static const int MOVING_UPDATE_INTERVAL = 5; // 5 seconds when moving
  static const int STATIONARY_UPDATE_INTERVAL = 30; // 30 seconds when stationary
  static const double STATIONARY_SPEED_THRESHOLD = 1.0; // m/s

  bool _isStationary = false;
  int _currentInterval = MOVING_UPDATE_INTERVAL;

  void _sendLocationUpdate(Position position) {
    // Detect if rider is stationary
    final wasStationary = _isStationary;
    _isStationary = position.speed < STATIONARY_SPEED_THRESHOLD;

    // Adjust update interval
    if (_isStationary && !wasStationary) {
      // Just stopped - reduce frequency
      _currentInterval = STATIONARY_UPDATE_INTERVAL;
      _restartTimer();
    } else if (!_isStationary && wasStationary) {
      // Just started moving - increase frequency
      _currentInterval = MOVING_UPDATE_INTERVAL;
      _restartTimer();
    }

    // Send update
    _sendToBackend(position);
  }

  void _restartTimer() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(
      Duration(seconds: _currentInterval),
      (_) => _getCurrentLocationAndSend(),
    );
  }
}
```

---

## Rider Performance Tracking

### Dashboard Metrics

**File: `backend/routes/rider-analytics.routes.js`**

```javascript
router.get("/performance/:riderId", auth, async (req, res) => {
  try {
    const { riderId } = req.params;
    const { days = 30 } = req.query;

    const performance = await analyticsService.getRiderPerformance(
      riderId,
      days
    );

    res.json({
      success: true,
      data: {
        totalDeliveries: performance.totalDeliveries || 0,
        averageDeliveryTime: Math.round(performance.avgDuration / 60), // minutes
        averageDistance: Math.round(performance.avgDistance / 1000), // km
        etaAccuracy: Math.round(performance.avgEtaAccuracy),
        totalDistanceCovered: Math.round(performance.totalDistance / 1000),
        rating: 4.5, // From separate ratings system
      },
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});
```

---

## Summary

These advanced features will take your tracking system to the next level:

✅ **Geofencing** - Automatic status updates  
✅ **Offline Support** - Works without internet  
✅ **Route Optimization** - For multiple deliveries  
✅ **Push Notifications** - Real-time alerts  
✅ **Analytics** - Performance insights  
✅ **Custom Markers** - Beautiful map UI  
✅ **Battery Optimization** - Adaptive tracking  
✅ **Performance Tracking** - Rider metrics

**Implementation Priority:**

1. Geofencing (High Impact, Medium Effort)
2. Push Notifications (High Impact, Low Effort)
3. Offline Support (Medium Impact, Medium Effort)
4. Analytics (Medium Impact, High Effort)
5. Route Optimization (Low Impact for single delivery, High for multi-delivery)

---

**Last Updated:** January 2026
