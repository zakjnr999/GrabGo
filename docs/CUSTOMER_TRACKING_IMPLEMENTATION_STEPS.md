# Customer Live Tracking - Step-by-Step Implementation Guide

## ✅ Prerequisites Check

You already have:
- ✅ `geolocator: ^14.0.2` - For GPS
- ✅ `socket_io_client: ^2.0.3+1` - For real-time updates
- ✅ `http: ^1.1.2` - For API calls
- ✅ UI already created in `map_tracking.dart`

## 🚀 What We Need to Add

### Missing Dependencies:
- ❌ `google_maps_flutter` - For displaying the map
- ❌ `flutter_polyline_points` - For decoding route polylines

---

## 📋 Implementation Steps

### **PHASE 1: Setup (15 minutes)**

#### Step 1.1: Add Missing Dependencies

Add to `pubspec.yaml`:
```yaml
dependencies:
  google_maps_flutter: ^2.10.0
  flutter_polyline_points: ^2.1.0
```

Run:
```bash
cd packages/grab_go_customer
flutter pub get
```

#### Step 1.2: Configure Google Maps API

**Android:** `android/app/src/main/AndroidManifest.xml`
```xml
<manifest>
    <application>
        <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
    </application>
</manifest>
```

**iOS:** `ios/Runner/AppDelegate.swift`
```swift
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

### **PHASE 2: Create Data Models (10 minutes)**

#### Step 2.1: Create Tracking Models

Create `lib/features/order/models/tracking_models.dart`:

```dart
class TrackingData {
  final String orderId;
  final LocationData currentLocation;
  final LocationData destination;
  final String status;
  final int distanceRemaining; // meters
  final DateTime estimatedArrival;
  final RouteData? route;
  final RiderInfo rider;

  TrackingData({
    required this.orderId,
    required this.currentLocation,
    required this.destination,
    required this.status,
    required this.distanceRemaining,
    required this.estimatedArrival,
    this.route,
    required this.rider,
  });

  factory TrackingData.fromJson(Map<String, dynamic> json) {
    return TrackingData(
      orderId: json['orderId'],
      currentLocation: LocationData.fromJson(json['currentLocation']),
      destination: LocationData.fromJson(json['destination']),
      status: json['status'],
      distanceRemaining: json['distanceRemaining'],
      estimatedArrival: DateTime.parse(json['estimatedArrival']),
      route: json['route'] != null ? RouteData.fromJson(json['route']) : null,
      rider: RiderInfo.fromJson(json['riderId']),
    );
  }
}

class LocationData {
  final double latitude;
  final double longitude;

  LocationData({required this.latitude, required this.longitude});

  factory LocationData.fromJson(Map<String, dynamic> json) {
    final coordinates = json['coordinates'] as List;
    return LocationData(
      longitude: coordinates[0].toDouble(),
      latitude: coordinates[1].toDouble(),
    );
  }
}

class RouteData {
  final String polyline;
  final int duration; // seconds
  final int distance; // meters

  RouteData({
    required this.polyline,
    required this.duration,
    required this.distance,
  });

  factory RouteData.fromJson(Map<String, dynamic> json) {
    return RouteData(
      polyline: json['polyline'],
      duration: json['duration'],
      distance: json['distance'],
    );
  }
}

class RiderInfo {
  final String id;
  final String name;
  final String? phone;
  final String? profileImage;
  final double? rating;

  RiderInfo({
    required this.id,
    required this.name,
    this.phone,
    this.profileImage,
    this.rating,
  });

  factory RiderInfo.fromJson(Map<String, dynamic> json) {
    return RiderInfo(
      id: json['_id'],
      name: json['name'] ?? 'Rider',
      phone: json['phone'],
      profileImage: json['profileImage'],
      rating: json['rating']?.toDouble(),
    );
  }
}
```

---

### **PHASE 3: Create API Service (15 minutes)**

#### Step 3.1: Create Tracking API Service

Create `lib/features/order/services/tracking_api_service.dart`:

```dart
import 'package:dio/dio.dart';
import '../models/tracking_models.dart';

class TrackingApiService {
  final Dio _dio;
  final String baseUrl;

  TrackingApiService({required Dio dio, required this.baseUrl}) : _dio = dio;

