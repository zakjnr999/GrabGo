import 'package:flutter/foundation.dart';

/// Utility class for optimizing image URLs
class ImageOptimizer {
  static String optimizeUrl(String imageUrl, {int? width, int? height, int quality = 80}) {
    if (imageUrl.isEmpty) return imageUrl;

    // Skip optimization for local assets
    if (imageUrl.startsWith('lib/assets/') || imageUrl.startsWith('packages/') || imageUrl.startsWith('assets/')) {
      return imageUrl;
    }

    try {
      final uri = Uri.parse(imageUrl);
      final params = Map<String, String>.from(uri.queryParameters);

      // Add optimization parameters
      if (width != null) {
        params['w'] = width.toString();
      }
      if (height != null) {
        params['h'] = height.toString();
      }
      if (quality > 0 && quality <= 100) {
        params['q'] = quality.toString();
      }

      // Rebuild URL with parameters
      final optimizedUri = uri.replace(queryParameters: params);

      return optimizedUri.toString();
    } catch (e) {
      if (kDebugMode) {
        print('Error optimizing image URL: $e');
      }
      return imageUrl; // Return original on error
    }
  }

  /// Get thumbnail URL (small size for lists)
  static String getThumbnailUrl(String imageUrl, {int size = 200}) {
    return optimizeUrl(imageUrl, width: size, quality: 75);
  }

  /// Get preview URL (medium size for cards)
  static String getPreviewUrl(String imageUrl, {int width = 400}) {
    return optimizeUrl(imageUrl, width: width, quality: 80);
  }

  /// Get full URL (high quality for detail views)
  static String getFullUrl(String imageUrl, {int width = 1200}) {
    return optimizeUrl(imageUrl, width: width, quality: 90);
  }
}
