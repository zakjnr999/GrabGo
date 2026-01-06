// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/core/api/api_client.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class RiderVerification extends StatefulWidget {
  const RiderVerification({super.key});

  @override
  State<RiderVerification> createState() => _RiderVerificationState();
}

class _RiderVerificationState extends State<RiderVerification> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final TextEditingController vehicleTypeController = TextEditingController();
  final TextEditingController licensePlateController = TextEditingController();
  final TextEditingController vehicleBrandController = TextEditingController();
  final TextEditingController vehicleModelController = TextEditingController();
  final TextEditingController nationalIdTypeController = TextEditingController();
  final TextEditingController nationalIdNumberController = TextEditingController();
  final TextEditingController paymentMethodController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController accountHolderNameController = TextEditingController();
  final TextEditingController mobileMoneyProviderController = TextEditingController();
  final TextEditingController mobileMoneyNumberController = TextEditingController();

  File? vehicleImage;
  File? idFrontImage;
  File? idBackImage;
  File? selfiePhoto;

  bool agreedToTerms = false;
  bool agreedToLocationAccess = false;
  bool agreedToAccuracy = false;

  String? vehicleTypeError;
  String? licensePlateError;
  String? nationalIdTypeError;
  String? nationalIdNumberError;

  String _formatDisplayName(String value) {
    return value.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  void _showVehicleTypeSelector() {
    final colors = context.appColors;
    final options = [
      {'value': 'motorcycle', 'label': 'Motorcycle'},
      {'value': 'bicycle', 'label': 'Bicycle'},
      {'value': 'car', 'label': 'Car'},
      {'value': 'scooter', 'label': 'Scooter'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderRadius8),
            topRight: Radius.circular(KBorderSize.borderRadius8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(top: 12.h, bottom: 20.h),
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                "Select Vehicle Type",
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
            ),
            SizedBox(height: 20.h),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = vehicleTypeController.text == option['value'];
                return ListTile(
                  title: Text(
                    option['label']!,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.accentOrange : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: colors.accentOrange, size: 24.sp) : null,
                  onTap: () {
                    setState(() {
                      vehicleTypeController.text = option['value']!;
                      vehicleTypeError = null;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  void _showNationalIdTypeSelector() {
    final colors = context.appColors;
    final options = [
      {'value': 'national_id', 'label': 'National ID'},
      {'value': 'passport', 'label': 'Passport'},
      {'value': 'drivers_license', 'label': "Driver's License"},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderRadius8),
            topRight: Radius.circular(KBorderSize.borderRadius8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(top: 12.h, bottom: 20.h),
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                "Select National ID Type",
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
            ),
            SizedBox(height: 20.h),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = nationalIdTypeController.text == option['value'];
                return ListTile(
                  title: Text(
                    option['label']!,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.accentOrange : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: colors.accentOrange, size: 24.sp) : null,
                  onTap: () {
                    setState(() {
                      nationalIdTypeController.text = option['value']!;
                      nationalIdTypeError = null;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethodSelector() {
    final colors = context.appColors;
    final options = [
      {'value': 'bank_account', 'label': 'Bank Account'},
      {'value': 'mobile_money', 'label': 'Mobile Money'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderRadius8),
            topRight: Radius.circular(KBorderSize.borderRadius8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(top: 12.h, bottom: 20.h),
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                "Select Payment Method",
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
            ),
            SizedBox(height: 20.h),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = paymentMethodController.text == option['value'];
                return ListTile(
                  title: Text(
                    option['label']!,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.accentOrange : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: colors.accentOrange, size: 24.sp) : null,
                  onTap: () {
                    setState(() {
                      paymentMethodController.text = option['value']!;
                      if (option['value'] == 'bank_account') {
                        mobileMoneyProviderController.clear();
                        mobileMoneyNumberController.clear();
                      } else {
                        bankNameController.clear();
                        accountNumberController.clear();
                        accountHolderNameController.clear();
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  void _showMobileMoneyProviderSelector() {
    final colors = context.appColors;
    final options = [
      {'value': 'mtn', 'label': 'MTN'},
      {'value': 'vodafone', 'label': 'Vodafone'},
      {'value': 'airtel', 'label': 'Airtel'},
      {'value': 'tigo', 'label': 'Tigo'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderRadius8),
            topRight: Radius.circular(KBorderSize.borderRadius8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(top: 12.h, bottom: 20.h),
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                "Select Mobile Money Provider",
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
            ),
            SizedBox(height: 20.h),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = mobileMoneyProviderController.text == option['value'];
                return ListTile(
                  title: Text(
                    option['label']!,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.accentOrange : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: colors.accentOrange, size: 24.sp) : null,
                  onTap: () {
                    setState(() {
                      mobileMoneyProviderController.text = option['value']!;
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    vehicleTypeController.dispose();
    licensePlateController.dispose();
    vehicleBrandController.dispose();
    vehicleModelController.dispose();
    nationalIdTypeController.dispose();
    nationalIdNumberController.dispose();
    paymentMethodController.dispose();
    bankNameController.dispose();
    accountNumberController.dispose();
    accountHolderNameController.dispose();
    mobileMoneyProviderController.dispose();
    mobileMoneyNumberController.dispose();
    super.dispose();
  }

  bool _hasFormBeenFilled() {
    return vehicleTypeController.text.isNotEmpty ||
        licensePlateController.text.isNotEmpty ||
        vehicleBrandController.text.isNotEmpty ||
        vehicleModelController.text.isNotEmpty ||
        nationalIdTypeController.text.isNotEmpty ||
        nationalIdNumberController.text.isNotEmpty ||
        paymentMethodController.text.isNotEmpty ||
        bankNameController.text.isNotEmpty ||
        accountNumberController.text.isNotEmpty ||
        accountHolderNameController.text.isNotEmpty ||
        mobileMoneyProviderController.text.isNotEmpty ||
        mobileMoneyNumberController.text.isNotEmpty ||
        vehicleImage != null ||
        idFrontImage != null ||
        idBackImage != null ||
        selfiePhoto != null ||
        agreedToTerms ||
        agreedToLocationAccess ||
        agreedToAccuracy;
  }

  Future<bool?> _handleGoBack() async {
    final shouldCancel = await AppDialog.show(
      context: context,
      title: 'Cancel Verification',
      message: 'Are you sure you want to cancel your verification? Your progress will be lost.',
      type: AppDialogType.warning,
      primaryButtonText: 'Cancel',
      secondaryButtonText: 'Continue',
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    return shouldCancel;
  }

  bool _validateFields() {
    setState(() {
      vehicleTypeError = null;
      licensePlateError = null;
      nationalIdTypeError = null;
      nationalIdNumberError = null;

      if (vehicleTypeController.text.trim().isEmpty) {
        vehicleTypeError = "Please select vehicle type";
      }
      if (licensePlateController.text.trim().isEmpty) {
        licensePlateError = "Please enter license plate number";
      }
      if (nationalIdTypeController.text.trim().isEmpty) {
        nationalIdTypeError = "Please select national ID type";
      }
      if (nationalIdNumberController.text.trim().isEmpty) {
        nationalIdNumberError = "Please enter national ID number";
      }
    });

    return vehicleTypeError == null &&
        licensePlateError == null &&
        nationalIdTypeError == null &&
        nationalIdNumberError == null;
  }

  Future<void> _submitVerification() async {
    if (!_validateFields()) {
      return;
    }

    if (!agreedToTerms || !agreedToLocationAccess || !agreedToAccuracy) {
      AppToastMessage.show(
        context: context,
        message: "Please agree to all terms and conditions",
        backgroundColor: context.appColors.error,
      );
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Submitting verification...");

    try {
      final response = await riderService.submitVerification(
        vehicleType: vehicleTypeController.text.trim(),
        licensePlateNumber: licensePlateController.text.trim(),
        vehicleBrand: vehicleBrandController.text.trim().isEmpty ? null : vehicleBrandController.text.trim(),
        vehicleModel: vehicleModelController.text.trim().isEmpty ? null : vehicleModelController.text.trim(),
        nationalIdType: nationalIdTypeController.text.trim(),
        nationalIdNumber: nationalIdNumberController.text.trim(),
        paymentMethod: paymentMethodController.text.trim().isEmpty ? null : paymentMethodController.text.trim(),
        bankName: bankNameController.text.trim().isEmpty ? null : bankNameController.text.trim(),
        accountNumber: accountNumberController.text.trim().isEmpty ? null : accountNumberController.text.trim(),
        accountHolderName: accountHolderNameController.text.trim().isEmpty
            ? null
            : accountHolderNameController.text.trim(),
        mobileMoneyProvider: mobileMoneyProviderController.text.trim().isEmpty
            ? null
            : mobileMoneyProviderController.text.trim(),
        mobileMoneyNumber: mobileMoneyNumberController.text.trim().isEmpty
            ? null
            : mobileMoneyNumberController.text.trim(),
        agreedToTerms: agreedToTerms.toString(),
        agreedToLocationAccess: agreedToLocationAccess.toString(),
        agreedToAccuracy: agreedToAccuracy.toString(),
        vehicleImagePath: vehicleImage?.path,
      );

      if (response.isSuccessful && response.body != null) {
        if (vehicleTypeController.text.trim().isNotEmpty) {
          await CacheService.saveVehicleType(vehicleTypeController.text.trim());
        }

        // Upload ID images separately after successful submission
        try {
          if (idFrontImage != null) {
            await riderService.uploadIdImage(imageType: 'front', imagePath: idFrontImage!.path);
          }
          if (idBackImage != null) {
            await riderService.uploadIdImage(imageType: 'back', imagePath: idBackImage!.path);
          }
          if (selfiePhoto != null) {
            await riderService.uploadIdImage(imageType: 'selfie', imagePath: selfiePhoto!.path);
          }
        } catch (e) {
          // Continue even if ID image upload fails
        }

        LoadingDialog.instance().hide();

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          context.push("/accountCreated");
        }
      } else {
        String errorMessage = "Failed to submit verification. Please try again.";
        if (response.error != null) {
          errorMessage = response.error.toString();
        }

        AppToastMessage.show(
          context: context,
          message: errorMessage,
          backgroundColor: context.appColors.error,
        );
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.instance().hide();
      }

      String errorMessage = "An error occurred. Please try again.";
      if (e.toString().contains('Connection reset') || e.toString().contains('SocketException')) {
        errorMessage = "Connection error. Please check your internet connection and try again.";
      } else if (e.toString().contains('Timeout')) {
        errorMessage = "Request timed out. Please try again.";
      } else if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        errorMessage = "Authentication failed. Please log in again.";
      } else if (e.toString().contains('403') || e.toString().contains('Forbidden')) {
        errorMessage = "You don't have permission to perform this action.";
      } else if (e.toString().contains('500') || e.toString().contains('Server')) {
        errorMessage = "Server error. Please try again later.";
      }

      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: errorMessage,
          backgroundColor: context.appColors.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 72,
        leading: SizedBox(
          height: KWidgetSize.buttonHeightSmall.h,
          width: KWidgetSize.buttonHeightSmall.w,
          child: Material(
            color: colors.backgroundPrimary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () async {
                if (_hasFormBeenFilled()) {
                  final shouldCancel = await _handleGoBack();
                  if (shouldCancel == true && mounted) {
                    context.pop();
                  }
                } else {
                  context.pop();
                }
              },
              customBorder: const CircleBorder(),
              splashColor: colors.iconSecondary.withAlpha(50),
              child: Padding(
                padding: EdgeInsets.all(KSpacing.md12.r),
                child: SvgPicture.asset(
                  Assets.icons.navArrowLeft,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
      body: PopScope(
        canPop: !_hasFormBeenFilled(),
        onPopInvoked: (bool didPop) async {
          if (didPop) return;
          if (_hasFormBeenFilled()) {
            final shouldCancel = await _handleGoBack();
            if (shouldCancel == true && mounted) {
              context.pop();
            }
          }
        },
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: ThemeHelper.getSystemUiOverlayStyle(context),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        height: 80.h,
                        width: 80.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          color: colors.accentOrange.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.icons.user,
                            package: 'grab_go_shared',
                            height: 50.h,
                            width: 50.h,
                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: KSpacing.lg25.h),

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        "Complete Your Verification",
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w900,
                          color: colors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: KSpacing.md.h),

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Text(
                        "We need a few details to confirm your identity and activate your rider account.",
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: KSpacing.xl40.h),

                  Text(
                    "Vehicle Information",
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  GestureDetector(
                    onTap: _showVehicleTypeSelector,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        border: Border.all(
                          color: vehicleTypeError != null ? colors.error : colors.inputBorder,
                          width: 1,
                        ),
                      ),
                      padding: EdgeInsets.all(KSpacing.md15.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Vehicle Type *",
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                          SizedBox(height: KSpacing.xs.h),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  vehicleTypeController.text.isEmpty
                                      ? "Choose your vehicle type"
                                      : _formatDisplayName(vehicleTypeController.text),
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w500,
                                    color: vehicleTypeController.text.isEmpty
                                        ? colors.textSecondary
                                        : colors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down, color: colors.textSecondary, size: 24.sp),
                            ],
                          ),
                          if (vehicleTypeError != null) ...[
                            SizedBox(height: KSpacing.xs.h),
                            Text(
                              vehicleTypeError!,
                              style: TextStyle(fontSize: 12.sp, color: colors.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: KSpacing.lg.h),

                  AppTextInput(
                    controller: licensePlateController,
                    label: "License Plate Number *",
                    hintText: "Enter your license plate number",
                    borderColor: colors.inputBorder,
                    fillColor: colors.backgroundSecondary,
                    borderRadius: KBorderSize.borderRadius4,
                    contentPadding: EdgeInsets.all(KSpacing.md15.r),
                    keyboardType: TextInputType.text,
                    errorText: licensePlateError,
                  ),
                  SizedBox(height: KSpacing.lg.h),

                  AppTextInput(
                    controller: vehicleBrandController,
                    label: "Vehicle Brand",
                    hintText: "Enter your vehicle brand",
                    borderColor: colors.inputBorder,
                    fillColor: colors.backgroundSecondary,
                    borderRadius: KBorderSize.borderRadius4,
                    contentPadding: EdgeInsets.all(KSpacing.md15.r),
                    keyboardType: TextInputType.text,
                  ),
                  SizedBox(height: KSpacing.lg.h),

                  AppTextInput(
                    controller: vehicleModelController,
                    label: "Vehicle Model",
                    hintText: "Enter your vehicle model",
                    borderColor: colors.inputBorder,
                    fillColor: colors.backgroundSecondary,
                    borderRadius: KBorderSize.borderRadius4,
                    contentPadding: EdgeInsets.all(KSpacing.md15.r),
                    keyboardType: TextInputType.text,
                  ),
                  SizedBox(height: KSpacing.lg.h),

                  ImageUploadWidget(
                    label: "Vehicle Image",
                    hintText: "Tap to select image",
                    borderRadius: KBorderSize.borderRadius4,
                    height: 120.h,
                    onImageSelected: (File? image) {
                      setState(() {
                        vehicleImage = image;
                      });
                    },
                    initialImage: vehicleImage,
                    successMessage: "Image uploaded successfully",
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  DottedLine(
                    direction: Axis.horizontal,
                    lineLength: double.infinity,
                    lineThickness: 1.5,
                    dashLength: 6,
                    dashColor: colors.inputBorder,
                    dashGapLength: 4,
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  Text(
                    "Identity Verification",
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  GestureDetector(
                    onTap: _showNationalIdTypeSelector,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        border: Border.all(
                          color: nationalIdTypeError != null ? colors.error : colors.inputBorder,
                          width: 1,
                        ),
                      ),
                      padding: EdgeInsets.all(KSpacing.md15.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "National ID Type *",
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                          SizedBox(height: KSpacing.xs.h),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  nationalIdTypeController.text.isEmpty
                                      ? "Choose your national ID type"
                                      : _formatDisplayName(nationalIdTypeController.text),
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w500,
                                    color: nationalIdTypeController.text.isEmpty
                                        ? colors.textSecondary
                                        : colors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down, color: colors.textSecondary, size: 24.sp),
                            ],
                          ),
                          if (nationalIdTypeError != null) ...[
                            SizedBox(height: KSpacing.xs.h),
                            Text(
                              nationalIdTypeError!,
                              style: TextStyle(fontSize: 12.sp, color: colors.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: KSpacing.lg.h),

                  AppTextInput(
                    controller: nationalIdNumberController,
                    label: "National ID Number *",
                    hintText: "Enter your national ID number",
                    borderColor: colors.inputBorder,
                    fillColor: colors.backgroundSecondary,
                    borderRadius: KBorderSize.borderRadius4,
                    contentPadding: EdgeInsets.all(KSpacing.md15.r),
                    keyboardType: TextInputType.text,
                    errorText: nationalIdNumberError,
                  ),

                  SizedBox(height: KSpacing.lg.h),

                  ImageUploadWidget(
                    label: "Upload ID (Front) *",
                    hintText: "Tap to select image",
                    borderRadius: KBorderSize.borderRadius4,
                    height: 120.h,
                    onImageSelected: (File? image) {
                      setState(() {
                        idFrontImage = image;
                      });
                    },
                    initialImage: idFrontImage,
                    successMessage: "Image uploaded successfully",
                  ),

                  SizedBox(height: KSpacing.lg.h),

                  ImageUploadWidget(
                    label: "Upload ID (Back) *",
                    hintText: "Tap to select image",
                    borderRadius: KBorderSize.borderRadius4,
                    height: 120.h,
                    onImageSelected: (File? image) {
                      setState(() {
                        idBackImage = image;
                      });
                    },
                    initialImage: idBackImage,
                    successMessage: "Image uploaded successfully",
                  ),

                  SizedBox(height: KSpacing.lg.h),

                  ImageUploadWidget(
                    label: "Upload Selfie Photo",
                    hintText: "Tap to select image",
                    borderRadius: KBorderSize.borderRadius4,
                    height: 120.h,
                    onImageSelected: (File? image) {
                      setState(() {
                        selfiePhoto = image;
                      });
                    },
                    initialImage: selfiePhoto,
                    successMessage: "Image uploaded successfully",
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  DottedLine(
                    direction: Axis.horizontal,
                    lineLength: double.infinity,
                    lineThickness: 1.5,
                    dashLength: 6,
                    dashColor: colors.inputBorder,
                    dashGapLength: 4,
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  Text(
                    "Payment Information \n(can be completed later)",
                    style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  GestureDetector(
                    onTap: _showPaymentMethodSelector,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        border: Border.all(color: colors.inputBorder, width: 1),
                      ),
                      padding: EdgeInsets.all(KSpacing.md15.r),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Payment Method *",
                            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                          SizedBox(height: KSpacing.xs.h),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  paymentMethodController.text.isEmpty
                                      ? "Choose your payment method"
                                      : _formatDisplayName(paymentMethodController.text),
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w500,
                                    color: paymentMethodController.text.isEmpty
                                        ? colors.textSecondary
                                        : colors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down, color: colors.textSecondary, size: 24.sp),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Show bank account fields if payment method is bank_account
                  if (paymentMethodController.text == 'bank_account') ...[
                    SizedBox(height: KSpacing.lg.h),
                    AppTextInput(
                      controller: bankNameController,
                      label: "Bank Name *",
                      hintText: "Enter your preferred bank name",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius4,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.text,
                    ),
                    SizedBox(height: KSpacing.lg.h),
                    AppTextInput(
                      controller: accountNumberController,
                      label: "Account Number *",
                      hintText: "Enter your account number",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius4,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.text,
                    ),
                    SizedBox(height: KSpacing.lg.h),
                    AppTextInput(
                      controller: accountHolderNameController,
                      label: "Account Holder Name *",
                      hintText: "Enter your account holder name",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius4,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.text,
                    ),
                  ],

                  // Show mobile money fields if payment method is mobile_money
                  if (paymentMethodController.text == 'mobile_money') ...[
                    SizedBox(height: KSpacing.lg.h),
                    GestureDetector(
                      onTap: _showMobileMoneyProviderSelector,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          border: Border.all(color: colors.inputBorder, width: 1),
                        ),
                        padding: EdgeInsets.all(KSpacing.md15.r),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Mobile Money Provider *",
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                            ),
                            SizedBox(height: KSpacing.xs.h),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    mobileMoneyProviderController.text.isEmpty
                                        ? "Choose your mobile money provider"
                                        : mobileMoneyProviderController.text == 'mtn'
                                        ? 'MTN'
                                        : mobileMoneyProviderController.text == 'vodafone'
                                        ? 'Vodafone'
                                        : mobileMoneyProviderController.text == 'airtel'
                                        ? 'Airtel'
                                        : mobileMoneyProviderController.text == 'tigo'
                                        ? 'Tigo'
                                        : mobileMoneyProviderController.text.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w500,
                                      color: mobileMoneyProviderController.text.isEmpty
                                          ? colors.textSecondary
                                          : colors.textPrimary,
                                    ),
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down, color: colors.textSecondary, size: 24.sp),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: KSpacing.lg.h),
                    AppTextInput(
                      controller: mobileMoneyNumberController,
                      label: "Mobile Money Number *",
                      hintText: "Enter your mobile money number",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius4,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.number,
                    ),
                  ],

                  SizedBox(height: KSpacing.lg.h),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: colors.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      border: Border.all(color: colors.accentOrange.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: SvgPicture.asset(
                            Assets.icons.shieldCheck,
                            package: 'grab_go_shared',
                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                          ),
                        ),
                        SizedBox(width: KSpacing.sm.w),
                        Expanded(
                          child: Text(
                            "These documents are securely stored and used only for verification. They help us verify you before approval.",
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: colors.textSecondary,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            agreedToTerms = !agreedToTerms;
                          });
                        },
                        child: Container(
                          width: 20.w,
                          height: 20.h,
                          decoration: BoxDecoration(
                            color: agreedToTerms ? colors.accentOrange : Colors.transparent,
                            border: Border.all(
                              color: agreedToTerms ? colors.accentOrange : colors.inputBorder,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: agreedToTerms ? Icon(Icons.check, color: Colors.white, size: 14.sp) : null,
                        ),
                      ),
                      SizedBox(width: KSpacing.sm.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              agreedToTerms = !agreedToTerms;
                            });
                          },
                          child: RichText(
                            text: TextSpan(
                              text: "I agree to the ",
                              style: TextStyle(
                                fontFamily: "Lato",
                                fontSize: 12.sp,
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                  text: "Terms & Conditions",
                                  style: TextStyle(
                                    fontFamily: "Lato",
                                    fontSize: 12.sp,
                                    color: colors.accentOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: " and ",
                                  style: TextStyle(fontFamily: "Lato", fontSize: 12.sp, color: colors.textSecondary),
                                ),
                                TextSpan(
                                  text: "Privacy Policy",
                                  style: TextStyle(
                                    fontFamily: "Lato",
                                    fontSize: 12.sp,
                                    color: colors.accentOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: KSpacing.lg.h),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            agreedToLocationAccess = !agreedToLocationAccess;
                          });
                        },
                        child: Container(
                          width: 20.w,
                          height: 20.h,
                          decoration: BoxDecoration(
                            color: agreedToLocationAccess ? colors.accentOrange : Colors.transparent,
                            border: Border.all(
                              color: agreedToLocationAccess ? colors.accentOrange : colors.inputBorder,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: agreedToLocationAccess ? Icon(Icons.check, color: Colors.white, size: 14.sp) : null,
                        ),
                      ),
                      SizedBox(width: KSpacing.sm.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              agreedToLocationAccess = !agreedToLocationAccess;
                            });
                          },
                          child: RichText(
                            text: TextSpan(
                              text: "I agree to the ",
                              style: TextStyle(
                                fontFamily: "Lato",
                                fontSize: 12.sp,
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(
                                  text: "Consent to Location Access",
                                  style: TextStyle(
                                    fontFamily: "Lato",
                                    fontSize: 12.sp,
                                    color: colors.accentOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: KSpacing.lg.h),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            agreedToAccuracy = !agreedToAccuracy;
                          });
                        },
                        child: Container(
                          width: 20.w,
                          height: 20.h,
                          decoration: BoxDecoration(
                            color: agreedToAccuracy ? colors.accentOrange : Colors.transparent,
                            border: Border.all(
                              color: agreedToAccuracy ? colors.accentOrange : colors.inputBorder,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: agreedToAccuracy ? Icon(Icons.check, color: Colors.white, size: 14.sp) : null,
                        ),
                      ),
                      SizedBox(width: KSpacing.sm.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              agreedToAccuracy = !agreedToAccuracy;
                            });
                          },
                          child: RichText(
                            text: TextSpan(
                              text: "I hereby agree that these information are accurate",
                              style: TextStyle(
                                fontFamily: "Lato",
                                fontSize: 12.sp,
                                color: colors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: KSpacing.xl40.h),

                  GestureDetector(
                    onTap: (agreedToTerms && agreedToLocationAccess && agreedToAccuracy) ? _submitVerification : null,
                    child: Container(
                      height: 56.h,
                      decoration: BoxDecoration(
                        gradient: (agreedToTerms && agreedToLocationAccess && agreedToAccuracy)
                            ? LinearGradient(
                                colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              )
                            : null,
                        color: (agreedToTerms && agreedToLocationAccess && agreedToAccuracy)
                            ? null
                            : colors.inputBorder,
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        boxShadow: (agreedToTerms && agreedToLocationAccess && agreedToAccuracy)
                            ? [
                                BoxShadow(
                                  color: colors.accentOrange.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          "Submit Registration",
                          style: TextStyle(
                            color: (agreedToTerms && agreedToLocationAccess && agreedToAccuracy)
                                ? Colors.white
                                : colors.textSecondary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: KSpacing.lg.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
