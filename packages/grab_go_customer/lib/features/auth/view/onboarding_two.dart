// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OnboardingTwo extends StatefulWidget {
  final PageController controller;

  const OnboardingTwo({super.key, required this.controller});

  @override
  State<OnboardingTwo> createState() => _OnboardingTwoState();
}

class _OnboardingTwoState extends State<OnboardingTwo> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Image with overlay gradient
                Align(
                  alignment: Alignment.topCenter,
                  child: Stack(
                    children: [
                      SizedBox(
                        width: size.width,
                        height: size.height * 0.55,
                        child: Assets.images.dishTwo.image(fit: BoxFit.cover, package: 'grab_go_shared'),
                      ),
                      Container(
                        width: size.width,
                        height: size.height * 0.55,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.4)],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content with animations
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ClipPath(
                    clipper: CurveOutClip(),
                    child: Container(
                      height: size.height * 0.50,
                      width: size.width,
                      padding: EdgeInsets.only(left: 25.w, right: 25.w, top: 60.h, bottom: 20.h),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                AppStrings.onboardingTwoMain,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28.sp,
                                  fontWeight: FontWeight.w900,
                                  color: colors.textPrimary,
                                  height: 1.3,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: 16.h),

                              Text(
                                AppStrings.onboardingTwoSub,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                  height: 1.5,
                                ),
                              ),

                              const Spacer(),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: AppButton(
                                      onPressed: () {
                                        widget.controller.jumpToPage(2);
                                      },
                                      backgroundColor: colors.backgroundSecondary,
                                      borderColor: colors.inputBorder,
                                      borderRadius: KBorderSize.borderRadius15,
                                      buttonText: AppStrings.skip,
                                      textStyle: TextStyle(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15.sp,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),

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
                                        onPressed: () {
                                          widget.controller.nextPage(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        },
                                        backgroundColor: Colors.transparent,
                                        borderRadius: KBorderSize.borderRadius15,
                                        buttonText: AppStrings.cont,
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
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
