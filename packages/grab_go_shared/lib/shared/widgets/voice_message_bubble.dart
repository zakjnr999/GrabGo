import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/services/audio_cache_service.dart';
import 'package:grab_go_shared/shared/services/voice_player_service.dart';
import 'package:grab_go_shared/shared/services/waveform_extractor.dart';
import 'package:grab_go_shared/shared/widgets/waveform_painter.dart';

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
  final AudioCacheService _cacheService = AudioCacheService();
  final WaveformExtractor _waveformExtractor = WaveformExtractor();

  bool _isPlaying = false;
  bool _isLoading = false;
  double _progress = 0;
  Duration _currentPosition = Duration.zero;
  double _waveformWidth = 0;
  double _playbackSpeed = 1.0;

  StreamSubscription<PositionUpdate>? _positionSubscription;
  StreamSubscription<PlaybackState>? _stateSubscription;

  // Waveform bars - initially placeholder, then real data
  List<double> _waveformBars = [];
  bool _hasRealWaveform = false;
  static const int _barCount = 28;

  @override
  void initState() {
    super.initState();
    _generateWaveform();
    _setupPlayerListeners();
    // Pre-cache audio for offline playback (only for remote URLs)
    if (widget.audioUrl.startsWith('http')) {
      _playerService.preCacheAudio(widget.audioUrl);
    }
  }

  @override
  void didUpdateWidget(VoiceMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only regenerate waveform if URL changed
    if (oldWidget.audioUrl != widget.audioUrl) {
      _hasRealWaveform = false;
      _generateWaveform();
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _stateSubscription?.cancel();
    // Stop playback if this widget's audio is currently playing
    if (_playerService.currentlyPlayingUrl == widget.audioUrl && _playerService.isPlaying) {
      _playerService.stop();
    }
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
          case PlaybackStatus.loading:
            _isLoading = true;
            _isPlaying = false;
            break;
          case PlaybackStatus.playing:
            _isLoading = false;
            _isPlaying = true;
            // Sync playback speed from service
            _playbackSpeed = _playerService.playbackSpeed;
            break;
          case PlaybackStatus.paused:
            _isLoading = false;
            _isPlaying = false;
            break;
          case PlaybackStatus.completed:
            _isLoading = false;
            _isPlaying = false;
            _progress = 0;
            _currentPosition = Duration.zero;
            break;
        }
      });
    });
  }

  void _generateWaveform() {
    // Check if we already have cached waveform for this URL
    final cachedWaveform = _waveformExtractor.getCachedWaveform(widget.audioUrl);
    if (cachedWaveform != null && cachedWaveform.isNotEmpty) {
      debugPrint('VoiceMessageBubble: Using cached waveform for ${widget.audioUrl}');
      _waveformBars = cachedWaveform;
      _hasRealWaveform = true;
      return;
    }

    debugPrint('VoiceMessageBubble: No cached waveform, generating placeholder for ${widget.audioUrl}');
    // Start with placeholder waveform based on hash
    _waveformBars = _generatePlaceholderWaveform();

    // Try to extract real waveform from cached audio
    _extractRealWaveform();
  }

  List<double> _generatePlaceholderWaveform() {
    // Generate deterministic waveform based on audio URL hash
    final random = math.Random(widget.audioUrl.hashCode);
    return List.generate(_barCount, (index) {
      final base = 0.3 + random.nextDouble() * 0.7;
      final variation = math.sin(index * 0.5) * 0.2;
      return (base + variation).clamp(0.2, 1.0);
    });
  }

  Future<void> _extractRealWaveform() async {
    // Don't re-extract if we already have real waveform
    if (_hasRealWaveform) {
      debugPrint('VoiceMessageBubble: Already have real waveform, skipping extraction');
      return;
    }

    // Capture the URL before any async operations
    final audioUrl = widget.audioUrl;

    try {
      String? filePath;

      // Check if it's a local file or remote URL
      if (audioUrl.startsWith('http')) {
        // Try to get cached file path
        filePath = await _cacheService.getCachedFilePath(audioUrl);
        debugPrint('VoiceMessageBubble: Cached file path (attempt 1): $filePath');

        // If not cached yet, wait for cache and try again
        if (filePath == null) {
          // Wait a bit for pre-caching to complete
          await Future.delayed(const Duration(milliseconds: 1000));
          filePath = await _cacheService.getCachedFilePath(audioUrl);
          debugPrint('VoiceMessageBubble: Cached file path (attempt 2): $filePath');
        }

        // If still not cached, try one more time after longer delay
        if (filePath == null) {
          await Future.delayed(const Duration(milliseconds: 2000));
          filePath = await _cacheService.getCachedFilePath(audioUrl);
          debugPrint('VoiceMessageBubble: Cached file path (attempt 3): $filePath');
        }
      } else {
        // Local file
        filePath = audioUrl;
      }

      if (filePath != null) {
        debugPrint('VoiceMessageBubble: Extracting waveform from $filePath');
        // Extract and cache waveform even if widget is unmounted
        // This ensures the waveform is cached for next time
        final waveform = await _waveformExtractor.extractWaveform(
          filePath,
          barCount: _barCount,
          cacheKey: audioUrl, // Cache by URL, not file path
        );

        debugPrint('VoiceMessageBubble: Extracted waveform with ${waveform.length} bars');

        // Only update UI if still mounted
        if (mounted && waveform.isNotEmpty) {
          setState(() {
            _waveformBars = waveform;
            _hasRealWaveform = true;
          });
          debugPrint('VoiceMessageBubble: Real waveform set successfully');
        } else {
          debugPrint('VoiceMessageBubble: Widget unmounted, but waveform is cached for next time');
        }
      } else {
        debugPrint('VoiceMessageBubble: No file path available for waveform extraction');
      }
    } catch (e) {
      // Keep placeholder waveform on error
      debugPrint('VoiceMessageBubble: Error extracting waveform: $e');
    }
  }

  Future<void> _togglePlayback() async {
    await _playerService.toggle(widget.audioUrl);
  }

  void _seekToPosition(double tapX) {
    if (_waveformWidth <= 0) return;

    // Only seek if this audio is currently loaded
    if (_playerService.currentlyPlayingUrl != widget.audioUrl) return;

    final seekProgress = (tapX / _waveformWidth).clamp(0.0, 1.0);
    final totalMs = widget.duration * 1000;
    final seekPosition = Duration(milliseconds: (seekProgress * totalMs).round());

    _playerService.seek(seekPosition);
  }

  Future<void> _cycleSpeed() async {
    // Only allow speed change if this audio is currently playing
    if (_playerService.currentlyPlayingUrl != widget.audioUrl) return;

    final newSpeed = await _playerService.cyclePlaybackSpeed();
    if (mounted) {
      setState(() {
        _playbackSpeed = newSpeed;
      });
    }
  }

  String _formatSpeed(double speed) {
    if (speed == 1.0) return '1x';
    if (speed == 1.5) return '1.5x';
    if (speed == 2.0) return '2x';
    return '${speed}x';
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
        // Play/Pause button or loading spinner
        GestureDetector(
          onTap: _isLoading ? null : _togglePlayback,
          child: Container(
            width: 36.w,
            height: 36.w,
            padding: EdgeInsets.all(5.r),
            decoration: BoxDecoration(color: widget.accentColor ?? Colors.white, shape: BoxShape.circle),
            child: _isLoading
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: playIconColor),
                  )
                : SvgPicture.asset(
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
              // Custom waveform (tappable to seek)
              GestureDetector(
                onTapDown: (details) => _seekToPosition(details.localPosition.dx),
                onHorizontalDragUpdate: (details) => _seekToPosition(details.localPosition.dx),
                child: SizedBox(
                  height: 24.h,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _waveformWidth = constraints.maxWidth;
                      return CustomPaint(
                        size: Size(double.infinity, 24.h),
                        painter: WaveformPainter(
                          bars: _waveformBars,
                          progress: _progress,
                          activeColor:
                              widget.waveActiveColor ??
                              (widget.isSentByMe ? Colors.white : (widget.accentColor ?? Colors.grey)),
                          inactiveColor:
                              widget.waveInactiveColor ??
                              (widget.isSentByMe ? Colors.white38 : Colors.grey.withValues(alpha: 0.3)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: 4.h),
              // Duration and speed control
              Row(
                children: [
                  Text(
                    _formatCurrentPosition(),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: widget.textColor ?? Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Spacer(),
                  // Speed control (only show when this audio is active)
                  if (_isPlaying || _playerService.currentlyPlayingUrl == widget.audioUrl)
                    GestureDetector(
                      onTap: _cycleSpeed,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: (widget.accentColor ?? Colors.grey).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          _formatSpeed(_playbackSpeed),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: widget.textColor ?? Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for waveform visualization
