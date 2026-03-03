import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class RiderDeliverySuccessPage extends StatefulWidget {
  final String orderId;
  final String vendorName;
  final String? vendorLogo;
  final String customerName;
  final String? customerPhoto;

  const RiderDeliverySuccessPage({
    super.key,
    required this.orderId,
    required this.vendorName,
    this.vendorLogo,
    required this.customerName,
    this.customerPhoto,
  });

  @override
  State<RiderDeliverySuccessPage> createState() =>
      _RiderDeliverySuccessPageState();
}

class _RiderDeliverySuccessPageState extends State<RiderDeliverySuccessPage>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _checkController;
  late Animation<double> _checkScale;
  late Animation<double> _checkOpacity;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _checkScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );
    _checkOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0, 0.35, curve: Curves.easeIn),
      ),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    _confettiController.play();
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    _checkController.forward();
  }

  void _continueToRating() {
    if (!mounted || _navigated) return;
    _navigated = true;
    context.go(
      '/rate-onboarding',
      extra: {
        'orderId': widget.orderId,
        'vendorName': widget.vendorName,
        'vendorLogo': widget.vendorLogo,
        'customerName': widget.customerName,
        'customerPhoto': widget.customerPhoto,
      },
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 18,
              gravity: 0.3,
              shouldLoop: false,
              colors: [
                colors.accentGreen,
                colors.accentBlue,
                colors.accentOrange,
                colors.accentViolet,
                const Color(0xFFFFD700),
              ],
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _checkController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _checkOpacity.value,
                          child: Transform.scale(
                            scale: _checkScale.value,
                            child: Container(
                              width: 120.w,
                              height: 120.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.accentGreen,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(18.r),
                                child: SvgPicture.asset(
                                  Assets.icons.checkBig,
                                  package: 'grab_go_shared',
                                  height: 60.h,
                                  width: 60.h,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 28.h),
                    AnimatedBuilder(
                      animation: _checkController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _checkOpacity.value,
                          child: Column(
                            children: [
                              Text(
                                "Delivery Completed!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 30.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                "Great job. Rate ${widget.vendorName} and ${widget.customerName}.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 28.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: _continueToRating,
                        buttonText: "Continue",
                        backgroundColor: colors.accentGreen,
                        borderRadius: KBorderSize.borderRadius4,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        height: 60.h,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: () => context.go("/home"),
                        buttonText: "Skip",
                        backgroundColor: colors.backgroundSecondary,
                        borderRadius: KBorderSize.borderRadius4,
                        height: 60.h,
                        textStyle: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
