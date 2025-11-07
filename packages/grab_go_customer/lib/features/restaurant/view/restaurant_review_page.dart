// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurant_registration_data.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'dart:async';
import 'package:grab_go_shared/grub_go_shared.dart';

class ReviewPage extends StatefulWidget {
  final RestaurantRegistrationData registrationData;

  const ReviewPage({super.key, required this.registrationData});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> with SingleTickerProviderStateMixin {
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

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

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
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
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> _checkServerConnection() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(AppConfig.apiBaseUrl));
      final response = await request.close().timeout(const Duration(seconds: 10));
      client.close();
      return response.statusCode == 200 || response.statusCode == 404 || response.statusCode == 405;
    } catch (e) {
      debugPrint('❌ Server connection failed: $e');
      return false;
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup("google.com");
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException {
      return false;
    }
    return false;
  }

  Future<void> handleRestaurantRegistration() async {
    LoadingDialog.instance().show(context: context, text: AppStrings.restaurantRegistrationCheckingConnection);

    _debugLogRegistrationData();

    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          icon: Icons.wifi_off,
          message: AppStrings.restaurantRegistrationNoInternet,
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    final serverReachable = await _checkServerConnection();
    if (!serverReachable) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          icon: Icons.cloud_off,
          message: AppStrings.restaurantRegistrationCannotReachServer,
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    LoadingDialog.instance().show(context: context, text: AppStrings.restaurantRegistrationSubmitting);

    try {
      _debugLogApiCall();
      _debugLogRegistrationData();

      final trimmedName = widget.registrationData.restaurantName.trim();
      final trimmedCity = widget.registrationData.restaurantCity.trim();

      if (trimmedName.isEmpty) {
        throw Exception('Restaurant name is required');
      }
      if (trimmedCity.isEmpty) {
        throw Exception('City is required');
      }

      final response = await restaurantService
          .registerRestaurant(
            restaurantName: trimmedName,
            email: widget.registrationData.restaurantEmail.trim(),
            phone: widget.registrationData.restaurantPhone.trim(),
            address: widget.registrationData.restaurantAddress.trim(),
            city: trimmedCity,
            ownerFullName: widget.registrationData.ownerName.trim(),
            ownerContactNumber: widget.registrationData.ownerPhone.trim(),
            businessIdNumber: widget.registrationData.businessId.trim(),
            password: widget.registrationData.password,
            logo: widget.registrationData.restaurantLogo?.path,
            businessIdPhoto: widget.registrationData.businessIdImage?.path,
            ownerPhoto: widget.registrationData.ownerPhoto?.path,
          )
          .timeout(
            const Duration(seconds: 120),
            onTimeout: () {
              throw TimeoutException('Server is taking too long to respond.');
            },
          );

      _debugLogResponse(response);

      if (response.isSuccessful && response.body != null) {
        if (mounted) {
          LoadingDialog.instance().hide();

          await StorageService.saveRestaurantApplicationSubmitted();
          await StorageService.saveRestaurantApplicationStatus("Submitted");

          AppToastMessage.show(
            context: context,
            icon: Icons.check_circle_outline,
            message: response.body?.message ?? AppStrings.restaurantRegistrationSuccess,
            backgroundColor: Colors.green,
          );

          context.push("/restaurantRegistrationSuccess");
        }
      } else {
        _debugLogErrorResponse(response);

        String errorMessage =
            response.body?.message ?? response.body?.error ?? "Failed to submit registration. Please try again.";

        if (response.statusCode == 400) {
          errorMessage = response.body?.message ?? "Invalid data provided. Please check your information.";
        } else if (response.statusCode == 409) {
          errorMessage = response.body?.message ?? "Restaurant already registered with this email.";
        } else if (response.statusCode == 500) {
          errorMessage = response.body?.message ?? "Server error. Please try again later.";
        } else if (response.statusCode == 404) {
          errorMessage = response.body?.message ?? "Endpoint not found. Please check your API route.";
        }

        if (mounted) {
          LoadingDialog.instance().hide();

          AppToastMessage.show(
            context: context,
            icon: Icons.error_outline,
            message: "$errorMessage\n\n(${response.statusCode})",
            backgroundColor: context.appColors.error,
          );
        }
      }
    } catch (e) {
      _debugLogException(e);

      if (mounted) {
        LoadingDialog.instance().hide();

        String errorMessage = AppStrings.restaurantRegistrationFailed;
        if (e.toString().contains('type') && e.toString().contains('subtype')) {
          errorMessage = "Registration successful but response parsing failed. Please check your application status.";
        }

        AppToastMessage.show(
          context: context,
          icon: Icons.error,
          message: errorMessage,
          backgroundColor: context.appColors.error,
        );
      }
    }
  }

  void _debugLogRegistrationData() {
    debugPrint('📋 RESTAURANT REGISTRATION DATA');
    debugPrint('├─ Restaurant Name: ${widget.registrationData.restaurantName}');
    debugPrint('├─ Email: ${widget.registrationData.restaurantEmail}');
    debugPrint('├─ Phone: ${widget.registrationData.restaurantPhone}');
    debugPrint('├─ Address: ${widget.registrationData.restaurantAddress}');
    debugPrint('├─ City: ${widget.registrationData.restaurantCity}');
    debugPrint('├─ Owner Name: ${widget.registrationData.ownerName}');
    debugPrint('├─ Owner Phone: ${widget.registrationData.ownerPhone}');
    debugPrint('├─ Business ID: ${widget.registrationData.businessId}');
    debugPrint('├─ Password Length: ${widget.registrationData.password.length}');
    debugPrint('├─ Logo File: ${widget.registrationData.restaurantLogo?.path ?? "null"}');
    debugPrint('├─ Business ID File: ${widget.registrationData.businessIdImage?.path ?? "null"}');
    debugPrint('├─ Owner Photo File: ${widget.registrationData.ownerPhoto?.path ?? "null"}');
    debugPrint('├─ Terms Accepted: ${widget.registrationData.termsAccepted}');
    debugPrint('├─ Is Complete: ${widget.registrationData.isComplete}');
    debugPrint('└─────────────────────────────────────────');
  }

  void _debugLogApiCall() {
    debugPrint('🚀 MAKING RESTAURANT REGISTRATION API CALL');
    debugPrint('├─ Endpoint: POST /restaurants');
    debugPrint('├─ Base URL: ${AppConfig.apiBaseUrl}');
    debugPrint('├─ Full URL: ${AppConfig.apiBaseUrl}/restaurants');
    debugPrint('├─ Content-Type: multipart/form-data');
    debugPrint('├─ Files to upload:');
    debugPrint('│  ├─ Logo: ${widget.registrationData.restaurantLogo?.path ?? "none"}');
    debugPrint('│  ├─ Business ID: ${widget.registrationData.businessIdImage?.path ?? "none"}');
    debugPrint('│  └─ Owner Photo: ${widget.registrationData.ownerPhoto?.path ?? "none"}');

    if (widget.registrationData.restaurantLogo != null) {
      final file = widget.registrationData.restaurantLogo!;
      debugPrint('│  ├─ Logo File Size: ${file.lengthSync()} bytes');
      debugPrint('│  ├─ Logo File Exists: ${file.existsSync()}');
    }
    if (widget.registrationData.businessIdImage != null) {
      final file = widget.registrationData.businessIdImage!;
      debugPrint('│  ├─ Business ID File Size: ${file.lengthSync()} bytes');
      debugPrint('│  ├─ Business ID File Exists: ${file.existsSync()}');
    }
    if (widget.registrationData.ownerPhoto != null) {
      final file = widget.registrationData.ownerPhoto!;
      debugPrint('│  ├─ Owner Photo File Size: ${file.lengthSync()} bytes');
      debugPrint('│  ├─ Owner Photo File Exists: ${file.existsSync()}');
    }

    debugPrint('└─────────────────────────────────────────');
  }

  void _debugLogResponse(response) {
    debugPrint('✅ RESTAURANT REGISTRATION RESPONSE');
    debugPrint('├─ Status Code: ${response.statusCode}');
    debugPrint('├─ Reason Phrase: ${response.base.reasonPhrase}');
    debugPrint('├─ Headers: ${response.base.headers}');
    debugPrint('├─ Body Type: ${response.body.runtimeType}');
    debugPrint('├─ Is Successful: ${response.isSuccessful}');

    if (response.body != null) {
      if (response.body is Map) {
        debugPrint('├─ Response Body: ${response.body}');
      } else if (response.body is List) {
        debugPrint('├─ Response Body: List with ${(response.body as List).length} items');
      } else {
        debugPrint('├─ Response Body: ${response.body}');
      }
    }

    if (response.error != null) {
      debugPrint('├─ Error: ${response.error}');
    }

    debugPrint('└─────────────────────────────────────────');
  }

  void _debugLogErrorResponse(response) {
    debugPrint('❌ RESTAURANT REGISTRATION FAILED');
    debugPrint('├─ Status Code: ${response.statusCode}');
    debugPrint('├─ Reason Phrase: ${response.base.reasonPhrase}');
    debugPrint('├─ Headers: ${response.base.headers}');
    debugPrint('├─ Error Body: ${response.error}');
    debugPrint('├─ Raw Body: ${response.body}');
    debugPrint('├─ Body String: ${response.bodyString}');
    debugPrint('├─ Response Message: ${response.body?.message ?? "No message"}');
    debugPrint('├─ Response Error: ${response.body?.error ?? "No error field"}');
    debugPrint('└─────────────────────────────────────────');
  }

  void _debugLogException(dynamic e) {
    debugPrint('💥 RESTAURANT REGISTRATION EXCEPTION');
    debugPrint('├─ Exception Type: ${e.runtimeType}');
    debugPrint('├─ Exception Message: $e');
    debugPrint('├─ Stack Trace: ${StackTrace.current}');
    debugPrint('└─────────────────────────────────────────');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              onTap: () => context.pop(),
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
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: colors.backgroundSecondary,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: colors.backgroundSecondary,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
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
                        margin: EdgeInsets.only(bottom: KSpacing.lg.h),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [colors.accentOrange.withOpacity(0.2), colors.accentOrange.withOpacity(0.1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: colors.accentOrange.withOpacity(0.2), blurRadius: 30, spreadRadius: 5),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.icons.shieldCheck,
                            package: 'grab_go_shared',
                            height: 50.h,
                            width: 50.h,
                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                          ),
                        ),
                      ),
                    ),
                  ),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          color: colors.accentOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: colors.accentOrange.withOpacity(0.3), width: 1),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "Review Your Information",
                              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                            ),
                            SizedBox(height: KSpacing.sm.h),
                            Text(
                              "Please review all your information and uploaded documents to ensure accuracy before submission. This helps us process your registration faster.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14.sp, color: colors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Restaurant Information",
                            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                          _buildInformationSection("Restaurant Information", [
                            _buildInfoRow("Restaurant Name", widget.registrationData.restaurantName, colors),
                            _buildInfoRow("Email", widget.registrationData.restaurantEmail, colors),
                            _buildInfoRow("Phone", widget.registrationData.restaurantPhone, colors),
                            _buildInfoRow("Address", widget.registrationData.restaurantAddress, colors),
                            _buildInfoRow("City", widget.registrationData.restaurantCity, colors),
                          ], colors),
                        ],
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

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Owner Information",
                            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                          _buildInformationSection("Owner Information", [
                            _buildInfoRow("Full Name", widget.registrationData.ownerName, colors),
                            _buildInfoRow("Phone Number", widget.registrationData.ownerPhone, colors),
                            _buildInfoRow("Business ID", widget.registrationData.businessId, colors),
                          ], colors),
                        ],
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

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Verification",
                            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                          _buildDocumentPreview(
                            "Restaurant Logo",
                            widget.registrationData.restaurantLogo,
                            (File? image) {},
                            colors,
                          ),
                          SizedBox(height: KSpacing.md.h),
                          _buildDocumentPreview(
                            "Business ID",
                            widget.registrationData.businessIdImage,
                            (File? image) {},
                            colors,
                          ),
                          SizedBox(height: KSpacing.md.h),
                          _buildDocumentPreview(
                            "Owner Photo",
                            widget.registrationData.ownerPhoto,
                            (File? image) {},
                            colors,
                          ),
                        ],
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

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Account Setup",
                            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                          ),
                          _buildPasswordSection(colors),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  onPressed: () {
                                    context.pop();
                                  },
                                  backgroundColor: colors.backgroundSecondary,
                                  borderColor: colors.inputBorder,
                                  borderRadius: KBorderSize.borderRadius15,
                                  buttonText: "Back",
                                  textStyle: TextStyle(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: KSpacing.md.w),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                                    ),
                                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.accentOrange.withOpacity(0.4),
                                        blurRadius: 15,
                                        spreadRadius: 0,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: AppButton(
                                    onPressed: _canSubmit()
                                        ? () async {
                                            await handleRestaurantRegistration();
                                          }
                                        : () {
                                            AppToastMessage.show(
                                              context: context,
                                              icon: Icons.error_outline,
                                              message: "Please complete all required fields",
                                              backgroundColor: Colors.red,
                                            );
                                          },
                                    backgroundColor: Colors.transparent,
                                    borderRadius: KBorderSize.borderRadius15,
                                    buttonText: "Submit for Review",
                                    textStyle: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.sp,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: KSpacing.lg.h),

                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: colors.accentOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: colors.accentOrange.withOpacity(0.3), width: 1),
                            ),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  Assets.icons.shieldCheck,
                                  package: 'grab_go_shared',
                                  width: 16.w,
                                  height: 16.h,
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                                SizedBox(width: KSpacing.sm.w),
                                Expanded(
                                  child: Text(
                                    "Your documents will be reviewed within 24-48 hours. You'll receive a notification via email once verification is complete.",
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInformationSection(String title, List<Widget> infoRows, dynamic colors) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          SizedBox(height: KSpacing.md.h),
          ...infoRows,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, dynamic colors) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              "$label:",
              style: TextStyle(fontSize: 14.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
            ),
          ),
          SizedBox(width: KSpacing.sm.w),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordSection(dynamic colors) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Account Setup",
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          SizedBox(height: KSpacing.md.h),

          _buildPasswordField("Password", widget.registrationData.password, _isPasswordVisible, () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          }, colors),

          SizedBox(height: KSpacing.lg.h),

          _buildPasswordField(
            "Confirm Password",
            widget.registrationData.confirmPassword,
            _isConfirmPasswordVisible,
            () {
              setState(() {
                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
              });
            },
            colors,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField(String label, String value, bool isVisible, VoidCallback onToggle, dynamic colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120.w,
          child: Text(
            "$label:",
            style: TextStyle(fontSize: 14.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ),
        SizedBox(width: KSpacing.sm.w),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: colors.inputBorder, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isVisible ? value : "••••••••",
                    style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                ),
                GestureDetector(
                  onTap: onToggle,
                  child: Padding(
                    padding: EdgeInsets.all(4.r),
                    child: SvgPicture.asset(
                      isVisible ? Assets.icons.eye : Assets.icons.eyeClosed,
                      package: 'grab_go_shared',
                      width: 20.w,
                      height: 20.h,
                      colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentPreview(String title, File? image, Function(File?) onImageSelected, dynamic colors) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              const Spacer(),
              if (image != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    "Uploaded",
                    style: TextStyle(fontSize: 10.sp, color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ),
            ],
          ),
          SizedBox(height: KSpacing.sm.h),
          // Read-only image display
          Container(
            width: double.infinity,
            height: 100.h,
            decoration: BoxDecoration(
              color: colors.inputBackground,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: colors.inputBorder, width: 1.5),
            ),
            child: image != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: Image.file(image, width: double.infinity, height: 100.h, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        Assets.icons.mediaImageXmark,
                        package: 'grab_go_shared',
                        width: 32.w,
                        height: 32.h,
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                      SizedBox(height: KSpacing.sm.h),
                      Text(
                        "No image uploaded",
                        style: TextStyle(fontSize: 12.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool _canSubmit() {
    return widget.registrationData.isComplete;
  }
}
