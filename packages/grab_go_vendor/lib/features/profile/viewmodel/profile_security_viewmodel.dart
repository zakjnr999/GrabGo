import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/profile/model/vendor_profile_models.dart';

class ProfileSecurityViewModel extends ChangeNotifier {
  ProfileSecurityViewModel() {
    _sessions = List<VendorSessionDevice>.from(mockSessionDevices());

    businessNameController = TextEditingController(
      text: 'GrabGo Downtown Vendor Hub',
    );
    ownerNameController = TextEditingController(text: 'Ama Mensah');
    businessEmailController = TextEditingController(
      text: 'downtown@vendorhub.app',
    );
    phoneController = TextEditingController(text: '+233 24 120 3319');
    addressController = TextEditingController(text: '14 Ring Road West, Accra');

    currentPasswordController = TextEditingController();
    newPasswordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  late final TextEditingController businessNameController;
  late final TextEditingController ownerNameController;
  late final TextEditingController businessEmailController;
  late final TextEditingController phoneController;
  late final TextEditingController addressController;

  late final TextEditingController currentPasswordController;
  late final TextEditingController newPasswordController;
  late final TextEditingController confirmPasswordController;

  late List<VendorSessionDevice> _sessions;
  List<VendorSessionDevice> get sessions => List.unmodifiable(_sessions);

  bool _biometricEnabled = false;
  bool _twoFactorEnabled = true;
  bool _otpForSensitiveActions = true;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  String? _businessNameError;
  String? _ownerNameError;
  String? _businessEmailError;
  String? _phoneError;
  String? _addressError;
  String? _currentPasswordError;
  String? _newPasswordError;
  String? _confirmPasswordError;

  bool get biometricEnabled => _biometricEnabled;
  bool get twoFactorEnabled => _twoFactorEnabled;
  bool get otpForSensitiveActions => _otpForSensitiveActions;
  bool get hideCurrentPassword => _hideCurrentPassword;
  bool get hideNewPassword => _hideNewPassword;
  bool get hideConfirmPassword => _hideConfirmPassword;

  String? get businessNameError => _businessNameError;
  String? get ownerNameError => _ownerNameError;
  String? get businessEmailError => _businessEmailError;
  String? get phoneError => _phoneError;
  String? get addressError => _addressError;
  String? get currentPasswordError => _currentPasswordError;
  String? get newPasswordError => _newPasswordError;
  String? get confirmPasswordError => _confirmPasswordError;

  bool get hasOtherSessions => _sessions.any((session) => !session.isCurrent);

  void setBiometricEnabled(bool value) {
    if (_biometricEnabled == value) return;
    _biometricEnabled = value;
    notifyListeners();
  }

  void setTwoFactorEnabled(bool value) {
    if (_twoFactorEnabled == value) return;
    _twoFactorEnabled = value;
    notifyListeners();
  }

  void setOtpForSensitiveActions(bool value) {
    if (_otpForSensitiveActions == value) return;
    _otpForSensitiveActions = value;
    notifyListeners();
  }

  void toggleCurrentPasswordVisibility() {
    _hideCurrentPassword = !_hideCurrentPassword;
    notifyListeners();
  }

  void toggleNewPasswordVisibility() {
    _hideNewPassword = !_hideNewPassword;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _hideConfirmPassword = !_hideConfirmPassword;
    notifyListeners();
  }

  bool validateProfileForm() {
    _businessNameError = null;
    _ownerNameError = null;
    _businessEmailError = null;
    _phoneError = null;
    _addressError = null;

    var hasError = false;
    if (businessNameController.text.trim().isEmpty) {
      _businessNameError = 'Business name is required';
      hasError = true;
    }
    if (ownerNameController.text.trim().isEmpty) {
      _ownerNameError = 'Owner name is required';
      hasError = true;
    }
    final email = businessEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _businessEmailError = 'Enter a valid business email';
      hasError = true;
    }
    if (phoneController.text.trim().isEmpty) {
      _phoneError = 'Phone is required';
      hasError = true;
    }
    if (addressController.text.trim().isEmpty) {
      _addressError = 'Address is required';
      hasError = true;
    }

    notifyListeners();
    return !hasError;
  }

  bool validatePasswordForm() {
    _currentPasswordError = null;
    _newPasswordError = null;
    _confirmPasswordError = null;

    final current = currentPasswordController.text.trim();
    final next = newPasswordController.text.trim();
    final confirm = confirmPasswordController.text.trim();
    var hasError = false;

    if (current.isEmpty) {
      _currentPasswordError = 'Current password is required';
      hasError = true;
    }
    if (next.length < 8) {
      _newPasswordError = 'Use at least 8 characters';
      hasError = true;
    }
    if (confirm != next) {
      _confirmPasswordError = 'Passwords do not match';
      hasError = true;
    }

    notifyListeners();
    return !hasError;
  }

  void clearPasswordForm() {
    currentPasswordController.clear();
    newPasswordController.clear();
    confirmPasswordController.clear();
    _currentPasswordError = null;
    _newPasswordError = null;
    _confirmPasswordError = null;
    notifyListeners();
  }

  void revokeSession(String sessionId) {
    _sessions = _sessions.where((session) {
      if (session.id != sessionId) return true;
      return session.isCurrent;
    }).toList();
    notifyListeners();
  }

  void revokeOtherSessions() {
    _sessions = _sessions.where((session) => session.isCurrent).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    businessNameController.dispose();
    ownerNameController.dispose();
    businessEmailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
