# Live Tracking Troubleshooting Guide

> Common issues and solutions for live order tracking implementation

## 📋 Table of Contents

1. [GPS & Location Issues](#gps--location-issues)
2. [Map Display Problems](#map-display-problems)
3. [Real-time Update Issues](#real-time-update-issues)
4. [Performance Problems](#performance-problems)
5. [API & Backend Errors](#api--backend-errors)
6. [Platform-Specific Issues](#platform-specific-issues)

---

## GPS & Location Issues

### Issue: Location not updating

**Symptoms:**
- Rider's location stays at one point
- No location updates received
- "Location permission denied" error

**Solutions:**

1. **Check Permissions**
```dart
// Verify permissions are granted
final permission = await Geolocator.checkPermission();
print('Location permission: $permission');

if (permission == LocationPermission.denied || 
    permission == LocationPermission.deniedForever) {
  // Request permission
  await Geolocator.requestPermission();
}
```

2. **Check Location Services**
```dart
final serviceEnabled = await Geolocator.isLocationServiceEnabled();
if (!serviceEnabled) {
  // Show dialog to enable location services
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Enable Location'),
      content: Text('Please enable location services to continue'),
      actions: [
        TextButton(
          onPressed: () => Geolocator.openLocationSettings(),
          child: Text('Open Settings'),
        ),
      ],
    ),
  );
}
```

3. **Android Manifest Configuration**
```xml
<!-- Add to AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- For background tracking (Android 10+) -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

4. **iOS Info.plist Configuration**
```xml
<!-- Add to Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to track deliveries</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need your location to track deliveries even in background</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

### Issue: Inaccurate GPS coordinates

**Symptoms:**
- Rider appears in wrong location
- Location jumps around erratically
- Accuracy is very low (> 100 meters)

**Solutions:**

1. **Filter Low Accuracy Readings**
```dart
Future<void> _sendLocationUpdate(Position position) async {
  // Ignore readings with accuracy > 50 meters
  if (position.accuracy > 50) {
    print('Ignoring low accuracy reading: ${position.accuracy}m');
    return;
  }
  
  // Send update
  await _sendToBackend(position);
}
```

2. **Use High Accuracy Mode**
```dart
const locationSettings = LocationSettings(
  accuracy: LocationAccuracy.high,  // Use high accuracy
  distanceFilter: 10,  // Only update when moved 10 meters
);
```

3. **Implement Kalman Filter** (Advanced)
```dart
class LocationFilter {
  double _lastLat = 0;
  double _lastLng = 0;
  
  Position filterLocation(Position position) {
    // Simple smoothing
    final smoothedLat = (_lastLat * 0.7) + (position.latitude * 0.3);
    final smoothedLng = (_lastLng * 0.7) + (position.longitude * 0.3);
    
    _lastLat = smoothedLat;
    _lastLng = smoothedLng;
    
    return Position(
      latitude: smoothedLat,
      longitude: smoothedLng,
      // ... other fields
    );
  }
}
```

---

## Map Display Problems

### Issue: Map not showing / blank screen

**Symptoms:**
- White/gray screen instead of map
- "Map failed to load" error
- No map tiles visible

**Solutions:**

1. **Verify API Key**
```bash
# Check if API key is set correctly
# Android: android/app/src/main/AndroidManifest.xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_ACTUAL_API_KEY_HERE"/>

# iOS: ios/Runner/AppDelegate.swift
GMSServices.provideAPIKey("YOUR_ACTUAL_API_KEY_HERE")
```

2. **Enable Required APIs in Google Cloud Console**
- Maps SDK for Android
- Maps SDK for iOS
- Directions API
- Distance Matrix API

3. **Check Billing**
- Ensure billing is enabled in Google Cloud Console
- Verify you haven't exceeded quota

4. **Debug API Key**
```dart
// Test if map loads
GoogleMap(
  initialCameraPosition: CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco
    zoom: 12,
  ),
  onMapCreated: (controller) {
    print('Map created successfully!');
  },
  onTap: (position) {
    print('Map tapped at: $position');
  },
)
```

### Issue: Markers not showing

**Symptoms:**
- Map loads but no markers visible
- Markers appear then disappear
- Only some markers show

**Solutions:**

1. **Verify Marker Data**
```dart
print('Markers count: ${_markers.length}');
for (final marker in _markers) {
  print('Marker ${marker.markerId}: ${marker.position}');
}
```

2. **Check Marker Position**
```dart
// Ensure coordinates are valid
if (latitude < -90 || latitude > 90 || 
    longitude < -180 || longitude > 180) {
  print('Invalid coordinates: $latitude, $longitude');
  return;
}
```

3. **Animate Camera to Markers**
```dart
void _showAllMarkers() {
  if (_markers.isEmpty) return;
  
  final bounds = _calculateBounds();
  _mapController?.animateCamera(
    CameraUpdate.newLatLngBounds(bounds, 50),
  );
}
```

### Issue: Polyline not displaying

**Symptoms:**
- Route line doesn't show on map
- Polyline appears broken
- Only partial route visible

**Solutions:**

1. **Verify Polyline Encoding**
```dart
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

void _drawRoute(String encodedPolyline) {
  try {
    final points = PolylinePoints().decodePolyline(encodedPolyline);
    
    if (points.isEmpty) {
      print('No points decoded from polyline');
      return;
    }
    
    print('Decoded ${points.length} points');
    
    setState(() {
      _polylines = {
        Polyline(
          polylineId: PolylineId('route'),
          points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          color: Colors.blue.withOpacity(0.8),
          width: 5,
          geodesic: true,
        ),
      };
    });
  } catch (e) {
    print('Error decoding polyline: $e');
  }
}
```

2. **Check Polyline Color Opacity**
```dart
// Make sure polyline is visible
Polyline(
  polylineId: PolylineId('route'),
  points: routePoints,
  color: Colors.blue,  // Not Colors.transparent!
  width: 5,
)
```

---

## Real-time Update Issues

### Issue: Socket not connecting

**Symptoms:**
- No real-time updates received
- "Socket connection failed" error
- Updates only work with polling

**Solutions:**

1. **Verify Socket URL**
```dart
final socket = io.io('http://YOUR_SERVER_IP:5000', <String, dynamic>{
  'transports': ['websocket'],
  'autoConnect': true,
});

socket.onConnect((_) {
  print('Socket connected!');
});

socket.onConnectError((error) {
  print('Socket connection error: $error');
});
```

2. **Check CORS on Backend**
```javascript
// backend/server.js
const cors = require('cors');

app.use(cors({
  origin: '*',  // For development
  credentials: true
}));

const io = require('socket.io')(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});
```

3. **Test Socket Connection**
```dart
void testSocketConnection() {
  socket.emit('test', {'message': 'Hello'});
  
  socket.on('test_response', (data) {
    print('Socket working: $data');
  });
}
```

### Issue: Updates delayed or not real-time

**Symptoms:**
- Location updates arrive 10-30 seconds late
- Customer sees old rider position
- ETA not updating

**Solutions:**

1. **Reduce Update Interval**
```dart
// Rider app
static const int UPDATE_INTERVAL_SECONDS = 5;  // Reduce from 10 to 5
```

2. **Use WebSocket Instead of Polling**
```dart
// Don't use Timer for fetching
// BAD:
Timer.periodic(Duration(seconds: 5), (_) {
  fetchTrackingData();
});

// GOOD: Use Socket.IO
socket.on('location_update', (data) {
  updateMap(data);
});
```

3. **Check Network Latency**
```javascript
// Backend - log update timing
router.post('/location', async (req, res) => {
  const startTime = Date.now();
  
  await trackingService.updateRiderLocation(...);
  
  const duration = Date.now() - startTime;
  console.log(`Location update took ${duration}ms`);
  
  res.json({ success: true });
});
```

---

## Performance Problems

### Issue: High battery drain

**Symptoms:**
- Rider app drains battery quickly
- Phone gets hot during delivery
- Battery drops 20%+ per hour

**Solutions:**

1. **Implement Adaptive Tracking**
```dart
class AdaptiveLocationService {
  int _updateInterval = 10;
  
  void adjustInterval(double speed) {
    if (speed < 1.0) {
      // Stationary - reduce frequency
      _updateInterval = 30;
    } else if (speed < 5.0) {
      // Slow movement
      _updateInterval = 15;
    } else {
      // Fast movement
      _updateInterval = 5;
    }
  }
}
```

2. **Use Distance Filter**
```dart
const locationSettings = LocationSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 10,  // Only update when moved 10+ meters
);
```

3. **Stop Tracking When Idle**
```dart
void onDeliveryCompleted() {
  locationTrackingService.stopTracking();
}

void onAppBackgrounded() {
  // Reduce frequency when backgrounded
  locationTrackingService.setUpdateInterval(30);
}
```

### Issue: App crashes or freezes

**Symptoms:**
- App crashes during tracking
- UI freezes when map updates
- Out of memory errors

**Solutions:**

1. **Limit Location History**
```javascript
// Backend
if (tracking.locationHistory.length > 100) {
  tracking.locationHistory = tracking.locationHistory.slice(-100);
}
```

2. **Optimize Map Updates**
```dart
// Don't rebuild entire map on every update
void _updateMap() {
  // Only update markers, not entire widget
  setState(() {
    _markers = _buildMarkers();
  });
}
```

3. **Use Debouncing**
```dart
Timer? _updateTimer;

void _onLocationUpdate(data) {
  _updateTimer?.cancel();
  _updateTimer = Timer(Duration(milliseconds: 500), () {
    _actuallyUpdateMap(data);
  });
}
```

---

## API & Backend Errors

### Issue: "OVER_QUERY_LIMIT" from Google Maps

**Symptoms:**
- ETA calculation fails
- Route not showing
- "You have exceeded your daily request quota"

**Solutions:**

1. **Implement Caching**
```javascript
const NodeCache = require('node-cache');
const etaCache = new NodeCache({ stdTTL: 60 });

async calculateETA(from, to) {
  const cacheKey = `${from.lat},${from.lng}-${to.lat},${to.lng}`;
  
  // Check cache first
  const cached = etaCache.get(cacheKey);
  if (cached) return cached;
  
  // Call API
  const result = await googleMapsClient.distancematrix(...);
  
  // Cache result
  etaCache.set(cacheKey, result);
  
  return result;
}
```

2. **Use Fallback Calculation**
```javascript
async calculateETA(fromLat, fromLng, toCoordinates) {
  try {
    return await this.calculateWithGoogleMaps(...);
  } catch (error) {
    if (error.message.includes('OVER_QUERY_LIMIT')) {
      console.warn('Google Maps quota exceeded, using fallback');
      return this.calculateStraightLineETA(...);
    }
    throw error;
  }
}
```

3. **Monitor API Usage**
```javascript
let apiCallCount = 0;

async function trackApiCall() {
  apiCallCount++;
  console.log(`Google Maps API calls today: ${apiCallCount}`);
  
  if (apiCallCount > 2000) {
    console.warn('Approaching daily limit!');
  }
}
```

### Issue: MongoDB geospatial query errors

**Symptoms:**
- "Can't extract geo keys" error
- Geospatial queries fail
- Index not being used

**Solutions:**

1. **Verify Index Creation**
```javascript
// Check if index exists
db.ordertrackings.getIndexes()

// Create index manually if needed
db.ordertrackings.createIndex({ "currentLocation": "2dsphere" })
```

2. **Correct GeoJSON Format**
```javascript
// CORRECT:
currentLocation: {
  type: 'Point',
  coordinates: [longitude, latitude]  // [lng, lat] NOT [lat, lng]!
}

// WRONG:
currentLocation: {
  coordinates: [latitude, longitude]  // This will fail!
}
```

3. **Test Geospatial Query**
```javascript
// Test query
const nearby = await OrderTracking.find({
  currentLocation: {
    $near: {
      $geometry: {
        type: 'Point',
        coordinates: [longitude, latitude]
      },
      $maxDistance: 1000  // 1km
    }
  }
});
```

---

## Platform-Specific Issues

### Android Issues

**Issue: Background location not working on Android 10+**

**Solution:**
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Add foreground service -->
<service
    android:name=".LocationService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="location" />
```

**Issue: App killed by battery optimization**

**Solution:**
```dart
// Request battery optimization exemption
import 'package:battery_optimization/battery_optimization.dart';

Future<void> requestBatteryOptimizationExemption() async {
  final isIgnoring = await BatteryOptimization.isIgnoringBatteryOptimizations();
  
  if (!isIgnoring) {
    await BatteryOptimization.openBatteryOptimizationSettings();
  }
}
```

### iOS Issues

**Issue: Location stops updating in background**

**Solution:**
```swift
// AppDelegate.swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_API_KEY")
    
    // Enable background location
    if #available(iOS 9.0, *) {
      application.registerUserNotificationSettings(
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      )
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**Issue: App Store rejection for location usage**

**Solution:**
- Provide clear, specific location usage descriptions
- Only request "Always" permission when necessary
- Implement "While Using" as default option

```xml
<!-- Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>GrabGo needs your location to show nearby restaurants and track your delivery in real-time</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>GrabGo needs your location even when the app is in the background to provide accurate delivery tracking and ensure your order arrives on time</string>
```

---

## Debugging Tips

### Enable Verbose Logging

**Backend:**
```javascript
// Add detailed logging
console.log('[TRACKING] Rider location update:', {
  orderId,
  location: { latitude, longitude },
  timestamp: new Date().toISOString()
});
```

**Flutter:**
```dart
// Enable debug prints
void debugLocation(String message, [dynamic data]) {
  if (kDebugMode) {
    print('[LOCATION] $message ${data ?? ''}');
  }
}
```

### Test with Mock Data

```dart
// Test tracking without actual GPS
void testWithMockData() {
  final mockLocations = [
    LatLng(5.6037, -0.1870),
    LatLng(5.6047, -0.1880),
    LatLng(5.6057, -0.1890),
  ];
  
  int index = 0;
  Timer.periodic(Duration(seconds: 2), (timer) {
    if (index >= mockLocations.length) {
      timer.cancel();
      return;
    }
    
    _updateMapWithLocation(mockLocations[index]);
    index++;
  });
}
```

---

## Quick Diagnostic Checklist

When tracking isn't working, check:

- [ ] Location permissions granted
- [ ] Location services enabled
- [ ] Internet connection active
- [ ] API keys configured correctly
- [ ] Backend server running
- [ ] Socket.IO connected
- [ ] MongoDB indexes created
- [ ] Google Maps APIs enabled
- [ ] Billing enabled in Google Cloud
- [ ] Correct coordinate format (lng, lat)
- [ ] No CORS errors in browser console
- [ ] Firewall not blocking WebSocket
- [ ] App has battery optimization exemption (Android)

---

**Last Updated:** January 2026
