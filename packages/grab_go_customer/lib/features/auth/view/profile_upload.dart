import 'dart:async';
import 'dart:io';
import 'package:chopper/chopper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/auth/service/phone_auth_service.dart';

class ProfileUpload extends StatefulWidget {
  const ProfileUpload({super.key});

  @override
  State<ProfileUpload> createState() => _ProfileUpload();
}

class _ProfileUpload extends State<ProfileUpload> with SingleTickerProviderStateMixin {
  File? _selectedImage;
  bool _isUploading = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _navigateAfterProfileUpload(BuildContext context) async {
    // New flow: Move directly to confirm-address
    if (context.mounted) {
      context.go("/confirm-address");
    }
  }

  Future<void> _handleImageSelection(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return;

    final file = File(imagePaths.first);

    final fileSize = await file.length();
    if (fileSize > 5 * 1024 * 1024) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: "Image size must be less than 5MB",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    final extension = imagePaths.first.toLowerCase().split('.').last;
    if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: "Please select a different image format",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    setState(() {
      _selectedImage = file;
    });
  }

  Future<void> _uploadProfileImage() async {
    if (_selectedImage == null) {
      AppToastMessage.show(
        context: context,
        message: "Please select an image first",
        backgroundColor: context.appColors.error,
      );
      return;
    }

    final userId = UserService().currentUser?.id ?? PhoneAuthService().userId;
    if (userId == null) {
      AppToastMessage.show(
        context: context,
        message: "User ID not found. Please restart the registration process.",
        backgroundColor: context.appColors.error,
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Uploading profile image...");

    try {
      final imagePath = _selectedImage!.path;
      Response<UserResponse> response;

      try {
        response = await authService
            .uploadProfileWithFile(userId, imagePath)
            .timeout(
              const Duration(seconds: 60),
              onTimeout: () {
                throw TimeoutException('Server is taking too long to respond.');
              },
            );
      } catch (e) {
        try {
          response = await authService
              .uploadProfileWithFileAlt(userId, imagePath)
              .timeout(
                const Duration(seconds: 60),
                onTimeout: () {
                  throw TimeoutException('Server is taking too long to respond.');
                },
              );
        } catch (e2) {
          response = await authService
              .uploadProfileWithFileAlt2(userId, imagePath)
              .timeout(
                const Duration(seconds: 60),
                onTimeout: () {
                  throw TimeoutException('Server is taking too long to respond.');
                },
              );
        }
      }

      if (response.isSuccessful && response.body != null) {
        final user = response.body!.userData ?? response.body!.user;
        if (user != null) {
          await UserService().setCurrentUser(user);
        }

        if (mounted) {
          context.go("/confirm-address");
        }
      } else {
        String errorMessage = "Failed to upload profile image. Please try again.";

        if (response.error != null) {
          errorMessage = response.error.toString();
        } else if (response.statusCode == 400) {
          errorMessage = "Invalid image format.";
        } else if (response.statusCode == 404) {
          errorMessage = "User not found.";
        } else if (response.statusCode == 500) {
          errorMessage = "Server error. Please try again later.";
        }

        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(context: context, message: errorMessage, backgroundColor: context.appColors.error);
        }
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          message: "Failed to upload profile image. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    }

    setState(() {
      _isUploading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: KSpacing.xl40.h),

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Text(
                      AppStrings.uploadProfileMain,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32.sp,
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
                      padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
                      child: Text(
                        AppStrings.uploadProfileSub,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: KSpacing.xl40.h),

                ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Stack(
                      children: [
                        Container(
                          height: 150.h,
                          width: 150.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                colors.accentOrange.withValues(alpha: 0.2),
                                colors.accentViolet.withValues(alpha: 0.2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.accentOrange.withValues(alpha: 0.2),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              height: size.width * 0.35,
                              width: size.width * 0.35,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.backgroundSecondary,
                                border: Border.all(color: colors.inputBorder, width: size.width * 0.01),
                              ),
                              child: _selectedImage != null
                                  ? ClipOval(child: Image.file(_selectedImage!, fit: BoxFit.cover))
                                  : ClipOval(
                                      child: Assets.icons.noProfile.image(fit: BoxFit.cover, package: 'grab_go_shared'),
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () =>
                                ImagePickerSheet.show(context, maxImages: 1, onImagesSelected: _handleImageSelection),
                            child: Container(
                              height: 45.h,
                              width: 45.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.accentOrange.withValues(alpha: 0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.camera_alt, color: Colors.white, size: 22.h),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: KSpacing.xl40.h),

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          onTap: _isUploading ? null : () => _uploadProfileImage(),
                          child: Container(
                            height: 56.h,
                            decoration: BoxDecoration(
                              gradient: _isUploading
                                  ? null
                                  : LinearGradient(
                                      colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                              color: _isUploading ? colors.inputBorder : null,
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              boxShadow: !_isUploading
                                  ? [
                                      BoxShadow(
                                        color: colors.accentOrange.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                _isUploading ? "Uploading..." : "Upload Photo",
                                style: TextStyle(
                                  color: _isUploading ? colors.textSecondary : Colors.white,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: KSpacing.lg.h),

                        GestureDetector(
                          onTap: () async {
                            await _navigateAfterProfileUpload(context);
                          },
                          child: Container(
                            height: 56.h,
                            decoration: BoxDecoration(
                              color: colors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              border: Border.all(color: colors.inputBorder, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                "Skip for Now",
                                style: TextStyle(
                                  color: colors.textPrimary,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
