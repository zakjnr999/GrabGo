import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

class AnimatedLastSeenText extends StatefulWidget {
  const AnimatedLastSeenText({
    super.key,
    required this.timestamp,
    required this.textColor,
    this.fontSize,
    this.fontWeight,
  });

  final DateTime timestamp;
  final Color textColor;
  final double? fontSize;
  final FontWeight? fontWeight;

  @override
  State<AnimatedLastSeenText> createState() => _AnimatedLastSeenTextState();
}

class _AnimatedLastSeenTextState extends State<AnimatedLastSeenText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _delayTimer;
  Timer? _reverseTimer;
  bool showingTime = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _startCycle();
  }

  void _startCycle() {
    _delayTimer?.cancel();
    _reverseTimer?.cancel();

    // Show date first, then after delay slide to time
    _delayTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() => showingTime = true);
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedLastSeenText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only reset if timestamp changed by more than 1 minute (significant change)
    final diff = (oldWidget.timestamp.millisecondsSinceEpoch - widget.timestamp.millisecondsSinceEpoch).abs();
    if (diff > 60000) {
      _controller.reset();
      setState(() => showingTime = false);
      _startCycle();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _reverseTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _getDateText() {
    final now = DateTime.now();
    final timestamp = widget.timestamp;

    if (now.difference(timestamp).inMinutes < 1) {
      return 'Last seen just now';
    }

    if (DateUtils.isSameDay(now, timestamp)) {
      return 'Last seen today at';
    }

    if (DateUtils.isSameDay(now.subtract(const Duration(days: 1)), timestamp)) {
      return 'Last seen yesterday at';
    }

    final dayPart = DateFormat('MMM dd').format(timestamp);
    return 'Last seen at $dayPart';
  }

  String _getTimeText() {
    final now = DateTime.now();
    final timestamp = widget.timestamp;

    if (now.difference(timestamp).inMinutes < 1) {
      return 'Last seen just now';
    }

    return DateFormat('hh:mm a').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _getDateText();
    final timeText = _getTimeText();
    final fontSize = widget.fontSize ?? 12.sp;
    final fontWeight = widget.fontWeight ?? FontWeight.w400;

    // If "just now", no animation needed
    if (dateText == 'Last seen just now') {
      return Text(
        dateText,
        style: TextStyle(
          fontFamily: "Lato",
          package: "grab_go_shared",
          color: widget.textColor,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ClipRect(
          child: Stack(
            children: [
              // Date text - slides out to left
              Transform.translate(
                offset: Offset(-50 * _animation.value, 0),
                child: Opacity(
                  opacity: 1 - _animation.value,
                  child: Text(
                    dateText,
                    style: TextStyle(
                      fontFamily: "Lato",
                      package: "grab_go_shared",
                      color: widget.textColor,
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              // Time text - slides in from right
              Transform.translate(
                offset: Offset(50 * (1 - _animation.value), 0),
                child: Opacity(
                  opacity: _animation.value,
                  child: Text(
                    timeText,
                    style: TextStyle(
                      fontFamily: "Lato",
                      package: "grab_go_shared",
                      color: widget.textColor,
                      fontSize: fontSize,
                      fontWeight: fontWeight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
