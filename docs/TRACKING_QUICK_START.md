# Live Order Tracking - Quick Start Guide

> Get started with implementing live order tracking in 30 minutes

## 🎯 Goal

By the end of this guide, you'll have:
- ✅ Backend tracking API working
- ✅ Rider app sending location updates
- ✅ Customer app displaying live location on map
- ✅ Real-time updates via Socket.IO

---

## ⚡ Step 1: Backend Setup (10 minutes)

### 1.1 Install Dependencies

```bash
cd backend
npm install geolib @googlemaps/google-maps-services-js
```

### 1.2 Create the Model

Create `backend/models/OrderTracking.js`:

```javascript
const mongoose = require('mongoose');

const orderTrackingSchema = new mongoose.Schema({
  orderId: { type: mongoose.Schema.Types.ObjectId, ref: 'Order', required: true, unique: true },
  riderId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  customerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  
  currentLocation: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], required: true } // [longitude, latitude]
  },
  
  destination: {
    type: { type: String, enum: ['Point'], default: 'Point' },
    coordinates: { type: [Number], required: true }
  },
  
  status: { 
    type: String, 
    enum: ['preparing', 'picked_up', 'in_transit', 'nearby', 'delivered'],
    default: 'preparing' 
  },
  
  distanceRemaining: Number,
  estimatedArrival: Date,
  lastUpdated: { type: Date, default: Date.now }
}, { timestamps: true });

orderTrackingSchema.index({ currentLocation: '2dsphere' });

module.exports = mongoose.model('OrderTracking', orderTrackingSchema);
```

### 1.3 Create Simple Tracking Routes

Create `backend/routes/tracking.js`:

```javascript
const express = require('express');
const router = express.Router();
const OrderTracking = require('../models/OrderTracking');
const geolib = require('geolib');
const auth = require('../middleware/auth');

// Initialize tracking
router.post('/initialize', auth, async (req, res) => {
  try {
    const { orderId, riderId, customerId, pickupLocation, destination } = req.body;
    
    const tracking = new OrderTracking({
      orderId,
      riderId,
      customerId,
      currentLocation: {
        coordinates: [pickupLocation.longitude, pickupLocation.latitude]
      },
      destination: {
        coordinates: [destination.longitude, destination.latitude]
      }
    });
    
    await tracking.save();
    res.status(201).json({ success: true, data: tracking });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Update location
router.post('/location', auth, async (req, res) => {
  try {
    const { orderId, latitude, longitude } = req.body;
    
    const tracking = await OrderTracking.findOne({ 
      orderId, 
      status: { $nin: ['delivered', 'cancelled'] } 
    });
    
    if (!tracking) {
      return res.status(404).json({ success: false, message: 'Tracking not found' });
    }
    
    // Update location
    tracking.currentLocation.coordinates = [longitude, latitude];
    
    // Calculate distance
    const distance = geolib.getDistance(
      { latitude, longitude },
      { 
        latitude: tracking.destination.coordinates[1], 
        longitude: tracking.destination.coordinates[0] 
      }
    );
    
    tracking.distanceRemaining = distance;
    
    // Simple ETA (assume 30 km/h average speed)
    const speedMps = (30 * 1000) / 3600; // meters per second
    const etaSeconds = Math.round(distance / speedMps);
    tracking.estimatedArrival = new Date(Date.now() + etaSeconds * 1000);
    
    // Update status based on distance
    if (distance < 100) tracking.status = 'nearby';
    else if (tracking.status === 'preparing') tracking.status = 'in_transit';
    
    tracking.lastUpdated = new Date();
    await tracking.save();
    
    // Emit socket event
    const io = req.app.get('io');
    if (io) {
      io.to(`customer_${tracking.customerId}`).emit('location_update', {
        orderId,
        location: { latitude, longitude },
        distance,
        eta: etaSeconds,
        status: tracking.status
      });
    }
    
    res.json({ success: true, data: tracking });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

// Get tracking info
router.get('/:orderId', auth, async (req, res) => {
  try {
    const tracking = await OrderTracking.findOne({ orderId: req.params.orderId })
      .populate('riderId', 'name phone profileImage');
    
    if (!tracking) {
      return res.status(404).json({ success: false, message: 'Tracking not found' });
    }
    
    res.json({ success: true, data: tracking });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
```

### 1.4 Register Routes

In `backend/server.js`, add:

```javascript
const trackingRoutes = require('./routes/tracking');
app.use('/api/tracking', trackingRoutes);
```

### 1.5 Test Backend

```bash
npm run dev
```

