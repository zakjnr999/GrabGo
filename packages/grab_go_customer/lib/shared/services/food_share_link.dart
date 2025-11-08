import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Service for creating and sharing food item links
/// Uses custom deep links instead of deprecated Firebase Dynamic Links
class FoodShareLinkService {
  // Base URL for your web app hosted on Vercel (or other hosting)
  // This URL should handle /food/:foodId routes and redirect to the app
  // Update this to match your Vercel deployment URL
  // Examples:
  //   - Production: https://grabgo.app
  //   - Vercel: https://grabgo.vercel.app (or your custom domain)
  static const String baseUrl = 'https://grabgo-deeplink-git-main-zaks-projects-7311a2cf.vercel.app/';

  // Custom URL scheme for deep linking
  // Format: grabgo://food/:foodId
  static const String customScheme = 'grabgo';

  /// Generate a shareable link for a food item
  ///
  /// The link format: https://grabgo.app/food/:sellerId/:foodName
  /// or custom scheme: grabgo://food/:sellerId/:foodName
  static String generateFoodLink({
    required String sellerId,
    required String foodName,
    required String sellerName,
    String? imageUrl,
  }) {
    // Generate a unique identifier (you can use sellerId + foodName hash)
    final foodId = _generateFoodId(sellerId: sellerId, foodName: foodName);

    // Option 1: Web URL (recommended for sharing via social media)
    // This URL can redirect to the app or show a web page
    // Ensure no double slashes by removing trailing slash from baseUrl
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final webUrl = '$cleanBaseUrl/food/$foodId';

    // For sharing, use web URL as it works everywhere
    // The web page can detect if the app is installed and redirect
    return webUrl;
  }

  /// Generate deep link for direct app opening
  static String generateDeepLink({required String sellerId, required String foodName}) {
    final foodId = _generateFoodId(sellerId: sellerId, foodName: foodName);
    return '$customScheme://food/$foodId';
  }

  /// Share a food item with a generated link
  ///
  /// Uses web URL (https://grabgo.app/food/:foodId) which works everywhere
  /// The web page should redirect to the app using deep links
  static Future<void> shareFoodItem({
    required String sellerId,
    required String foodName,
    required String sellerName,
    String? imageUrl,
    String? description,
    bool useWebUrl = true, // Default to true - web URLs work everywhere
  }) async {
    try {
      // Generate the link - use web URL by default (works everywhere)
      // Web page on Vercel will handle redirecting to the app
      final link = useWebUrl
          ? generateFoodLink(sellerId: sellerId, foodName: foodName, sellerName: sellerName, imageUrl: imageUrl)
          : generateDeepLink(sellerId: sellerId, foodName: foodName);

      // Create a shareable message with better formatting
      final message = _createShareMessage(
        foodName: foodName,
        sellerName: sellerName,
        link: link,
        description: description,
        isDeepLink: !useWebUrl,
      );

      // Share using share_plus package
      // Note: If you get MissingPluginException, stop the app and do a full rebuild:
      // flutter clean && flutter pub get && flutter run
      final result = await Share.share(message, subject: '$foodName from $sellerName - GrabGo');

      if (kDebugMode) {
        print('✅ Shared food item: $foodName');
        print('🔗 Link: $link');
        print('📤 Share result: ${result.status}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sharing food item: $e');
        print('💡 Tip: If you see MissingPluginException, stop the app and run:');
        print('   flutter clean && flutter pub get && flutter run');
      }
      rethrow;
    }
  }

  /// Share with additional options (including image if supported)
  static Future<void> shareFoodItemWithOptions({
    required String sellerId,
    required String foodName,
    required String sellerName,
    String? imageUrl,
    String? description,
  }) async {
    try {
      final link = generateFoodLink(sellerId: sellerId, foodName: foodName, sellerName: sellerName, imageUrl: imageUrl);

      final message = _createShareMessage(
        foodName: foodName,
        sellerName: sellerName,
        link: link,
        description: description,
      );

      // Use Share.shareXFiles if you want to share images
      // For now, we'll use text sharing
      final shareResult = await Share.share(message, subject: 'Check out $foodName from $sellerName on GrabGo!');

      if (kDebugMode) {
        print('✅ Shared food item: $foodName');
        print('🔗 Link: $link');
        print('📤 Share result: ${shareResult.status}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sharing food item: $e');
      }
      rethrow;
    }
  }

  /// Parse food ID from a URL or deep link
  /// Returns the food ID if found, null otherwise
  static String? parseFoodIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Handle custom scheme: grabgo://food/:id
      if (uri.scheme == customScheme) {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty && pathSegments[0] == 'food' && pathSegments.length > 1) {
          return pathSegments[1];
        }
      }

      // Handle web URL: https://grabgo.app/food/:id
      if (uri.scheme == 'https' || uri.scheme == 'http') {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty && pathSegments[0] == 'food' && pathSegments.length > 1) {
          return pathSegments[1];
        }

        // Also check query parameters: ?foodId=xxx
        final foodId = uri.queryParameters['foodId'];
        if (foodId != null && foodId.isNotEmpty) {
          return foodId;
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error parsing food ID from URL: $e');
      }
      return null;
    }
  }

  /// Generate a unique food ID from sellerId and foodName
  static String _generateFoodId({required String sellerId, required String foodName}) {
    // Create a hash-based ID for consistency
    // Format: base64 encoded combination of sellerId and foodName
    final combined = '$sellerId:$foodName';
    final bytes = combined.codeUnits;
    final hash = bytes.fold<int>(0, (prev, curr) => prev + curr);

    // Create a readable ID: sellerId_foodNameHash
    final foodNameHash = hash.abs().toString().padLeft(8, '0');
    final cleanSellerId = sellerId
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .substring(0, sellerId.length > 6 ? 6 : sellerId.length);
    final cleanFoodName = _cleanForUrl(foodName).substring(0, foodName.length > 20 ? 20 : foodName.length);

    return '${cleanSellerId}_${cleanFoodName}_$foodNameHash';
  }

  /// Clean string for URL usage
  static String _cleanForUrl(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }

  /// Create share message with food details
  static String _createShareMessage({
    required String foodName,
    required String sellerName,
    required String link,
    String? description,
    bool isDeepLink = false,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🍽️ Check out "$foodName" from $sellerName on GrabGo!');

    if (description != null && description.isNotEmpty) {
      // Truncate description if too long
      final shortDesc = description.length > 100 ? '${description.substring(0, 100)}...' : description;
      buffer.writeln('\n$shortDesc');
    }

    buffer.writeln('\n🔗 $link');
    buffer.writeln('\nDownload GrabGo to order now!');

    return buffer.toString();
  }

  /// Extract seller ID and food name from food ID
  /// This is used when opening a shared link
  static Map<String, String>? parseFoodId(String foodId) {
    try {
      // Format: sellerId_foodName_hash
      final parts = foodId.split('_');
      if (parts.length >= 2) {
        return {
          'sellerId': parts[0],
          'foodName': parts.sublist(1, parts.length - 1).join('_'), // Everything except first and last
          'hash': parts.last,
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error parsing food ID: $e');
      }
      return null;
    }
  }
}
