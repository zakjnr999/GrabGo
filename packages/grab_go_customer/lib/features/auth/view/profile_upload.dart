import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:chopper/chopper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:path_provider/path_provider.dart';
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
  String? _selectedPresetAsset;
  bool _isUploading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  static const List<String> _presetAvatars = [
    'lib/assets/images/person1.png',
    'lib/assets/images/person2.png',
    'lib/assets/images/person3.png',
    'lib/assets/images/person4.png',
    'lib/assets/images/person5.png',
    'lib/assets/images/person6.png',
    'lib/assets/images/person7.png',
    'lib/assets/images/person8.png',
    'lib/assets/images/person9.png',
  ];

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
    if (context.mounted) {
      context.go("/confirm-address");
    }
  }

  Future<void> _handleImageSelection(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return;
    final file = File(imagePaths.first);
    await _applySelectedImage(file);
  }

  Future<void> _applySelectedImage(File file, {String? presetAsset}) async {
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

    final extension = file.path.toLowerCase().split('.').last;
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

    if (!mounted) return;
    setState(() {
      _selectedImage = file;
      _selectedPresetAsset = presetAsset;
    });
  }

  Future<File> _fileFromAsset(String assetPath) async {
    final bundlePath = assetPath.startsWith('packages/') ? assetPath : 'packages/grab_go_shared/$assetPath';
    final data = await rootBundle.load(bundlePath);
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/${assetPath.split('/').last}');
    await file.writeAsBytes(data.buffer.asUint8List());
    return file;
  }

  Future<void> _selectPresetAvatar(String assetPath) async {
    try {
      final file = await _fileFromAsset(assetPath);
      await _applySelectedImage(file, presetAsset: assetPath);
    } catch (e) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: "Failed to select avatar. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    }
  }

  void _showProfileImageOptions() {
    final colors = context.appColors;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.only(
            left: KSpacing.lg.w,
            right: KSpacing.lg.w,
            top: KSpacing.md.h,
            bottom: MediaQuery.of(context).viewInsets.bottom + KSpacing.lg.h,
          ),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: KSpacing.md.h),
                  decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(100.r)),
                ),
                Text(
                  "Choose profile photo",
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
                SizedBox(height: KSpacing.md.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Presets",
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                  ),
                ),
                SizedBox(height: KSpacing.md.h),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _presetAvatars.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final assetPath = _presetAvatars[index];
                    final isSelected = assetPath == _selectedPresetAsset;
                    return GestureDetector(
                      onTap: () async {
                        await _selectPresetAvatar(assetPath);
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? colors.accentOrange : colors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipOval(
                                child: Image.asset(assetPath, package: 'grab_go_shared', fit: BoxFit.cover),
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  height: 18,
                                  width: 18,
                                  decoration: BoxDecoration(
                                    color: colors.accentOrange,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: colors.backgroundPrimary, width: 1),
                                  ),
                                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: KSpacing.lg.h),
                AppButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ImagePickerSheet.show(context, maxImages: 1, onImagesSelected: _handleImageSelection);
                  },
                  width: double.infinity,
                  backgroundColor: colors.accentOrange,
                  borderRadius: KBorderSize.borderRadius15,
                  buttonText: "Choose from phone",
                  textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
                ),
                SizedBox(height: KSpacing.lg.h),
              ],
            ),
          ),
        );
      },
    );
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

      UserResponse? parsedResponse;
      if (response.body == null && response.bodyString.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.bodyString);
          if (decoded is Map<String, dynamic>) {
            parsedResponse = UserResponse.fromJson(decoded);
          } else if (decoded is Map) {
            parsedResponse = UserResponse.fromJson(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }

      final responseData = response.body ?? parsedResponse;

      if (response.isSuccessful) {
        final user = responseData?.userData ?? responseData?.user;
        if (user != null) {
          await UserService().setCurrentUser(user);
        }

        if (mounted) {
          LoadingDialog.instance().hide();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        actionsPadding: EdgeInsets.only(right: KSpacing.md.w),
        actions: [
          TextButton(
            onPressed: () async {
              await _navigateAfterProfileUpload(context);
            },
            child: Text(
              "Skip",
              style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
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
                          height: 120.h,
                          width: 120.h,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.accentOrange.withValues(alpha: 0.2),
                          ),
                          child: Center(
                            child: _selectedImage != null
                                ? ClipOval(child: Image.file(_selectedImage!, fit: BoxFit.cover))
                                : SvgPicture.asset(
                                    Assets.icons.user,
                                    package: "grab_go_shared",
                                    height: 60.h,
                                    width: 60.w,
                                    fit: BoxFit.cover,
                                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showProfileImageOptions,
                            child: Container(
                              height: 35.h,
                              width: 35.h,
                              padding: EdgeInsets.all(8.h),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.accentOrange,
                                border: Border.all(color: colors.backgroundPrimary, width: 2),
                              ),
                              child: SvgPicture.asset(
                                Assets.icons.camera,
                                package: "grab_go_shared",
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: KSpacing.xl50.h),

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: colors.accentOrange.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AppButton(
                            onPressed: () => _isUploading ? null : _uploadProfileImage(),
                            backgroundColor: colors.accentOrange,
                            borderRadius: KBorderSize.borderRadius15,
                            buttonText: _isUploading ? "Uploading..." : "Choose photo",
                            textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
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
