import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;

/// Represents an order reservation from the dispatch system
class OrderReservation {
  final String reservationId;
  final String orderId;
  final String orderNumber;
  final DateTime expiresAt;
  final int timeoutMs;
  final int attemptNumber;
  final double estimatedEarnings;
  final double distanceToPickup;
  final ReservationOrderSnapshot order;

  OrderReservation({
    required this.reservationId,
    required this.orderId,
    required this.orderNumber,
    required this.expiresAt,
    required this.timeoutMs,
    required this.attemptNumber,
    required this.estimatedEarnings,
    required this.distanceToPickup,
    required this.order,
  });

  /// Remaining time in milliseconds
  int get remainingMs {
    final now = DateTime.now();
    final diff = expiresAt.difference(now).inMilliseconds;
    return diff > 0 ? diff : 0;
  }

  /// Whether the reservation has expired
  bool get isExpired => remainingMs <= 0;

  factory OrderReservation.fromJson(Map<String, dynamic> json) {
    return OrderReservation(
      reservationId: json['reservationId']?.toString() ?? json['_id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      timeoutMs: (json['timeoutMs'] as num?)?.toInt() ?? 8000,
      attemptNumber: (json['attemptNumber'] as num?)?.toInt() ?? 1,
      estimatedEarnings: (json['estimatedEarnings'] as num?)?.toDouble() ?? 0.0,
      distanceToPickup: (json['distanceToPickup'] as num?)?.toDouble() ?? 0.0,
      order: ReservationOrderSnapshot.fromJson(json['order'] as Map<String, dynamic>? ?? {}),
    );
  }
}

/// Snapshot of order details for display in reservation UI
class ReservationOrderSnapshot {
  final String orderType;
  final double totalAmount;
  final String paymentMethod;
  final int itemCount;
  final String pickupAddress;
  final double? pickupLat;
  final double? pickupLon;
  final String deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLon;
  final String storeName;
  final String? storeLogo;
  final String customerName;
  final double distance;

  ReservationOrderSnapshot({
    required this.orderType,
    required this.totalAmount,
    required this.paymentMethod,
    required this.itemCount,
    required this.pickupAddress,
    this.pickupLat,
    this.pickupLon,
    required this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLon,
    required this.storeName,
    this.storeLogo,
    required this.customerName,
    required this.distance,
  });

  factory ReservationOrderSnapshot.fromJson(Map<String, dynamic> json) {
    return ReservationOrderSnapshot(
      orderType: json['orderType']?.toString() ?? 'food',
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      pickupAddress: json['pickupAddress']?.toString() ?? '',
      pickupLat: (json['pickupLat'] as num?)?.toDouble(),
      pickupLon: (json['pickupLon'] as num?)?.toDouble(),
      deliveryAddress: json['deliveryAddress']?.toString() ?? '',
      deliveryLat: (json['deliveryLat'] as num?)?.toDouble(),
      deliveryLon: (json['deliveryLon'] as num?)?.toDouble(),
      storeName: json['storeName']?.toString() ?? 'Store',
      storeLogo: json['storeLogo']?.toString(),
      customerName: json['customerName']?.toString() ?? 'Customer',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Service for managing order reservations in the rider app
class OrderReservationService extends ChangeNotifier {
  OrderReservationService._();
  static final OrderReservationService _instance = OrderReservationService._();
  factory OrderReservationService() => _instance;

  final http.Client _client = http.Client();
  String get _baseUrl => AppConfig.apiBaseUrl;

  // Current active reservation
  OrderReservation? _activeReservation;
  OrderReservation? get activeReservation => _activeReservation;
  bool get hasActiveReservation => _activeReservation != null && !_activeReservation!.isExpired;

  // Countdown timer
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  int get remainingSeconds => _remainingSeconds;

  // Loading states
  bool _isAccepting = false;
  bool _isDeclining = false;
  bool get isAccepting => _isAccepting;
  bool get isDeclining => _isDeclining;

  // Error state
  String? _error;
  String? get error => _error;

  // Callbacks
  void Function(OrderReservation)? onReservationReceived;
  void Function()? onReservationExpired;
  void Function(String orderId)? onReservationAccepted;
  void Function()? onReservationDeclined;
  void Function(String orderId, String reason)? onReservationCancelled;

  // Track if already initialized
  bool _isInitialized = false;

  /// Initialize the service and set up socket listeners
  void initialize() {
    if (_isInitialized) {
      debugPrint('OrderReservationService already initialized');
      return;
    }
    _isInitialized = true;

    final socket = SocketService();

    // Listen for new order reservations using the listener pattern
    // This ensures listeners are called even if socket connects later
    socket.addOrderReservedListener((data) {
      debugPrint('📦 OrderReservationService received order_reserved: $data');
      if (data is Map<String, dynamic>) {
        _handleNewReservation(data);
      }
    });

    // Listen for reservation cancellations
    socket.addReservationCancelledListener((data) {
      debugPrint('❌ OrderReservationService received reservation_cancelled: $data');
      if (data is Map<String, dynamic>) {
        _handleReservationCancelled(data);
      }
    });

    // Listen for reservation expiry (from server)
    socket.addReservationExpiredListener((data) {
      debugPrint('⏰ OrderReservationService received reservation_expired: $data');
      _handleReservationExpired();
    });

    // Listen for order taken by another rider
    socket.addOrderTakenListener((data) {
      debugPrint('🚴 OrderReservationService received order_taken: $data');
      if (data is Map<String, dynamic>) {
        final takenOrderId = data['orderId']?.toString();
        if (_activeReservation?.orderId == takenOrderId) {
          _clearReservation();
        }
      }
    });

    debugPrint('✅ OrderReservationService initialized with socket listeners');
  }

  /// Handle incoming reservation from socket
  void _handleNewReservation(Map<String, dynamic> data) {
    try {
      _activeReservation = OrderReservation.fromJson(data);
      _error = null;
      _startCountdown();
      notifyListeners();

      onReservationReceived?.call(_activeReservation!);
      debugPrint(
        '🎯 New reservation: ${_activeReservation!.orderNumber} - ${_activeReservation!.remainingMs}ms remaining',
      );
    } catch (e) {
      debugPrint('Error parsing reservation: $e');
      _error = 'Failed to parse reservation';
      notifyListeners();
    }
  }

  /// Handle reservation cancelled by server
  void _handleReservationCancelled(Map<String, dynamic> data) {
    final cancelledOrderId = data['orderId']?.toString();
    final reason = data['reason']?.toString() ?? 'unknown';

    if (_activeReservation?.orderId == cancelledOrderId) {
      _clearReservation();
      onReservationCancelled?.call(cancelledOrderId!, reason);
    }
  }

  /// Handle reservation expired
  void _handleReservationExpired() {
    _clearReservation();
    onReservationExpired?.call();
  }

  /// Start countdown timer for the reservation
  void _startCountdown() {
    _stopCountdown();

    if (_activeReservation == null) return;

    _remainingSeconds = (_activeReservation!.remainingMs / 1000).ceil();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds--;
      notifyListeners();

      if (_remainingSeconds <= 0) {
        _handleReservationExpired();
      }
    });
  }

  /// Stop countdown timer
  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Clear current reservation
  void _clearReservation() {
    _stopCountdown();
    _activeReservation = null;
    _remainingSeconds = 0;
    _isAccepting = false;
    _isDeclining = false;
    notifyListeners();
  }

  /// Build auth headers for API requests
  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final token = await CacheService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      debugPrint('Error getting auth token: $e');
    }
    return headers;
  }

