import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Service for caching audio files locally for offline playback
class AudioCacheService {
  AudioCacheService._();
  static final AudioCacheService _instance = AudioCacheService._();
  factory AudioCacheService() => _instance;

  static const String _cacheFolder = 'audio_cache';
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100 MB max cache size
  static const Duration _maxCacheAge = Duration(days: 7); // Cache files for 7 days

  Directory? _cacheDir;
  bool _isInitialized = false;

  // Track ongoing downloads to prevent duplicate requests
  final Set<String> _downloadingUrls = {};

  /// Initialize the cache directory
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/$_cacheFolder');

      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      _isInitialized = true;

      // Clean up old cache files in background
      _cleanupOldFiles();
    } catch (e) {
      debugPrint('AudioCacheService: Error initializing cache: $e');
    }
  }

  /// Get the local file path for an audio URL
  /// Returns the cached file path if exists, otherwise downloads and caches
  Future<String?> getAudioFile(String url) async {
    await initialize();

    if (_cacheDir == null) return null;

    final fileName = _getFileNameFromUrl(url);
    final cachedFile = File('${_cacheDir!.path}/$fileName');

    // Check if file exists in cache
    if (await cachedFile.exists()) {
      debugPrint('AudioCacheService: Cache hit for $url');
      // Update last accessed time
      await cachedFile.setLastAccessed(DateTime.now());
      return cachedFile.path;
    }

    // Download and cache the file
    debugPrint('AudioCacheService: Cache miss, downloading $url');
    return await _downloadAndCache(url, cachedFile);
  }

  /// Check if an audio file is cached
  Future<bool> isCached(String url) async {
    await initialize();

    if (_cacheDir == null) return false;

    final fileName = _getFileNameFromUrl(url);
    final cachedFile = File('${_cacheDir!.path}/$fileName');

    return await cachedFile.exists();
  }

  /// Get cached file path without downloading (returns null if not cached)
  Future<String?> getCachedFilePath(String url) async {
    await initialize();

    if (_cacheDir == null) return null;

    final fileName = _getFileNameFromUrl(url);
    final cachedFile = File('${_cacheDir!.path}/$fileName');

    if (await cachedFile.exists()) {
      return cachedFile.path;
    }

    return null;
  }

  /// Pre-cache an audio file (download in background)
  Future<void> preCacheAudio(String url) async {
    await initialize();

    if (_cacheDir == null) return;

    // Skip if already downloading
    if (_downloadingUrls.contains(url)) return;

    final fileName = _getFileNameFromUrl(url);
    final cachedFile = File('${_cacheDir!.path}/$fileName');

    // Skip if already cached
    if (await cachedFile.exists()) return;

    // Mark as downloading and start download in background
    _downloadingUrls.add(url);
    _downloadAndCache(url, cachedFile).whenComplete(() {
      _downloadingUrls.remove(url);
    });
  }

  /// Clear all cached audio files
  Future<void> clearCache() async {
    await initialize();

    if (_cacheDir == null) return;

    try {
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
      debugPrint('AudioCacheService: Cache cleared');
    } catch (e) {
      debugPrint('AudioCacheService: Error clearing cache: $e');
    }
  }

  /// Get total cache size in bytes
  Future<int> getCacheSize() async {
    await initialize();

    if (_cacheDir == null) return 0;

    try {
      int totalSize = 0;
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      debugPrint('AudioCacheService: Error getting cache size: $e');
      return 0;
    }
  }

  /// Generate a unique filename from URL using MD5 hash
  String _getFileNameFromUrl(String url) {
    final bytes = utf8.encode(url);
    final hash = md5.convert(bytes);

    // Extract file extension from URL
    String extension = '.m4a'; // Default extension
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      if (path.contains('.')) {
        extension = path.substring(path.lastIndexOf('.'));
        // Limit extension length and sanitize
        if (extension.length > 5 || extension.contains('/')) {
          extension = '.m4a';
        }
      }
    } catch (_) {}

    return '${hash.toString()}$extension';
  }

  /// Download audio file and save to cache
  Future<String?> _downloadAndCache(String url, File targetFile) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        await targetFile.writeAsBytes(response.bodyBytes);
        debugPrint('AudioCacheService: Cached audio to ${targetFile.path}');

        // Check cache size and cleanup if needed
        _checkCacheSize();

        return targetFile.path;
      } else {
        debugPrint('AudioCacheService: Failed to download audio: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('AudioCacheService: Error downloading audio: $e');
      return null;
    }
  }

  /// Clean up old cache files
  Future<void> _cleanupOldFiles() async {
    if (_cacheDir == null) return;

    try {
      final now = DateTime.now();
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.accessed);

          if (age > _maxCacheAge) {
            await entity.delete();
            debugPrint('AudioCacheService: Deleted old cache file: ${entity.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('AudioCacheService: Error cleaning up old files: $e');
    }
  }

  /// Check cache size and remove oldest files if over limit
  Future<void> _checkCacheSize() async {
    if (_cacheDir == null) return;

    try {
      final files = <File>[];
      int totalSize = 0;

      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          files.add(entity);
          totalSize += await entity.length();
        }
      }

      if (totalSize <= _maxCacheSize) return;

      // Sort by last accessed time (oldest first)
      final fileStats = <File, FileStat>{};
      for (final file in files) {
        fileStats[file] = await file.stat();
      }

      files.sort((a, b) {
        final statA = fileStats[a]!;
        final statB = fileStats[b]!;
        return statA.accessed.compareTo(statB.accessed);
      });

      // Delete oldest files until under limit
      for (final file in files) {
        if (totalSize <= _maxCacheSize) break;

        final fileSize = await file.length();
        await file.delete();
        totalSize -= fileSize;
        debugPrint('AudioCacheService: Deleted cache file to free space: ${file.path}');
      }
    } catch (e) {
      debugPrint('AudioCacheService: Error checking cache size: $e');
    }
  }
}
