import 'dart:async';

import 'package:flutter/material.dart';

class OtpVerificationViewModel extends ChangeNotifier {
  final TextEditingController codeController = TextEditingController();
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  String? _codeError;

  int get secondsRemaining => _secondsRemaining;
  bool get canResend => _canResend;
  String? get codeError => _codeError;

  OtpVerificationViewModel() {
    startCountdown();
  }

  void startCountdown() {
    _timer?.cancel();
    _secondsRemaining = 60;
    _canResend = false;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        _secondsRemaining = 0;
        _canResend = true;
        timer.cancel();
      } else {
        _secondsRemaining--;
      }
      notifyListeners();
    });
  }

  void resendCode() {
    if (!_canResend) return;
    codeController.clear();
    _codeError = null;
    startCountdown();
  }

  bool validateCode() {
    final code = codeController.text.trim();
    _codeError = null;

    if (code.isEmpty) {
      _codeError = 'Please enter the verification code';
    } else if (code.length != 6) {
      _codeError = 'Verification code must be 6 digits';
    } else if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _codeError = 'Verification code must contain only digits';
    }

    notifyListeners();
    return _codeError == null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    codeController.dispose();
    super.dispose();
  }
}
