// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart' show SizeExtension;
import 'package:grab_go_customer/features/auth/view/onboarding_one.dart';
import 'package:grab_go_customer/features/auth/view/onboarding_three.dart';
import 'package:grab_go_customer/features/auth/view/onboarding_two.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OnboardingMain extends StatefulWidget {
  const OnboardingMain({super.key});

  @override
  State<OnboardingMain> createState() => _OnboardingMain();
}

class _OnboardingMain extends State<OnboardingMain> {
  final PageController _controller = PageController();
  int currentPage = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.addListener(() {
      int newPage = _controller.page?.round() ?? 0;
      if (currentPage != newPage) {
        setState(() {
          currentPage = newPage;
        });
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                PageView(
                  controller: _controller,
                  children: [
                    OnboardingOne(controller: _controller),
                    OnboardingTwo(controller: _controller),
                    const OnboardingThree(),
                  ],
                ),
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 90.h,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
                      ),
                      child: SmoothPageIndicator(
                        controller: _controller,
                        count: 3,
                        effect: ExpandingDotsEffect(
                          dotColor: Colors.white.withOpacity(0.4),
                          activeDotColor: colors.accentOrange,
                          dotHeight: 10.h,
                          dotWidth: 10.w,
                          expansionFactor: 4,
                          spacing: 8.w,
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
