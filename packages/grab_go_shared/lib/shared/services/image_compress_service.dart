import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Service for compressing images before upload
class ImageCompressService {
  ImageCompressService._();
  static final ImageCompressService _instance = ImageCompressService._();
  static ImageCompressService get instance => _instance;

  /// Compress a single image file
  /// Returns the path to the compressed image
  /// [quality] - Compression quality (0-100), default 70
  /// [maxWidth] - Maximum width in pixels, default 1080
  /// [maxHeight] - Maximum height in pixels, default 1920
  Future<String?> compressImage(String imagePath, {int quality = 70, int maxWidth = 1080, int maxHeight = 1920}) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('ImageCompressService: File does not exist: $imagePath');
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        final originalSize = await file.length();
        final compressedSize = await result.length();
        final savings = ((originalSize - compressedSize) / originalSize * 100).toStringAsFixed(1);
        debugPrint(
          'ImageCompressService: Compressed $imagePath - Original: ${_formatBytes(originalSize)}, Compressed: ${_formatBytes(compressedSize)} (saved $savings%)',
        );
        return result.path;
      }

      return null;
    } catch (e) {
      debugPrint('ImageCompressService: Error compressing image: $e');
      return null;
    }
  }

  /// Compress multiple images in parallel
  /// Returns a list of paths to compressed images
  Future<List<String>> compressImages(
    List<String> imagePaths, {
    int quality = 70,
    int maxWidth = 1080,
    int maxHeight = 1920,
  }) async {
    final results = await Future.wait(
      imagePaths.map((path) => compressImage(path, quality: quality, maxWidth: maxWidth, maxHeight: maxHeight)),
    );

    return results.whereType<String>().toList();
  }

  /// Compress image bytes directly
  Future<Uint8List?> compressImageBytes(
    Uint8List bytes, {
    int quality = 70,
    int maxWidth = 1080,
    int maxHeight = 1920,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      return result;
    } catch (e) {
      debugPrint('ImageCompressService: Error compressing image bytes: $e');
      return null;
    }
  }

  /// Clean up old compressed images from temp directory
  /// Call this periodically to free up storage
  Future<void> cleanupOldCompressedImages({Duration maxAge = const Duration(hours: 24)}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      final cutoff = DateTime.now().subtract(maxAge);

      for (final file in files) {
        if (file is File && file.path.contains('compressed_')) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoff)) {
            await file.delete();
            debugPrint('ImageCompressService: Deleted old compressed file: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('ImageCompressService: Error cleaning up compressed images: $e');
    }
  }

  /// Delete specific compressed files after upload is complete
  Future<void> deleteCompressedFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists() && path.contains('compressed_')) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('ImageCompressService: Error deleting file $path: $e');
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
