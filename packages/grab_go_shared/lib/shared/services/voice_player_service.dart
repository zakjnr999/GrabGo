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
  bool _isInitialized = false;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<PlayerState>? _stateSubscription;

  // Stream controllers for broadcasting events to multiple listeners
  final _positionController = StreamController<PositionUpdate>.broadcast();
  final _stateController = StreamController<PlaybackState>.broadcast();

  /// Stream of position updates
  Stream<PositionUpdate> get positionStream => _positionController.stream;

  /// Stream of playback state changes
  Stream<PlaybackState> get stateStream => _stateController.stream;

  bool get isPlaying => _isPlaying;
  String? get currentlyPlayingUrl => _currentlyPlayingUrl;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;

  double get progress {
    if (_totalDuration.inMilliseconds == 0) return 0;
    return _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
  }

  /// Initialize the player and set up listeners (idempotent)
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _positionSubscription = _player.onPositionChanged.listen((position) {
      _currentPosition = position;
      if (_currentlyPlayingUrl != null) {
        _positionController.add(PositionUpdate(url: _currentlyPlayingUrl!, position: position, total: _totalDuration));
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
            _stateController.add(PlaybackState(url: _currentlyPlayingUrl!, state: PlaybackStatus.playing));
          }
          break;
        case PlayerState.paused:
          _isPlaying = false;
          if (_currentlyPlayingUrl != null) {
            _stateController.add(PlaybackState(url: _currentlyPlayingUrl!, state: PlaybackStatus.paused));
          }
          break;
        case PlayerState.stopped:
        case PlayerState.completed:
          _isPlaying = false;
          if (_currentlyPlayingUrl != null) {
            _stateController.add(PlaybackState(url: _currentlyPlayingUrl!, state: PlaybackStatus.completed));
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
    initialize(); // Ensure initialized
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
    }
  }

  /// Play a voice message from local file path
  Future<void> playFile(String path) async {
    initialize(); // Ensure initialized
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

  /// Toggle play/pause for a specific URL or file path
  Future<void> toggle(String urlOrPath) async {
    initialize(); // Ensure initialized before any operation
    if (_currentlyPlayingUrl == urlOrPath && _isPlaying) {
      await pause();
    } else if (_currentlyPlayingUrl == urlOrPath && !_isPlaying) {
      await resume();
    } else {
      // Determine if it's a local file or remote URL
      if (urlOrPath.startsWith('http')) {
        await play(urlOrPath);
      } else {
        await playFile(urlOrPath);
      }
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
    _positionController.close();
    _stateController.close();
    _player.dispose();
  }
}

/// Data class for position updates
class PositionUpdate {
  final String url;
  final Duration position;
  final Duration total;

  PositionUpdate({required this.url, required this.position, required this.total});
}

/// Playback status enum
enum PlaybackStatus { playing, paused, completed }

/// Data class for playback state changes
class PlaybackState {
  final String url;
  final PlaybackStatus state;

  PlaybackState({required this.url, required this.state});
}