Test with curl:
```bash
# Initialize tracking
curl -X POST http://localhost:5000/api/tracking/initialize \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "orderId": "ORDER_ID",
    "riderId": "RIDER_ID",
    "customerId": "CUSTOMER_ID",
    "pickupLocation": {"latitude": 5.6037, "longitude": -0.1870},
    "destination": {"latitude": 5.6137, "longitude": -0.1970}
  }'
```

---

## ⚡ Step 2: Rider App Integration (10 minutes)

### 2.1 Add Dependencies

In `packages/grab_go_rider/pubspec.yaml`:

```yaml
dependencies:
  geolocator: ^14.0.2
```

Run:
```bash
cd packages/grab_go_rider
flutter pub get
```

### 2.2 Add Permissions

**Android** - `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**iOS** - `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to track deliveries</string>
```

### 2.3 Create Simple Location Service

Create `packages/grab_go_rider/lib/services/simple_location_service.dart`:

```dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

class SimpleLocationService {
  Timer? _timer;
  final Dio _dio = Dio();
  String? _orderId;
  String? _token;
  
  Future<void> startTracking(String orderId, String token) async {
    _orderId = orderId;
    _token = token;
    
    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    // Send updates every 10 seconds
    _timer = Timer.periodic(Duration(seconds: 10), (_) async {
      try {
        Position position = await Geolocator.getCurrentPosition();
        await _sendLocation(position.latitude, position.longitude);
      } catch (e) {
        print('Error getting location: $e');
      }
    });
  }
  
  Future<void> _sendLocation(double lat, double lng) async {
    try {
      await _dio.post(
        'http://YOUR_SERVER_IP:5000/api/tracking/location',
        data: {
          'orderId': _orderId,
          'latitude': lat,
          'longitude': lng,
        },
        options: Options(
          headers: {'Authorization': 'Bearer $_token'},
        ),
      );
      print('Location sent: $lat, $lng');
    } catch (e) {
      print('Error sending location: $e');
    }
  }
  
  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _orderId = null;
  }
}
```

### 2.4 Use in Delivery Screen

In your delivery screen:

```dart
import 'package:grab_go_rider/services/simple_location_service.dart';

class DeliveryScreen extends StatefulWidget {
  final String orderId;
  const DeliveryScreen({required this.orderId});
  
  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final _locationService = SimpleLocationService();
  bool _isTracking = false;
  
  void _startTracking() async {
    final token = 'YOUR_AUTH_TOKEN'; // Get from secure storage
    await _locationService.startTracking(widget.orderId, token);
    setState(() => _isTracking = true);
  }
  
  void _stopTracking() {
    _locationService.stopTracking();
    setState(() => _isTracking = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Delivery')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_isTracking ? 'Tracking Active' : 'Not Tracking'),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isTracking ? _stopTracking : _startTracking,
              child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }
}
```

---

## ⚡ Step 3: Customer App Integration (10 minutes)

### 3.1 Add Dependencies

In `packages/grab_go_customer/pubspec.yaml`:

```yaml
dependencies:
  google_maps_flutter: ^2.5.0
```

Run:
```bash
cd packages/grab_go_customer
flutter pub get
```

### 3.2 Add Google Maps API Key

Get your API key from [Google Cloud Console](https://console.cloud.google.com/)

**Android** - `android/app/src/main/AndroidManifest.xml`:
```xml
<application>
  <meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ANDROID_API_KEY"/>
</application>
```

**iOS** - `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_IOS_API_KEY")
```

### 3.3 Create Simple Tracking Screen

Create `packages/grab_go_customer/lib/features/orders/view/simple_tracking_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dio/dio.dart';
import 'dart:async';

class SimpleTrackingPage extends StatefulWidget {
  final String orderId;
  const SimpleTrackingPage({required this.orderId});
  
  @override
  State<SimpleTrackingPage> createState() => _SimpleTrackingPageState();
}

class _SimpleTrackingPageState extends State<SimpleTrackingPage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Timer? _refreshTimer;
  final Dio _dio = Dio();
  
  LatLng? _riderLocation;
  LatLng? _destination;
  String _status = 'Loading...';
  int _etaMinutes = 0;
  
