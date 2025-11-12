import 'dart:async';
import 'package:chopper/chopper.dart';
import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';

class AuthInterceptor implements Interceptor {
  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    final request = chain.request;
    debugPrint('🔄 AuthInterceptor: Processing ${request.method} ${request.url.path}');
    
    // Skip auth for login/register endpoints
    final urlPath = request.url.path;
    final isLoginEndpoint = urlPath.endsWith('/users/login') && (request.method == 'POST');
    final isRegisterEndpoint = urlPath.endsWith('/users') && (request.method == 'POST');
    
    if (isLoginEndpoint || isRegisterEndpoint) {
      debugPrint('🔄 AuthInterceptor: Skipping auth for ${request.url.path}');
      return chain.proceed(request);
    }
    
    // Add authorization token
    try {
      debugPrint('🔍 AuthInterceptor: Checking CacheService availability: ${CacheService.isCacheAvailable()}');
      
      final token = CacheService.getAuthToken();
      debugPrint('🔍 AuthInterceptor: Retrieved token: ${token != null ? "${token.substring(0, token.length > 20 ? 20 : token.length)}..." : "null"}');
      debugPrint('🔍 AuthInterceptor: Token length: ${token?.length ?? 0}');
      
      if (token != null && token.isNotEmpty) {
        final headers = Map<String, String>.from(request.headers);
        headers['Authorization'] = 'Bearer $token';
        
        debugPrint('🔑 ✅ AuthInterceptor: Token added to request for: ${request.url.path}');
        debugPrint('🔑 ✅ AuthInterceptor: Authorization header set: Bearer ${token.substring(0, 20)}...');
        debugPrint('🔑 ✅ AuthInterceptor: Final headers: ${headers.keys.toList()}');
        
        final modifiedRequest = request.copyWith(headers: headers);
        return chain.proceed(modifiedRequest);
      } else {
        debugPrint('⚠️ ❌ AuthInterceptor: No token found for request: ${request.url.path}');
        debugPrint('⚠️ ❌ AuthInterceptor: Token value: ${token ?? "null"}');
      }
    } catch (e) {
      debugPrint('❌ AuthInterceptor: Error getting token: $e');
    }
    
    return chain.proceed(request);
  }
}