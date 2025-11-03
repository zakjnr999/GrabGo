import 'dart:async';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_admin/features/restaurants/model/restaurant_response.dart';

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
      case const (RestaurantResponse):
        return RestaurantResponse.fromJson(data as Map<String, dynamic>);
      case const (RestaurantData):
        if (data is Map<String, dynamic>) {
          if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
            return RestaurantData.fromJson(data['data'] as Map<String, dynamic>);
          }
          return RestaurantData.fromJson(data);
        }
        return data;
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
    final method = request.method;

    debugPrint('📤 API Request Debug:');
    debugPrint('Method: $method');
    debugPrint('Path: $urlPath');
    debugPrint('Body: ${req.body}');
    debugPrint('Headers: ${req.headers}');

    final isLoginEndpoint = urlPath.endsWith('/users/login') && (method == 'POST');
    final isRestaurantUpdate = urlPath.contains('/restaurants/') && (method == 'PUT') && !urlPath.endsWith('/register');

    if (isLoginEndpoint || isRestaurantUpdate) {
      headers['API_KEY'] = AppConfig.apiKey;
      debugPrint('🔑 Added API_KEY header');
    }

    return req.copyWith(headers: headers, body: req.body);
  }
}
