// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart' show SizeExtension;
import 'package:grab_go_customer/features/auth/view/onboarding_page.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OnboardingMain extends StatefulWidget {
  const OnboardingMain({super.key});

  @override
  State<OnboardingMain> createState() => _OnboardingMain();
}

class _OnboardingMain extends State<OnboardingMain> {
  final PageController _controller = PageController();
  final ValueNotifier<int> _currentPage = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller.addListener(_onPageChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _preloadImages();
  }

  void _preloadImages() {
    precacheImage(Assets.images.dishOne.provider(package: 'grab_go_shared'), context);
    precacheImage(Assets.images.dishTwo.provider(package: 'grab_go_shared'), context);
    precacheImage(Assets.images.dishThree.provider(package: 'grab_go_shared'), context);
  }

  void _onPageChanged() {
    final newPage = _controller.page?.round() ?? 0;
    if (_currentPage.value != newPage) {
      HapticFeedback.selectionClick();
      _currentPage.value = newPage;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onPageChanged);
    _controller.dispose();
    _currentPage.dispose();
    super.dispose();
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
        child: Stack(
          children: [
            PageView(
              controller: _controller,
              children: [
                OnboardingPage(
                  image: Assets.images.dishOne,
                  title: AppStrings.onboardingOneMain,
                  subtitle: AppStrings.onboardingOneSub,
                  clipper: CurveInClip(),
                  controller: _controller,
                ),
                OnboardingPage(
                  image: Assets.images.dishTwo,
                  title: AppStrings.onboardingTwoMain,
                  subtitle: AppStrings.onboardingTwoSub,
                  clipper: CurveOutClip(),
                  controller: _controller,
                ),
                OnboardingPage(
                  image: Assets.images.dishThree,
                  title: AppStrings.onboardingThreeMain,
                  subtitle: AppStrings.onboardingThreeSub,
                  clipper: CurveInClip(),
                  isLastPage: true,
                ),
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 2)],
                  ),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _currentPage,
                    builder: (context, page, child) {
                      return SmoothPageIndicator(
                        controller: _controller,
                        count: 3,
                        effect: ExpandingDotsEffect(
                          dotColor: Colors.white.withValues(alpha: 0.4),
                          activeDotColor: colors.accentOrange,
                          dotHeight: 10.h,
                          dotWidth: 10.w,
                          expansionFactor: 4,
                          spacing: 8.w,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
