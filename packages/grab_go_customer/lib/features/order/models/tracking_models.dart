import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Main tracking data model
class TrackingData {
  final String orderId;
  final LocationData? currentLocation;
  final LocationData destination;
  final LocationData? pickupLocation;
  final String status;
  final int distanceRemaining;
  final DateTime? estimatedArrival;
  final RouteData? route;
  final RiderInfo? rider;
  final List<LocationHistory> locationHistory;

  TrackingData({
    required this.orderId,
    this.currentLocation,
    required this.destination,
    this.pickupLocation,
    required this.status,
    required this.distanceRemaining,
    this.estimatedArrival,
    this.route,
    this.rider,
    this.locationHistory = const [],
  });

  factory TrackingData.fromJson(Map<String, dynamic> json) {
    return TrackingData(
      orderId: json['orderId'] ?? '',
      currentLocation: json['currentLocation'] != null ? LocationData.fromJson(json['currentLocation']) : null,
      destination: LocationData.fromJson(json['destination']),
      pickupLocation: json['pickupLocation'] != null ? LocationData.fromJson(json['pickupLocation']) : null,
      status: json['status'] ?? 'preparing',
      distanceRemaining: json['distanceRemaining'] ?? 0,
      estimatedArrival: json['estimatedArrival'] != null ? DateTime.parse(json['estimatedArrival']) : null,
      route: json['route'] != null ? RouteData.fromJson(json['route']) : null,
      rider: json['riderId'] != null ? RiderInfo.fromJson(json['riderId']) : null,
      locationHistory:
          (json['locationHistory'] as List<dynamic>?)?.map((e) => LocationHistory.fromJson(e)).toList() ?? [],
    );
  }

  /// Convert distance in meters to kilometers
  String get distanceInKm {
    return (distanceRemaining / 1000).toStringAsFixed(1);
  }

  /// Get ETA in minutes
  int? get etaInMinutes {
    if (estimatedArrival == null) return null;
    final diff = estimatedArrival!.difference(DateTime.now());
    return diff.inMinutes;
  }

  /// Get formatted ETA string
  String get formattedEta {
    final minutes = etaInMinutes;
    if (minutes == null) return 'Calculating...';
    if (minutes < 1) return 'Arriving now';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  /// Get status display text
  String get statusText {
    switch (status.toLowerCase()) {
      case 'preparing':
        return 'Preparing Order';
      case 'picked_up':
        return 'On The Way';
      case 'in_transit':
        return 'On The Way';
      case 'nearby':
        return 'Arriving Soon';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  /// Get active step for progress indicator
  int get activeStep {
    switch (status.toLowerCase()) {
      case 'preparing':
        return 1;
      case 'picked_up':
      case 'in_transit':
        return 2;
      case 'nearby':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }
}

/// Location data with coordinates
class LocationData {
  final double latitude;
  final double longitude;

  LocationData({required this.latitude, required this.longitude});

  factory LocationData.fromJson(Map<String, dynamic> json) {
    // Handle GeoJSON format from backend
    if (json['coordinates'] != null) {
      final coordinates = json['coordinates'] as List;
      return LocationData(longitude: coordinates[0].toDouble(), latitude: coordinates[1].toDouble());
    }
    // Handle direct lat/lng format
    return LocationData(latitude: json['latitude']?.toDouble() ?? 0.0, longitude: json['longitude']?.toDouble() ?? 0.0);
  }

  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}

/// Route data with polyline
class RouteData {
  final String polyline;
  final int duration; // seconds
  final int distance; // meters

  RouteData({required this.polyline, required this.duration, required this.distance});

  factory RouteData.fromJson(Map<String, dynamic> json) {
    return RouteData(
      polyline: json['polyline'] ?? '',
      duration: json['duration'] ?? 0,
      distance: json['distance'] ?? 0,
    );
  }

  /// Get duration in minutes
  int get durationInMinutes {
    return (duration / 60).ceil();
  }

  /// Get distance in kilometers
  String get distanceInKm {
    return (distance / 1000).toStringAsFixed(1);
  }
}

/// Rider information
class RiderInfo {
  final String id;
  final String name;
  final String? phone;
  final String? profileImage;
  final double? rating;

  RiderInfo({required this.id, required this.name, this.phone, this.profileImage, this.rating});

  factory RiderInfo.fromJson(Map<String, dynamic> json) {
    return RiderInfo(
      id: json['_id'] ?? '',
      name: json['name'] ?? json['username'] ?? 'Rider',
      phone: json['phone'],
      profileImage: json['profileImage'] ?? json['profilePicture'],
      rating: json['rating']?.toDouble(),
    );
  }

  String get formattedRating {
    if (rating == null) return 'N/A';
    return rating!.toStringAsFixed(1);
  }
}

/// Location history entry
class LocationHistory {
  final LocationData location;
  final DateTime timestamp;
  final double? speed;
  final double? accuracy;

  LocationHistory({required this.location, required this.timestamp, this.speed, this.accuracy});

  factory LocationHistory.fromJson(Map<String, dynamic> json) {
    return LocationHistory(
      location: LocationData.fromJson({'coordinates': json['coordinates']}),
      timestamp: DateTime.parse(json['timestamp']),
      speed: json['speed']?.toDouble(),
      accuracy: json['accuracy']?.toDouble(),
    );
  }
}

/// Socket event data for location updates
class LocationUpdateEvent {
  final String orderId;
  final LocationData location;
  final int distance;
  final DateTime eta;
  final String status;

  LocationUpdateEvent({
    required this.orderId,
    required this.location,
    required this.distance,
    required this.eta,
    required this.status,
  });

  factory LocationUpdateEvent.fromJson(Map<String, dynamic> json) {
    // Parse ETA - backend sends duration in seconds, convert to DateTime
    DateTime parsedEta;
    final etaValue = json['eta'];
    if (etaValue is int) {
      // ETA is duration in seconds - add to current time
      parsedEta = DateTime.now().add(Duration(seconds: etaValue));
    } else if (etaValue is String) {
      // ETA is already a date string
      parsedEta = DateTime.tryParse(etaValue) ?? DateTime.now().add(const Duration(minutes: 10));
    } else {
      parsedEta = DateTime.now().add(const Duration(minutes: 10));
    }

    // Parse distance - ensure it's an int
    final distanceValue = json['distance'];
    final int parsedDistance = distanceValue is int
        ? distanceValue
        : (distanceValue is double ? distanceValue.toInt() : int.tryParse(distanceValue.toString()) ?? 0);

    return LocationUpdateEvent(
      orderId: json['orderId']?.toString() ?? '',
      location: LocationData(
        latitude: (json['location']['latitude'] as num).toDouble(),
        longitude: (json['location']['longitude'] as num).toDouble(),
      ),
      distance: parsedDistance,
      eta: parsedEta,
      status: json['status']?.toString() ?? 'unknown',
    );
  }
}

/// Socket event data for status updates
class StatusUpdateEvent {
  final String orderId;
  final String status;
  final String? message;

  StatusUpdateEvent({required this.orderId, required this.status, this.message});

  factory StatusUpdateEvent.fromJson(Map<String, dynamic> json) {
    return StatusUpdateEvent(
      orderId: json['orderId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unknown',
      message: json['message']?.toString(),
    );
  }
}
