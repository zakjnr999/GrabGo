import 'dart:async';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

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
        debugPrint('⚠️ AUTH ERROR: Status ${response.statusCode} - May need API key');
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
    final req = super.convertRequest(request);
    final headers = Map<String, String>.from(req.headers);

    final urlPath = req.url.path;
    final isLoginEndpoint = urlPath.endsWith('/users/login') && (request.method == 'POST');

    if (isLoginEndpoint) {
      headers['API_KEY'] = AppConfig.apiKey;
    }

    final body = _convertBody(req.body);
    return req.copyWith(headers: headers, body: body);
  }

  /// Override this method in subclasses to handle specific request types
  dynamic _convertBody(dynamic body) {
    if (body is RegisterRequest) return body.toJson();
    if (body is LoginRequest) return body.toJson();
    if (body is GoogleSignInRequest) return body.toJson();
    if (body is PhoneVerificationRequest) return body.toJson();
    return body;
  }
}
