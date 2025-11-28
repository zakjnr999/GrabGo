import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Service to extract waveform data from audio files
/// Generates amplitude samples for visualization
class WaveformExtractor {
  WaveformExtractor._();
  static final WaveformExtractor _instance = WaveformExtractor._();
  factory WaveformExtractor() => _instance;

  // Cache for extracted waveforms (URL/path -> waveform data)
  final Map<String, List<double>> _waveformCache = {};
  static const int _maxCacheEntries = 100; // Limit cache size

  /// Check if waveform is cached for a URL
  bool hasCachedWaveform(String urlOrPath) {
    return _waveformCache.containsKey(urlOrPath);
  }

  /// Get cached waveform if available
  List<double>? getCachedWaveform(String urlOrPath) {
    return _waveformCache[urlOrPath];
  }

  /// Cache waveform for a URL (useful when extracting from file but want to cache by URL)
  void cacheWaveform(String urlOrPath, List<double> waveform) {
    if (_waveformCache.length >= _maxCacheEntries) {
      _waveformCache.remove(_waveformCache.keys.first);
    }
    _waveformCache[urlOrPath] = waveform;
  }

  /// Extract waveform from an audio file
  /// Returns a list of normalized amplitude values (0.0 to 1.0)
  /// [barCount] - Number of bars to generate for the waveform
  /// [cacheKey] - Optional key to cache the result (e.g., original URL)
  Future<List<double>> extractWaveform(String filePath, {int barCount = 28, String? cacheKey}) async {
    final key = cacheKey ?? filePath;

    // Check cache first
    if (_waveformCache.containsKey(key)) {
      return _waveformCache[key]!;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('WaveformExtractor: File not found: $filePath');
        return _generateFallbackWaveform(filePath, barCount);
      }

      final bytes = await file.readAsBytes();
      final waveform = await compute(_extractWaveformFromBytes, _WaveformParams(bytes, barCount));

      // Cache the result (with size limit)
      if (_waveformCache.length >= _maxCacheEntries) {
        // Remove oldest entry (first key)
        _waveformCache.remove(_waveformCache.keys.first);
      }
      _waveformCache[key] = waveform;

      return waveform;
    } catch (e) {
      debugPrint('WaveformExtractor: Error extracting waveform: $e');
      return _generateFallbackWaveform(filePath, barCount);
    }
  }

  /// Extract waveform from bytes (for use with cached audio)
  Future<List<double>> extractWaveformFromBytes(Uint8List bytes, {int barCount = 28}) async {
    try {
      return await compute(_extractWaveformFromBytes, _WaveformParams(bytes, barCount));
    } catch (e) {
      debugPrint('WaveformExtractor: Error extracting waveform from bytes: $e');
      return _generateFallbackWaveform('', barCount);
    }
  }

  /// Generate a fallback waveform based on hash (used when extraction fails)
  List<double> _generateFallbackWaveform(String seed, int barCount) {
    final random = math.Random(seed.hashCode);
    return List.generate(barCount, (index) {
      final base = 0.3 + random.nextDouble() * 0.7;
      final variation = math.sin(index * 0.5) * 0.2;
      return (base + variation).clamp(0.2, 1.0);
    });
  }

  /// Clear waveform cache
  void clearCache() {
    _waveformCache.clear();
  }

  /// Remove specific entry from cache
  void removeFromCache(String filePath) {
    _waveformCache.remove(filePath);
  }
}

/// Parameters for isolate computation
class _WaveformParams {
  final Uint8List bytes;
  final int barCount;

  _WaveformParams(this.bytes, this.barCount);
}

/// Extract waveform from audio bytes (runs in isolate)
List<double> _extractWaveformFromBytes(_WaveformParams params) {
  final bytes = params.bytes;
  final barCount = params.barCount;

  if (bytes.isEmpty) {
    return _generateDefaultWaveform(barCount);
  }

  try {
    // Try to detect audio format and extract samples
    List<double>? samples;

    // Check for common audio format headers
    if (_isM4A(bytes) || _isAAC(bytes)) {
      samples = _extractFromM4A(bytes);
    } else if (_isOgg(bytes)) {
      samples = _extractFromOgg(bytes);
    } else if (_isWav(bytes)) {
      samples = _extractFromWav(bytes);
    } else if (_isMp3(bytes)) {
      samples = _extractFromMp3(bytes);
    }

    // If format-specific extraction failed, use generic approach
    samples ??= _extractGenericSamples(bytes);

    if (samples.isEmpty) {
      return _generateDefaultWaveform(barCount);
    }

    // Downsample to barCount
    return _downsampleToWaveform(samples, barCount);
  } catch (e) {
    return _generateDefaultWaveform(barCount);
  }
}

/// Check if bytes represent M4A/AAC format
bool _isM4A(Uint8List bytes) {
  if (bytes.length < 12) return false;
  // Check for ftyp box
  return bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70;
}

/// Check if bytes represent AAC format
bool _isAAC(Uint8List bytes) {
  if (bytes.length < 2) return false;
  // ADTS sync word
  return bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0;
}

/// Check if bytes represent OGG format
bool _isOgg(Uint8List bytes) {
  if (bytes.length < 4) return false;
  // OggS magic
  return bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53;
}

/// Check if bytes represent WAV format
bool _isWav(Uint8List bytes) {
  if (bytes.length < 12) return false;
  // RIFF....WAVE
  return bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x41 &&
      bytes[10] == 0x56 &&
      bytes[11] == 0x45;
}

