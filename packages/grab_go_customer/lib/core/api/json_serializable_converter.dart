import 'dart:async';
import 'package:chopper/chopper.dart';
import 'package:grab_go_customer/features/auth/service/token_service.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurant_response.dart';
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
        // Use TokenService for synchronous token access
        final tokenService = TokenService();
        tokenService.getToken().then((token) {
          if (token != null && token.isNotEmpty) {
            headers['Authorization'] = 'Bearer $token';
          }
        });
      } catch (e) {
        // Silent error handling
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
