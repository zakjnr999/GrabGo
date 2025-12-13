import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class AppRefreshIndicator extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? iconPath;

  const AppRefreshIndicator({super.key, required this.child, required this.onRefresh, this.iconPath});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);

    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      builder: (context, child, controller) {
        return Stack(
          children: [
            child,
            if (controller.state != IndicatorState.idle)
              Positioned(
                top: size.height * 0.15 + (controller.value * 50),
                left: 0,
                right: 0,
                child: _buildIndicator(controller, colors),
              ),
          ],
        );
      },
      child: child,
    );
  }

  Widget _buildIndicator(IndicatorController controller, AppColorsExtension colors) {
    final value = controller.value.clamp(0.0, 1.5);
    final opacity = (value * 2).clamp(0.0, 1.0);
    final scale = (value * 0.8).clamp(0.0, 1.0);
    final rotation = controller.state.isLoading ? null : value * math.pi * 2;

    return Opacity(
      opacity: opacity,
      child: Container(
        height: 100.h,
        alignment: Alignment.center,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 60.w,
            height: 60.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.accentOrange.withOpacity(0.3),
                  spreadRadius: 0,
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: controller.state.isLoading ? _LoadingAnimation(iconPath: iconPath) : _buildPullIcon(rotation),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPullIcon(double? rotation) {
    return Transform.rotate(
      angle: rotation ?? 0,
      child: SvgPicture.asset(
        iconPath ?? Assets.icons.utensilsCrossed,
        package: 'grab_go_shared',
        height: 24.h,
        width: 24.w,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }
}

class _LoadingAnimation extends StatefulWidget {
  final String? iconPath;

  const _LoadingAnimation({this.iconPath});

  @override
  State<_LoadingAnimation> createState() => _LoadingAnimationState();
}

class _LoadingAnimationState extends State<_LoadingAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(angle: _controller.value * math.pi * 2, child: child);
      },
      child: SvgPicture.asset(
        widget.iconPath ?? Assets.icons.utensilsCrossed,
        package: 'grab_go_shared',
        height: 24.h,
        width: 24.w,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }
}
