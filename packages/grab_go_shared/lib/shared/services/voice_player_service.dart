import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for playing voice messages
/// Manages a single audio player instance for the app
class VoicePlayerService {
  VoicePlayerService._();
  static final VoicePlayerService _instance = VoicePlayerService._();
  factory VoicePlayerService() => _instance;

  final AudioPlayer _player = AudioPlayer();

  String? _currentlyPlayingUrl;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  // Callbacks
  void Function(String url)? onPlayStarted;
  void Function(String url)? onPlayPaused;
  void Function(String url)? onPlayCompleted;
  void Function(String url, Duration position, Duration total)? onPositionChanged;
  void Function(String error)? onError;

  bool get isPlaying => _isPlaying;
  String? get currentlyPlayingUrl => _currentlyPlayingUrl;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;

  double get progress {
    if (_totalDuration.inMilliseconds == 0) return 0;
    return _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
  }

  /// Initialize the player and set up listeners
  void initialize() {
    _positionSubscription = _player.onPositionChanged.listen((position) {
      _currentPosition = position;
      if (_currentlyPlayingUrl != null) {
        onPositionChanged?.call(_currentlyPlayingUrl!, position, _totalDuration);
      }
    });

    _durationSubscription = _player.onDurationChanged.listen((duration) {
      _totalDuration = duration;
    });

    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      switch (state) {
        case PlayerState.playing:
          _isPlaying = true;
          if (_currentlyPlayingUrl != null) {
            onPlayStarted?.call(_currentlyPlayingUrl!);
          }
          break;
        case PlayerState.paused:
          _isPlaying = false;
          if (_currentlyPlayingUrl != null) {
            onPlayPaused?.call(_currentlyPlayingUrl!);
          }
          break;
        case PlayerState.stopped:
        case PlayerState.completed:
          _isPlaying = false;
          if (_currentlyPlayingUrl != null) {
            onPlayCompleted?.call(_currentlyPlayingUrl!);
          }
          _currentPosition = Duration.zero;
          break;
        case PlayerState.disposed:
          _isPlaying = false;
          break;
      }
    });
  }

  /// Play a voice message from URL
  Future<void> play(String url) async {
    try {
      // If playing the same URL, just resume
      if (_currentlyPlayingUrl == url && !_isPlaying) {
        await _player.resume();
        return;
      }

      // If playing a different URL, stop current and play new
      if (_currentlyPlayingUrl != null && _currentlyPlayingUrl != url) {
        await stop();
      }

      _currentlyPlayingUrl = url;
      _currentPosition = Duration.zero;

      await _player.play(UrlSource(url));
    } catch (e) {
      debugPrint('VoicePlayerService: Error playing audio: $e');
      onError?.call('Failed to play voice message');
    }
  }

  /// Play a voice message from local file path
  Future<void> playFile(String path) async {
    try {
      // If playing the same file, just resume
      if (_currentlyPlayingUrl == path && !_isPlaying) {
        await _player.resume();
        return;
      }

      // If playing a different file, stop current and play new
      if (_currentlyPlayingUrl != null && _currentlyPlayingUrl != path) {
        await stop();
      }

      _currentlyPlayingUrl = path;
      _currentPosition = Duration.zero;

      await _player.play(DeviceFileSource(path));
    } catch (e) {
      debugPrint('VoicePlayerService: Error playing audio file: $e');
      onError?.call('Failed to play voice message');
    }
  }

  /// Pause the current playback
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('VoicePlayerService: Error pausing audio: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (e) {
      debugPrint('VoicePlayerService: Error resuming audio: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await _player.stop();
      _currentlyPlayingUrl = null;
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;
    } catch (e) {
      debugPrint('VoicePlayerService: Error stopping audio: $e');
    }
  }

  /// Seek to a specific position
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('VoicePlayerService: Error seeking audio: $e');
    }
  }

  /// Toggle play/pause for a specific URL
  Future<void> toggle(String url) async {
    if (_currentlyPlayingUrl == url && _isPlaying) {
      await pause();
    } else {
      await play(url);
    }
  }

  /// Check if a specific URL is currently playing
  bool isPlayingUrl(String url) {
    return _currentlyPlayingUrl == url && _isPlaying;
  }

  /// Format duration as mm:ss
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Dispose resources
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _stateSubscription?.cancel();
    _player.dispose();
  }
}
