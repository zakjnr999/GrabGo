import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/shared/services/voice_player_service.dart';

/// A widget that displays a voice message with playback controls
/// Styled similar to WhatsApp voice messages
class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.isSentByMe,
    this.isRead = false,
    this.timestamp,
    this.bubbleColor,
    this.iconColor,
    this.textColor,
    this.progressColor,
    this.progressBackgroundColor,
  });

  final String audioUrl;
  final double duration; // Duration in seconds
  final bool isSentByMe;
  final bool isRead;
  final DateTime? timestamp;
  final Color? bubbleColor;
  final Color? iconColor;
  final Color? textColor;
  final Color? progressColor;
  final Color? progressBackgroundColor;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final VoicePlayerService _playerService = VoicePlayerService();
  bool _isPlaying = false;
  double _progress = 0;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _playerService.initialize();
    _playerService.onPositionChanged = _handlePositionChanged;
    _playerService.onPlayCompleted = _handlePlayCompleted;
    _playerService.onPlayStarted = _handlePlayStarted;
    _playerService.onPlayPaused = _handlePlayPaused;
  }

  void _handlePositionChanged(String url, Duration position, Duration total) {
    if (url != widget.audioUrl || !mounted) return;
    setState(() {
      _currentPosition = position;
      if (total.inMilliseconds > 0) {
        _progress = position.inMilliseconds / total.inMilliseconds;
      }
    });
  }

  void _handlePlayCompleted(String url) {
    if (url != widget.audioUrl || !mounted) return;
    setState(() {
      _isPlaying = false;
      _progress = 0;
      _currentPosition = Duration.zero;
    });
  }

  void _handlePlayStarted(String url) {
    if (url != widget.audioUrl || !mounted) return;
    setState(() {
      _isPlaying = true;
    });
  }

  void _handlePlayPaused(String url) {
    if (url != widget.audioUrl || !mounted) return;
    setState(() {
      _isPlaying = false;
    });
  }

  void _togglePlayback() {
    _playerService.toggle(widget.audioUrl);
  }

  String _formatDuration(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  String _formatCurrentPosition() {
    if (_currentPosition == Duration.zero) {
      return _formatDuration(widget.duration);
    }
    return VoicePlayerService.formatDuration(_currentPosition);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Default colors based on sender and theme
    final defaultBubbleColor = widget.isSentByMe
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
        : (isDark ? const Color(0xFF1F2C34) : Colors.white);

    final defaultIconColor = widget.isSentByMe
        ? (isDark ? Colors.white : const Color(0xFF075E54))
        : (isDark ? Colors.white70 : const Color(0xFF075E54));

    final defaultTextColor = isDark ? Colors.white70 : Colors.black54;

    final defaultProgressColor = widget.isSentByMe
        ? (isDark ? const Color(0xFF25D366) : const Color(0xFF075E54))
        : (isDark ? const Color(0xFF25D366) : const Color(0xFF075E54));

    final defaultProgressBgColor = isDark ? Colors.white24 : Colors.black12;

    final bubbleColor = widget.bubbleColor ?? defaultBubbleColor;
    final iconColor = widget.iconColor ?? defaultIconColor;
    final textColor = widget.textColor ?? defaultTextColor;
    final progressColor = widget.progressColor ?? defaultProgressColor;
    final progressBgColor = widget.progressBackgroundColor ?? defaultProgressBgColor;

    return Container(
      constraints: BoxConstraints(maxWidth: 260.w, minWidth: 200.w),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(16.r)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlayback,
            child: Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
              child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: bubbleColor, size: 28.sp),
            ),
          ),
          SizedBox(width: 10.w),
          // Progress and duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: progressBgColor,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 4.h,
                  ),
                ),
                SizedBox(height: 6.h),
                // Duration and timestamp
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatCurrentPosition(),
                      style: TextStyle(fontSize: 12.sp, color: textColor),
                    ),
                    if (widget.timestamp != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(widget.timestamp!),
                            style: TextStyle(fontSize: 11.sp, color: textColor),
                          ),
                          if (widget.isSentByMe) ...[
                            SizedBox(width: 4.w),
                            Icon(
                              widget.isRead ? Icons.done_all : Icons.done,
                              size: 14.sp,
                              color: widget.isRead ? const Color(0xFF34B7F1) : textColor,
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// A compact recording indicator widget
/// Shows during voice recording with duration and cancel option
class VoiceRecordingIndicator extends StatelessWidget {
  const VoiceRecordingIndicator({
    super.key,
    required this.duration,
    required this.onCancel,
    this.isLocked = false,
    this.onSend,
  });

  final Duration duration;
  final VoidCallback onCancel;
  final bool isLocked;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2C34) : Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Recording indicator
          Container(
            width: 12.w,
            height: 12.w,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
          SizedBox(width: 12.w),
          // Duration
          Text(
            _formatDuration(duration),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          if (!isLocked) ...[
            // Slide to cancel hint
            Text(
              '< Slide to cancel',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey),
            ),
          ] else ...[
            // Cancel button
            IconButton(
              onPressed: onCancel,
              icon: Icon(Icons.delete_outline, color: Colors.red, size: 24.sp),
            ),
            // Send button
            IconButton(
              onPressed: onSend,
              icon: Icon(Icons.send, color: theme.primaryColor, size: 24.sp),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