  /// Accept the current reservation
  Future<bool> acceptReservation() async {
    if (_activeReservation == null) {
      _error = 'No active reservation';
      notifyListeners();
      return false;
    }

    if (_activeReservation!.isExpired) {
      _error = 'Reservation has expired';
      _clearReservation();
      notifyListeners();
      return false;
    }

    _isAccepting = true;
    _error = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$_baseUrl/riders/reservation/${_activeReservation!.reservationId}/accept');
      final response = await _client.post(uri, headers: await _buildHeaders());

      debugPrint('Accept reservation response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true) {
          final orderId = _activeReservation!.orderId;
          _clearReservation();
          onReservationAccepted?.call(orderId);
          return true;
        } else {
          _error = decoded['message']?.toString() ?? 'Failed to accept';
        }
      } else {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _error = decoded['message']?.toString() ?? 'Server error';
      }
    } catch (e) {
      debugPrint('Error accepting reservation: $e');
      _error = 'Network error: $e';
    }

    _isAccepting = false;
    notifyListeners();
    return false;
  }

  /// Decline the current reservation
  Future<bool> declineReservation({String? reason}) async {
    if (_activeReservation == null) {
      _error = 'No active reservation';
      notifyListeners();
      return false;
    }

    _isDeclining = true;
    _error = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$_baseUrl/riders/reservation/${_activeReservation!.reservationId}/decline');
      final body = reason != null ? jsonEncode({'reason': reason}) : '{}';
      final response = await _client.post(uri, headers: await _buildHeaders(), body: body);

      debugPrint('Decline reservation response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        _clearReservation();
        onReservationDeclined?.call();
        return true;
      } else {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        _error = decoded['message']?.toString() ?? 'Failed to decline';
      }
    } catch (e) {
      debugPrint('Error declining reservation: $e');
      _error = 'Network error: $e';
    }

    _isDeclining = false;
    notifyListeners();
    return false;
  }

  /// Fetch active reservation from server (for app resume)
  Future<OrderReservation?> fetchActiveReservation() async {
    try {
      final uri = Uri.parse('$_baseUrl/riders/active-reservation');
      final response = await _client.get(uri, headers: await _buildHeaders());

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['hasReservation'] == true && decoded['data'] != null) {
          _activeReservation = OrderReservation.fromJson(decoded['data'] as Map<String, dynamic>);
          if (!_activeReservation!.isExpired) {
            _startCountdown();
            notifyListeners();
            return _activeReservation;
          } else {
            _activeReservation = null;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching active reservation: $e');
    }
    return null;
  }

  /// Notify server that rider is going online
  void goOnline() {
    final socket = SocketService();
    socket.socket?.emit('rider:go_online');
    debugPrint('🟢 Rider going online');
  }

  /// Notify server that rider is going offline
  void goOffline() {
    final socket = SocketService();
    socket.socket?.emit('rider:go_offline');
    _clearReservation();
    debugPrint('🔴 Rider going offline');
  }

  /// Update rider location
  void updateLocation(double latitude, double longitude) {
    final socket = SocketService();
    socket.socket?.emit('rider:location_update', {'latitude': latitude, 'longitude': longitude});
  }

  /// Dispose the service
  @override
  void dispose() {
    _stopCountdown();
    _activeReservation = null;
    super.dispose();
  }
}
