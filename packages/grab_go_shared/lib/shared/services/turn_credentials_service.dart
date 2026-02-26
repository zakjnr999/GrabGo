import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/config.dart';
import 'secure_storage_service.dart';

/// Service to fetch TURN credentials from the backend.
///
/// The backend owns provider secrets and returns short-lived ICE credentials.
class TurnCredentialsService {
  static const Duration _requestTimeout = Duration(seconds: 5);
  static const Duration _cacheTtl = Duration(minutes: 5);

  static DateTime? _cachedAt;
  static Map<String, dynamic>? _cachedPayload;

  static const List<Map<String, dynamic>> _stunOnlyFallback = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  /// Fetch TURN credentials from backend `/api/calls/turn-credentials`.
  static Future<Map<String, dynamic>> fetchTurnCredentials({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedPayload != null && _cachedAt != null) {
      final age = DateTime.now().difference(_cachedAt!);
      if (age <= _cacheTtl) {
        return _cachedPayload!;
      }
    }

    final token = await SecureStorageService.getAuthToken();
    if (token == null || token.isEmpty) {
      return _fallbackCredentials('missing_auth_token');
    }

    final apiBaseUrl = AppConfig.apiBaseUrl;
    if (apiBaseUrl.isEmpty) {
      return _fallbackCredentials('missing_api_base_url');
    }

    try {
      final normalizedBaseUrl = apiBaseUrl.endsWith('/')
          ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
          : apiBaseUrl;
      final response = await http
          .get(
            Uri.parse('$normalizedBaseUrl/api/calls/turn-credentials'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch TURN credentials (${response.statusCode})',
        );
      }

      final body = json.decode(response.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('TURN credentials payload must be a JSON object');
      }

      final iceServers = body['iceServers'];
      if (iceServers is! List || iceServers.isEmpty) {
        throw Exception('TURN credentials payload is missing iceServers');
      }

      final payload = {
        'iceServers': iceServers,
        'source': body['source'] ?? 'backend',
        'fetchedAt': DateTime.now().toIso8601String(),
      };

      _cachedPayload = payload;
      _cachedAt = DateTime.now();
      return payload;
    } catch (error) {
      debugPrint('Error fetching TURN credentials from backend: $error');
      return _fallbackCredentials('backend_fetch_failed');
    }
  }

  static Map<String, dynamic> _fallbackCredentials(String reason) {
    final payload = {
      'iceServers': _stunOnlyFallback,
      'source': 'fallback',
      'reason': reason,
      'fetchedAt': DateTime.now().toIso8601String(),
    };

    _cachedPayload = payload;
    _cachedAt = DateTime.now();
    return payload;
  }
}
