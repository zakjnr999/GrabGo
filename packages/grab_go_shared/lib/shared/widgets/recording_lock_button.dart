import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';

class RecordingLockButton extends StatefulWidget {
  final Color color;
  final Color backgroundColor;
  final bool isLocked;

  const RecordingLockButton({super.key, required this.color, required this.backgroundColor, required this.isLocked});

  @override
  State<RecordingLockButton> createState() => _RecordingLockButtonState();
}

class _RecordingLockButtonState extends State<RecordingLockButton> {
  int _arrowAnimationKey = 0;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: widget.color.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: SvgPicture.asset(
                widget.isLocked ? Assets.icons.lock : Assets.icons.lock,
                package: "grab_go_shared",
                height: 24.h,
                width: 24.w,
                colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          TweenAnimationBuilder<double>(
            key: ValueKey('lock_arrow_$_arrowAnimationKey'),
            tween: Tween(begin: 0.0, end: -8.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            builder: (context, offset, child) {
              return Transform.translate(
                offset: Offset(0, offset),
                child: SvgPicture.asset(
                  Assets.icons.navArrowUp,
                  package: "grab_go_shared",
                  height: 20.h,
                  width: 20.w,
                  colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
                ),
              );
            },
            onEnd: () {
              if (mounted) {
                setState(() {
                  _arrowAnimationKey++;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
