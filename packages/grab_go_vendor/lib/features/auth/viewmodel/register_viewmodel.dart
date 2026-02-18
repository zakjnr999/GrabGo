import 'dart:io';

import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';

class RegisterViewModel extends ChangeNotifier {
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController businessEmailController = TextEditingController();
  final TextEditingController businessPhoneController = TextEditingController();
  final TextEditingController businessAddressController =
      TextEditingController();
  final TextEditingController businessIdController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController ownerPhoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _termsAccepted = false;

  final Set<VendorServiceType> _selectedServices = {VendorServiceType.food};

  File? _businessLogoImage;
  File? _businessIdImage;
  File? _ownerPhotoImage;
  File? _additionalDocumentImage;

  String? _businessNameError;
  String? _businessEmailError;
  String? _businessPhoneError;
  String? _businessAddressError;
  String? _businessIdError;
  String? _ownerNameError;
  String? _ownerPhoneError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _serviceError;
  String? _termsError;
  String? _businessLogoImageError;
  String? _businessIdImageError;
  String? _ownerPhotoImageError;

  bool get isPasswordVisible => _isPasswordVisible;
  bool get isConfirmPasswordVisible => _isConfirmPasswordVisible;
  bool get termsAccepted => _termsAccepted;
  Set<VendorServiceType> get selectedServices => _selectedServices;
  File? get businessLogoImage => _businessLogoImage;
  File? get businessIdImage => _businessIdImage;
  File? get ownerPhotoImage => _ownerPhotoImage;
  File? get additionalDocumentImage => _additionalDocumentImage;

  String? get businessNameError => _businessNameError;
  String? get businessEmailError => _businessEmailError;
  String? get businessPhoneError => _businessPhoneError;
  String? get businessAddressError => _businessAddressError;
  String? get businessIdError => _businessIdError;
  String? get ownerNameError => _ownerNameError;
  String? get ownerPhoneError => _ownerPhoneError;
  String? get passwordError => _passwordError;
  String? get confirmPasswordError => _confirmPasswordError;
  String? get serviceError => _serviceError;
  String? get termsError => _termsError;
  String? get businessLogoImageError => _businessLogoImageError;
  String? get businessIdImageError => _businessIdImageError;
  String? get ownerPhotoImageError => _ownerPhotoImageError;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    notifyListeners();
  }

  void toggleTermsAccepted(bool? value) {
    _termsAccepted = value ?? false;
    if (_termsAccepted) _termsError = null;
    notifyListeners();
  }

  void toggleService(VendorServiceType type) {
    if (_selectedServices.contains(type)) {
      _selectedServices.remove(type);
    } else {
      _selectedServices.add(type);
    }
    if (_selectedServices.isNotEmpty) _serviceError = null;
    notifyListeners();
  }

  void setBusinessLogoImage(File? file) {
    _businessLogoImage = file;
    if (file != null) _businessLogoImageError = null;
    notifyListeners();
  }

  void setBusinessIdImage(File? file) {
    _businessIdImage = file;
    if (file != null) _businessIdImageError = null;
    notifyListeners();
  }

  void setOwnerPhotoImage(File? file) {
    _ownerPhotoImage = file;
    if (file != null) _ownerPhotoImageError = null;
    notifyListeners();
  }

  void setAdditionalDocumentImage(File? file) {
    _additionalDocumentImage = file;
    notifyListeners();
  }

  bool validate() {
    _businessNameError = null;
    _businessEmailError = null;
    _businessPhoneError = null;
    _businessAddressError = null;
    _businessIdError = null;
    _ownerNameError = null;
    _ownerPhoneError = null;
    _passwordError = null;
    _confirmPasswordError = null;
    _serviceError = null;
    _termsError = null;
    _businessLogoImageError = null;
    _businessIdImageError = null;
    _ownerPhotoImageError = null;

    final businessName = businessNameController.text.trim();
    final businessEmail = businessEmailController.text.trim();
    final businessPhone = businessPhoneController.text.trim();
    final businessAddress = businessAddressController.text.trim();
    final businessId = businessIdController.text.trim();
    final ownerName = ownerNameController.text.trim();
    final ownerPhone = ownerPhoneController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (businessName.isEmpty) {
      _businessNameError = 'Please enter your business name';
    } else if (businessName.length < 2) {
      _businessNameError = 'Business name must be at least 2 characters';
    }

    if (businessEmail.isEmpty) {
      _businessEmailError = 'Please enter your business email';
    } else if (!_isValidEmail(businessEmail)) {
      _businessEmailError = 'Please enter a valid email address';
    }

    if (businessPhone.isEmpty) {
      _businessPhoneError = 'Please enter your business phone';
    } else if (businessPhone.length < 10) {
      _businessPhoneError = 'Phone number must be at least 10 digits';
    }

    if (businessAddress.isEmpty) {
      _businessAddressError = 'Please enter your business address';
    } else if (businessAddress.length < 10) {
      _businessAddressError = 'Address must be at least 10 characters';
    }

    if (businessId.isEmpty) {
      _businessIdError = 'Please enter your business ID';
    } else if (businessId.length < 5) {
      _businessIdError = 'Business ID must be at least 5 characters';
    }

    if (ownerName.isEmpty) {
      _ownerNameError = 'Please enter the owner full name';
    } else if (ownerName.length < 2) {
      _ownerNameError = 'Owner name must be at least 2 characters';
    }

    if (ownerPhone.isEmpty) {
      _ownerPhoneError = 'Please enter owner phone number';
    } else if (ownerPhone.length < 10) {
      _ownerPhoneError = 'Phone number must be at least 10 digits';
    }

    if (password.isEmpty) {
      _passwordError = 'Please enter a password';
    } else if (password.length < 8) {
      _passwordError = 'Password must be at least 8 characters';
    }

    if (confirmPassword.isEmpty) {
      _confirmPasswordError = 'Please confirm your password';
    } else if (confirmPassword != password) {
      _confirmPasswordError = 'Passwords do not match';
    }

    if (_selectedServices.isEmpty) {
      _serviceError = 'Select at least one service type';
    }

    if (!_termsAccepted) {
      _termsError = 'Please accept the terms to continue';
    }

    if (_businessLogoImage == null) {
      _businessLogoImageError = 'Please upload your business logo';
    }
    if (_businessIdImage == null) {
      _businessIdImageError = 'Please upload your business ID document';
    }
    if (_ownerPhotoImage == null) {
      _ownerPhotoImageError = 'Please upload owner verification photo';
    }

    notifyListeners();
    return _businessNameError == null &&
        _businessEmailError == null &&
        _businessPhoneError == null &&
        _businessAddressError == null &&
        _businessIdError == null &&
        _ownerNameError == null &&
        _ownerPhoneError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _serviceError == null &&
        _termsError == null &&
        _businessLogoImageError == null &&
        _businessIdImageError == null &&
        _ownerPhotoImageError == null;
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(value);
  }

  @override
  void dispose() {
    businessNameController.dispose();
    businessEmailController.dispose();
    businessPhoneController.dispose();
    businessAddressController.dispose();
    businessIdController.dispose();
    ownerNameController.dispose();
    ownerPhoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
