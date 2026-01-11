// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:easy_stepper/easy_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class MapTracking extends StatefulWidget {
  const MapTracking({super.key});

  @override
  State<MapTracking> createState() => _MapTrackingState();
}

class _MapTrackingState extends State<MapTracking> {
  @override
  Widget build(BuildContext context) {
    int activeStep = 2;
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
              child: Container(
                height: size.height * 0.36,
                color: colors.accentOrange,
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipOval(
                              child: Assets.icons.noProfile.image(
                                fit: BoxFit.cover,
                                height: 50.h,
                                width: 50.w,
                                package: 'grab_go_shared',
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Kwame Atta",
                                    style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4.h),
                                  Row(
                                    children: [
                                      SvgPicture.asset(
                                        Assets.icons.starSolid,
                                        package: "grab_go_shared",
                                        height: 14.h,
                                        width: 14.w,
                                        colorFilter: const ColorFilter.mode(Colors.yellow, BlendMode.srcIn),
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        "4.6",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _buildActionButton(icon: Assets.icons.chatBubbleSolid, colors: colors, onTap: () {}),
                                SizedBox(width: 12.w),
                                _buildActionButton(icon: Assets.icons.phoneSolid, colors: colors, onTap: () {}),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(KBorderSize.border),
                            topRight: Radius.circular(KBorderSize.border),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              spreadRadius: 2,
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "On The Way",
                              style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w800),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "The rider is on the way to you. Your order will arrive soon.",
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 20.h),

                            EasyStepper(
                              activeStep: activeStep,
                              stepRadius: 25.r,
                              enableStepTapping: false,
                              showTitle: true,
                              disableScroll: true,
                              lineStyle: LineStyle(
                                lineLength: 60.w,
                                lineSpace: 0,
                                lineThickness: 4,
                                lineType: LineType.normal,
                                defaultLineColor: colors.inputBorder,
                                finishedLineColor: colors.accentOrange,
                              ),
                              showStepBorder: false,
                              unreachedStepBackgroundColor: colors.inputBorder,
                              activeStepBackgroundColor: colors.inputBorder,
                              finishedStepBackgroundColor: colors.accentOrange,
                              stepShape: StepShape.circle,
                              showLoadingAnimation: false,
                              steps: [
                                EasyStep(
                                  customTitle: Text(
                                    "Accepted",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  customStep: Container(
                                    width: 50.w,
                                    height: 50.h,
                                    decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        Assets.icons.check,
                                        package: 'grab_go_shared',
                                        width: 24.w,
                                        height: 24.h,
                                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                      ),
                                    ),
                                  ),
                                ),
                                EasyStep(
                                  customTitle: Text(
                                    "Preparing",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  customStep: Container(
                                    width: 50.w,
                                    height: 50.h,
                                    decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        Assets.icons.store,
                                        package: 'grab_go_shared',
                                        width: 24.w,
                                        height: 24.h,
                                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                      ),
                                    ),
                                  ),
                                ),
                                EasyStep(
                                  customTitle: Text(
                                    "On The Way",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  customStep: Container(
                                    width: 50.w,
                                    height: 50.h,
                                    decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        Assets.icons.deliveryTruck,
                                        package: 'grab_go_shared',
                                        height: 24.h,
                                        width: 24.w,
                                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                      ),
                                    ),
                                  ),
                                ),
                                EasyStep(
                                  customStep: Container(
                                    width: 50.w,
                                    height: 50.h,
                                    decoration: BoxDecoration(color: colors.inputBorder, shape: BoxShape.circle),
                                    child: Center(
                                      child: Icon(Icons.handshake, color: colors.textSecondary, size: 24.sp),
                                    ),
                                  ),
                                ),
                              ],
                              onStepReached: (index) {
                                setState(() {
                                  activeStep = index;
                                });
                              },
                            ),
                            SizedBox(height: 20.h),

                            // ETA and Distance Row
                            Row(
                              children: [
                                // ETA
                                Expanded(
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        Assets.icons.timer,
                                        package: 'grab_go_shared',
                                        width: 18.w,
                                        height: 18.h,
                                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                      ),
                                      SizedBox(width: 6.w),
                                      Flexible(
                                        child: RichText(
                                          text: TextSpan(
                                            text: "Delivery:  ",
                                            style: TextStyle(
                                              fontFamily: "Lato",
                                              package: 'grab_go_shared',
                                              color: colors.textSecondary,
                                              fontSize: 12.sp,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: "28 min",
                                                style: TextStyle(
                                                  fontFamily: "Lato",
                                                  package: 'grab_go_shared',
                                                  fontWeight: FontWeight.w800,
                                                  color: colors.textPrimary,
                                                  fontSize: 13.sp,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Distance
                                Expanded(
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        Assets.icons.mapPin,
                                        package: 'grab_go_shared',
                                        width: 18.w,
                                        height: 18.h,
                                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                      ),
                                      SizedBox(width: 6.w),
                                      Flexible(
                                        child: RichText(
                                          text: TextSpan(
                                            text: "Distance:  ",
                                            style: TextStyle(
                                              fontFamily: "Lato",
                                              package: 'grab_go_shared',
                                              color: colors.textSecondary,
                                              fontSize: 12.sp,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: "1.2 km",
                                                style: TextStyle(
                                                  fontFamily: "Lato",
                                                  package: 'grab_go_shared',
                                                  fontWeight: FontWeight.w800,
                                                  color: colors.textPrimary,
                                                  fontSize: 13.sp,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
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
          Positioned(
            bottom: size.height * 0.38,
            right: 20.w,
            child: Container(
              height: 32.h,
              width: 32.w,
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
                    padding: EdgeInsets.all(6.r),
                    child: SvgPicture.asset(
                      Assets.icons.crosshair,
                      package: 'grab_go_shared',
                      colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetailsModal(BuildContext context, AppColorsExtension colors) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.border),
            topRight: Radius.circular(KBorderSize.border),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: colors.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(Icons.receipt_long, color: colors.accentOrange, size: 24.sp),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order Details",
                          style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          "Order #12345",
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: colors.textSecondary, size: 24.sp),
                  ),
                ],
              ),
            ),

            Divider(color: colors.inputBorder.withOpacity(0.3), height: 1),

            // Order Items List
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(20.w),
                children: [
                  // Items Section
                  Text(
                    "Items",
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12.h),

                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                      border: Border.all(color: colors.inputBorder.withOpacity(0.2), width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildOrderItem(
                          colors: colors,
                          itemName: "Jollof Rice with Chicken",
                          quantity: 2,
                          price: "GHS 45.00",
                        ),
                        Divider(color: colors.inputBorder.withOpacity(0.3), height: 24.h),
                        _buildOrderItem(colors: colors, itemName: "Fried Plantain", quantity: 1, price: "GHS 15.00"),
                        Divider(color: colors.inputBorder.withOpacity(0.3), height: 24.h),
                        _buildOrderItem(colors: colors, itemName: "Coca Cola (500ml)", quantity: 1, price: "GHS 5.00"),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  // Summary Section
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: colors.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                      border: Border.all(color: colors.accentOrange.withOpacity(0.2), width: 1),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(colors, "Subtotal", "GHS 65.00"),
                        SizedBox(height: 8.h),
                        _buildSummaryRow(colors, "Delivery Fee", "GHS 5.00"),
                        SizedBox(height: 8.h),
                        _buildSummaryRow(colors, "Service Fee", "GHS 2.00"),
                        Divider(color: colors.accentOrange.withOpacity(0.3), height: 20.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total",
                              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              "GHS 72.00",
                              style: TextStyle(
                                color: colors.accentOrange,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required String icon, required AppColorsExtension colors, required VoidCallback onTap}) {
    return Container(
      height: 40.h,
      width: 40.w,
      decoration: BoxDecoration(color: colors.backgroundPrimary.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItem({
    required AppColorsExtension colors,
    required String itemName,
    required int quantity,
    required String price,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: colors.accentOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            "${quantity}x",
            style: TextStyle(color: colors.accentOrange, fontSize: 12.sp, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            itemName,
            style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          price,
          style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(AppColorsExtension colors, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
