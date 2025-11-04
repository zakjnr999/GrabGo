// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:grab_go_shared/shared/utils/theme_helper.dart';
import 'package:grab_go_shared/shared/widgets/app_text_input.dart';
import 'package:grab_go_shared/shared/widgets/logo_upload_widget.dart';

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
                context.pop();
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

      body: GestureDetector(
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
                        gradient: LinearGradient(
                          colors: [colors.accentOrange.withOpacity(0.2), colors.accentViolet.withOpacity(0.2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(color: colors.accentOrange.withOpacity(0.2), blurRadius: 4, spreadRadius: 5),
                        ],
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

                AppTextInput(
                  label: "Vehicle Type *",
                  hintText: "Choose your vehicle type",
                  borderColor: colors.inputBorder,
                  fillColor: colors.backgroundSecondary,
                  borderRadius: KBorderSize.borderRadius4,
                  contentPadding: EdgeInsets.all(KSpacing.md15.r),
                  keyboardType: TextInputType.text,
                ),

                SizedBox(height: KSpacing.lg.h),

                AppTextInput(
                  label: "License Plate Number *",
                  hintText: "Enter your license plate number",
                  borderColor: colors.inputBorder,
                  fillColor: colors.backgroundSecondary,
                  borderRadius: KBorderSize.borderRadius4,
                  contentPadding: EdgeInsets.all(KSpacing.md15.r),
                  keyboardType: TextInputType.text,
                ),
                SizedBox(height: KSpacing.lg.h),

                AppTextInput(
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
                    setState(() {});
                  },
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

                AppTextInput(
                  label: "National ID Type *",
                  hintText: "Choose your national ID type",
                  borderColor: colors.inputBorder,
                  fillColor: colors.backgroundSecondary,
                  borderRadius: KBorderSize.borderRadius4,
                  contentPadding: EdgeInsets.all(KSpacing.md15.r),
                  keyboardType: TextInputType.text,
                ),

                SizedBox(height: KSpacing.lg.h),

                AppTextInput(
                  label: "National ID Number *",
                  hintText: "Enter your national ID number",
                  borderColor: colors.inputBorder,
                  fillColor: colors.backgroundSecondary,
                  borderRadius: KBorderSize.borderRadius4,
                  contentPadding: EdgeInsets.all(KSpacing.md15.r),
                  keyboardType: TextInputType.text,
                ),

                SizedBox(height: KSpacing.lg.h),

                ImageUploadWidget(
                  label: "Upload ID (Front) *",
                  hintText: "Tap to select image",
                  borderRadius: KBorderSize.borderRadius4,
                  height: 120.h,
                  onImageSelected: (File? image) {
                    setState(() {});
                  },
                  successMessage: "Image uploaded successfully",
                ),

                SizedBox(height: KSpacing.lg.h),

                ImageUploadWidget(
                  label: "Upload ID (Back) *",
                  hintText: "Tap to select image",
                  borderRadius: KBorderSize.borderRadius4,
                  height: 120.h,
                  onImageSelected: (File? image) {
                    setState(() {});
                  },
                  successMessage: "Image uploaded successfully",
                ),

                SizedBox(height: KSpacing.lg.h),

                ImageUploadWidget(
                  label: "Upload Selfie Photo",
                  hintText: "Tap to select image",
                  borderRadius: KBorderSize.borderRadius4,
                  height: 120.h,
                  onImageSelected: (File? image) {
                    setState(() {});
                  },
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

                AppTextInput(
                  label: "Payment Method *",
                  hintText: "Choose your payment method",
                  borderColor: colors.inputBorder,
                  fillColor: colors.backgroundSecondary,
                  borderRadius: KBorderSize.borderRadius4,
                  contentPadding: EdgeInsets.all(KSpacing.md15.r),
                  keyboardType: TextInputType.text,
                ),

                SizedBox(height: KSpacing.lg.h),

                AppTextInput(
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
                  label: "Account Holder Name *",
                  hintText: "Enter your account holder name",
                  borderColor: colors.inputBorder,
                  fillColor: colors.backgroundSecondary,
                  borderRadius: KBorderSize.borderRadius4,
                  contentPadding: EdgeInsets.all(KSpacing.md15.r),
                  keyboardType: TextInputType.text,
                ),

                SizedBox(height: KSpacing.lg.h),

                AppTextInput(
                  label: "Mobile Money Provider *",
                  hintText: "Choose your mobile money provider",
                  borderColor: colors.inputBorder,
                  fillColor: colors.backgroundSecondary,
                  borderRadius: KBorderSize.borderRadius4,
                  contentPadding: EdgeInsets.all(KSpacing.md15.r),
                  keyboardType: TextInputType.text,
                ),

                SizedBox(height: KSpacing.lg.h),

                AppTextInput(
                  label: "Mobile Money Number *",
                  hintText: "Enter your mobile money number",
                  borderColor: colors.inputBorder,
                  fillColor: colors.backgroundSecondary,
                  borderRadius: KBorderSize.borderRadius4,
                  contentPadding: EdgeInsets.all(KSpacing.md15.r),
                  keyboardType: TextInputType.text,
                ),

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
                        setState(() {});
                      },
                      child: Container(
                        width: 20.w,
                        height: 20.h,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: colors.inputBorder, width: 2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: 14.sp),
                      ),
                    ),
                    SizedBox(width: KSpacing.sm.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {});
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
                        setState(() {});
                      },
                      child: Container(
                        width: 20.w,
                        height: 20.h,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: colors.inputBorder, width: 2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: 14.sp),
                      ),
                    ),
                    SizedBox(width: KSpacing.sm.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {});
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
                        setState(() {});
                      },
                      child: Container(
                        width: 20.w,
                        height: 20.h,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: colors.inputBorder, width: 2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Icon(Icons.check, color: Colors.white, size: 14.sp),
                      ),
                    ),
                    SizedBox(width: KSpacing.sm.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {});
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
                  onTap: () {
                    context.push("/accountCreated");
                  },
                  child: Container(
                    height: 56.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      color: colors.inputBorder,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accentOrange.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        "Submit Registration",
                        style: TextStyle(
                          color: Colors.white,
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
    );
  }
}
