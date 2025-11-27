// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;
  final bool isSentByMe;
  final Color kColor;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onSwipe,
    required this.isSentByMe,
    required this.kColor,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double _dragExtent = 0;
  static const double _swipeThreshold = 60.0;
  bool _hasTriggered = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;

    if (widget.isSentByMe) {
      _dragExtent = (_dragExtent + delta).clamp(-_swipeThreshold * 1.5, 0);
    } else {
      _dragExtent = (_dragExtent + delta).clamp(0, _swipeThreshold * 1.5);
    }

    setState(() {});

    if (_dragExtent.abs() >= _swipeThreshold && !_hasTriggered) {
      _hasTriggered = true;
      HapticFeedback.mediumImpact();
    } else if (_dragExtent.abs() < _swipeThreshold) {
      _hasTriggered = false;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragExtent.abs() >= _swipeThreshold) {
      widget.onSwipe();
    }

    _dragExtent = 0;
    _hasTriggered = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragExtent.abs() / _swipeThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        alignment: widget.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          Positioned(
            left: widget.isSentByMe ? null : 8.w,
            right: widget.isSentByMe ? 8.w : null,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.5 + (progress * 0.5),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(color: widget.kColor.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(Icons.reply, size: 20.w, color: widget.kColor),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dragExtent, 0), child: widget.child),
        ],
      ),
    );
  }
}
