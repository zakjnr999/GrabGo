import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/services/voice_player_service.dart';

/// Voice message content widget - displays inside the message bubble
/// Matches the app's message bubble style with custom waveform visualization
class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.isSentByMe,
    this.isRead = false,
    this.timestamp,
    this.accentColor,
    this.textColor,
    this.waveActiveColor,
    this.waveInactiveColor,
    this.playButtonIconColor,
  });

  final String audioUrl;
  final double duration; // Duration in seconds
  final bool isSentByMe;
  final bool isRead;
  final DateTime? timestamp;
  final Color? accentColor;
  final Color? textColor;
  final Color? waveActiveColor;
  final Color? waveInactiveColor;
  final Color? playButtonIconColor;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final VoicePlayerService _playerService = VoicePlayerService();
  bool _isPlaying = false;
  double _progress = 0;
  Duration _currentPosition = Duration.zero;

  StreamSubscription<PositionUpdate>? _positionSubscription;
  StreamSubscription<PlaybackState>? _stateSubscription;

  // Generate consistent waveform bars based on audio URL hash
  late List<double> _waveformBars;
  static const int _barCount = 28;

  @override
  void initState() {
    super.initState();
    _generateWaveform();
    _setupPlayerListeners();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }

  void _setupPlayerListeners() {
    _playerService.initialize();

    // Subscribe to position updates
    _positionSubscription = _playerService.positionStream.listen((update) {
      if (update.url != widget.audioUrl || !mounted) return;

      setState(() {
        _currentPosition = update.position;

        // Use the player's total duration if available, otherwise use widget.duration
        final totalMs = update.total.inMilliseconds > 0
            ? update.total.inMilliseconds
            : (widget.duration * 1000).round();

        if (totalMs > 0) {
          _progress = (update.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
        }
      });
    });

    // Subscribe to playback state changes
    _stateSubscription = _playerService.stateStream.listen((state) {
      if (state.url != widget.audioUrl || !mounted) return;
      setState(() {
        switch (state.state) {
          case PlaybackStatus.playing:
            _isPlaying = true;
            break;
          case PlaybackStatus.paused:
            _isPlaying = false;
            break;
          case PlaybackStatus.completed:
            _isPlaying = false;
            _progress = 0;
            _currentPosition = Duration.zero;
            break;
        }
      });
    });
  }

  void _generateWaveform() {
    // Generate deterministic waveform based on audio URL hash
    final random = math.Random(widget.audioUrl.hashCode);
    _waveformBars = List.generate(_barCount, (index) {
      // Create a more natural waveform pattern
      final base = 0.3 + random.nextDouble() * 0.7;
      // Add some variation to make it look more organic
      final variation = math.sin(index * 0.5) * 0.2;
      return (base + variation).clamp(0.2, 1.0);
    });
  }

  Future<void> _togglePlayback() async {
    await _playerService.toggle(widget.audioUrl);
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
    // Determine play button icon color
    final playIconColor = widget.playButtonIconColor ?? (widget.isSentByMe ? Colors.black87 : Colors.white);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        GestureDetector(
          onTap: _togglePlayback,
          child: Container(
            width: 36.w,
            height: 36.w,
            padding: EdgeInsets.all(5.r),
            decoration: BoxDecoration(color: widget.accentColor ?? Colors.white, shape: BoxShape.circle),
            child: SvgPicture.asset(
              _isPlaying ? Assets.icons.pause : Assets.icons.play,
              package: "grab_go_shared",
              colorFilter: ColorFilter.mode(playIconColor, BlendMode.srcIn),
            ),
          ),
        ),
        SizedBox(width: 10.w),
        // Waveform and duration
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Custom waveform
              SizedBox(
                height: 24.h,
                child: CustomPaint(
                  size: Size(double.infinity, 24.h),
                  painter: _WaveformPainter(
                    bars: _waveformBars,
                    progress: _progress,
                    activeColor:
                        widget.waveActiveColor ??
                        (widget.isSentByMe ? Colors.white : (widget.accentColor ?? Colors.grey)),
                    inactiveColor:
                        widget.waveInactiveColor ??
                        (widget.isSentByMe ? Colors.white38 : Colors.grey.withValues(alpha: 0.3)),
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              // Duration
              Text(
                _formatCurrentPosition(),
                style: TextStyle(fontSize: 11.sp, color: widget.textColor ?? Colors.grey, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for waveform visualization
class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.bars,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final List<double> bars;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = 3.0;
    final spacing = (size.width - (bars.length * barWidth)) / (bars.length - 1);
    final maxHeight = size.height;
    final progressIndex = (progress * bars.length).floor();

    for (int i = 0; i < bars.length; i++) {
      final x = i * (barWidth + spacing);
      final barHeight = bars[i] * maxHeight;
      final y = (maxHeight - barHeight) / 2;

      final paint = Paint()
        ..color = i <= progressIndex ? activeColor : inactiveColor
        ..strokeCap = StrokeCap.round;

      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barHeight), const Radius.circular(2));
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
