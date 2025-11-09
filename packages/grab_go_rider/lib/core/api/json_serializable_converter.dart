import 'dart:async';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_rider/shared/service/cache_service.dart';

class JsonSerializableConverter extends JsonConverter {
  const JsonSerializableConverter();

  @override
  FutureOr<Response<BodyType>> convertResponse<BodyType, InnerType>(Response response) async {
    final Response jsonRes = await super.convertResponse(response);

    debugPrint('📥 API Response Debug:');
    debugPrint('Status Code: ${response.statusCode}');
    debugPrint('✅ Success: ${response.isSuccessful}');
    debugPrint('Headers: ${response.headers}');
    debugPrint('Body: ${jsonRes.body}');

    if (!response.isSuccessful) {
      final bodyStr = jsonRes.body.toString().toLowerCase();
      if (bodyStr.contains('api') && bodyStr.contains('key')) {
        debugPrint('⚠️ ERROR: Response may indicate API key is required!');
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        debugPrint('⚠️ AUTH ERROR: Status ${response.statusCode} - May need auth token');
      }
    }

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
      default:
        return data;
    }
  }

  @override
  Request convertRequest(Request request) {
    debugPrint('🔄 convertRequest called for: ${request.method} ${request.url.path}');
    final req = super.convertRequest(request);
    final headers = Map<String, String>.from(req.headers);

    final urlPath = req.url.path;
    final isLoginEndpoint = urlPath.endsWith('/users/login') && (request.method == 'POST');
    final isRegisterEndpoint = urlPath.endsWith('/users') && (request.method == 'POST');

    debugPrint('   isLoginEndpoint: $isLoginEndpoint, isRegisterEndpoint: $isRegisterEndpoint');

    // Add API key for login endpoint
    if (isLoginEndpoint) {
      headers['API_KEY'] = AppConfig.apiKey;
    }

    // Add auth token for protected endpoints (not login/register)
    if (!isLoginEndpoint && !isRegisterEndpoint) {
      final token = CacheService.getAuthToken();
      debugPrint('🔍 Checking auth token for: ${request.url.path}');
      debugPrint('   Token exists: ${token != null}');
      debugPrint('   Token length: ${token?.length ?? 0}');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        debugPrint('✅ Adding auth token to request: ${request.url.path}');
        debugPrint('   Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      } else {
        debugPrint('❌ No auth token found for protected endpoint: ${request.url.path}');
        debugPrint('   Please ensure you are logged in or have registered recently.');
      }
    }

    final body = _convertBody(req.body);
    return req.copyWith(headers: headers, body: body);
  }

  /// Override this method in subclasses to handle specific request types
  dynamic _convertBody(dynamic body) {
    if (body is RegisterRequest) {
      final json = body.toJson();
      debugPrint('🔄 Converting RegisterRequest to JSON:');
      debugPrint('   Role: ${body.role}');
      debugPrint('   JSON: $json');
      return json;
    }
    if (body is LoginRequest) return body.toJson();
    if (body is GoogleSignInRequest) {
      final json = body.toJson();
      debugPrint('🔄 Converting GoogleSignInRequest to JSON:');
      debugPrint('   Role: ${body.role}');
      debugPrint('   JSON: $json');
      return json;
    }
    if (body is PhoneVerificationRequest) return body.toJson();
    return body;
  }
}
