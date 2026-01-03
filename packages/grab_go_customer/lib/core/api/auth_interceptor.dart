import 'dart:async';
import 'package:chopper/chopper.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

class AuthInterceptor implements Interceptor {
  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    final request = chain.request;

    // Skip auth for login/register endpoints
    final urlPath = request.url.path;
    final isLoginEndpoint = urlPath.endsWith('/users/login') && (request.method == 'POST');
    final isRegisterEndpoint = urlPath.endsWith('/users') && (request.method == 'POST');

    if (isLoginEndpoint || isRegisterEndpoint) {
      return chain.proceed(request);
    }

    // Add authorization token
    try {
      final token = await CacheService.getAuthToken();

      if (token != null && token.isNotEmpty) {
        final headers = Map<String, String>.from(request.headers);
        headers['Authorization'] = 'Bearer $token';

        final modifiedRequest = request.copyWith(headers: headers);
        return chain.proceed(modifiedRequest);
      }
    } catch (e) {
      // Silent error handling
    }

    return chain.proceed(request);
  }
}
