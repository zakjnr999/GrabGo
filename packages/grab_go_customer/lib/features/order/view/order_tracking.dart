// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OrderStep {
  final String title;
  final String description;
  final String time;
  final bool isCompleted;

  OrderStep({required this.title, required this.description, required this.time, required this.isCompleted});
}

class OrderTracking extends StatefulWidget {
  const OrderTracking({super.key});

  @override
  State<OrderTracking> createState() => _OrderTrackingState();
}

class _OrderTrackingState extends State<OrderTracking> {
  int activeStep = 2; // Current step (0-3)

  final List<OrderStep> orderSteps = [
    OrderStep(title: "Order Placed", description: "Your order has been received", time: "10:30 AM", isCompleted: true),
    OrderStep(
      title: "Preparing your order",
      description: "Restaurant is preparing your order",
      time: "10:35 AM",
      isCompleted: true,
    ),
    OrderStep(title: "Out for Delivery", description: "Your order is on the way", time: "10:45 AM", isCompleted: true),
    OrderStep(title: "Delivered", description: "Order has been delivered", time: "10:50 AM", isCompleted: false),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
                      decoration: BoxDecoration(color: colors.accentOrange.withOpacity(0.1), shape: BoxShape.circle),
                      child: SvgPicture.asset(
                        Assets.icons.deliveryTruck,
                        package: 'grab_go_shared',
                        height: 16.h,
                        width: 16.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "Track Order",
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
                    onTap: () {},
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.r),
                      child: SvgPicture.asset(
                        Assets.icons.headsetHelp,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentOrange.withOpacity(0.3),
                      spreadRadius: 0,
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          child: SvgPicture.asset(
                            Assets.icons.deliveryTruck,
                            package: 'grab_go_shared',
                            height: 24.h,
                            width: 24.w,
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                orderSteps[activeStep].title,
                                style: TextStyle(fontSize: 18.sp, color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                orderSteps[activeStep].description,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, color: Colors.white, size: 16.sp),
                          SizedBox(width: 6.w),
                          Text(
                            "Est. ${orderSteps[activeStep].time}",
                            style: TextStyle(fontSize: 12.sp, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              EasyStepper(
                activeStep: activeStep,
                stepRadius: 25.r,
                enableStepTapping: false,
                showTitle: false,
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
                    customStep: Container(
                      width: 50.w,
                      height: 50.h,
                      decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.chefHat,
                          package: 'grab_go_shared',
                          width: 24.w,
                          height: 24.h,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                  EasyStep(
                    customStep: Container(
                      width: 50.w,
                      height: 50.h,
                      decoration: BoxDecoration(
                        color: colors.accentOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.inputBorder, width: 2),
                      ),
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
                      decoration: BoxDecoration(
                        color: colors.inputBorder,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.inputBorder, width: 2),
                      ),
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

              SizedBox(height: 24.h),

              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                    child: Assets.icons.orderTrackSample.image(
                      width: double.infinity,
                      height: 200.h,
                      fit: BoxFit.cover,
                      package: 'grab_go_shared',
                    ),
                  ),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                        child: Assets.icons.orderTrackSample.image(
                          width: double.infinity,
                          height: 200.h,
                          fit: BoxFit.cover,
                          package: 'grab_go_shared',
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: GestureDetector(
                            onTap: () => context.push("/mapTracking"),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Container(
                                  color: colors.accentOrange.withOpacity(0.2),
                                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "View",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 5.w),
                                      SvgPicture.asset(
                                        Assets.icons.navArrowDown,
                                        package: 'grab_go_shared',
                                        height: 16.h,
                                        width: 16.w,
                                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 24.h),

              Container(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: colors.accentOrange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            Assets.icons.mapPin,
                            package: 'grab_go_shared',
                            height: 16.h,
                            width: 16.w,
                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          "Delivery Details",
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    _buildDeliveryDetailRow(Assets.icons.mapPin, "Address", "Cocoyam St. Madina Adenta, Ghana", colors),
                    SizedBox(height: 12.h),
                    _buildDeliveryDetailRow(Assets.icons.deliveryTruck, "Type", "Door delivery", colors),
                    SizedBox(height: 12.h),
                    _buildDeliveryDetailRow(Assets.icons.shieldCheck, "Service", "Premium", colors),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              Container(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: colors.accentViolet.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            Assets.icons.cart,
                            package: 'grab_go_shared',
                            height: 16.h,
                            width: 16.w,
                            colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          "Order Summary",
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    _buildOrderSummaryRow("Fufu with Palm Nut Soup", "GHS 5.69", colors),
                    SizedBox(height: 12.h),
                    GestureDetector(
                      onTap: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "View details",
                            style: TextStyle(fontSize: 13.sp, color: colors.accentOrange, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.arrow_forward_ios, size: 12.sp, color: colors.accentOrange),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),

              Container(
                width: double.infinity,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total Paid",
                      style: TextStyle(fontSize: 16.sp, color: colors.textPrimary, fontWeight: FontWeight.w700),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        "GHS 24.80",
                        style: TextStyle(fontSize: 16.sp, color: colors.accentGreen, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryDetailRow(dynamic icon, String label, String value, AppColorsExtension colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(6.r),
          decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(8.r)),
          child: icon is String
              ? SvgPicture.asset(
                  icon,
                  package: "grab_go_shared",
                  height: 14.h,
                  width: 14.w,
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                )
              : Icon(icon, size: 14.sp, color: colors.textSecondary),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(fontSize: 13.sp, color: colors.textPrimary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummaryRow(String item, String price, AppColorsExtension colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            item,
            style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          price,
          style: TextStyle(fontSize: 14.sp, color: colors.accentOrange, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
