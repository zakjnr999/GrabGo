import 'dart:async';
import 'dart:io';
import 'package:chopper/chopper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/auth/service/firebase_phone_auth_service.dart';
import 'package:image_picker/image_picker.dart';

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

  Future<void> _selectImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_selectedImage == null) {
      AppToastMessage.show(
        context: context,
        icon: Icons.error_outline,
        message: "Please select an image first",
        backgroundColor: context.appColors.error,
      );
      return;
    }

    final userId = FirebasePhoneAuthService().userId;
    if (userId == null) {
      AppToastMessage.show(
        context: context,
        icon: Icons.error_outline,
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
        // Update user data with new profile picture
        final user = response.body!.userData ?? response.body!.user;
        if (user != null) {
          await UserService().setCurrentUser(user);
        }

        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(
            context: context,
            icon: Icons.check_circle,
            message: "Profile image uploaded successfully!",
            backgroundColor: Colors.green,
          );

          context.go("/accountCreated");
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
          AppToastMessage.show(
            context: context,
            icon: Icons.error_outline,
            message: errorMessage,
            backgroundColor: context.appColors.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          icon: Icons.error,
          message: "Failed to upload profile image. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    }

    setState(() {
      _isUploading = false;
    });
  }

  Future<void> imagePickerModal(BuildContext context) async {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (Platform.isIOS) {
      return showCupertinoModalPopup(
        context: context,
        builder: (context) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              child: Text(
                "Camera",
                style: TextStyle(color: colors.textPrimary, fontSize: KTextSize.medium.sp, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                _selectImage(ImageSource.camera);
                context.pop();
              },
            ),
            CupertinoActionSheetAction(
              child: Text(
                "Gallery",
                style: TextStyle(color: colors.textPrimary, fontSize: KTextSize.medium.sp, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                _selectImage(ImageSource.gallery);
                context.pop();
              },
            ),
          ],
        ),
      );
    } else {
      return showModalBottomSheet(
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        elevation: 0,
        enableDrag: true,
        isScrollControlled: true,
        isDismissible: true,
        context: context,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(KBorderSize.borderRadius20),
              topRight: Radius.circular(KBorderSize.borderRadius20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(color: colors.inputBorder, borderRadius: BorderRadius.circular(2.r)),
              ),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.md.h),
                child: Text(
                  "Choose Photo Source",
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
              ),

              SizedBox(height: KSpacing.sm.h),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _selectImage(ImageSource.camera);
                        context.pop();
                      },
                      child: Container(
                        padding: EdgeInsets.all(KSpacing.lg.r),
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                          border: Border.all(color: colors.inputBorder, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 48.h,
                              width: 48.h,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.accentOrange.withValues(alpha: 0.2),
                                    colors.accentOrange.withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius12),
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  Assets.icons.camera,
                                  package: 'grab_go_shared',
                                  height: 24.h,
                                  width: 24.h,
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                              ),
                            ),
                            SizedBox(width: KSpacing.lg.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Camera",
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    "Take a new photo",
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w400,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16.h, color: colors.textSecondary),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: KSpacing.md.h),

                    GestureDetector(
                      onTap: () {
                        _selectImage(ImageSource.gallery);
                        context.pop();
                      },
                      child: Container(
                        padding: EdgeInsets.all(KSpacing.lg.r),
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                          border: Border.all(color: colors.inputBorder, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              height: 48.h,
                              width: 48.h,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.accentViolet.withValues(alpha: 0.2),
                                    colors.accentViolet.withValues(alpha: 0.1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius12),
                              ),
                              child: Center(
                                child: SvgPicture.asset(
                                  Assets.icons.mediaImage,
                                  package: 'grab_go_shared',
                                  height: 24.h,
                                  width: 24.h,
                                  colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                                ),
                              ),
                            ),
                            SizedBox(width: KSpacing.lg.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Gallery",
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    "Choose from library",
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w400,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16.h, color: colors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: KSpacing.lg.h),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    decoration: BoxDecoration(
                      color: isDark ? colors.backgroundSecondary : colors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                      border: Border.all(color: colors.inputBorder, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        "Cancel",
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: KSpacing.lg25.h),
            ],
          ),
        ),
      );
    }
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
                            onTap: () => imagePickerModal(context),
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
                          onTap: () => context.push("/homepage"),
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
