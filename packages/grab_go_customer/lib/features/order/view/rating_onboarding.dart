import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/order/model/item_review_models.dart';
import 'package:grab_go_customer/features/order/view/item_rating.dart';
import 'package:grab_go_customer/features/order/view/rider_rating.dart';
import 'package:grab_go_customer/features/order/view/vendor_rating.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class RatingOnboarding extends StatefulWidget {
  final String orderId;
  final String? riderName;
  final String? riderImage;
  final String? vendorName;
  final String? vendorLogo;
  final bool showRiderStep;
  final bool includeVendorStep;
  final List<ReviewableOrderItem> reviewableItems;
  final VoidCallback? onFinished;

  const RatingOnboarding({
    super.key,
    required this.orderId,
    this.riderName,
    this.riderImage,
    this.vendorName,
    this.vendorLogo,
    this.showRiderStep = true,
    this.includeVendorStep = true,
    this.reviewableItems = const [],
    this.onFinished,
  });

  @override
  State<RatingOnboarding> createState() => RatingOnboardingState();
}

class RatingOnboardingState extends State<RatingOnboarding>
    with SingleTickerProviderStateMixin {
  final PageController controller = PageController();
  int _index = 0;
  late final List<_ReviewStep> _steps = _buildSteps();

  List<_ReviewStep> _buildSteps() {
    final steps = <_ReviewStep>[];

    if (widget.showRiderStep) {
      steps.add(const _ReviewStep(type: _ReviewStepType.rider));
    }

    if (widget.includeVendorStep) {
      steps.add(const _ReviewStep(type: _ReviewStepType.vendor));
    }

    for (final item in widget.reviewableItems) {
      steps.add(_ReviewStep(type: _ReviewStepType.item, item: item));
    }

    return steps;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _advanceOrFinish() async {
    if (_index < _steps.length - 1) {
      await controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (!mounted) return;
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    context.go('/homepage');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) {
                    setState(() => _index = i);
                  },
                  children: _steps.map(_buildStep).toList(growable: false),
                ),
                Positioned(
                  left: 20.w,
                  right: 20.w,
                  top: padding.top + 10.h,
                  child: StoryStepper(
                    count: _steps.length,
                    index: _index,
                    activeColor: colors.accentOrange,
                    inactiveColor: colors.backgroundSecondary,
                  ),
                ),
                Positioned(
                  left: 10,
                  top: padding.top + 20.h,
                  child: Container(
                    height: 44.h,
                    width: 44.w,
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => context.pop(),
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: EdgeInsets.all(10.r),
                          child: SvgPicture.asset(
                            Assets.icons.xmark,
                            package: 'grab_go_shared',
                            colorFilter: ColorFilter.mode(
                              colors.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_steps[_index].type == _ReviewStepType.rider)
                  Positioned(
                    right: 10,
                    top: padding.top + 20.h,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _advanceOrFinish,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: EdgeInsets.all(10.r),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_steps[_index].type == _ReviewStepType.rider)
                  Positioned(
                    left: 20.w,
                    right: 20.w,
                    bottom: padding.bottom + 20.h,
                    child: AppButton(
                      buttonText: "Continue",
                      onPressed: _advanceOrFinish,
                      backgroundColor: colors.accentOrange,
                      borderRadius: KBorderSize.borderRadius15,
                      textStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

  Widget _buildStep(_ReviewStep step) {
    switch (step.type) {
      case _ReviewStepType.rider:
        return RiderRating(
          orderId: widget.orderId,
          riderName: widget.riderName,
          riderImage: widget.riderImage,
        );
      case _ReviewStepType.vendor:
        return VendorRating(
          orderId: widget.orderId,
          vendorName: widget.vendorName,
          vendorImage: widget.vendorLogo,
          embedded: true,
          onCompleted: (_) => _advanceOrFinish(),
        );
      case _ReviewStepType.item:
        final item = step.item!;
        return ItemRating(
          orderId: widget.orderId,
          orderItemId: item.orderItemId,
          itemType: item.itemType,
          itemName: item.name,
          itemImage: item.image,
          embedded: true,
          onCompleted: (_) => _advanceOrFinish(),
        );
    }
  }
}

enum _ReviewStepType { rider, vendor, item }

class _ReviewStep {
  final _ReviewStepType type;
  final ReviewableOrderItem? item;

  const _ReviewStep({required this.type, this.item});
}
