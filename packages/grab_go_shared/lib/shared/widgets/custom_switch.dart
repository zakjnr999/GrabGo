import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Custom animated switch widget with smooth transitions and modern design
class CustomSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? thumbColor;
  final double? width;
  final double? height;
  final Duration? duration;

  const CustomSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.thumbColor,
    this.width,
    this.height,
    this.duration,
  });

  @override
  State<CustomSwitch> createState() => _CustomSwitchState();
}

class _CustomSwitchState extends State<CustomSwitch> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: widget.duration ?? const Duration(milliseconds: 200),
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    if (widget.value) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(CustomSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = widget.activeColor ?? const Color(0xFFFF6B35);
    final inactiveColor = widget.inactiveColor ?? (isDark ? Colors.grey[800]! : Colors.grey[300]!);
    final thumbColor = widget.thumbColor ?? Colors.white;
    final width = widget.width ?? 52.w;
    final height = widget.height ?? 28.h;
    final thumbSize = height - 4.h;

    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: LinearGradient(
                colors: [
                  Color.lerp(inactiveColor, activeColor, _slideAnimation.value)!,
                  Color.lerp(inactiveColor.withOpacity(0.8), activeColor.withOpacity(0.9), _slideAnimation.value)!,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              // boxShadow: [
              //   BoxShadow(
              //     color: Color.lerp(
              //       Colors.black.withOpacity(0.1),
              //       activeColor.withOpacity(0.3),
              //       _slideAnimation.value,
              //     )!,
              //     blurRadius: 8,
              //     offset: const Offset(0, 2),
              //   ),
              // ],
            ),
            child: Stack(
              children: [
                // Animated thumb
                AnimatedPositioned(
                  duration: widget.duration ?? const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  left: widget.value ? width - thumbSize - 2.w : 2.w,
                  top: 2.h,
                  child: Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: thumbColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: widget.value ? 1.0 : 0.0,
                          child: Icon(Icons.check, size: 12.sp, color: activeColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
