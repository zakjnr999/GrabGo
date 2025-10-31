import 'dart:io';
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
      
      if (kDebugMode) {
        print('Image cache initialized: ${_cacheDir!.path}');
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
        // Parse timestamps (simplified for this example)
        // In production, use proper JSON parsing
        // final content = await timestampFile.readAsString();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading cache timestamps: $e');
      }
    }
  }

  /// Save cache timestamps to storage
  static Future<void> _saveCacheTimestamps() async {
    try {
      // In production, use proper JSON serialization
      // final timestampFile = File('${_cacheDir!.path}/timestamps.json');
      // final timestamps = _cacheTimestamps.map((key, value) => 
      //   MapEntry(key, value.toIso8601String()));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving cache timestamps: $e');
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
    
    return file.existsSync() ? file : null;
  }

  /// Cache image from URL
  static Future<File?> cacheImage(String imageUrl) async {
    if (_cacheDir == null) {
      await initialize();
    }
    
    try {
      // Check if already cached and not expired
      if (isImageCached(imageUrl)) {
        return getCachedImageFile(imageUrl);
      }

      if (kDebugMode) {
        print('Caching image: $imageUrl');
      }

      // Download image
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('Failed to download image: ${response.statusCode}');
        }
        return null;
      }

      // Save to cache
      final cachedPath = _getCachedImagePath(imageUrl);
      final file = File(cachedPath);
      await file.writeAsBytes(response.bodyBytes);
      
      // Update timestamp
      _cacheTimestamps[imageUrl] = DateTime.now();
      await _saveCacheTimestamps();

      if (kDebugMode) {
        print('Image cached successfully: $cachedPath');
      }

      return file;
    } catch (e) {
      if (kDebugMode) {
        print('Error caching image: $e');
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


