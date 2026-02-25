import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;

/// Data transfer object for tracking initialization
class TrackingInitDto {
  final String orderId;
  final String riderId;
  final String customerId;
  final LocationDto pickupLocation;
  final LocationDto destination;

  TrackingInitDto({
    required this.orderId,
    required this.riderId,
    required this.customerId,
    required this.pickupLocation,
    required this.destination,
  });

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'riderId': riderId,
    'customerId': customerId,
    'pickupLocation': pickupLocation.toJson(),
    'destination': destination.toJson(),
  };
}

/// Location data transfer object
class LocationDto {
  final double latitude;
  final double longitude;

  LocationDto({required this.latitude, required this.longitude});

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  factory LocationDto.fromJson(Map<String, dynamic> json) => LocationDto(
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
  );
}

/// Response from location update API
class LocationUpdateResponse {
  final double distanceRemaining;
  final DateTime? estimatedArrival;
  final String status;
  final int? etaSeconds;

  LocationUpdateResponse({
    required this.distanceRemaining,
    this.estimatedArrival,
    required this.status,
    this.etaSeconds,
  });

  factory LocationUpdateResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      return LocationUpdateResponse(distanceRemaining: 0, status: 'unknown');
    }

    DateTime? eta;
    if (data['estimatedArrival'] != null) {
      try {
        eta = DateTime.parse(data['estimatedArrival'] as String);
      } catch (_) {}
    }

    return LocationUpdateResponse(
      distanceRemaining: (data['distanceRemaining'] as num?)?.toDouble() ?? 0,
      estimatedArrival: eta,
      status: data['status']?.toString() ?? 'unknown',
      etaSeconds: (data['etaSeconds'] as num?)?.toInt(),
    );
  }

  /// Get ETA in minutes
  double get etaMinutes {
    if (etaSeconds != null) {
      return etaSeconds! / 60.0;
    }
    if (estimatedArrival != null) {
      final diff = estimatedArrival!.difference(DateTime.now()).inSeconds;
      return diff / 60.0;
    }
    return 0;
  }

  /// Get distance in kilometers
  double get distanceKm => distanceRemaining / 1000.0;
}

/// Response for authoritative order lifecycle status updates.
class LifecycleStatusUpdateResult {
  final bool success;
  final String? message;

  const LifecycleStatusUpdateResult({required this.success, this.message});
}

/// Tracking info response
class TrackingInfo {
  final String orderId;
  final String riderId;
  final String customerId;
  final String status;
  final LocationDto? currentLocation;
  final LocationDto? pickupLocation;
  final LocationDto? destination;
  final double? distanceRemaining;
  final DateTime? estimatedArrival;
  final RouteInfo? route;

  TrackingInfo({
    required this.orderId,
    required this.riderId,
    required this.customerId,
    required this.status,
    this.currentLocation,
    this.pickupLocation,
    this.destination,
    this.distanceRemaining,
    this.estimatedArrival,
    this.route,
  });

  factory TrackingInfo.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;

    LocationDto? parseLocation(dynamic loc) {
      if (loc == null) return null;
      if (loc is Map<String, dynamic>) {
        if (loc['type'] == 'Point' && loc['coordinates'] is List) {
          final coords = loc['coordinates'] as List;
          if (coords.length >= 2) {
            return LocationDto(
              longitude: (coords[0] as num).toDouble(),
              latitude: (coords[1] as num).toDouble(),
            );
          }
        }
        if (loc['latitude'] != null && loc['longitude'] != null) {
          return LocationDto.fromJson(loc);
        }
      }
      return null;
    }

    DateTime? eta;
    if (data['estimatedArrival'] != null) {
      try {
        eta = DateTime.parse(data['estimatedArrival'] as String);
      } catch (_) {}
    }

