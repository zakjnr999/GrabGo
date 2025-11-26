import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Service for recording voice messages
/// Uses Opus codec for WhatsApp-style compression
class VoiceRecorderService {
  VoiceRecorderService._();
  static final VoiceRecorderService _instance = VoiceRecorderService._();
  factory VoiceRecorderService() => _instance;

  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  Timer? _durationTimer;

  // Callbacks
  void Function(Duration)? onDurationChanged;
  void Function()? onRecordingStarted;
  void Function(String path, Duration duration)? onRecordingStopped;
  void Function(String error)? onError;

  bool get isRecording => _isRecording;

  Duration get currentDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Start recording a voice message
  Future<bool> startRecording() async {
    try {
      // Check permission
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          onError?.call('Microphone permission denied');
          return false;
        }
      }

      // Check if already recording
      if (_isRecording) {
        return false;
      }

      // Check if recorder is available
      if (!await _recorder.hasPermission()) {
        onError?.call('Microphone not available');
        return false;
      }

      // Generate unique file path
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/voice_message_$timestamp.m4a';

      // Configure and start recording
      // Using AAC encoder for better compatibility
      // Opus would be ideal but m4a/AAC has better cross-platform support
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();

      // Start duration timer
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        onDurationChanged?.call(currentDuration);
      });

      onRecordingStarted?.call();
      return true;
    } catch (e) {
      debugPrint('VoiceRecorderService: Error starting recording: $e');
      onError?.call('Failed to start recording');
      return false;
    }
  }

  /// Stop recording and return the file path and duration
  Future<(String? path, Duration duration)?> stopRecording() async {
    if (!_isRecording) {
      return null;
    }

    try {
      _durationTimer?.cancel();
      _durationTimer = null;

      final duration = currentDuration;
      final path = await _recorder.stop();

      _isRecording = false;
      _recordingStartTime = null;

      if (path != null && path.isNotEmpty) {
        // Verify file exists
        final file = File(path);
        if (await file.exists()) {
          onRecordingStopped?.call(path, duration);
          return (path, duration);
        }
      }

      onError?.call('Recording file not found');
      return null;
    } catch (e) {
      debugPrint('VoiceRecorderService: Error stopping recording: $e');
      _isRecording = false;
      _recordingStartTime = null;
      onError?.call('Failed to stop recording');
      return null;
    }
  }

  /// Cancel the current recording without saving
  Future<void> cancelRecording() async {
    if (!_isRecording) {
      return;
    }

    try {
      _durationTimer?.cancel();
      _durationTimer = null;

      await _recorder.stop();

      // Delete the partial recording file
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      _isRecording = false;
      _recordingStartTime = null;
      _currentRecordingPath = null;
    } catch (e) {
      debugPrint('VoiceRecorderService: Error canceling recording: $e');
      _isRecording = false;
      _recordingStartTime = null;
    }
  }

  /// Delete a recorded file
  Future<void> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('VoiceRecorderService: Error deleting recording: $e');
    }
  }

  /// Format duration as mm:ss
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Dispose resources
  void dispose() {
    _durationTimer?.cancel();
    _recorder.dispose();
  }
}
