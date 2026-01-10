# Live Order Tracking Implementation Guide

> Complete guide to implementing production-ready live order tracking for GrabGo food delivery platform

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Backend Implementation](#backend-implementation)
4. [Mobile App Integration](#mobile-app-integration)
5. [Real-time Updates](#real-time-updates)
6. [Map Integration](#map-integration)
7. [Testing & Optimization](#testing--optimization)
8. [Production Deployment](#production-deployment)

---

## Overview

### What is Live Order Tracking?

Live order tracking allows customers to:
- See real-time location of their delivery rider on a map
- Get accurate ETA (Estimated Time of Arrival)
- Receive status updates as the order progresses
- View the route the rider is taking

### Key Components

1. **GPS Location Tracking** - Rider's device sends location updates
2. **Real-time Communication** - Socket.IO for instant updates
3. **Map Visualization** - Google Maps/Mapbox for displaying location
4. **ETA Calculation** - Distance Matrix API for time estimates
5. **Status Management** - Order state machine
6. **Background Services** - Location tracking even when app is backgrounded

---

## Architecture

### System Flow

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Rider     │         │   Backend   │         │  Customer   │
│   App       │         │   Server    │         │    App      │
└──────┬──────┘         └──────┬──────┘         └──────┬──────┘
       │                       │                       │
       │ 1. Send GPS Location  │                       │
       │──────────────────────>│                       │
       │   (every 5-10 sec)    │                       │
       │                       │                       │
       │                       │ 2. Broadcast Location │
       │                       │──────────────────────>│
       │                       │   (Socket.IO)         │
       │                       │                       │
       │                       │ 3. Request ETA Update │
       │                       │<──────────────────────│
       │                       │                       │
       │                       │ 4. Calculate & Send   │
       │                       │──────────────────────>│
       │                       │                       │
```

### Data Models

#### Order Location Schema (MongoDB)

```javascript
{
  orderId: ObjectId,
  riderId: ObjectId,
  customerId: ObjectId,
  
  // Current rider location
  currentLocation: {
    type: "Point",
    coordinates: [longitude, latitude]
  },
  
  // Destination (customer address)
  destination: {
    type: "Point",
    coordinates: [longitude, latitude],
    address: String
  },
  
  // Restaurant location (pickup point)
  pickupLocation: {
    type: "Point",
    coordinates: [longitude, latitude],
    address: String
  },
  
  // Tracking metadata
  status: String, // 'preparing', 'picked_up', 'in_transit', 'nearby', 'delivered'
  estimatedArrival: Date,
  distanceRemaining: Number, // in meters
  route: {
    polyline: String, // Encoded polyline
    duration: Number, // in seconds
    distance: Number  // in meters
  },
  
  // Location history for analytics
  locationHistory: [{
    coordinates: [Number],
    timestamp: Date,
    speed: Number,
    accuracy: Number
  }],
  
  lastUpdated: Date,
  createdAt: Date
}
```

---

## Backend Implementation

### 1. Setup Dependencies

```bash
cd backend
npm install geolib node-geocoder @googlemaps/google-maps-services-js
```

### 2. Create Order Tracking Model

**File: `backend/models/OrderTracking.js`**

```javascript
const mongoose = require('mongoose');

const locationSchema = new mongoose.Schema({
  type: {
    type: String,
    enum: ['Point'],
    default: 'Point'
  },
  coordinates: {
    type: [Number], // [longitude, latitude]
    required: true
  }
});

const orderTrackingSchema = new mongoose.Schema({
  orderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Order',
    required: true,
    unique: true
  },
  riderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  customerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  
  currentLocation: {
    type: locationSchema,
    index: '2dsphere'
  },
  
  destination: {
    type: locationSchema,
    required: true
  },
  
  pickupLocation: {
    type: locationSchema,
    required: true
  },
  
  status: {
    type: String,
    enum: ['preparing', 'picked_up', 'in_transit', 'nearby', 'delivered', 'cancelled'],
    default: 'preparing'
  },
  
  estimatedArrival: Date,
  distanceRemaining: Number,
  
  route: {
    polyline: String,
    duration: Number,
    distance: Number
  },
  
  locationHistory: [{
    coordinates: [Number],
    timestamp: { type: Date, default: Date.now },
    speed: Number,
    accuracy: Number
  }],
  
  lastUpdated: { type: Date, default: Date.now }
}, {
  timestamps: true
});

// Index for geospatial queries
orderTrackingSchema.index({ currentLocation: '2dsphere' });
orderTrackingSchema.index({ orderId: 1, status: 1 });

module.exports = mongoose.model('OrderTracking', orderTrackingSchema);
```

### 3. Create Tracking Service

**File: `backend/services/tracking.service.js`**

```javascript
const { Client } = require('@googlemaps/google-maps-services-js');
const geolib = require('geolib');
const OrderTracking = require('../models/OrderTracking');
const socketService = require('./socket.service');

const googleMapsClient = new Client({});
const GOOGLE_MAPS_API_KEY = process.env.GOOGLE_MAPS_API_KEY;

class TrackingService {
  
  /**
   * Initialize tracking for a new order
   */
  async initializeTracking(orderId, riderId, customerId, pickupLocation, destination) {
    try {
      const tracking = new OrderTracking({
        orderId,
        riderId,
        customerId,
        pickupLocation: {
          type: 'Point',
          coordinates: [pickupLocation.longitude, pickupLocation.latitude]
        },
        destination: {
          type: 'Point',
          coordinates: [destination.longitude, destination.latitude]
        },
        status: 'preparing'
      });
      
      await tracking.save();
      return tracking;
    } catch (error) {
      console.error('Error initializing tracking:', error);
      throw error;
    }
  }
  
  /**
   * Update rider's current location
   */
  async updateRiderLocation(orderId, latitude, longitude, speed = 0, accuracy = 0) {
    try {
      const tracking = await OrderTracking.findOne({ orderId, status: { $nin: ['delivered', 'cancelled'] } });
      
      if (!tracking) {
        throw new Error('Active tracking not found for this order');
      }
      
      // Update current location
      tracking.currentLocation = {
        type: 'Point',
        coordinates: [longitude, latitude]
      };
      
      // Add to location history
      tracking.locationHistory.push({
        coordinates: [longitude, latitude],
        timestamp: new Date(),
        speed,
        accuracy
      });
      
      // Keep only last 100 locations to prevent document bloat
      if (tracking.locationHistory.length > 100) {
        tracking.locationHistory = tracking.locationHistory.slice(-100);
      }
      
      // Calculate distance to destination
      const distance = geolib.getDistance(
        { latitude, longitude },
        { 
          latitude: tracking.destination.coordinates[1], 
          longitude: tracking.destination.coordinates[0] 
        }
      );
      
      tracking.distanceRemaining = distance;
      
      // Update status based on distance
      if (distance < 100 && tracking.status === 'in_transit') {
        tracking.status = 'nearby';
      }
      
      // Calculate ETA
      const eta = await this.calculateETA(latitude, longitude, tracking.destination.coordinates);
      tracking.estimatedArrival = eta.arrivalTime;
      tracking.route = eta.route;
      
      tracking.lastUpdated = new Date();
      await tracking.save();
      
      // Broadcast update to customer via Socket.IO
      socketService.emitToUser(tracking.customerId.toString(), 'location_update', {
        orderId: orderId.toString(),
        location: { latitude, longitude },
        distance: distance,
        eta: eta.duration,
        status: tracking.status,
        route: tracking.route
      });
      
      return tracking;
    } catch (error) {
      console.error('Error updating rider location:', error);
      throw error;
    }
  }
  
  /**
   * Calculate ETA using Google Maps Distance Matrix API
   */
  async calculateETA(fromLat, fromLng, toCoordinates) {
    try {
      const response = await googleMapsClient.distancematrix({
        params: {
          origins: [`${fromLat},${fromLng}`],
          destinations: [`${toCoordinates[1]},${toCoordinates[0]}`],
          mode: 'driving',
          departure_time: 'now',
          traffic_model: 'best_guess',
          key: GOOGLE_MAPS_API_KEY
        }
      });
      
      const result = response.data.rows[0].elements[0];
      
      if (result.status === 'OK') {
        const durationInSeconds = result.duration_in_traffic 
          ? result.duration_in_traffic.value 
          : result.duration.value;
        
        // Get route polyline
        const directions = await this.getDirections(fromLat, fromLng, toCoordinates);
        
        return {
          duration: durationInSeconds,
          distance: result.distance.value,
          arrivalTime: new Date(Date.now() + durationInSeconds * 1000),
          route: directions
        };
      }
      
      // Fallback to straight-line calculation
      return this.calculateStraightLineETA(fromLat, fromLng, toCoordinates);
    } catch (error) {
      console.error('Error calculating ETA:', error);
      return this.calculateStraightLineETA(fromLat, fromLng, toCoordinates);
    }
  }
  
  /**
   * Get directions polyline for route visualization
   */
  async getDirections(fromLat, fromLng, toCoordinates) {
    try {
      const response = await googleMapsClient.directions({
        params: {
          origin: `${fromLat},${fromLng}`,
          destination: `${toCoordinates[1]},${toCoordinates[0]}`,
          mode: 'driving',
          key: GOOGLE_MAPS_API_KEY
        }
      });
      
      if (response.data.routes.length > 0) {
        const route = response.data.routes[0];
        return {
          polyline: route.overview_polyline.points,
          duration: route.legs[0].duration.value,
          distance: route.legs[0].distance.value
        };
      }
      
      return null;
    } catch (error) {
      console.error('Error getting directions:', error);
      return null;
    }
  }
  
  /**
   * Fallback ETA calculation (straight line)
   */
  calculateStraightLineETA(fromLat, fromLng, toCoordinates) {
    const distance = geolib.getDistance(
      { latitude: fromLat, longitude: fromLng },
      { latitude: toCoordinates[1], longitude: toCoordinates[0] }
    );
    
    // Assume average speed of 30 km/h in city
    const averageSpeed = 30 * 1000 / 3600; // m/s
    const duration = Math.round(distance / averageSpeed);
    
    return {
      duration,
      distance,
      arrivalTime: new Date(Date.now() + duration * 1000),
      route: null
    };
  }
  
  /**
   * Update order status
   */
  async updateOrderStatus(orderId, status) {
    try {
      const tracking = await OrderTracking.findOne({ orderId });
      
      if (!tracking) {
        throw new Error('Tracking not found');
      }
      
      tracking.status = status;
      tracking.lastUpdated = new Date();
      await tracking.save();
      
      // Notify customer
      socketService.emitToUser(tracking.customerId.toString(), 'order_status_update', {
        orderId: orderId.toString(),
        status
      });
      
      return tracking;
    } catch (error) {
      console.error('Error updating order status:', error);
      throw error;
    }
  }
  
  /**
   * Get current tracking info
   */
  async getTrackingInfo(orderId) {
    try {
      const tracking = await OrderTracking.findOne({ orderId })
        .populate('riderId', 'name phone profileImage')
        .populate('customerId', 'name phone');
      
      if (!tracking) {
        throw new Error('Tracking not found');
      }
      
      return tracking;
    } catch (error) {
      console.error('Error getting tracking info:', error);
      throw error;
    }
  }
}

module.exports = new TrackingService();
```

### 4. Create Tracking Routes

**File: `backend/routes/tracking.routes.js`**

```javascript
const express = require('express');
const router = express.Router();
const trackingService = require('../services/tracking.service');
const auth = require('../middleware/auth');

// Initialize tracking (called when rider accepts order)
router.post('/initialize', auth, async (req, res) => {
  try {
    const { orderId, riderId, customerId, pickupLocation, destination } = req.body;
    
    const tracking = await trackingService.initializeTracking(
      orderId,
      riderId,
      customerId,
      pickupLocation,
      destination
    );
    
    res.status(201).json({
      success: true,
      data: tracking
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Update rider location (called by rider app every 5-10 seconds)
router.post('/location', auth, async (req, res) => {
  try {
    const { orderId, latitude, longitude, speed, accuracy } = req.body;
    
    const tracking = await trackingService.updateRiderLocation(
      orderId,
      latitude,
      longitude,
      speed,
      accuracy
    );
    
    res.json({
      success: true,
      data: {
        distanceRemaining: tracking.distanceRemaining,
        estimatedArrival: tracking.estimatedArrival,
        status: tracking.status
      }
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Update order status
router.patch('/status', auth, async (req, res) => {
  try {
    const { orderId, status } = req.body;
    
    const tracking = await trackingService.updateOrderStatus(orderId, status);
    
    res.json({
      success: true,
      data: tracking
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: error.message
    });
  }
});

// Get tracking info (called by customer app)
router.get('/:orderId', auth, async (req, res) => {
  try {
    const tracking = await trackingService.getTrackingInfo(req.params.orderId);
    
    res.json({
      success: true,
      data: tracking
    });
  } catch (error) {
    res.status(404).json({
      success: false,
      message: error.message
    });
  }
});

module.exports = router;
```

---

## Mobile App Integration

### 1. Rider App - Location Tracking Service

**File: `packages/grab_go_rider/lib/services/location_tracking_service.dart`**

```dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:grab_go_shared/grab_go_shared.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();
  
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _locationUpdateTimer;
  String? _activeOrderId;
  
  // Configuration
  static const int UPDATE_INTERVAL_SECONDS = 10;
  static const int LOCATION_ACCURACY_METERS = 10;
  
  /// Start tracking location for an order
  Future<void> startTracking(String orderId) async {
    if (_activeOrderId != null) {
      await stopTracking();
    }
    
    _activeOrderId = orderId;
    
    // Check permissions
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      throw Exception('Location permission not granted');
    }
    
    // Start listening to location updates
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: LOCATION_ACCURACY_METERS,
    );
    
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _sendLocationUpdate(position);
    });
    
    // Fallback timer-based updates
    _locationUpdateTimer = Timer.periodic(
      Duration(seconds: UPDATE_INTERVAL_SECONDS),
      (_) async {
        try {
          final position = await Geolocator.getCurrentPosition();
          _sendLocationUpdate(position);
        } catch (e) {
          print('Error getting position: $e');
        }
      },
    );
  }
  
  /// Stop tracking
  Future<void> stopTracking() async {
    await _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    
    _activeOrderId = null;
  }
  
  /// Send location update to backend
  Future<void> _sendLocationUpdate(Position position) async {
    if (_activeOrderId == null) return;
    
    try {
      final apiService = getIt<ApiService>();
      
      await apiService.post('/tracking/location', data: {
        'orderId': _activeOrderId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed,
        'accuracy': position.accuracy,
      });
    } catch (e) {
      print('Error sending location update: $e');
    }
  }
  
  /// Check and request location permission
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    
    return true;
  }
}
```

### 2. Customer App - Live Tracking Screen

**File: `packages/grab_go_customer/lib/features/orders/view/live_tracking_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../providers/order_tracking_provider.dart';

class LiveTrackingPage extends StatefulWidget {
  final String orderId;
  
  const LiveTrackingPage({Key? key, required this.orderId}) : super(key: key);
  
  @override
  State<LiveTrackingPage> createState() => _LiveTrackingPageState();
}

class _LiveTrackingPageState extends State<LiveTrackingPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }
  
  Future<void> _initializeTracking() async {
    final provider = context.read<OrderTrackingProvider>();
    await provider.startTracking(widget.orderId);
    
    // Listen to location updates
    provider.addListener(_updateMap);
  }
  
  void _updateMap() {
    final provider = context.read<OrderTrackingProvider>();
    final tracking = provider.trackingData;
    
    if (tracking == null) return;
    
    setState(() {
      _markers = {
        // Rider marker
        Marker(
          markerId: MarkerId('rider'),
          position: LatLng(
            tracking.currentLocation.latitude,
            tracking.currentLocation.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: 'Rider'),
        ),
        
        // Destination marker
        Marker(
          markerId: MarkerId('destination'),
          position: LatLng(
            tracking.destination.latitude,
            tracking.destination.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Your Location'),
        ),
      };
      
      // Draw route polyline
      if (tracking.route != null && tracking.route!.polyline.isNotEmpty) {
        _drawRoute(tracking.route!.polyline);
      }
    });
    
    // Animate camera to show both markers
    _animateToRoute();
  }
  
  void _drawRoute(String encodedPolyline) {
    final points = PolylinePoints().decodePolyline(encodedPolyline);
    
    setState(() {
      _polylines = {
        Polyline(
          polylineId: PolylineId('route'),
          points: points.map((point) => LatLng(point.latitude, point.longitude)).toList(),
          color: Colors.blue,
          width: 5,
        ),
      };
    });
  }
  
  void _animateToRoute() async {
    if (_mapController == null || _markers.length < 2) return;
    
    final bounds = _calculateBounds();
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }
  
  LatLngBounds _calculateBounds() {
    final positions = _markers.map((m) => m.position).toList();
    
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;
    
    for (var pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Your Order'),
      ),
      body: Consumer<OrderTrackingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }
          
          final tracking = provider.trackingData;
          
          return Stack(
            children: [
              // Google Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: tracking != null
                      ? LatLng(tracking.currentLocation.latitude, tracking.currentLocation.longitude)
                      : LatLng(0, 0),
                  zoom: 15,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              ),
              
              // Info Card
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildInfoCard(tracking),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildInfoCard(OrderTrackingData? tracking) {
    if (tracking == null) return SizedBox.shrink();
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(tracking.riderImage ?? ''),
                radius: 30,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tracking.riderName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getStatusText(tracking.status),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.phone),
                onPressed: () {
                  // Call rider
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoItem(
                Icons.access_time,
                'ETA',
                _formatETA(tracking.estimatedArrival),
              ),
              _buildInfoItem(
                Icons.location_on,
                'Distance',
                _formatDistance(tracking.distanceRemaining),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'preparing':
        return 'Preparing your order';
      case 'picked_up':
        return 'Order picked up';
      case 'in_transit':
        return 'On the way';
      case 'nearby':
        return 'Arriving soon!';
      default:
        return status;
    }
  }
  
  String _formatETA(DateTime? eta) {
    if (eta == null) return '--';
    final duration = eta.difference(DateTime.now());
    return '${duration.inMinutes} min';
  }
  
  String _formatDistance(double? distance) {
    if (distance == null) return '--';
    if (distance < 1000) {
      return '${distance.toInt()} m';
    }
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }
  
  @override
  void dispose() {
    final provider = context.read<OrderTrackingProvider>();
    provider.removeListener(_updateMap);
    provider.stopTracking();
    _mapController?.dispose();
    super.dispose();
  }
}
```

---

## Real-time Updates with Socket.IO

### Backend Socket Events

**File: `backend/services/socket.service.js`** (Add these methods)

```javascript
// Emit location update to specific user
emitToUser(userId, event, data) {
  const socketId = this.userSockets.get(userId);
  if (socketId && this.io) {
    this.io.to(socketId).emit(event, data);
  }
}

// Join order tracking room
joinOrderRoom(socket, orderId) {
  socket.join(`order_${orderId}`);
}

// Leave order tracking room
leaveOrderRoom(socket, orderId) {
  socket.leave(`order_${orderId}`);
}

// Broadcast to order room
emitToOrder(orderId, event, data) {
  if (this.io) {
    this.io.to(`order_${orderId}`).emit(event, data);
  }
}
```

### Flutter Socket Integration

**File: `packages/grab_go_customer/lib/providers/order_tracking_provider.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/grab_go_shared.dart';

class OrderTrackingProvider extends ChangeNotifier {
  final SocketService _socketService = getIt<SocketService>();
  final ApiService _apiService = getIt<ApiService>();
  
  OrderTrackingData? _trackingData;
  bool _isLoading = false;
  
  OrderTrackingData? get trackingData => _trackingData;
  bool get isLoading => _isLoading;
  
  Future<void> startTracking(String orderId) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Fetch initial tracking data
      final response = await _apiService.get('/tracking/$orderId');
      _trackingData = OrderTrackingData.fromJson(response.data);
      
      // Subscribe to real-time updates
      _socketService.socket?.emit('join_order_room', orderId);
      
      _socketService.socket?.on('location_update', (data) {
        _handleLocationUpdate(data);
      });
      
      _socketService.socket?.on('order_status_update', (data) {
        _handleStatusUpdate(data);
      });
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  void _handleLocationUpdate(dynamic data) {
    if (_trackingData == null) return;
    
    _trackingData = _trackingData!.copyWith(
      currentLocation: LocationData(
        latitude: data['location']['latitude'],
        longitude: data['location']['longitude'],
      ),
      distanceRemaining: data['distance']?.toDouble(),
      estimatedArrival: data['eta'] != null 
          ? DateTime.now().add(Duration(seconds: data['eta']))
          : null,
      route: data['route'] != null ? RouteData.fromJson(data['route']) : null,
      status: data['status'],
    );
    
    notifyListeners();
  }
  
  void _handleStatusUpdate(dynamic data) {
    if (_trackingData == null) return;
    
    _trackingData = _trackingData!.copyWith(
      status: data['status'],
    );
    
    notifyListeners();
  }
  
  void stopTracking() {
    if (_trackingData != null) {
      _socketService.socket?.emit('leave_order_room', _trackingData!.orderId);
    }
    
    _socketService.socket?.off('location_update');
    _socketService.socket?.off('order_status_update');
    
    _trackingData = null;
    notifyListeners();
  }
}
```

---

## Testing & Optimization

### Performance Optimization

1. **Reduce Update Frequency**
   - Send updates every 10 seconds instead of every second
   - Only send updates when location changes significantly (> 10 meters)

2. **Batch Updates**
   - Queue location updates and send in batches if network is slow

3. **Optimize Database Queries**
   - Use geospatial indexes for location queries
   - Limit location history to prevent document bloat

4. **Cache ETA Calculations**
   - Cache Google Maps API responses for 30-60 seconds
   - Use fallback calculations when API quota is exceeded

### Testing Checklist

- [ ] Test with poor GPS signal
- [ ] Test with poor network connectivity
- [ ] Test battery consumption over 1 hour
- [ ] Test with app in background
- [ ] Test with multiple simultaneous orders
- [ ] Test ETA accuracy
- [ ] Test map rendering performance
- [ ] Test Socket.IO reconnection

---

## Production Deployment

### Environment Variables

```env
GOOGLE_MAPS_API_KEY=your_api_key_here
LOCATION_UPDATE_INTERVAL=10
MAX_LOCATION_HISTORY=100
ETA_CACHE_DURATION=60
```

### Monitoring

1. **Track Key Metrics**
   - Location update frequency
   - ETA accuracy
   - Socket connection stability
   - API response times

2. **Error Handling**
   - Log failed location updates
   - Alert on high error rates
   - Fallback to manual status updates

3. **Cost Management**
   - Monitor Google Maps API usage
   - Implement request caching
   - Set daily quotas

---

## Next Steps

1. Implement background location tracking for iOS/Android
2. Add offline support with location queue
3. Implement route optimization for multiple deliveries
4. Add predictive ETA using machine learning
5. Implement geofencing for automatic status updates

---

**Last Updated:** January 2026