    return TrackingInfo(
      orderId: data['orderId']?.toString() ?? '',
      riderId: data['riderId']?.toString() ?? '',
      customerId: data['customerId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'unknown',
      currentLocation: parseLocation(data['currentLocation']),
      pickupLocation: parseLocation(data['pickupLocation']),
      destination: parseLocation(data['destination']),
      distanceRemaining: (data['distanceRemaining'] as num?)?.toDouble(),
      estimatedArrival: eta,
      route: data['route'] != null
          ? RouteInfo.fromJson(data['route'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Route information including polyline for map display
class RouteInfo {
  final String? polyline;
  final int? durationSeconds;
  final int? distanceMeters;

  RouteInfo({this.polyline, this.durationSeconds, this.distanceMeters});

  factory RouteInfo.fromJson(Map<String, dynamic> json) => RouteInfo(
    polyline: json['polyline'] as String?,
    durationSeconds: (json['duration'] as num?)?.toInt(),
    distanceMeters: (json['distance'] as num?)?.toInt(),
  );
}

/// Tracking status enum matching backend
enum TrackingStatus {
  preparing,
  pickedUp,
  inTransit,
  nearby,
  delivered,
  cancelled;

  String toApiValue() {
    switch (this) {
      case TrackingStatus.preparing:
        return 'preparing';
      case TrackingStatus.pickedUp:
        return 'picked_up';
      case TrackingStatus.inTransit:
        return 'in_transit';
      case TrackingStatus.nearby:
        return 'nearby';
      case TrackingStatus.delivered:
        return 'delivered';
      case TrackingStatus.cancelled:
        return 'cancelled';
    }
  }

  static TrackingStatus fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('_', '');
    switch (normalized) {
      case 'preparing':
        return TrackingStatus.preparing;
      case 'pickedup':
        return TrackingStatus.pickedUp;
      case 'intransit':
        return TrackingStatus.inTransit;
      case 'nearby':
        return TrackingStatus.nearby;
      case 'delivered':
        return TrackingStatus.delivered;
      case 'cancelled':
        return TrackingStatus.cancelled;
      default:
        debugPrint(
          '⚠️ Unknown tracking status: $value, defaulting to preparing',
        );
        return TrackingStatus.preparing;
    }
  }
}

/// Service to interact with backend tracking API
class RiderTrackingService {
  /// Create a tracking service
  RiderTrackingService({String? authToken, http.Client? client})
    : _authToken = authToken,
      _client = client ?? http.Client();

  final http.Client _client;
  final String? _authToken;

  String get _baseUrl => AppConfig.apiBaseUrl;

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    // Use provided auth token if available (for background service)
    if (_authToken != null && _authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
      return headers;
    }

    // Otherwise get from cache (foreground usage)
    try {
      final token = await CacheService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      debugPrint('Error getting auth token for tracking requests: $e');
    }
    return headers;
  }

  /// Initialize tracking when rider accepts an order
  Future<TrackingInfo?> initializeTracking(TrackingInitDto dto) async {
    final uri = Uri.parse('$_baseUrl/tracking/initialize');
    try {
      debugPrint('🚀 Initializing tracking: ${dto.orderId}');

      final response = await _client.post(
        uri,
        headers: await _buildHeaders(),
        body: jsonEncode(dto.toJson()),
      );

      debugPrint('📍 Initialize tracking response: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          return TrackingInfo.fromJson(decoded);
        }
      }

      debugPrint('❌ Initialize tracking failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ Error initializing tracking: $e');
      return null;
    }
  }

  /// Update rider's current location (call every 5-10 seconds during delivery)
  Future<LocationUpdateResponse?> updateLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    double speed = 0,
    double accuracy = 0,
  }) async {
    final uri = Uri.parse('$_baseUrl/tracking/location');
    try {
      final response = await _client.post(
        uri,
        headers: await _buildHeaders(),
        body: jsonEncode({
          'orderId': orderId,
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
          'accuracy': accuracy,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          return LocationUpdateResponse.fromJson(decoded);
        }
      }

      debugPrint('❌ Location update failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ Error updating location: $e');
      return null;
    }
  }

  /// Update order status (preparing -> picked_up -> in_transit -> nearby -> delivered)
  Future<bool> updateStatus({
    required String orderId,
    required TrackingStatus status,
  }) async {
    final uri = Uri.parse('$_baseUrl/tracking/status');
    try {
      debugPrint('📦 Updating status to: ${status.toApiValue()}');

      final response = await _client.patch(
        uri,
        headers: await _buildHeaders(),
        body: jsonEncode({'orderId': orderId, 'status': status.toApiValue()}),
      );

      debugPrint('📦 Status update response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }

      debugPrint('❌ Status update failed: ${response.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Error updating status: $e');
      return false;
    }
  }

  /// Update the authoritative order lifecycle status in PostgreSQL.
  Future<LifecycleStatusUpdateResult> updateLifecycleStatus({
    required String orderId,
    required String status,
    Map<String, dynamic>? deliveryVerification,
    String? cancellationReason,
  }) async {
    final uri = Uri.parse('$_baseUrl/orders/$orderId/status');

    try {
      final body = <String, dynamic>{'status': status};
      if (deliveryVerification != null) {
        body['deliveryVerification'] = deliveryVerification;
      }
      if (cancellationReason != null && cancellationReason.isNotEmpty) {
        body['cancellationReason'] = cancellationReason;
      }

      debugPrint('📦 Updating authoritative order status to: $status');
      final response = await _client.put(
        uri,
        headers: await _buildHeaders(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final ok = decoded['success'] == true;
        return LifecycleStatusUpdateResult(
          success: ok,
          message: decoded['message']?.toString(),
        );
      }

      String? message;
      try {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        message = decoded['message']?.toString();
      } catch (_) {
        message = 'Failed to update order status';
      }

      debugPrint(
        '❌ Authoritative order status update failed: ${response.statusCode} ${response.body}',
      );
      return LifecycleStatusUpdateResult(success: false, message: message);
    } catch (e) {
      debugPrint('❌ Error updating authoritative order status: $e');
      return LifecycleStatusUpdateResult(
        success: false,
        message: 'Network error: $e',
      );
    }
  }

  /// Get current tracking info for an order
  Future<TrackingInfo?> getTrackingInfo(String orderId) async {
    final uri = Uri.parse('$_baseUrl/tracking/$orderId');
    try {
      final response = await _client.get(uri, headers: await _buildHeaders());

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          return TrackingInfo.fromJson(decoded);
        }
      }

      debugPrint('❌ Get tracking info failed: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting tracking info: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
