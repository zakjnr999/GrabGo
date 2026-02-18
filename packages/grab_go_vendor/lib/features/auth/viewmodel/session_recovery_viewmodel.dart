import 'package:flutter/material.dart';

enum SessionRecoveryMethod { emailLink, otpCode }

class SessionRecoveryViewModel extends ChangeNotifier {
  final TextEditingController accountController = TextEditingController();

  SessionRecoveryMethod _method = SessionRecoveryMethod.emailLink;
  bool _secureAllSessions = true;
  String? _accountError;

  SessionRecoveryMethod get method => _method;
  bool get secureAllSessions => _secureAllSessions;
  String? get accountError => _accountError;

  void setMethod(SessionRecoveryMethod value) {
    if (_method == value) {
      return;
    }
    _method = value;
    notifyListeners();
  }

  void setSecureAllSessions(bool value) {
    if (_secureAllSessions == value) {
      return;
    }
    _secureAllSessions = value;
    notifyListeners();
  }

  bool validate() {
    _accountError = null;
    final account = accountController.text.trim();
    if (account.isEmpty) {
      _accountError = 'Enter your business email or phone';
    } else if (!_isValidEmail(account) && !_isValidPhone(account)) {
      _accountError = 'Enter a valid business email or phone number';
    }

    notifyListeners();
    return _accountError == null;
  }

  bool _isValidEmail(String input) {
    final regex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(input);
  }

  bool _isValidPhone(String input) {
    final numeric = input.replaceAll(RegExp(r'[^0-9+]'), '');
    return numeric.length >= 10;
  }

  @override
  void dispose() {
    accountController.dispose();
    super.dispose();
  }
}
