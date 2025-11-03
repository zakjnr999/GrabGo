// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurant_registration_data.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class RestaurantRegistration extends StatefulWidget {
  const RestaurantRegistration({super.key});

  @override
  State<RestaurantRegistration> createState() => _RestaurantRegistrationState();
}

class _RestaurantRegistrationState extends State<RestaurantRegistration> with SingleTickerProviderStateMixin {
  final TextEditingController restaurantNameController = TextEditingController();
  final TextEditingController restaurantEmailController = TextEditingController();
  final TextEditingController restaurantPhoneController = TextEditingController();
  final TextEditingController restaurantAddressController = TextEditingController();
  final TextEditingController restaurantCityController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController ownerPhoneController = TextEditingController();
  final TextEditingController businessIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  String? restaurantNameError;
  String? restaurantEmailError;
  String? restaurantPhoneError;
  String? restaurantAddressError;
  String? restaurantCityError;
  String? ownerNameError;
  String? ownerPhoneError;
  String? businessIdError;
  String? passwordError;
  String? confirmPasswordError;
  String? logoImageError;
  String? businessIdImageError;
  String? ownerPhotoError;

  File? _selectedLogoImage;
  File? _selectedBusinessIdImage;
  File? _selectedOwnerPhotoImage;

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isTermsAccepted = false;
  bool hasPendingApplication = false;
  bool _hasStartedFillingForm = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

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

