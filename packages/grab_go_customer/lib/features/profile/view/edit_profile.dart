// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class EditProfile extends StatefulWidget {
  const EditProfile({super.key});

  @override
  State<EditProfile> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await UserService().getCurrentUser();
      setState(() {
        _user = user;
      });

      if (mounted) {
        setState(() {
          _user = user;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.backgroundSecondary,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Row(
            children: [
              Container(
                height: 44.h,
                width: 44.w,
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.pop(),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.r),
                      child: SvgPicture.asset(
                        Assets.icons.navArrowLeft,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(color: colors.accentViolet.withOpacity(0.1), shape: BoxShape.circle),
                      child: SvgPicture.asset(
                        Assets.icons.editPencil,
                        package: 'grab_go_shared',
                        height: 16.h,
                        width: 16.w,
                        colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "Edit Profile",
                      style: TextStyle(
                        fontFamily: "Lato",
                        package: "grab_go_shared",
                        color: colors.textPrimary,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              SizedBox(width: 44.w),
            ],
          ),
        ),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: colors.backgroundSecondary,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundSecondary,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: 30.h),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: size.width * 0.35,
                    width: size.width * 0.35,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accentViolet, colors.accentViolet.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.accentViolet.withOpacity(0.3),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(size.width * 0.01),
                      child: ClipOval(
                        child: CachedImageWidget(
                          height: size.width * 0.35,
                          width: size.width * 0.35,
                          imageUrl: _user?.profilePicture ?? "",
                          placeholder: Assets.icons.noProfile.image(
                            height: size.width * 0.35,
                            width: size.width * 0.35,
                            fit: BoxFit.cover,
                            package: 'grab_go_shared',
                          ),
                          errorWidget: Assets.icons.noProfile.image(
                            height: size.width * 0.35,
                            width: size.width * 0.35,
                            fit: BoxFit.cover,
                            package: 'grab_go_shared',
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4.h,
                    right: 0.w,
                    child: Container(
                      height: 40.h,
                      width: 40.w,
                      decoration: BoxDecoration(
                        color: colors.accentOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.backgroundSecondary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: colors.accentOrange.withOpacity(0.4),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {},
                          customBorder: const CircleBorder(),
                          child: Center(
                            child: SvgPicture.asset(
                              Assets.icons.camera,
                              package: 'grab_go_shared',
                              height: 18.h,
                              width: 18.w,
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 40.h),

              Container(
                margin: EdgeInsets.symmetric(horizontal: 20.w),
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                  border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                      spreadRadius: 0,
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    AppTextInput(
                      label: "Fullname",
                      hintText: _user?.username ?? "Enter your fullname",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.name,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.user,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    AppTextInput(
                      label: "Email Address",
                      hintText: _user?.email ?? "Enter your email address",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.mail,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    AppTextInput(
                      label: "Phone Number",
                      hintText: _user?.phone?.toString() ?? "Enter your phone number",
                      borderColor: colors.inputBorder,
                      fillColor: colors.backgroundSecondary,
                      borderRadius: KBorderSize.borderRadius15,
                      contentPadding: EdgeInsets.all(KSpacing.md15.r),
                      keyboardType: TextInputType.phone,
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(KSpacing.md12.r),
                        child: SvgPicture.asset(
                          Assets.icons.phone,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30.h),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: GestureDetector(
                  onTap: () {
                    // Handle submit
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accentOrange.withOpacity(0.4),
                          spreadRadius: 0,
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          Assets.icons.check,
                          package: 'grab_go_shared',
                          height: 20.h,
                          width: 20.w,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          "Save Changes",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 30.h),
            ],
          ),
        ),
      ),
    );
  }
}
