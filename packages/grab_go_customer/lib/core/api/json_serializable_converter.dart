import 'dart:async';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurant_response.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class JsonSerializableConverter extends JsonConverter {
  const JsonSerializableConverter();

  @override
  FutureOr<Response<BodyType>> convertResponse<BodyType, InnerType>(Response response) async {
    final Response jsonRes = await super.convertResponse(response);
    return jsonRes.copyWith<BodyType>(body: _convertToModel<BodyType>(jsonRes.body) as BodyType);
  }

  dynamic _convertToModel<T>(dynamic data) {
    if (data == null) return null;

    switch (T) {
      case const (UserResponse):
        return UserResponse.fromJson(data as Map<String, dynamic>);
      case const (User):
        return User.fromJson(data as Map<String, dynamic>);
      case const (UserPermissions):
        return UserPermissions.fromJson(data as Map<String, dynamic>);
      case const (PhoneVerificationRequest):
        return PhoneVerificationRequest.fromJson(data as Map<String, dynamic>);
      case const (RestaurantResponse):
        return RestaurantResponse.fromJson(data as Map<String, dynamic>);
      case const (RestaurantData):
        return RestaurantData.fromJson(data as Map<String, dynamic>);
      case const (Socials):
        return Socials.fromJson(data as Map<String, dynamic>);
      case const (List<RestaurantData>):
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          final listData = data['data'];
          if (listData is List) {
            return listData.map((item) => RestaurantData.fromJson(item as Map<String, dynamic>)).toList();
          }
        }
        if (data is List) {
          return data.map((item) => RestaurantData.fromJson(item as Map<String, dynamic>)).toList();
        }
        return data;
      default:
        return data;
    }
  }

  @override
  Request convertRequest(Request request) {
    debugPrint('🚨 ===== CONVERTER CALLED =====');
    debugPrint('🔄 JsonSerializableConverter.convertRequest() called');
    debugPrint('🔄 Request URL: ${request.url}');
    debugPrint('🔄 Request Method: ${request.method}');
    debugPrint('🔄 Request Headers: ${request.headers}');
    debugPrint('🚨 ===========================');
    
    final req = super.convertRequest(request);
    final headers = Map<String, String>.from(req.headers);

    final urlPath = req.url.path;
    final isLoginEndpoint = urlPath.endsWith('/users/login') && (request.method == 'POST');
    final isRegisterEndpoint = urlPath.endsWith('/users') && (request.method == 'POST');

    if (isLoginEndpoint) {
      headers['API_KEY'] = AppConfig.apiKey;
    }

    if (!isLoginEndpoint && !isRegisterEndpoint) {
      try {
        debugPrint('🔍 Converter: Processing ${req.method} ${req.url.path}');
        debugPrint('🔍 Converter: Checking CacheService availability: ${CacheService.isCacheAvailable()}');
        
        final token = CacheService.getAuthToken();
        debugPrint('🔍 Converter: Retrieved token from cache: ${token != null ? "${token.substring(0, token.length > 20 ? 20 : token.length)}..." : "null"}');
        debugPrint('🔍 Converter: Token length: ${token?.length ?? 0}');
        
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
          debugPrint('🔑 ✅ Converter: Token added to request for: ${req.url.path}');
          debugPrint('🔑 ✅ Converter: Authorization header set: Bearer ${token.substring(0, 20)}...');
          debugPrint('🔑 ✅ Converter: Final headers for ${req.url.path}: ${headers.keys.toList()}');
        } else {
          debugPrint('⚠️ ❌ Converter: No token found for request: ${req.url.path}');
          debugPrint('⚠️ ❌ Converter: Token value: ${token ?? "null"}');
          debugPrint('⚠️ ❌ Converter: Token empty: ${token?.isEmpty ?? "token is null"}');
          
          // Try alternative token retrieval methods as fallback
          try {
            final userData = CacheService.getUserData();
            debugPrint('🔄 Converter: Trying fallback from userData...');
            if (userData != null && userData.containsKey('token')) {
              final fallbackToken = userData['token'] as String?;
              if (fallbackToken != null && fallbackToken.isNotEmpty) {
                headers['Authorization'] = 'Bearer $fallbackToken';
                debugPrint('🔄 ✅ Converter: Fallback token from userData used for: ${req.url.path}');
              } else {
                debugPrint('🔄 ❌ Converter: Fallback token is null or empty');
              }
            } else {
              debugPrint('🔄 ❌ Converter: No userData or no token key in userData');
            }
          } catch (fallbackError) {
            debugPrint('🔄 ❌ Converter: Fallback token retrieval failed: $fallbackError');
          }
        }
        
        debugPrint('🔍 Converter: Request headers after processing: ${headers.keys.toList()}');
        debugPrint('🔍 Converter: Authorization header value: ${headers['Authorization'] ?? "NOT SET"}');
        
      } catch (e) {
        debugPrint('❌ Converter: Error getting token from CacheService: $e');
        debugPrint('❌ Converter: This might mean CacheService is not initialized');
        debugPrint('❌ Converter: CacheService available: ${CacheService.isCacheAvailable()}');
      }
    }

    final body = _convertBody(req.body);
    return req.copyWith(headers: headers, body: body);
  }

  dynamic _convertBody(dynamic body) {
    if (body is RegisterRequest) {
      return body.toJson();
    }
    if (body is LoginRequest) {
      return body.toJson();
    }
    if (body is GoogleSignInRequest) {
      return body.toJson();
    }
    if (body is PhoneVerificationRequest) {
      return body.toJson();
    }
    return body;
  }
}
