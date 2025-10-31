import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/shared/utils/story_stepper.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'onboarding_one.dart';
import 'onboarding_two.dart';
import 'onboarding_three.dart';

class OnboardingMain extends StatefulWidget {
  const OnboardingMain({super.key});

  @override
  State<OnboardingMain> createState() => OnboardingMainState();
}

class OnboardingMainState extends State<OnboardingMain> with SingleTickerProviderStateMixin {
  final PageController controller = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void skip() => context.go('/login');

  void next() {
    if (_index < 2) {
      controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        body: LayoutBuilder(
          builder: (context, _) {
            final padding = MediaQuery.of(context).padding;
            return Stack(
              children: [
                PageView(
                  controller: controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: const [OnboardingOne(), OnboardingTwo(), OnboardingThree()],
                ),

                Positioned(
                  left: 20.w,
                  right: 20.w,
                  top: padding.top + 10.h,
                  child: StoryStepper(
                    count: 3,
                    index: _index,
                    activeColor: colors.textPrimary,
                    inactiveColor: colors.inputBorder.withValues(alpha: 0.35),
                  ),
                ),

                Positioned(
                  left: 20.w,
                  right: 20.w,
                  bottom: padding.bottom + 20.h,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        flex: 1,
                        child: AppButton(
                          buttonText: AppStrings.skip,
                          onPressed: skip,
                          backgroundColor: Colors.transparent,
                          borderColor: colors.inputBorder,
                          borderRadius: KBorderSize.borderRadius8,
                          textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.black),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          buttonText: _index < 2 ? AppStrings.cont : AppStrings.getStarted,
                          onPressed: next,
                          backgroundColor: colors.textPrimary,
                          textColor: colors.backgroundPrimary,
                          borderRadius: KBorderSize.borderRadius8,
                          textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                    ],
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
