import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/tracking_models.dart';

/// Service for real-time tracking updates via Socket.IO
class TrackingSocketService {
  IO.Socket? _socket;
  final String serverUrl;
  final String token;

  // Stream controllers for different events
  final _locationUpdateController = StreamController<LocationUpdateEvent>.broadcast();
  final _statusUpdateController = StreamController<StatusUpdateEvent>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Public streams
  Stream<LocationUpdateEvent> get locationUpdates => _locationUpdateController.stream;
  Stream<StatusUpdateEvent> get statusUpdates => _statusUpdateController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;

  TrackingSocketService({required this.serverUrl, required this.token});

  /// Connect to Socket.IO server
  void connect() {
    if (_socket != null && _socket!.connected) {
      print('✅ Socket already connected');
      return;
    }

    print('🔌 Connecting to socket: $serverUrl');

    _socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': 'Bearer $token'})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
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
      print('✅ Socket connected successfully');
      _connectionController.add(true);
    });

    _socket?.on('disconnect', (_) {
      print('❌ Socket disconnected');
      _connectionController.add(false);
    });

    _socket?.on('connect_error', (error) {
      print('❌ Socket connection error: $error');
      _connectionController.add(false);
    });

    _socket?.on('reconnect', (attempt) {
      print('🔄 Socket reconnected after $attempt attempts');
      _connectionController.add(true);
    });

    _socket?.on('reconnect_attempt', (attempt) {
      print('🔄 Socket reconnection attempt $attempt');
    });

    _socket?.on('reconnect_error', (error) {
      print('❌ Socket reconnection error: $error');
    });

    _socket?.on('reconnect_failed', (_) {
      print('❌ Socket reconnection failed');
      _connectionController.add(false);
    });

    // Tracking events
    _socket?.on('location_update', (data) {
      print('📍 Location update received: $data');
      try {
        final event = LocationUpdateEvent.fromJson(data as Map<String, dynamic>);
        _locationUpdateController.add(event);
      } catch (e) {
        print('❌ Error parsing location update: $e');
      }
    });

    _socket?.on('order_status_update', (data) {
      print('📊 Status update received: $data');
      try {
        final event = StatusUpdateEvent.fromJson(data as Map<String, dynamic>);
        _statusUpdateController.add(event);
      } catch (e) {
        print('❌ Error parsing status update: $e');
      }
    });

    // Geofence events
    _socket?.on('geofence_entered', (data) {
      print('🎯 Geofence entered: $data');
      // Handle geofence events (e.g., rider arrived at restaurant)
    });

    _socket?.on('rider_nearby', (data) {
      print('🚴 Rider nearby: $data');
      // Handle rider nearby event
    });
  }

  /// Join a specific order room for updates
  void joinOrderRoom(String orderId) {
    if (_socket == null || !_socket!.connected) {
      print('❌ Cannot join room: Socket not connected');
      return;
    }

    print('🚪 Joining order room: $orderId');
    _socket?.emit('join_order', {'orderId': orderId});
  }

  /// Leave an order room
  void leaveOrderRoom(String orderId) {
    if (_socket == null || !_socket!.connected) {
      return;
    }

    print('🚪 Leaving order room: $orderId');
    _socket?.emit('leave_order', {'orderId': orderId});
  }

  /// Disconnect from socket
  void disconnect() {
    if (_socket == null) return;

    print('🔌 Disconnecting socket');
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connectionController.add(false);
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