  @override
  void initState() {
    super.initState();
    _fetchTrackingData();
    
    // Refresh every 5 seconds
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (_) {
      _fetchTrackingData();
    });
  }
  
  Future<void> _fetchTrackingData() async {
    try {
      final response = await _dio.get(
        'http://YOUR_SERVER_IP:5000/api/tracking/${widget.orderId}',
        options: Options(
          headers: {'Authorization': 'Bearer YOUR_TOKEN'},
        ),
      );
      
      final data = response.data['data'];
      final currentLoc = data['currentLocation']['coordinates'];
      final destLoc = data['destination']['coordinates'];
      
      setState(() {
        _riderLocation = LatLng(currentLoc[1], currentLoc[0]);
        _destination = LatLng(destLoc[1], destLoc[0]);
        _status = data['status'];
        
        if (data['estimatedArrival'] != null) {
          final eta = DateTime.parse(data['estimatedArrival']);
          _etaMinutes = eta.difference(DateTime.now()).inMinutes;
        }
        
        _markers = {
          Marker(
            markerId: MarkerId('rider'),
            position: _riderLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(title: 'Rider'),
          ),
          Marker(
            markerId: MarkerId('destination'),
            position: _destination!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: 'Your Location'),
          ),
        };
      });
      
      _animateCamera();
    } catch (e) {
      print('Error fetching tracking: $e');
    }
  }
  
  void _animateCamera() {
    if (_mapController == null || _riderLocation == null || _destination == null) return;
    
    final bounds = LatLngBounds(
      southwest: LatLng(
        _riderLocation!.latitude < _destination!.latitude ? _riderLocation!.latitude : _destination!.latitude,
        _riderLocation!.longitude < _destination!.longitude ? _riderLocation!.longitude : _destination!.longitude,
      ),
      northeast: LatLng(
        _riderLocation!.latitude > _destination!.latitude ? _riderLocation!.latitude : _destination!.latitude,
        _riderLocation!.longitude > _destination!.longitude ? _riderLocation!.longitude : _destination!.longitude,
      ),
    );
    
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Track Your Order'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Map
          _riderLocation == null
              ? Center(child: CircularProgressIndicator())
              : GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _riderLocation!,
                    zoom: 14,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _animateCamera();
                  },
                ),
          
          // Info Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(20),
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
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem(Icons.access_time, 'ETA', '$_etaMinutes min'),
                      _buildInfoItem(Icons.info, 'Status', _formatStatus(_status)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 30),
        SizedBox(height: 5),
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
  
  String _formatStatus(String status) {
    switch (status) {
      case 'preparing': return 'Preparing';
      case 'picked_up': return 'Picked Up';
      case 'in_transit': return 'On the Way';
      case 'nearby': return 'Arriving Soon!';
      default: return status;
    }
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
```

---

## 🎉 Test the Complete Flow

### 1. Start Backend
```bash
cd backend
npm run dev
```

### 2. Run Rider App
```bash
cd packages/grab_go_rider
flutter run
```

- Create/accept an order
- Click "Start Tracking"
- Walk around with your phone

### 3. Run Customer App
```bash
cd packages/grab_go_customer
flutter run
```

- Open the tracking screen for the order
- You should see the rider's location updating every 5-10 seconds!

---

## 🚀 Next Steps

Now that you have the basic tracking working:

1. **Add Socket.IO** for real-time updates (instead of polling)
2. **Implement Route Polyline** to show the path
3. **Add Google Maps Directions API** for accurate ETA
4. **Implement Background Tracking** for rider app
5. **Add Geofencing** for automatic status updates
6. **Optimize Battery Usage** with adaptive update frequency

Refer to the full documentation:
- [LIVE_ORDER_TRACKING.md](./LIVE_ORDER_TRACKING.md) - Complete implementation
- [TRACKING_IMPLEMENTATION_CHECKLIST.md](./TRACKING_IMPLEMENTATION_CHECKLIST.md) - Step-by-step checklist

---

## 🐛 Troubleshooting

### Map not showing?
- Check API key is correct
- Verify billing is enabled in Google Cloud Console
- Check AndroidManifest.xml / Info.plist configuration

### Location not updating?
- Check permissions are granted
- Verify backend URL is correct (use your computer's IP, not localhost)
- Check authentication token is valid

### High battery drain?
- Increase update interval to 15-20 seconds
- Use `distanceFilter` in location settings
- Stop tracking when app is backgrounded

---

## 💡 Pro Tips

1. **Use your computer's IP address** instead of `localhost` when testing on real devices
2. **Test on real devices**, not just emulators (GPS is more accurate)
3. **Start simple** - get basic tracking working before adding advanced features
4. **Monitor battery usage** from day one
5. **Cache API responses** to reduce costs

---

**Congratulations!** 🎊 You now have live order tracking working in your food delivery app!

*Estimated setup time: 30-45 minutes*
