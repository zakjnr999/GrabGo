import 'package:flutter/material.dart';

class ShimmerLoading extends StatefulWidget {
  final bool isLoading;
  final Widget child;
  final bool? isDark;

  const ShimmerLoading({super.key, required this.isLoading, required this.child, this.isDark});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    final isDark = widget.isDark ?? Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                isDark ? Colors.grey.shade800 : Colors.grey.shade300,
              ],
              stops: [_controller.value - 0.3, _controller.value, _controller.value + 0.3],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}
