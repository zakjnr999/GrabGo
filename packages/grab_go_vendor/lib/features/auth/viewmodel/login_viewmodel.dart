import 'package:flutter/material.dart';

class LoginViewModel extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  String? _emailError;
  String? _passwordError;

  bool get rememberMe => _rememberMe;
  bool get isPasswordVisible => _isPasswordVisible;
  String? get emailError => _emailError;
  String? get passwordError => _passwordError;

  void toggleRememberMe(bool? value) {
    _rememberMe = value ?? false;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  bool validate() {
    _emailError = null;
    _passwordError = null;

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty) {
      _emailError = 'Please enter your email address';
    } else if (!_isValidEmail(email)) {
      _emailError = 'Please enter a valid email address';
    }

    if (password.isEmpty) {
      _passwordError = 'Please enter your password';
    } else if (password.length < 8) {
      _passwordError = 'Password must be at least 8 characters';
    }

    notifyListeners();
    return _emailError == null && _passwordError == null;
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
