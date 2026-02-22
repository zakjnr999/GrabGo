import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/onboarding/view/onboarding_card.dart';
import 'package:grab_go_vendor/features/onboarding/view/onboarding_setup_shell.dart';
import 'package:grab_go_vendor/features/onboarding/viewmodel/onboarding_viewmodel.dart';
import 'package:provider/provider.dart';

class OnboardingMain extends StatelessWidget {
  final bool isReplayMode;

  const OnboardingMain({super.key, this.isReplayMode = false});
  const OnboardingMain.replay({super.key}) : isReplayMode = true;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingViewModel(),
      child: _OnboardingMainView(isReplayMode: isReplayMode),
    );
  }
}

class _OnboardingMainView extends StatelessWidget {
  final bool isReplayMode;

  const _OnboardingMainView({required this.isReplayMode});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.vendorPrimaryBlue,
        body: Consumer<OnboardingViewModel>(
          builder: (context, viewModel, child) {
            return Column(
              children: [
                Expanded(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: PageView.builder(
                      controller: viewModel.pageController,
                      itemCount: viewModel.items.length,
                      onPageChanged: viewModel.onPageChanged,
                      itemBuilder: (context, index) {
                        final item = viewModel.items[index];
                        return OnboardingCard(
                          item: item,
                          pageIndex: index,
                          isActive: viewModel.currentIndex == index,
                          currentIndex: viewModel.currentIndex,
                          totalCount: viewModel.items.length,
                        );
                      },
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: colors.backgroundPrimary,
                  padding: EdgeInsets.fromLTRB(
                    20.w,
                    16.h,
                    20.w,
                    12.h + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: viewModel.isLastPage
                      ? SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            buttonText: AppStrings.getStarted,
                            onPressed: () => _finishOnboarding(context),
                            backgroundColor: colors.vendorPrimaryBlue,
                            borderRadius: KBorderSize.border,
                            textStyle: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15.sp,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            AppButton(
                              width: double.infinity,
                              buttonText: AppStrings.cont,
                              onPressed: viewModel.nextPage,
                              backgroundColor: colors.vendorPrimaryBlue,
                              borderRadius: KBorderSize.border,
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            GestureDetector(
                              onTap: viewModel.skipToLastPage,
                              child: Text(
                                AppStrings.skip,
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: colors.textSecondary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
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

  void _finishOnboarding(BuildContext context) {
    HapticFeedback.selectionClick();
    if (isReplayMode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const OnboardingSetupShell(isReplayMode: true),
        ),
      );
      return;
    }
    context.go('/login');
  }
}
