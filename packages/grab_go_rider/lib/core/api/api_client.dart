import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;
import 'package:grab_go_rider/core/api/json_serializable_converter.dart' as local;

/// Interceptor that adds Bearer token to authenticated requests
class AuthInterceptor implements Interceptor {
  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    final request = chain.request;

    // Get token from cache
    final token = await CacheService.getAuthToken();

    if (token != null && token.isNotEmpty) {
      // Add Authorization header
      final authenticatedRequest = applyHeader(request, 'Authorization', 'Bearer $token');
      return chain.proceed(authenticatedRequest);
    }

    return chain.proceed(request);
  }
}

final chopperClient = ChopperClient(
  baseUrl: Uri.parse(AppConfig.apiBaseUrl),
  services: [FoodService.create(), AuthService.create(), RiderService.create()],
  converter: const local.JsonSerializableConverter(),
  interceptors: [
    AuthInterceptor(), // Add auth token to requests
    HttpLoggingInterceptor(),
  ],
  client: http.Client(),
);

final _foodService = FoodService.create(chopperClient);
final _authService = AuthService.create(chopperClient);
final _riderService = RiderService.create(chopperClient);

FoodService get foodService => _foodService;
AuthService get authService => _authService;
RiderService get riderService => _riderService;