  /// Get tracking information for an order
  Future<TrackingData> getTrackingInfo(String orderId) async {
    try {
      final response = await _dio.get('$baseUrl/api/tracking/$orderId');
      
      if (response.data['success'] == true) {
        return TrackingData.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Failed to get tracking info');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }
}
```

---

### **PHASE 4: Create Socket Service (15 minutes)**

#### Step 4.1: Create Tracking Socket Service

Create `lib/features/order/services/tracking_socket_service.dart`:

```dart
import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class TrackingSocketService {
  IO.Socket? _socket;
  final String serverUrl;
  final String token;
  
  final _locationUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<Map<String, dynamic>> get locationUpdates => _locationUpdateController.stream;
  Stream<Map<String, dynamic>> get statusUpdates => _statusUpdateController.stream;

  TrackingSocketService({
    required this.serverUrl,
    required this.token,
  });

  void connect() {
    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': 'Bearer $token'})
          .enableAutoConnect()
          .build(),
    );

    _socket?.on('connect', (_) {
      print('✅ Socket connected for tracking');
    });

    _socket?.on('location_update', (data) {
      print('📍 Location update received: $data');
      _locationUpdateController.add(data as Map<String, dynamic>);
    });

    _socket?.on('order_status_update', (data) {
      print('📊 Status update received: $data');
      _statusUpdateController.add(data as Map<String, dynamic>);
    });

    _socket?.on('disconnect', (_) {
      print('❌ Socket disconnected');
    });

    _socket?.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
  }

  void dispose() {
    disconnect();
    _locationUpdateController.close();
    _statusUpdateController.close();
  }
}
```

---

### **PHASE 5: Create Tracking Provider (20 minutes)**

#### Step 5.1: Create Tracking State Provider

Create `lib/features/order/providers/tracking_provider.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../models/tracking_models.dart';
import '../services/tracking_api_service.dart';
import '../services/tracking_socket_service.dart';

class TrackingProvider extends ChangeNotifier {
  final TrackingApiService _apiService;
  final TrackingSocketService _socketService;

  TrackingData? _trackingData;
  bool _isLoading = false;
  String? _error;
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _riderLocation;

  // Getters
  TrackingData? get trackingData => _trackingData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  LatLng? get riderLocation => _riderLocation;

  TrackingProvider({
    required TrackingApiService apiService,
    required TrackingSocketService socketService,
  })  : _apiService = apiService,
        _socketService = socketService {
    _initializeSocketListeners();
  }

  void _initializeSocketListeners() {
    _socketService.locationUpdates.listen((data) {
      _handleLocationUpdate(data);
    });

    _socketService.statusUpdates.listen((data) {
      _handleStatusUpdate(data);
    });
  }

  /// Initialize tracking for an order
  Future<void> initializeTracking(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get initial tracking data
      _trackingData = await _apiService.getTrackingInfo(orderId);
      
      // Connect to socket
      _socketService.connect();
      
      // Setup map markers and polylines
      await _setupMapElements();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _setupMapElements() async {
    if (_trackingData == null) return;

    // Create markers
    _markers = {
      // Rider marker
      Marker(
        markerId: const MarkerId('rider'),
        position: LatLng(
          _trackingData!.currentLocation.latitude,
          _trackingData!.currentLocation.longitude,
        ),
        icon: await _getRiderIcon(),
        infoWindow: InfoWindow(
          title: _trackingData!.rider.name,
          snippet: 'Your delivery rider',
        ),
      ),
      // Destination marker
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(
          _trackingData!.destination.latitude,
          _trackingData!.destination.longitude,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(
          title: 'Delivery Location',
          snippet: 'Your address',
        ),
      ),
    };

    // Create polyline from route
    if (_trackingData!.route != null) {
      await _createPolyline(_trackingData!.route!.polyline);
    }

    notifyListeners();
  }

  Future<BitmapDescriptor> _getRiderIcon() async {
    // TODO: Create custom rider icon
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
  }

  Future<void> _createPolyline(String encodedPolyline) async {
    final polylinePoints = PolylinePoints();
    final decoded = polylinePoints.decodePolyline(encodedPolyline);
    
    final polylineCoordinates = decoded
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: polylineCoordinates,
        color: Colors.blue,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  void _handleLocationUpdate(Map<String, dynamic> data) {
    if (_trackingData == null) return;

    // Update rider location
    final location = data['location'];
    _riderLocation = LatLng(
      location['latitude'].toDouble(),
      location['longitude'].toDouble(),
    );

    // Update marker
    _markers = _markers.map((marker) {
      if (marker.markerId.value == 'rider') {
        return marker.copyWith(positionParam: _riderLocation);
      }
      return marker;
    }).toSet();

    // Update tracking data
    _trackingData = TrackingData(
      orderId: _trackingData!.orderId,
      currentLocation: LocationData(
        latitude: location['latitude'].toDouble(),
        longitude: location['longitude'].toDouble(),
      ),
      destination: _trackingData!.destination,
      status: data['status'] ?? _trackingData!.status,
      distanceRemaining: data['distance'] ?? _trackingData!.distanceRemaining,
      estimatedArrival: DateTime.now().add(Duration(seconds: data['eta'] ?? 0)),
      route: _trackingData!.route,
      rider: _trackingData!.rider,
    );

    notifyListeners();
  }

  void _handleStatusUpdate(Map<String, dynamic> data) {
    if (_trackingData == null) return;

    _trackingData = TrackingData(
      orderId: _trackingData!.orderId,
      currentLocation: _trackingData!.currentLocation,
      destination: _trackingData!.destination,
      status: data['status'],
      distanceRemaining: _trackingData!.distanceRemaining,
      estimatedArrival: _trackingData!.estimatedArrival,
      route: _trackingData!.route,
      rider: _trackingData!.rider,
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _socketService.dispose();
    super.dispose();
  }
}
```

---

## 🎯 Next Steps

After creating these files, we'll:
1. Update the `map_tracking.dart` UI to use the provider
2. Add Google Map widget
3. Connect real-time updates
4. Test with your backend

**Ready to proceed with Step 1.1 (Add Dependencies)?** 🚀
