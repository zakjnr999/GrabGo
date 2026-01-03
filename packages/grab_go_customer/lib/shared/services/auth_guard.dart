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
      if (isAuthenticated) {
        if (context.mounted) {
          context.go('/homepage');
        }
      } else {
        if (context.mounted) {
          context.go('/login');
        }
      }
    } catch (e) {
      if (context.mounted) {
        context.go('/login');
      }
    }
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
      return {
        'isAuthenticated': false,
        'hasUser': false,
        'error': e.toString(),
      };
    }
  }
}


