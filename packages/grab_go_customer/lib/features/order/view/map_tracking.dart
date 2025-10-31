// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class MapTracking extends StatelessWidget {
  const MapTracking({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final Size size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        leadingWidth: 72,
        centerTitle: true,
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
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              children: [
                Assets.images.trackingSample.image(fit: BoxFit.cover, package: 'grab_go_shared'),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.1), Colors.transparent, Colors.black.withOpacity(0.3)],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 100.h,
                  right: 20.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'On the way',
                          style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.border),
                topRight: Radius.circular(KBorderSize.border),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  height: size.height * 0.45,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [colors.backgroundPrimary.withOpacity(0.95), colors.backgroundPrimary.withOpacity(0.98)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 40.w,
                          height: 4.h,
                          margin: EdgeInsets.only(top: 12.h),
                          decoration: BoxDecoration(
                            color: colors.textSecondary.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2.r),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Container(
                            padding: EdgeInsets.all(16.r),
                            decoration: BoxDecoration(
                              color: colors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              border: Border.all(color: colors.inputBorder.withOpacity(0.2), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(8),
                                  spreadRadius: 0,
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Stack(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(2.r),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(colors: [Colors.green, Colors.green.shade300]),
                                      ),
                                      child: ClipOval(
                                        child: Assets.icons.noProfile.image(
                                          fit: BoxFit.cover,
                                          height: size.width * 0.14,
                                          width: size.width * 0.14,
                                          package: 'grab_go_shared',
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 12.w,
                                        height: 12.h,
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: colors.backgroundPrimary, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 16.w),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Zak Jnr",
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        "Delivery Guy",
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    _buildActionButton(
                                      icon: Assets.icons.chatBubbleSolid,
                                      colors: colors,
                                      onTap: () {},
                                    ),
                                    SizedBox(width: 12.w),
                                    _buildActionButton(icon: Assets.icons.phoneSolid, colors: colors, onTap: () {}),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: KSpacing.lg.h),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(20.r),
                            decoration: BoxDecoration(
                              color: colors.backgroundPrimary,
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              border: Border.all(color: colors.inputBorder.withOpacity(0.1), width: 1),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.w),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.accentOrange.withOpacity(0.5),
                                        spreadRadius: 0,
                                        blurRadius: 20,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.receipt_long, color: Colors.white, size: 20.sp),
                                      SizedBox(width: 8.w),
                                      Text(
                                        "Order Details",
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: KSpacing.lg.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: colors.backgroundSecondary,
                                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                          border: Border.all(color: colors.backgroundTertiary, width: 1),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(14.r),
                                              decoration: BoxDecoration(
                                                color: colors.backgroundPrimary,
                                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.08),
                                                    spreadRadius: 0,
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(8.r),
                                                    decoration: BoxDecoration(
                                                      color: colors.error.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8.r),
                                                    ),
                                                    child: SvgPicture.asset(
                                                      Assets.icons.mapPin,
                                                      package: 'grab_go_shared',
                                                      height: 20.h,
                                                      width: 20.w,
                                                      colorFilter: ColorFilter.mode(colors.error, BlendMode.srcIn),
                                                    ),
                                                  ),
                                                  SizedBox(width: 12.w),
                                                  Expanded(
                                                    child: Text(
                                                      "Your Address",
                                                      style: TextStyle(
                                                        color: colors.textPrimary,
                                                        fontSize: 14.sp,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 8.h),
                                            Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                                              child: Text(
                                                "Cocoyam St.\nMadina Adenta",
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w400,
                                                  color: colors.textSecondary,
                                                  height: 1.4,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            SizedBox(height: 8.h),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: colors.backgroundSecondary,
                                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                          border: Border.all(color: colors.backgroundTertiary, width: 1),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.all(14.r),
                                              decoration: BoxDecoration(
                                                color: colors.backgroundPrimary,
                                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.08),
                                                    spreadRadius: 0,
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: EdgeInsets.all(8.r),
                                                    decoration: BoxDecoration(
                                                      color: colors.accentBlue.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(8.r),
                                                    ),
                                                    child: SvgPicture.asset(
                                                      Assets.icons.clock,
                                                      package: 'grab_go_shared',
                                                      height: 20.h,
                                                      width: 20.w,
                                                      colorFilter: ColorFilter.mode(colors.accentBlue, BlendMode.srcIn),
                                                    ),
                                                  ),
                                                  SizedBox(width: 12.w),
                                                  Expanded(
                                                    child: Text(
                                                      "Delivery Time",
                                                      style: TextStyle(
                                                        color: colors.textPrimary,
                                                        fontSize: 14.sp,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 8.h),
                                            Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w),
                                              child: Text(
                                                "Just 15 Minutes\nFast & Fresh",
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w400,
                                                  color: colors.textSecondary,
                                                  height: 1.4,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            SizedBox(height: 8.h),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
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
          ),
          Positioned(
            bottom: size.height * 0.5,
            right: 20.w,
            child: FloatingActionButton(
              onPressed: () {},
              backgroundColor: Colors.red,
              child: Icon(Icons.emergency, color: Colors.white, size: 24.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required String icon, required AppColorsExtension colors, required VoidCallback onTap}) {
    return Container(
      height: 44.h,
      width: 44.w,
      decoration: BoxDecoration(
        color: colors.accentOrange.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: colors.accentOrange.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: colors.accentOrange.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(12.r),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}