/// Check if bytes represent MP3 format
bool _isMp3(Uint8List bytes) {
  if (bytes.length < 3) return false;
  // ID3 tag or MP3 sync
  return (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) || // ID3
      (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0); // MP3 sync
}

/// Extract samples from M4A/AAC container
List<double> _extractFromM4A(Uint8List bytes) {
  // For M4A, we'll extract amplitude from the mdat box
  // This is a simplified extraction - real M4A parsing is complex
  return _extractGenericSamples(bytes);
}

/// Extract samples from OGG container
List<double> _extractFromOgg(Uint8List bytes) {
  // OGG parsing is complex, use generic approach
  return _extractGenericSamples(bytes);
}

/// Extract samples from WAV file
List<double> _extractFromWav(Uint8List bytes) {
  try {
    // Find data chunk
    int dataOffset = 44; // Standard WAV header size
    int dataSize = bytes.length - dataOffset;

    // Look for 'data' chunk
    for (int i = 12; i < bytes.length - 8; i++) {
      if (bytes[i] == 0x64 && bytes[i + 1] == 0x61 && bytes[i + 2] == 0x74 && bytes[i + 3] == 0x61) {
        dataOffset = i + 8;
        dataSize = bytes[i + 4] | (bytes[i + 5] << 8) | (bytes[i + 6] << 16) | (bytes[i + 7] << 24);
        break;
      }
    }

    // Get bits per sample (usually at offset 34)
    int bitsPerSample = 16;
    if (bytes.length > 35) {
      bitsPerSample = bytes[34] | (bytes[35] << 8);
    }

    final samples = <double>[];
    final bytesPerSample = bitsPerSample ~/ 8;
    final endOffset = math.min(dataOffset + dataSize, bytes.length);

    for (int i = dataOffset; i < endOffset; i += bytesPerSample * 2) {
      // Skip every other sample for speed
      if (i + bytesPerSample > bytes.length) break;

      int sample;
      if (bytesPerSample == 2) {
        // 16-bit signed
        sample = bytes[i] | (bytes[i + 1] << 8);
        if (sample > 32767) sample -= 65536;
        samples.add(sample.abs() / 32768.0);
      } else if (bytesPerSample == 1) {
        // 8-bit unsigned
        sample = bytes[i] - 128;
        samples.add(sample.abs() / 128.0);
      }
    }

    return samples;
  } catch (e) {
    return _extractGenericSamples(bytes);
  }
}

/// Extract samples from MP3 file
List<double> _extractFromMp3(Uint8List bytes) {
  // MP3 decoding is complex, use generic approach
  return _extractGenericSamples(bytes);
}

/// Generic sample extraction - analyzes byte patterns for amplitude
List<double> _extractGenericSamples(Uint8List bytes) {
  final samples = <double>[];

  // Skip header area (first 1KB typically contains metadata)
  final startOffset = math.min(1024, bytes.length ~/ 10);
  final endOffset = bytes.length;

  // Sample every N bytes to get a reasonable number of samples
  final totalSamples = 1000; // Target number of samples
  final step = math.max(1, (endOffset - startOffset) ~/ totalSamples);

  for (int i = startOffset; i < endOffset; i += step) {
    // Analyze pairs of bytes as potential audio samples
    if (i + 1 < bytes.length) {
      // Treat as signed 16-bit little-endian
      int value = bytes[i] | (bytes[i + 1] << 8);
      if (value > 32767) value -= 65536;

      // Normalize to 0-1 range
      final normalized = value.abs() / 32768.0;
      samples.add(normalized);
    }
  }

  return samples;
}

/// Downsample raw samples to waveform bars
List<double> _downsampleToWaveform(List<double> samples, int barCount) {
  if (samples.isEmpty) {
    return _generateDefaultWaveform(barCount);
  }

  final waveform = <double>[];
  final samplesPerBar = samples.length ~/ barCount;

  if (samplesPerBar == 0) {
    // Not enough samples, pad with existing
    for (int i = 0; i < barCount; i++) {
      final index = (i * samples.length / barCount).floor();
      waveform.add(samples[index.clamp(0, samples.length - 1)]);
    }
  } else {
    for (int i = 0; i < barCount; i++) {
      final start = i * samplesPerBar;
      final end = math.min(start + samplesPerBar, samples.length);

      // Calculate RMS (root mean square) for this segment
      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += samples[j] * samples[j];
      }
      final rms = math.sqrt(sum / (end - start));

      // Apply some scaling to make the waveform more visually appealing
      final scaled = (rms * 2.5).clamp(0.15, 1.0);
      waveform.add(scaled);
    }
  }

  // Normalize the waveform
  if (waveform.isNotEmpty) {
    final maxVal = waveform.reduce(math.max);
    if (maxVal > 0) {
      for (int i = 0; i < waveform.length; i++) {
        waveform[i] = (waveform[i] / maxVal).clamp(0.2, 1.0);
      }
    }
  }

  return waveform;
}

/// Generate a default waveform pattern
List<double> _generateDefaultWaveform(int barCount) {
  return List.generate(barCount, (index) {
    // Create a natural-looking pattern
    final base = 0.4 + 0.3 * math.sin(index * 0.4);
    final variation = 0.2 * math.cos(index * 0.7);
    return (base + variation).clamp(0.2, 1.0);
  });
}
