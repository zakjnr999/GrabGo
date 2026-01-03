import 'dart:async';
import 'package:chopper/chopper.dart';
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
      case const (RiderResponse):
        return RiderResponse.fromJson(data as Map<String, dynamic>);
      case const (Rider):
        return Rider.fromJson(data as Map<String, dynamic>);
      default:
        return data;
    }
  }

  @override
  Request convertRequest(Request request) {
    final req = super.convertRequest(request);
    final headers = <String, String>{};
    headers.addAll(req.headers);

    final urlPath = req.url.path;
    final isLoginEndpoint = urlPath.endsWith('/users/login') && (request.method == 'POST');
    final isRegisterEndpoint = urlPath.endsWith('/users') && (request.method == 'POST');

    // Add API key for login endpoint
    if (isLoginEndpoint) {
      headers['API_KEY'] = AppConfig.apiKey;
    }

    // Add auth token for protected endpoints (not login/register)
    // Note: This uses .then() to handle async token retrieval in a sync method
    if (!isLoginEndpoint && !isRegisterEndpoint) {
      CacheService.getAuthToken().then((token) {
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      });
    }

    // Filter out null values from multipart requests
    if (req.multipart && req.parts.isNotEmpty) {
      final filteredParts = <PartValue>[];
      for (final part in req.parts) {
        if (part is PartValueFile) {
          final value = part.value;
          if (value != null && value.toString().isNotEmpty) {
            filteredParts.add(part);
          }
        } else {
          final value = part.value;
          if (value != null && value.toString().isNotEmpty) {
            filteredParts.add(part);
          }
        }
      }

      final body = _convertBody(req.body);
      final newRequest = req.copyWith(headers: headers, body: body, parts: filteredParts);
      return newRequest;
    }

    final body = _convertBody(req.body);
    final newRequest = req.copyWith(headers: headers, body: body);
    return newRequest;
  }

  /// Override this method in subclasses to handle specific request types
  dynamic _convertBody(dynamic body) {
    if (body is RegisterRequest) {
      return body.toJson();
    }
    if (body is LoginRequest) return body.toJson();
    if (body is GoogleSignInRequest) {
      return body.toJson();
    }
    if (body is PhoneVerificationRequest) return body.toJson();
    return body;
  }
}