    _checkPendingApplication();
    _setupTextControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      _animationController.forward();
    });
  }

  Future<void> _checkPendingApplication() async {
    final hasApplication = await StorageService.hasRestaurantApplicationSubmitted();
    final isCompleted = await StorageService.isRestaurantApplicationCompleted();

    if (mounted) {
      setState(() {
        hasPendingApplication = hasApplication && !isCompleted;
      });
    }
  }

  void _setupTextControllers() {
    void checkIfFormStarted() {
      final hasAnyText =
          restaurantNameController.text.isNotEmpty ||
          restaurantEmailController.text.isNotEmpty ||
          restaurantPhoneController.text.isNotEmpty ||
          restaurantAddressController.text.isNotEmpty ||
          restaurantCityController.text.isNotEmpty ||
          ownerNameController.text.isNotEmpty ||
          ownerPhoneController.text.isNotEmpty ||
          businessIdController.text.isNotEmpty ||
          passwordController.text.isNotEmpty ||
          confirmPasswordController.text.isNotEmpty ||
          _selectedLogoImage != null ||
          _selectedBusinessIdImage != null ||
          _selectedOwnerPhotoImage != null;

      if (hasAnyText && !_hasStartedFillingForm) {
        setState(() {
          _hasStartedFillingForm = true;
        });
      }
    }

    restaurantNameController.addListener(checkIfFormStarted);
    restaurantEmailController.addListener(checkIfFormStarted);
    restaurantPhoneController.addListener(checkIfFormStarted);
    restaurantAddressController.addListener(checkIfFormStarted);
    restaurantCityController.addListener(checkIfFormStarted);
    ownerNameController.addListener(checkIfFormStarted);
    ownerPhoneController.addListener(checkIfFormStarted);
    businessIdController.addListener(checkIfFormStarted);
    passwordController.addListener(checkIfFormStarted);
    confirmPasswordController.addListener(checkIfFormStarted);
  }

  bool _hasFormBeenFilled() {
    return restaurantNameController.text.isNotEmpty ||
        restaurantEmailController.text.isNotEmpty ||
        restaurantPhoneController.text.isNotEmpty ||
        restaurantAddressController.text.isNotEmpty ||
        restaurantCityController.text.isNotEmpty ||
        ownerNameController.text.isNotEmpty ||
        ownerPhoneController.text.isNotEmpty ||
        businessIdController.text.isNotEmpty ||
        passwordController.text.isNotEmpty ||
        confirmPasswordController.text.isNotEmpty ||
        _selectedLogoImage != null ||
        _selectedBusinessIdImage != null ||
        _selectedOwnerPhotoImage != null;
  }

  @override
  void dispose() {
    _animationController.dispose();
    restaurantNameController.dispose();
    restaurantEmailController.dispose();
    restaurantPhoneController.dispose();
    restaurantAddressController.dispose();
    restaurantCityController.dispose();
    ownerNameController.dispose();
    ownerPhoneController.dispose();
    businessIdController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateFields() {
    setState(() {
      restaurantNameError = null;
      restaurantEmailError = null;
      restaurantPhoneError = null;
      restaurantAddressError = null;
      restaurantCityError = null;
      ownerNameError = null;
      ownerPhoneError = null;
      businessIdError = null;
      passwordError = null;
      confirmPasswordError = null;
      logoImageError = null;
      businessIdImageError = null;
      ownerPhotoError = null;

      if (restaurantNameController.text.trim().isEmpty) {
        restaurantNameError = "Please enter your restaurant name";
      } else if (restaurantNameController.text.trim().length < 2) {
        restaurantNameError = "Restaurant name must be at least 2 characters";
      } else if (restaurantNameController.text.trim().length > 100) {
        restaurantNameError = "Restaurant name must be at most 100 characters";
      } else if (!RegExp(r'^[a-zA-Z0-9\s\-&.,]+$').hasMatch(restaurantNameController.text.trim())) {
        restaurantNameError = "Restaurant name contains invalid characters";
      }

      if (restaurantEmailController.text.trim().isEmpty) {
        restaurantEmailError = "Please enter your restaurant email address";
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(restaurantEmailController.text.trim())) {
        restaurantEmailError = "Please enter a valid email address";
      }

      if (restaurantPhoneController.text.trim().isEmpty) {
        restaurantPhoneError = "Please enter your restaurant phone number";
      } else if (restaurantPhoneController.text.trim().length < 10) {
        restaurantPhoneError = "Phone number must be at least 10 digits";
      } else if (restaurantPhoneController.text.trim().length > 15) {
        restaurantPhoneError = "Phone number must be at most 15 digits";
      } else if (!RegExp(r'^[0-9+\-\s\(\)]+$').hasMatch(restaurantPhoneController.text.trim())) {
        restaurantPhoneError = "Please enter a valid phone number";
      }

      if (restaurantAddressController.text.trim().isEmpty) {
        restaurantAddressError = "Please enter your restaurant address";
      } else if (restaurantAddressController.text.trim().length < 10) {
        restaurantAddressError = "Address must be at least 10 characters";
      } else if (restaurantAddressController.text.trim().length > 200) {
        restaurantAddressError = "Address must be at most 200 characters";
      }

      if (restaurantCityController.text.trim().isEmpty) {
        restaurantCityError = "Please enter your restaurant city";
      } else if (restaurantCityController.text.trim().length < 2) {
        restaurantCityError = "City name must be at least 2 characters";
      } else if (restaurantCityController.text.trim().length > 50) {
        restaurantCityError = "City name must be at most 50 characters";
      } else if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(restaurantCityController.text.trim())) {
        restaurantCityError = "City name contains invalid characters";
      }

      if (ownerNameController.text.trim().isEmpty) {
        ownerNameError = "Please enter your full name";
      } else if (ownerNameController.text.trim().length < 2) {
        ownerNameError = "Name must be at least 2 characters";
      } else if (ownerNameController.text.trim().length > 50) {
        ownerNameError = "Name must be at most 50 characters";
      } else if (!RegExp(r'^[a-zA-Z\s\-\.]+$').hasMatch(ownerNameController.text.trim())) {
        ownerNameError = "Name contains invalid characters";
      }

      if (ownerPhoneController.text.trim().isEmpty) {
        ownerPhoneError = "Please enter your phone number";
      } else if (ownerPhoneController.text.trim().length < 10) {
        ownerPhoneError = "Phone number must be at least 10 digits";
      } else if (ownerPhoneController.text.trim().length > 15) {
        ownerPhoneError = "Phone number must be at most 15 digits";
      } else if (!RegExp(r'^[0-9+\-\s\(\)]+$').hasMatch(ownerPhoneController.text.trim())) {
        ownerPhoneError = "Please enter a valid phone number";
      }

      if (businessIdController.text.trim().isEmpty) {
        businessIdError = "Please enter your business ID";
      } else if (businessIdController.text.trim().length < 5) {
        businessIdError = "Business ID must be at least 5 characters";
      } else if (businessIdController.text.trim().length > 50) {
        businessIdError = "Business ID must be at most 50 characters";
      } else if (!RegExp(r'^[a-zA-Z0-9\-\s]+$').hasMatch(businessIdController.text.trim())) {
        businessIdError = "Business ID contains invalid characters";
      }

      if (passwordController.text.isEmpty) {
        passwordError = "Please enter a password";
      } else if (passwordController.text.length < 8) {
        passwordError = "Password must be at least 8 characters";
      } else if (passwordController.text.length > 128) {
        passwordError = "Password must be at most 128 characters";
      } else if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(passwordController.text)) {
        passwordError = "Password must contain uppercase, lowercase, and number";
      } else if (passwordController.text.contains(' ')) {
        passwordError = "Password cannot contain spaces";
      }

      if (confirmPasswordController.text.isEmpty) {
        confirmPasswordError = "Please confirm your password";
      } else if (passwordController.text != confirmPasswordController.text) {
        confirmPasswordError = "Passwords do not match";
      }

      if (_selectedLogoImage == null) {
        logoImageError = "Please upload your restaurant logo";
      }
      if (_selectedBusinessIdImage == null) {
        businessIdImageError = "Please upload your business ID document";
      }
      if (_selectedOwnerPhotoImage == null) {
        ownerPhotoError = "Please upload your owner photo";
      }
    });

    return restaurantNameError == null &&
        restaurantEmailError == null &&
        restaurantPhoneError == null &&
        restaurantAddressError == null &&
        restaurantCityError == null &&
        ownerNameError == null &&
        ownerPhoneError == null &&
        businessIdError == null &&
        passwordError == null &&
        confirmPasswordError == null &&
        logoImageError == null &&
        businessIdImageError == null &&
        ownerPhotoError == null;
  }

  Future<bool?> _handleGoBack() async {
    final shouldCancel = await AppDialog.show(
      context: context,
      title: 'Cancel Registration',
      message: 'Are you sure you want to cancel your restaurant registration? This action cannot be undone.',
      type: AppDialogType.warning,
      primaryButtonText: 'Cancel',
      secondaryButtonText: 'Continue',
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    return shouldCancel;
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
                    if (mounted) {
                      context.pop();
                    }
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
              if (mounted) {
                context.pop();
              }
            }
          }
        },
        child: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: ThemeHelper.getSystemUiOverlayStyle(context),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          height: 100.h,
                          width: 100.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [colors.accentOrange.withOpacity(0.2), colors.accentViolet.withOpacity(0.2)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(color: colors.accentOrange.withOpacity(0.2), blurRadius: 30, spreadRadius: 5),
                            ],
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              Assets.icons.chefHat,
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
                          "Join GrabGo as a Restaurant Partner",
                          textAlign: TextAlign.center,
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
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: KSpacing.sm.w),
                          child: Text(
                            "Grow your business with GrabGo — reach new customers, manage orders efficiently, and boost your restaurant's visibility across the country.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: KSpacing.xl40.h),

                    Text(
                      "Restaurant Information",
                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),

                    SizedBox(height: KSpacing.lg25.h),

                    AppTextInput(
                      controller: restaurantNameController,
                      label: "Name",
                      hintText: "Enter your restaurant name",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.text,
                      errorText: restaurantNameError,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.user,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),

                    SizedBox(height: KSpacing.lg.h),

                    AppTextInput(
                      controller: restaurantEmailController,
                      label: "Email",
                      hintText: "Enter your restaurant email",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.emailAddress,
                      errorText: restaurantEmailError,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.mail,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                    SizedBox(height: KSpacing.md15.h),

                    AppTextInput(
                      controller: restaurantPhoneController,
                      label: "Phone",
                      hintText: "Enter your restaurant phone number",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.phone,
                      errorText: restaurantPhoneError,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.phone,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                    SizedBox(height: KSpacing.md15.h),

                    AppTextInput(
                      controller: restaurantAddressController,
                      label: "Address",
                      hintText: "Enter your restaurant address",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.text,
                      errorText: restaurantAddressError,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.mapPin,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                    SizedBox(height: KSpacing.md15.h),

                    AppTextInput(
                      controller: restaurantCityController,
                      label: "City",
                      hintText: "Enter your restaurant city",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.text,
                      errorText: restaurantCityError,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.city,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),

                    SizedBox(height: KSpacing.md15.h),

                    ImageUploadWidget(
                      label: "Restaurant Logo",
                      hintText: "Tap to select image",
                      height: 120.h,
                      initialImage: _selectedLogoImage,
                      onImageSelected: (File? image) {
                        setState(() {
                          _selectedLogoImage = image;
                          if (image != null) {
                            logoImageError = null;
                            if (!_hasStartedFillingForm) {
                              _hasStartedFillingForm = true;
                            }
                          }
                        });
                      },
                      successMessage: "Logo uploaded successfully",
                    ),
                    if (logoImageError != null) ...[
                      SizedBox(height: KSpacing.xs.h),
                      Text(
                        logoImageError!,
                        style: TextStyle(
                          fontSize: KTextSize.extraSmall.sp,
                          color: colors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

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
                      "Owner Information",
                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),

                    SizedBox(height: KSpacing.lg25.h),

                    AppTextInput(
                      controller: ownerNameController,
                      label: "Full Name",
                      hintText: "Enter your full name",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.text,
                      errorText: ownerNameError,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.user,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),

                    SizedBox(height: KSpacing.lg.h),

                    AppTextInput(
                      controller: ownerPhoneController,
                      label: "Phone Number",
                      hintText: "Enter your phone number",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.phone,
                      errorText: ownerPhoneError,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.phone,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),

                    SizedBox(height: KSpacing.lg.h),

                    AppTextInput(
                      controller: businessIdController,
                      label: "Business ID",
                      hintText: "Enter your business ID",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.text,
                      errorText: businessIdError,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.idCard,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
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
                      "Verification",
                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),

                    SizedBox(height: KSpacing.lg25.h),

                    ImageUploadWidget(
                      label: "Business ID",
                      hintText: "Tap to select Business ID",
                      height: 120.h,
                      initialImage: _selectedBusinessIdImage,
                      onImageSelected: (File? image) {
                        setState(() {
                          _selectedBusinessIdImage = image;
                          if (image != null) {
                            businessIdImageError = null;
                            if (!_hasStartedFillingForm) {
                              _hasStartedFillingForm = true;
                            }
                          }
                        });
                      },
                      successMessage: "Business ID uploaded successfully",
                    ),
                    if (businessIdImageError != null) ...[
                      SizedBox(height: KSpacing.xs.h),
                      Text(
                        businessIdImageError!,
                        style: TextStyle(
                          fontSize: KTextSize.extraSmall.sp,
                          color: colors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    SizedBox(height: KSpacing.lg.h),

                    ImageUploadWidget(
                      label: "Owner Photo",
                      hintText: "Tap to select Owner Photo",
                      height: 120.h,
                      initialImage: _selectedOwnerPhotoImage,
                      onImageSelected: (File? image) {
                        setState(() {
                          _selectedOwnerPhotoImage = image;
                          if (image != null) {
                            ownerPhotoError = null;
                            if (!_hasStartedFillingForm) {
                              _hasStartedFillingForm = true;
                            }
                          }
                        });
                      },
                      successMessage: "Owner Photo uploaded successfully",
                    ),
                    if (ownerPhotoError != null) ...[
                      SizedBox(height: KSpacing.xs.h),
                      Text(
                        ownerPhotoError!,
                        style: TextStyle(
                          fontSize: KTextSize.extraSmall.sp,
                          color: colors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    SizedBox(height: KSpacing.sm.h),

                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
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
                              "These documents are securely stored and used only for verification. They help us verify your business ownership before approval.",
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
                      "Account Setup",
                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),

                    SizedBox(height: KSpacing.lg25.h),

                    AppTextInput(
                      controller: passwordController,
                      label: "Set Password",
                      hintText: "Enter your password",
                      fillColor: colors.backgroundSecondary,
                      borderColor: colors.inputBorder,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      obscureText: !isPasswordVisible,
                      errorText: passwordError,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.lock,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          setState(() {
                            isPasswordVisible = !isPasswordVisible;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.all(KSpacing.md12.r),
                          child: SvgPicture.asset(
                            isPasswordVisible ? Assets.icons.eye : Assets.icons.eyeClosed,
                            package: 'grab_go_shared',
                            width: KIconSize.md,
                            height: KIconSize.md,
                            colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: KSpacing.lg.h),

                    AppTextInput(
                      controller: confirmPasswordController,
                      label: "Confirm Password",
                      hintText: "Enter your confirm password",
                      fillColor: colors.backgroundSecondary,
                      borderColor: colors.inputBorder,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      obscureText: !isConfirmPasswordVisible,
                      errorText: confirmPasswordError,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.lock,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                        ),
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          setState(() {
                            isConfirmPasswordVisible = !isConfirmPasswordVisible;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.all(KSpacing.md12.r),
                          child: SvgPicture.asset(
                            isConfirmPasswordVisible ? Assets.icons.eye : Assets.icons.eyeClosed,
                            package: 'grab_go_shared',
                            width: KIconSize.md,
                            height: KIconSize.md,
                            colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: KSpacing.lg25.h),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              isTermsAccepted = !isTermsAccepted;
                            });
                          },
                          child: Container(
                            width: 20.w,
                            height: 20.h,
                            decoration: BoxDecoration(
                              color: isTermsAccepted ? colors.accentOrange : Colors.transparent,
                              border: Border.all(
                                color: isTermsAccepted ? colors.accentOrange : colors.inputBorder,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: isTermsAccepted ? Icon(Icons.check, color: Colors.white, size: 14.sp) : null,
                          ),
                        ),
                        SizedBox(width: KSpacing.sm.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                isTermsAccepted = !isTermsAccepted;
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

                    SizedBox(height: KSpacing.xl40.h),

                    GestureDetector(
                      onTap: () async {
                        if (hasPendingApplication) {
                          AppToastMessage.show(
                            context: context,
                            icon: Icons.info_outline,
                            message:
                                "You already have a pending restaurant application. Please wait for it to be reviewed before submitting another.",
                            backgroundColor: colors.accentOrange,
                          );
                          return;
                        }

                        if (_validateFields() && isTermsAccepted) {
                          LoadingDialog.instance().show(context: context, text: "Preparing review...");
                          final registrationData = RestaurantRegistrationData(
                            restaurantName: restaurantNameController.text.trim(),
                            restaurantEmail: restaurantEmailController.text.trim(),
                            restaurantPhone: restaurantPhoneController.text.trim(),
                            restaurantAddress: restaurantAddressController.text.trim(),
                            restaurantCity: restaurantCityController.text.trim(),
                            restaurantLogo: _selectedLogoImage,
                            ownerName: ownerNameController.text.trim(),
                            ownerPhone: ownerPhoneController.text.trim(),
                            businessId: businessIdController.text.trim(),
                            businessIdImage: _selectedBusinessIdImage,
                            ownerPhoto: _selectedOwnerPhotoImage,
                            password: passwordController.text,
                            confirmPassword: confirmPasswordController.text,
                            termsAccepted: isTermsAccepted,
                          );

                          context.push("/review", extra: registrationData);
                          LoadingDialog.instance().hide();
                        } else if (!isTermsAccepted) {
                          AppToastMessage.show(
                            context: context,
                            icon: Icons.error_outline,
                            message: "Please accept the Terms & Conditions",
                            backgroundColor: colors.error,
                          );
                        }
                      },
                      child: Container(
                        height: 56.h,
                        decoration: BoxDecoration(
                          gradient: isTermsAccepted
                              ? LinearGradient(
                                  colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                )
                              : null,
                          color: isTermsAccepted ? null : colors.inputBorder,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                          boxShadow: isTermsAccepted
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
                              color: isTermsAccepted ? Colors.white : colors.textSecondary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
