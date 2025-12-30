import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

/// Service for caching images locally to show them offline
class ImageCacheService {
  static const String _cacheDirName = 'image_cache';
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const Duration _cacheExpiry = Duration(days: 7);

  static Directory? _cacheDir;
  static final Map<String, DateTime> _cacheTimestamps = {};
  static final Map<String, DateTime> _accessTimestamps = {}; // For LRU tracking

  /// Initialize the image cache service
  static Future<void> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/$_cacheDirName');

      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }

      // Load existing cache timestamps
      await _loadCacheTimestamps();

      // Clean up expired cache on startup
      await clearExpiredCache();

      if (kDebugMode) {
        print('Image cache initialized: ${_cacheDir!.path}');
        print('Cached images: ${_cacheTimestamps.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing image cache: $e');
      }
    }
  }

  /// Load cache timestamps from storage
  static Future<void> _loadCacheTimestamps() async {
    try {
      final timestampFile = File('${_cacheDir!.path}/timestamps.json');
      if (await timestampFile.exists()) {
        final content = await timestampFile.readAsString();
        final Map<String, dynamic> jsonData = jsonDecode(content);

        _cacheTimestamps.clear();
        _accessTimestamps.clear();

        for (final entry in jsonData.entries) {
          final data = entry.value as Map<String, dynamic>;
          _cacheTimestamps[entry.key] = DateTime.parse(data['created'] as String);
          _accessTimestamps[entry.key] = DateTime.parse(data['accessed'] as String);
        }

        if (kDebugMode) {
          print('✅ Loaded ${_cacheTimestamps.length} cached image timestamps');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading cache timestamps: $e');
      }
      _cacheTimestamps.clear();
      _accessTimestamps.clear();
    }
  }

  /// Save cache timestamps to storage
  static Future<void> _saveCacheTimestamps() async {
    try {
      final timestampFile = File('${_cacheDir!.path}/timestamps.json');
      final Map<String, dynamic> jsonData = {};

      for (final entry in _cacheTimestamps.entries) {
        jsonData[entry.key] = {
          'created': entry.value.toIso8601String(),
          'accessed': (_accessTimestamps[entry.key] ?? entry.value).toIso8601String(),
        };
      }

      await timestampFile.writeAsString(jsonEncode(jsonData));

      if (kDebugMode) {
        print('💾 Saved ${_cacheTimestamps.length} image timestamps to disk');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving cache timestamps: $e');
      }
    }
  }

  /// Update access time for LRU tracking
  static Future<void> _updateAccessTime(String imageUrl) async {
    _accessTimestamps[imageUrl] = DateTime.now();
    // Save periodically, not on every access (performance optimization)
    if (_accessTimestamps.length % 10 == 0) {
      await _saveCacheTimestamps();
    }
  }

  /// Calculate total cache size
  static Future<int> _calculateCacheSize() async {
    if (_cacheDir == null) return 0;

    try {
      int totalSize = 0;
      final files = await _cacheDir!.list().toList();

      for (final file in files) {
        if (file is File && !file.path.endsWith('timestamps.json')) {
          totalSize += await file.length();
        }
      }

      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        print('Error calculating cache size: $e');
      }
      return 0;
    }
  }

  /// Enforce cache size limit using LRU eviction
  static Future<void> _enforceCacheLimit() async {
    try {
      final currentSize = await _calculateCacheSize();

      if (currentSize <= _maxCacheSize) {
        return; // Within limit
      }

      if (kDebugMode) {
        print('⚠️ Cache size (${currentSize ~/ (1024 * 1024)}MB) exceeds limit (${_maxCacheSize ~/ (1024 * 1024)}MB)');
        print('🗑️ Starting LRU eviction...');
      }

      // Sort by access time (oldest first)
      final sortedEntries = _accessTimestamps.entries.toList()..sort((a, b) => a.value.compareTo(b.value));

      int freedSpace = 0;
      int removedCount = 0;

      // Remove oldest images until we're under 80% of limit (20% buffer)
      final targetSize = (_maxCacheSize * 0.8).toInt();

      for (final entry in sortedEntries) {
        if (currentSize - freedSpace <= targetSize) {
          break;
        }

        final imageUrl = entry.key;
        final file = File(_getCachedImagePath(imageUrl));

        if (await file.exists()) {
          final fileSize = await file.length();
          await file.delete();
          freedSpace += fileSize;
          removedCount++;

          _cacheTimestamps.remove(imageUrl);
          _accessTimestamps.remove(imageUrl);
        }
      }

      await _saveCacheTimestamps();

      if (kDebugMode) {
        print('✅ Removed $removedCount images, freed ${freedSpace ~/ (1024 * 1024)}MB');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error enforcing cache limit: $e');
      }
    }
  }

  /// Get cached image file path
  static String _getCachedImagePath(String imageUrl) {
    final hash = md5.convert(imageUrl.codeUnits).toString();
    return '${_cacheDir!.path}/$hash';
  }

  /// Check if image is cached and not expired
  static bool isImageCached(String imageUrl) {
    if (_cacheDir == null) return false;

    final cachedPath = _getCachedImagePath(imageUrl);
    final file = File(cachedPath);

    if (!file.existsSync()) return false;

    final timestamp = _cacheTimestamps[imageUrl];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _cacheExpiry;
  }

  /// Get cached image file
  static File? getCachedImageFile(String imageUrl) {
    if (!isImageCached(imageUrl)) return null;

    final cachedPath = _getCachedImagePath(imageUrl);
    final file = File(cachedPath);

    if (file.existsSync()) {
      // Update access time for LRU tracking (don't await to keep it fast)
      _updateAccessTime(imageUrl);
      return file;
    }

    return null;
  }

  /// Cache image from URL
  static Future<File?> cacheImage(String imageUrl) async {
    if (_cacheDir == null) {
      await initialize();
    }

    try {
      // Check if already cached and not expired
      if (isImageCached(imageUrl)) {
        final cachedFile = getCachedImageFile(imageUrl);
        if (cachedFile != null) {
          return cachedFile;
        }
      }

      if (kDebugMode) {
        print('📥 Caching image: $imageUrl');
      }

      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('❌ Failed to download image: ${response.statusCode}');
        }
        return null;
      }

      // Save to cache
      final cachedPath = _getCachedImagePath(imageUrl);
      final file = File(cachedPath);
      await file.writeAsBytes(response.bodyBytes);

      // Update timestamps
      final now = DateTime.now();
      _cacheTimestamps[imageUrl] = now;
      _accessTimestamps[imageUrl] = now;
      await _saveCacheTimestamps();

      // Enforce cache size limit
      await _enforceCacheLimit();

      if (kDebugMode) {
        final sizeKB = response.bodyBytes.length ~/ 1024;
        print('✅ Image cached successfully: ${sizeKB}KB');
      }

      return file;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error caching image: $e');
      }
      return null;
    }
  }

  /// Preload images for offline use
  static Future<void> preloadImages(List<String> imageUrls) async {
    if (_cacheDir == null) {
      await initialize();
    }

    for (final url in imageUrls) {
      if (!isImageCached(url)) {
        await cacheImage(url);
        // Small delay to avoid overwhelming the network
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// Clear expired cache
  static Future<void> clearExpiredCache() async {
    if (_cacheDir == null) return;

    try {
      final now = DateTime.now();
      final expiredUrls = <String>[];

      for (final entry in _cacheTimestamps.entries) {
        if (now.difference(entry.value) > _cacheExpiry) {
          expiredUrls.add(entry.key);
        }
      }

      for (final url in expiredUrls) {
        final file = File(_getCachedImagePath(url));
        if (await file.exists()) {
          await file.delete();
        }
        _cacheTimestamps.remove(url);
      }

      await _saveCacheTimestamps();

      if (kDebugMode) {
        print('Cleared ${expiredUrls.length} expired images');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing expired cache: $e');
      }
    }
  }

  /// Clear all cached images
  static Future<void> clearAllCache() async {
    if (_cacheDir == null) return;

    try {
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }

      _cacheTimestamps.clear();
      await _saveCacheTimestamps();

      if (kDebugMode) {
        print('Cleared all image cache');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing all cache: $e');
      }
    }
  }

  /// Get cache size
  static Future<int> getCacheSize() async {
    if (_cacheDir == null) return 0;

    try {
      int totalSize = 0;
      final files = await _cacheDir!.list().toList();

      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting cache size: $e');
      }
      return 0;
    }
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStatistics() {
    return {
      'cachedImages': _cacheTimestamps.length,
      'cacheDirectory': _cacheDir?.path,
      'maxCacheSize': _maxCacheSize,
      'cacheExpiry': _cacheExpiry.inDays,
    };
  }
}
