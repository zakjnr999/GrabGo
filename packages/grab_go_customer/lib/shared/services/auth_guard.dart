import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/user_service.dart';

class AuthGuard {
  static final AuthGuard _instance = AuthGuard._internal();
  factory AuthGuard() => _instance;
  AuthGuard._internal();

  static Future<void> checkAuthAndRedirect(BuildContext context) async {
    try {
      final isAuthenticated = UserService().isLoggedIn;
      if (!context.mounted) return;

      if (isAuthenticated) {
        context.go('/homepage');
      } else {
        context.go('/homepage');
      }
    } catch (e) {
      if (context.mounted) {
        context.go('/homepage');
      }
    }
  }

  static const Set<String> _protectedPaths = {
    '/cart',
    '/orders',
    '/favorites',
    '/credits',
    '/subscription',
    '/promos',
    '/referral',
    '/settings',
    '/checkout',
    '/editProfile',
    '/parcel',
    '/parcel/orders',
    '/mapTracking',
    '/orderTracking',
    '/paymentConfirming',
    '/paymentComplete',
    '/paymentFailed',
  };

  static bool requiresAuthenticationForUri(Uri uri) {
    if (_protectedPaths.contains(uri.path)) {
      return true;
    }

    return false;
  }

  static String loginRoute({String? returnTo}) {
    if (returnTo == null || returnTo.trim().isEmpty) {
      return '/login';
    }

    return '/login?returnTo=${Uri.encodeComponent(returnTo)}';
  }

  static String? redirectForState(GoRouterState state) {
    final uri = state.uri;
    final isAuthenticated = UserService().isLoggedIn;

    if (!isAuthenticated && requiresAuthenticationForUri(uri)) {
      return loginRoute(returnTo: uri.toString());
    }

    if (isAuthenticated && uri.path == '/login') {
      final returnTo = uri.queryParameters['returnTo'];
      if (returnTo != null && returnTo.trim().isNotEmpty) {
        return Uri.decodeComponent(returnTo);
      }
      return '/homepage';
    }

    return null;
  }

  static Future<bool> ensureAuthenticated(BuildContext context, {String? returnTo}) async {
    if (UserService().isLoggedIn) {
      return true;
    }

    if (!context.mounted) {
      return false;
    }

    await context.push(loginRoute(returnTo: returnTo));
    return false;
  }

  static Future<bool> isAuthenticated() async {
    try {
      return UserService().isLoggedIn;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> getAuthStatus() async {
    try {
      final isAuth = UserService().isLoggedIn;
      final user = UserService().currentUser;

      return {
        'isAuthenticated': isAuth,
        'hasUser': user != null,
        'username': user?.username,
        'email': user?.email,
        'userId': user?.id,
        'role': user?.role,
      };
    } catch (e) {
      return {'isAuthenticated': false, 'hasUser': false, 'error': e.toString()};
    }
  }
}
