import 'package:flutter/material.dart';

class ForgotPasswordViewModel extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  String? _emailError;

  String? get emailError => _emailError;

  bool validate() {
    _emailError = null;
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _emailError = 'Please enter your email address';
    } else if (!_isValidEmail(email)) {
      _emailError = 'Please enter a valid email address';
    }

    notifyListeners();
    return _emailError == null;
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(value);
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }
}
