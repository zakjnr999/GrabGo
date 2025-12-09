import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';

/// Reusable onboarding page widget to eliminate code duplication
class OnboardingPage extends StatefulWidget {
  final AssetGenImage image;
  final String title;
  final String subtitle;
  final CustomClipper<Path> clipper;
  final PageController? controller;
  final bool isLastPage;

  const OnboardingPage({
    super.key,
    required this.image,
    required this.title,
    required this.subtitle,
    required this.clipper,
    this.controller,
    this.isLastPage = false,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _scaleAnimation = CurvedAnimation(parent: _animationController, curve: Curves.elasticOut);

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleSkip() {
    HapticFeedback.lightImpact();
    widget.controller?.animateToPage(2, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
  }

  void _handleContinue() {
    HapticFeedback.lightImpact();
    widget.controller?.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _handleGetStarted() async {
    HapticFeedback.mediumImpact();
    try {
      await StorageService.setFirstLaunchComplete();
      if (mounted) {
        context.go("/login");
      }
    } catch (e) {
      if (mounted) {
        context.go("/login");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Stack(
                children: [
                  SizedBox(
                    width: size.width,
                    height: size.height * 0.55,
                    child: widget.image.image(fit: BoxFit.cover, package: 'grab_go_shared'),
                  ),
                  Container(
                    width: size.width,
                    height: size.height * 0.55,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.4)],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: ClipPath(
                clipper: widget.clipper,
                child: Container(
                  height: size.height * 0.50,
                  width: size.width,
                  padding: EdgeInsets.only(left: 25.w, right: 25.w, top: 60.h, bottom: 20.h),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
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
                            widget.title,
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
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const Spacer(),
                          _buildButtons(colors),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtons(AppColorsExtension colors) {
    if (widget.isLastPage) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
            boxShadow: [
              BoxShadow(
                color: colors.accentOrange.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AppButton(
            onPressed: _handleGetStarted,
            backgroundColor: Colors.transparent,
            borderRadius: KBorderSize.borderRadius15,
            buttonText: AppStrings.getStarted,
            textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.sp, letterSpacing: 0.5),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: AppButton(
            onPressed: _handleSkip,
            backgroundColor: colors.backgroundSecondary,
            borderColor: colors.inputBorder,
            borderRadius: KBorderSize.borderRadius15,
            buttonText: AppStrings.skip,
            textStyle: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15.sp),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)]),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
              boxShadow: [
                BoxShadow(
                  color: colors.accentOrange.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: AppButton(
              onPressed: _handleContinue,
              backgroundColor: Colors.transparent,
              borderRadius: KBorderSize.borderRadius15,
              buttonText: AppStrings.cont,
              textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
            ),
          ),
        ),
      ],
    );
  }
}
