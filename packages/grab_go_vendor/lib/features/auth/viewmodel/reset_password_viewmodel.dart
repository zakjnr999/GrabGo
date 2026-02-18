import 'package:flutter/material.dart';

class ResetPasswordViewModel extends ChangeNotifier {
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _passwordError;
  String? _confirmPasswordError;

  bool get isPasswordVisible => _isPasswordVisible;
  bool get isConfirmPasswordVisible => _isConfirmPasswordVisible;
  String? get passwordError => _passwordError;
  String? get confirmPasswordError => _confirmPasswordError;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    notifyListeners();
  }

  bool validate() {
    _passwordError = null;
    _confirmPasswordError = null;

    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (password.isEmpty) {
      _passwordError = 'Please enter a new password';
    } else if (password.length < 8) {
      _passwordError = 'Password must be at least 8 characters';
    }

    if (confirmPassword.isEmpty) {
      _confirmPasswordError = 'Please confirm your new password';
    } else if (confirmPassword != password) {
      _confirmPasswordError = 'Passwords do not match';
    }

    notifyListeners();
    return _passwordError == null && _confirmPasswordError == null;
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
