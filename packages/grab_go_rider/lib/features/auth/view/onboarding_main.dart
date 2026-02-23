import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/shared/service/storage_service.dart';
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

  void skip() => controller.jumpToPage(2);

  void next() async {
    if (_index < 2) {
      controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      await StorageService.setFirstLaunchComplete();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  onPageChanged: (i) {
                    setState(() => _index = i);
                  },
                  children: const [OnboardingOne(), OnboardingTwo(), OnboardingThree()],
                ),

                Positioned(
                  left: 20.w,
                  right: 20.w,
                  top: padding.top + 10.h,
                  child: StoryStepper(
                    count: 3,
                    index: _index,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.35),
                  ),
                ),

                Positioned(
                  left: 20.w,
                  right: 20.w,
                  bottom: padding.bottom + 20.h,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_index < 2)
                        Expanded(
                          flex: 1,
                          child: AppButton(
                            buttonText: AppStrings.skip,
                            onPressed: skip,
                            backgroundColor: Colors.transparent,
                            borderColor: Colors.white.withValues(alpha: 0.3),
                            borderRadius: KBorderSize.borderRadius4,
                            textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        )
                      else
                        SizedBox(width: 0),
                      if (_index < 2) SizedBox(width: 10.w),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          buttonText: _index < 2 ? AppStrings.cont : AppStrings.getStarted,
                          onPressed: next,
                          backgroundColor: Colors.white,
                          borderRadius: KBorderSize.borderRadius4,
                          textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.black),
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
