import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service to get unique device identifier
class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService _instance = DeviceIdService._();
  factory DeviceIdService() => _instance;

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String? _cachedDeviceId;

  /// Get unique device ID
  /// This ID is used to prevent duplicate FCM token registration.
  /// It is guaranteed to return a non-null, non-empty string.
  Future<String> getDeviceId() async {
    // Validate cached ID before returning
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty && _cachedDeviceId!.trim().isNotEmpty) {
      return _cachedDeviceId!;
    }

    try {
      String? deviceId;

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        debugPrint('Device ID (Android): $deviceId');
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = iosInfo.identifierForVendor;
        debugPrint('Device ID (iOS): $deviceId');
      } else {
        debugPrint('Unsupported platform for device ID, using fallback');
      }

      // Validate before caching - check for null, empty, or whitespace-only
      if (deviceId == null || deviceId.isEmpty || deviceId.trim().isEmpty) {
        debugPrint('Invalid device ID, using fallback');
        deviceId = await _getFallbackDeviceId();
      }

      _cachedDeviceId = deviceId;
      return _cachedDeviceId!;
    } catch (e) {
      debugPrint('Error getting device ID: $e, using fallback');
      _cachedDeviceId = await _getFallbackDeviceId();
      return _cachedDeviceId!;
    }
  }

  /// Get or generate fallback device ID persisted in SharedPreferences
  Future<String> _getFallbackDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? fallbackId = prefs.getString('fallback_device_id');

      if (fallbackId == null || fallbackId.isEmpty) {
        fallbackId = const Uuid().v4();
        await prefs.setString('fallback_device_id', fallbackId);
        debugPrint('Generated and saved fallback device ID: $fallbackId');
      } else {
        debugPrint('Using existing fallback device ID: $fallbackId');
      }
      return fallbackId;
    } catch (e) {
      debugPrint('Error accessing SharedPreferences for fallback ID: $e');
      return const Uuid().v4(); // Temporary fallback
    }
  }

  /// Clear cached device ID (for testing)
  void clearCache() {
    _cachedDeviceId = null;
  }
}
