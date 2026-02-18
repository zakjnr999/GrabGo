import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_item.dart';
import 'package:grab_go_vendor/features/onboarding/view/onboarding_setup_shell.dart';
import 'package:grab_go_vendor/features/onboarding/view/widgets/vendor_service_chip.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          child: Consumer<OnboardingViewModel>(
            builder: (context, viewModel, child) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Vendor Setup',
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textSecondary),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    _ProgressBar(count: viewModel.items.length, index: viewModel.currentIndex),
                    SizedBox(height: 16.h),
                    Expanded(
                      child: PageView.builder(
                        controller: viewModel.pageController,
                        itemCount: viewModel.items.length,
                        onPageChanged: viewModel.onPageChanged,
                        itemBuilder: (context, index) {
                          final item = viewModel.items[index];
                          return _OnboardingCard(item: item, accentColor: _accentColorForIndex(colors, index));
                        },
                      ),
                    ),
                    SizedBox(height: 16.h),
                    if (viewModel.isLastPage)
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          buttonText: AppStrings.getStarted,
                          onPressed: () => _finishOnboarding(context),
                          backgroundColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.borderRadius12,
                          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              buttonText: AppStrings.skip,
                              onPressed: viewModel.skipToLastPage,
                              backgroundColor: colors.backgroundPrimary,
                              borderColor: colors.inputBorder,
                              borderRadius: KBorderSize.borderRadius12,
                              textStyle: TextStyle(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            flex: 2,
                            child: AppButton(
                              buttonText: AppStrings.cont,
                              onPressed: viewModel.nextPage,
                              backgroundColor: colors.vendorPrimaryBlue,
                              borderRadius: KBorderSize.borderRadius12,
                              textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.sp),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _accentColorForIndex(AppColorsExtension colors, int index) {
    switch (index) {
      case 1:
        return colors.serviceGrocery;
      case 2:
        return colors.serviceFood;
      default:
        return colors.vendorPrimaryBlue;
    }
  }

  void _finishOnboarding(BuildContext context) {
    HapticFeedback.selectionClick();
    if (isReplayMode) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingSetupShell(isReplayMode: true)),
      );
      return;
    }
    context.go('/onboardingGuide');
  }
}

class _ProgressBar extends StatelessWidget {
  final int count;
  final int index;

  const _ProgressBar({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: List.generate(count, (itemIndex) {
        final isActive = itemIndex == index;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            margin: EdgeInsets.only(right: itemIndex == count - 1 ? 0 : 6.w),
            height: 5.h,
            decoration: BoxDecoration(
              color: isActive ? colors.vendorPrimaryBlue : colors.inputBorder,
              borderRadius: BorderRadius.circular(100.r),
            ),
          ),
        );
      }),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  final VendorOnboardingItem item;
  final Color accentColor;

  const _OnboardingCard({required this.item, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
            decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(22.r)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        Assets.icons.store,
                        height: 14.h,
                        width: 14.w,
                        package: "grab_go_shared",
                        colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        item.badge,
                        style: TextStyle(color: accentColor, fontSize: 12.sp, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 18.h),
                Center(
                  child: Container(
                    width: 94.w,
                    height: 94.w,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: SvgPicture.asset(
                      item.heroIcon,
                      package: "grab_go_shared",
                      width: 52.sp,
                      height: 52.sp,
                      colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
                    ),
                  ),
                ),
                SizedBox(height: 18.h),
                Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 16.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    VendorServiceChip(label: 'Food', icon: Icons.restaurant_rounded, color: colors.serviceFood),
                    VendorServiceChip(
                      label: 'Grocery',
                      icon: Icons.local_grocery_store_rounded,
                      color: colors.serviceGrocery,
                    ),
                    VendorServiceChip(
                      label: 'Pharmacy',
                      icon: Icons.local_pharmacy_outlined,
                      color: colors.servicePharmacy,
                    ),
                    VendorServiceChip(
                      label: 'GrabMart',
                      icon: Icons.shopping_bag_outlined,
                      color: colors.serviceGrabMart,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
