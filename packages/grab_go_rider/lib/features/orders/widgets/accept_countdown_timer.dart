import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class AcceptCountdownTimer extends StatefulWidget {
  final int duration;
  final VoidCallback onExpired;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const AcceptCountdownTimer({
    super.key,
    this.duration = 30,
    required this.onExpired,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<AcceptCountdownTimer> createState() => _AcceptCountdownTimerState();
}

class _AcceptCountdownTimerState extends State<AcceptCountdownTimer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _remainingSeconds;
  Timer? _timer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.duration;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.duration),
    );
    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        if (!_disposed) {
          widget.onExpired();
        }
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Color _getTimerColor(AppColorsExtension colors) {
    if (_remainingSeconds <= 5) {
      return colors.error;
    } else if (_remainingSeconds <= 10) {
      return colors.accentOrange;
    }
    return colors.accentGreen;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final progress = _remainingSeconds / widget.duration;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 105.w,
              height: 105.w,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 6.w,
                backgroundColor: colors.border.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation<Color>(_getTimerColor(colors)),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$_remainingSeconds',
                  style: TextStyle(color: _getTimerColor(colors), fontSize: 28.sp, fontWeight: FontWeight.w700),
                ),
                Text(
                  'sec',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 20.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onDecline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error, width: 1),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
                ),
                child: Text(
                  'Decline',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: widget.onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentGreen,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
                  elevation: 0,
                ),
                child: Text(
                  'Accept Order',
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
