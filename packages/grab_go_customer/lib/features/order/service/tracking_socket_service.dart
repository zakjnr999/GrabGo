import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/tracking_models.dart';

/// Service for real-time tracking updates via Socket.IO
class TrackingSocketService {
  IO.Socket? _socket;
  final String serverUrl;
  final String token;

  // Stream controllers for different events
  final _locationUpdateController =
      StreamController<LocationUpdateEvent>.broadcast();
  final _statusUpdateController =
      StreamController<StatusUpdateEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Public streams
  Stream<LocationUpdateEvent> get locationUpdates =>
      _locationUpdateController.stream;
  Stream<StatusUpdateEvent> get statusUpdates => _statusUpdateController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  TrackingSocketService({required this.serverUrl, required this.token});

  /// Connect to Socket.IO server
  void connect() {
    if (_socket != null && _socket!.connected) {
      debugPrint('✅ Tracking socket already connected');
      return;
    }

    debugPrint('🔌 Connecting tracking socket: $serverUrl');

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(50)
          .setReconnectionDelay(2000)
          .build(),
    );

    _setupEventListeners();
    _socket?.connect();
  }

  /// Setup all socket event listeners
  void _setupEventListeners() {
    // Connection events
    _socket?.on('connect', (_) {
      debugPrint('✅ Tracking socket connected');
      if (!_connectionController.isClosed) {
        _connectionController.add(true);
      }
    });

    _socket?.on('disconnect', (_) {
      debugPrint('❌ Tracking socket disconnected');
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
    });

    _socket?.on('connect_error', (error) {
      debugPrint('❌ Tracking socket connection error: $error');
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
    });

    _socket?.on('reconnect', (attempt) {
      debugPrint('🔄 Tracking socket reconnected after $attempt attempts');
      if (!_connectionController.isClosed) {
        _connectionController.add(true);
      }
    });

    _socket?.on('reconnect_attempt', (attempt) {
      debugPrint('🔄 Tracking socket reconnection attempt $attempt');
    });

    _socket?.on('reconnect_error', (error) {
      debugPrint('❌ Tracking socket reconnection error: $error');
    });

    _socket?.on('reconnect_failed', (_) {
      debugPrint('❌ Tracking socket reconnection failed');
      if (!_connectionController.isClosed) {
        _connectionController.add(false);
      }
    });

    _socket?.on('tracking:error', (data) {
      debugPrint('⚠️ Tracking socket server error: $data');
    });

    // Tracking events
    _socket?.on('location_update', (data) {
      debugPrint('📍 Tracking location update: $data');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        final event = LocationUpdateEvent.fromJson(payload);
        if (!_locationUpdateController.isClosed) {
          _locationUpdateController.add(event);
        }
      } catch (e) {
        debugPrint('❌ Error parsing location update: $e');
      }
    });

    _socket?.on('order_status_update', (data) {
      debugPrint('📊 Tracking status update: $data');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        final event = StatusUpdateEvent.fromJson(payload);
        if (!_statusUpdateController.isClosed) {
          _statusUpdateController.add(event);
        }
      } catch (e) {
        debugPrint('❌ Error parsing status update: $e');
      }
    });

    // Geofence events
    _socket?.on('geofence_event', (data) {
      debugPrint('🎯 Tracking geofence event: $data');
      try {
        final payload = Map<String, dynamic>.from(data as Map);
        final event = StatusUpdateEvent(
          orderId: payload['orderId']?.toString() ?? '',
          status: payload['status']?.toString() ?? 'unknown',
          message: payload['eventType']?.toString(),
        );
        if (!_statusUpdateController.isClosed) {
          _statusUpdateController.add(event);
        }
      } catch (e) {
        debugPrint('❌ Error parsing geofence event: $e');
      }
    });
  }

  /// Join a specific order room for updates
  void joinOrderRoom(String orderId) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('❌ Cannot join tracking room: socket not connected');
      return;
    }

    debugPrint('🚪 Joining tracking room: $orderId');
    _socket?.emit('join_order', {'orderId': orderId});
  }

  /// Leave an order room
  void leaveOrderRoom(String orderId) {
    if (_socket == null || !_socket!.connected) {
      return;
    }

    debugPrint('🚪 Leaving tracking room: $orderId');
    _socket?.emit('leave_order', {'orderId': orderId});
  }

  /// Disconnect from socket
  void disconnect() {
    if (_socket == null) return;

    debugPrint('🔌 Disconnecting tracking socket');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    _locationUpdateController.close();
    _statusUpdateController.close();
    _connectionController.close();
  }

  /// Reconnect to socket
  void reconnect() {
    disconnect();
    connect();
  }
}
