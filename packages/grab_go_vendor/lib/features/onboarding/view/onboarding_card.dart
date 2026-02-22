import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_item.dart';

class OnboardingCard extends StatefulWidget {
  final VendorOnboardingItem item;
  final int pageIndex;
  final bool isActive;
  final int currentIndex;
  final int totalCount;

  const OnboardingCard({
    super.key,
    required this.item,
    required this.pageIndex,
    required this.isActive,
    required this.currentIndex,
    required this.totalCount,
  });

  @override
  State<OnboardingCard> createState() => _OnboardingCardState();
}

class _OnboardingCardState extends State<OnboardingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _reveal;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _reveal = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    if (widget.isActive) {
      _controller.forward();
    } else {
      _controller.value = 0;
    }
  }

  @override
  void didUpdateWidget(covariant OnboardingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _controller
        ..value = 0
        ..forward();
      return;
    }
    if (oldWidget.isActive && !widget.isActive) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, _) {
        final t = _reveal.value;
        final motion = _motionForPage(widget.pageIndex);

        return Column(
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    color: colors.vendorPrimaryBlue,
                  ),
                  _animatedShape(motion.first, t),
                  _animatedShape(motion.second, t),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.center,
                      child: Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, (1 - t) * 20.h),
                          child: SizedBox(
                            width: 260.w,
                            height: 260.w,
                            child: SvgPicture.asset(
                              widget.item.heroIcon,
                              package: 'grab_go_shared',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                color: colors.backgroundPrimary,
                padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 12.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.totalCount, (dotIndex) {
                        final isActive = dotIndex == widget.currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: EdgeInsets.symmetric(horizontal: 4.w),
                          width: isActive ? 9.w : 7.w,
                          height: isActive ? 9.w : 7.w,
                          decoration: BoxDecoration(
                            color: isActive
                                ? colors.vendorPrimaryBlue
                                : colors.inputBorder,
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 30.h),
                    Text(
                      widget.item.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      widget.item.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _animatedShape(_ShapePlacement shape, double t) {
    final dx = _lerp(shape.startDx, shape.endDx, t);
    final dy = _lerp(shape.startDy, shape.endDy, t);
    final angle = _lerp(shape.startAngle, shape.endAngle, t);

    return Align(
      alignment: shape.alignment,
      child: Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: shape.width,
              height: shape.height,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: shape.alpha),
                borderRadius: switch (shape.exposedSide) {
                  _ExposedSide.left => const BorderRadius.only(
                    topLeft: Radius.circular(999),
                    bottomLeft: Radius.circular(999),
                  ),
                  _ExposedSide.right => const BorderRadius.only(
                    topRight: Radius.circular(999),
                    bottomRight: Radius.circular(999),
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ShapeMotion _motionForPage(int pageIndex) {
    return switch (pageIndex) {
      // Screen 1: keep your current tuned positions as baseline.
      0 => _ShapeMotion(
        first: _ShapePlacement(
          alignment: Alignment.centerRight,
          startDx: 120.w,
          startDy: -108.h,
          endDx: 52.w,
          endDy: -90.h,
          width: 156.w,
          height: 120.w,
          alpha: 0.14,
          exposedSide: _ExposedSide.left,
        ),
        second: _ShapePlacement(
          alignment: Alignment.bottomLeft,
          startDx: -170.w,
          startDy: 8.h,
          endDx: -84.w,
          endDy: -20.h,
          width: 250.w,
          height: 120.w,
          alpha: 0.14,
          exposedSide: _ExposedSide.right,
        ),
      ),
      1 => _ShapeMotion(
        first: _ShapePlacement(
          alignment: Alignment.topLeft,
          startDx: -225.w,
          startDy: -145.h,
          endDx: -80.w,
          endDy: -20.h,
          width: 200.w,
          height: 126.w,
          alpha: 0.14,
          exposedSide: _ExposedSide.right,
          startAngle: 0.26,
          endAngle: 0.60,
        ),
        second: _ShapePlacement(
          alignment: Alignment.bottomRight,
          startDx: 210.w,
          startDy: 120.h,
          endDx: 80.w,
          endDy: 20.h,
          width: 200.w,
          height: 126.w,
          alpha: 0.14,
          exposedSide: _ExposedSide.left,
          startAngle: -0.26,
          endAngle: 0.60,
        ),
      ),
      _ => _ShapeMotion(
        first: _ShapePlacement(
          alignment: Alignment.bottomRight,
          startDx: -160.w,
          startDy: 54.h,
          endDx: 58.w,
          endDy: 20.h,
          width: 172.w,
          height: 126.w,
          alpha: 0.14,
          exposedSide: _ExposedSide.left,
        ),
        second: _ShapePlacement(
          alignment: Alignment.topLeft,
          startDx: 190.w,
          startDy: -90.h,
          endDx: -96.w,
          endDy: -20.h,
          width: 260.w,
          height: 118.w,
          alpha: 0.14,
          exposedSide: _ExposedSide.right,
        ),
      ),
    };
  }

  double _lerp(double begin, double end, double t) {
    return begin + (end - begin) * t;
  }
}

enum _ExposedSide { left, right }

class _ShapePlacement {
  final Alignment alignment;
  final double startDx;
  final double startDy;
  final double endDx;
  final double endDy;
  final double width;
  final double height;
  final double alpha;
  final _ExposedSide exposedSide;
  final double startAngle;
  final double endAngle;

  const _ShapePlacement({
    required this.alignment,
    required this.startDx,
    required this.startDy,
    required this.endDx,
    required this.endDy,
    required this.width,
    required this.height,
    required this.alpha,
    required this.exposedSide,
    this.startAngle = 0,
    this.endAngle = 0,
  });
}

class _ShapeMotion {
  final _ShapePlacement first;
  final _ShapePlacement second;

  const _ShapeMotion({required this.first, required this.second});
}
