import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grab_go_customer/features/status/model/status_model.dart';
import 'package:grab_go_customer/features/status/service/status_service.dart';

/// Repository for Status feature
/// Handles data fetching, caching, and transformation from the API
class StatusRepository {
  final StatusService _statusService;

  // Cache keys
  static const String _storiesCacheKey = 'status_stories_cache';
  static const String _statusesCacheKey = 'status_statuses_cache';
  static const String _viewedStatusesCacheKey = 'status_viewed_cache';
  static const String _restaurantStatusesCachePrefix = 'status_restaurant_';
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  static const Duration _offlineCacheValidDuration = Duration(hours: 24); // Longer cache for offline
  static const int _maxViewedStatusesCache = 50; // Limit cached viewed statuses

  StatusRepository(this._statusService);

  // ============================================================
  // Retry Logic
  // ============================================================

  /// Execute a function with retry logic
  Future<T> _withRetry<T>(
    Future<T> Function() fn, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        attempts++;
        return await fn();
      } catch (e) {
        if (attempts >= maxRetries) {
          rethrow;
        }
        if (kDebugMode) {
          print('⚠️ Retry attempt $attempts failed: $e. Retrying in ${delay.inMilliseconds}ms...');
        }
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
  }

  // ============================================================
  // Offline Cache Helpers
  // ============================================================

  Future<void> _cacheData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
      await prefs.setInt('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to cache data: $e');
      }
    }
  }

  Future<T?> _getCachedData<T>(String key, T Function(dynamic) parser, {bool forOffline = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('${key}_timestamp') ?? 0;
      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

      // Use longer duration for offline mode
      final validDuration = forOffline ? _offlineCacheValidDuration : _cacheValidDuration;

      // Check if cache is still valid
      if (DateTime.now().difference(cachedTime) > validDuration) {
        if (!forOffline) {
          // Only clear stale cache if not in offline mode
          await prefs.remove(key);
          await prefs.remove('${key}_timestamp');
        }
        return null;
      }

      final cached = prefs.getString(key);
      if (cached != null) {
        return parser(jsonDecode(cached));
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to get cached data: $e');
      }
    }
    return null;
  }

  /// Filter out expired statuses from a list
  List<StatusModel> _filterExpiredStatuses(List<StatusModel> statuses) {
    final now = DateTime.now();
    return statuses.where((status) => status.expiresAt.isAfter(now)).toList();
  }

  /// Filter out expired stories from a list
  List<StoryModel> _filterExpiredStories(List<StoryModel> stories) {
    final now = DateTime.now();
    return stories.where((story) => story.latestStatusAt.isAfter(now.subtract(const Duration(hours: 24)))).toList();
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storiesCacheKey);
      await prefs.remove(_statusesCacheKey);
      await prefs.remove('${_storiesCacheKey}_timestamp');
      await prefs.remove('${_statusesCacheKey}_timestamp');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to clear cache: $e');
      }
    }
  }

  // ============================================================
  // Offline Cache Methods
  // ============================================================

  /// Cache a viewed status for offline viewing
  Future<void> cacheViewedStatus(StatusModel status) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing cached statuses
      final cachedJson = prefs.getString(_viewedStatusesCacheKey);
      List<Map<String, dynamic>> cachedList = [];

      if (cachedJson != null) {
        cachedList = (jsonDecode(cachedJson) as List).cast<Map<String, dynamic>>();
      }

      // Remove if already exists (to update position)
      cachedList.removeWhere((item) => item['_id'] == status.id);

      // Add to front (most recent)
      cachedList.insert(0, status.toJson());

      // Limit cache size
      if (cachedList.length > _maxViewedStatusesCache) {
        cachedList = cachedList.sublist(0, _maxViewedStatusesCache);
      }

      await prefs.setString(_viewedStatusesCacheKey, jsonEncode(cachedList));
      await prefs.setInt('${_viewedStatusesCacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);

      if (kDebugMode) {
        print('📦 Cached viewed status: ${status.id} (total: ${cachedList.length})');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to cache viewed status: $e');
      }
    }
  }

  /// Cache multiple statuses for a restaurant (for offline story viewing)
  Future<void> cacheRestaurantStatuses(String restaurantId, List<StatusModel> statuses) async {
    try {
      final key = '$_restaurantStatusesCachePrefix$restaurantId';
      final statusesJson = statuses.map((s) => s.toJson()).toList();
      await _cacheData(key, statusesJson);

      // Also cache each status individually for offline viewing
      for (final status in statuses) {
        await cacheViewedStatus(status);
      }

      if (kDebugMode) {
        print('📦 Cached ${statuses.length} statuses for restaurant: $restaurantId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to cache restaurant statuses: $e');
      }
    }
  }

  /// Get cached statuses for a restaurant (for offline viewing)
  Future<List<StatusModel>?> getCachedRestaurantStatuses(String restaurantId) async {
    final key = '$_restaurantStatusesCachePrefix$restaurantId';
    return _getCachedData<List<StatusModel>>(
      key,
      (data) => (data as List).map((json) => StatusModel.fromJson(json as Map<String, dynamic>)).toList(),
      forOffline: true,
    );
  }

  /// Get all cached viewed statuses for offline viewing
  /// When offline, we return all cached statuses even if expired (better than nothing)
  Future<List<StatusModel>> getCachedViewedStatuses({bool filterExpired = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_viewedStatusesCacheKey);

      if (kDebugMode) {
        print(
          '🔍 Cache key: $_viewedStatusesCacheKey, has data: ${cachedJson != null}, length: ${cachedJson?.length ?? 0}',
        );
      }

      if (cachedJson != null && cachedJson.isNotEmpty) {
        final cachedList = (jsonDecode(cachedJson) as List)
            .map((json) => StatusModel.fromJson(json as Map<String, dynamic>))
            .toList();

        // Optionally filter expired statuses
        final statuses = filterExpired ? _filterExpiredStatuses(cachedList) : cachedList;

        if (kDebugMode) {
          print('📦 Retrieved ${statuses.length} cached viewed statuses');
        }
        return statuses;
      } else {
        if (kDebugMode) {
          print('⚠️ No cached data found for key: $_viewedStatusesCacheKey');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('⚠️ Failed to get cached viewed statuses: $e');
        print('Stack trace: $stackTrace');
      }
    }
    return [];
  }

  /// Clear offline cache for a specific restaurant
  Future<void> clearRestaurantCache(String restaurantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_restaurantStatusesCachePrefix$restaurantId';
      await prefs.remove(key);
      await prefs.remove('${key}_timestamp');
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to clear restaurant cache: $e');
      }
    }
  }

  /// Clear all offline caches
  Future<void> clearAllOfflineCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith(_restaurantStatusesCachePrefix) ||
            key == _viewedStatusesCacheKey ||
            key == '${_viewedStatusesCacheKey}_timestamp') {
          await prefs.remove(key);
        }
      }

      if (kDebugMode) {
        print('🗑️ Cleared all offline caches');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to clear offline caches: $e');
      }
    }
  }

  // ============================================================
  // API Methods with Retry and Caching
  // ============================================================

  /// Fetch all active statuses with optional filters
  Future<({List<StatusModel> statuses, StatusPagination pagination})> fetchStatuses({
    StatusCategory? category,
    String? restaurantId,
    bool? recommended,
    int limit = 50,
    int page = 1,
    bool useCache = true,
  }) async {
    // Try cache first for first page without filters
    if (useCache && page == 1 && category == null && restaurantId == null && recommended != true) {
      final cached = await _getCachedData<List<StatusModel>>(
        _statusesCacheKey,
        (data) => (data as List).map((json) => StatusModel.fromJson(json as Map<String, dynamic>)).toList(),
      );
      if (cached != null) {
        // Filter out expired statuses from cache
        final validStatuses = _filterExpiredStatuses(cached);
        if (validStatuses.isNotEmpty) {
          if (kDebugMode) {
            print(
              '📦 Using cached statuses (${validStatuses.length} valid, ${cached.length - validStatuses.length} expired)',
            );
          }
          return (
            statuses: validStatuses,
            pagination: StatusPagination(
              currentPage: 1,
              totalPages: 1,
              totalItems: validStatuses.length,
              itemsPerPage: limit,
            ),
          );
        }
        // All cached statuses expired, clear cache and fetch fresh
        await clearCache();
      }
    }

    return _withRetry(() async {
      final response = await _statusService.getStatuses(
        category: category?.toApiString(),
        restaurant: restaurantId,
        recommended: recommended == true ? 'true' : null,
        limit: limit,
        page: page,
      );

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        if (data['success'] == true) {
          final statusesJson = data['data'] as List<dynamic>? ?? [];
          final statuses = statusesJson.map((json) => StatusModel.fromJson(json as Map<String, dynamic>)).toList();
          final pagination = StatusPagination.fromJson(data['pagination'] as Map<String, dynamic>? ?? {});

          // Cache first page results
          if (page == 1 && category == null && restaurantId == null && recommended != true) {
            _cacheData(_statusesCacheKey, statusesJson);
          }

          return (statuses: statuses, pagination: pagination);
        }
      }

      throw Exception(response.error?.toString() ?? 'Failed to fetch statuses');
    });
  }

  /// Fetch restaurant stories (for story ring)
  Future<List<StoryModel>> fetchStories({int limit = 20, String sortBy = 'recent', bool useCache = true}) async {
    // Try cache first
    if (useCache) {
      final cached = await _getCachedData<List<StoryModel>>(
        _storiesCacheKey,
        (data) => (data as List).map((json) => StoryModel.fromJson(json as Map<String, dynamic>)).toList(),
      );
      if (cached != null) {
        // Filter out expired stories from cache
        final validStories = _filterExpiredStories(cached);
        if (validStories.isNotEmpty) {
          if (kDebugMode) {
            print(
              '📦 Using cached stories (${validStories.length} valid, ${cached.length - validStories.length} expired)',
            );
          }
          return validStories;
        }
        // All cached stories expired, clear cache and fetch fresh
        await clearCache();
      }
    }

    return _withRetry(() async {
      final response = await _statusService.getStories(limit: limit, sortBy: sortBy);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        if (data['success'] == true) {
          final storiesJson = data['data'] as List<dynamic>? ?? [];
          final stories = storiesJson.map((json) => StoryModel.fromJson(json as Map<String, dynamic>)).toList();

          // Cache the results
          _cacheData(_storiesCacheKey, storiesJson);

          return stories;
        }
      }

      throw Exception(response.error?.toString() ?? 'Failed to fetch stories');
    });
  }

  /// Fetch all statuses for a specific restaurant
  Future<List<StatusModel>> fetchRestaurantStatuses(String restaurantId) async {
    return _withRetry(() async {
      final response = await _statusService.getRestaurantStories(restaurantId);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        if (data['success'] == true) {
          final statusesJson = data['data'] as List<dynamic>? ?? [];
          return statusesJson.map((json) => StatusModel.fromJson(json as Map<String, dynamic>)).toList();
        }
      }

      throw Exception(response.error?.toString() ?? 'Failed to fetch restaurant statuses');
    });
  }

  /// Fetch a single status by ID
  Future<StatusModel> fetchStatus(String statusId) async {
    return _withRetry(() async {
      final response = await _statusService.getStatus(statusId);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        if (data['success'] == true && data['data'] != null) {
          return StatusModel.fromJson(data['data'] as Map<String, dynamic>);
        }
      }

      throw Exception(response.error?.toString() ?? 'Failed to fetch status');
    });
  }

  /// Fetch statuses viewed by current user
  Future<List<StatusModel>> fetchViewedStatuses() async {
    return _withRetry(() async {
      final response = await _statusService.getViewedStatuses();

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        if (data['success'] == true) {
          final statusesJson = data['data'] as List<dynamic>? ?? [];
          return statusesJson.map((json) => StatusModel.fromJson(json as Map<String, dynamic>)).toList();
        }
      }

      throw Exception(response.error?.toString() ?? 'Failed to fetch viewed statuses');
    });
  }

  /// Record a view on a status (no retry - fire and forget is acceptable)
  Future<({int viewCount, int avgViewDuration})> recordView(String statusId, {int duration = 0}) async {
    try {
      final response = await _statusService.recordView(statusId, {'duration': duration});

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        if (data['success'] == true && data['data'] != null) {
          final resultData = data['data'] as Map<String, dynamic>;
          return (
            viewCount: (resultData['viewCount'] ?? 0) as int,
            avgViewDuration: (resultData['avgViewDuration'] ?? 0) as int,
          );
        }
      }

      throw Exception(response.error?.toString() ?? 'Failed to record view');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error recording view: $e');
      }
      rethrow;
    }
  }

  /// Record multiple views at once (for story swipe-through)
  Future<List<Map<String, dynamic>>> recordBatchViews(List<BatchViewItem> views) async {
    try {
      final response = await _statusService.recordBatchViews({'views': views.map((v) => v.toJson()).toList()});

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        if (data['success'] == true && data['data'] != null) {
          final resultData = data['data'] as Map<String, dynamic>;
          final results = resultData['results'] as List<dynamic>? ?? [];
          return results.cast<Map<String, dynamic>>();
        }
      }

      throw Exception(response.error?.toString() ?? 'Failed to record batch views');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error recording batch views: $e');
      }
      rethrow;
    }
  }

  /// Toggle like on a status
  Future<({bool isLiked, int likeCount})> toggleLike(String statusId) async {
    return _withRetry(() async {
      final response = await _statusService.toggleLike(statusId);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        if (data['success'] == true && data['data'] != null) {
          final resultData = data['data'] as Map<String, dynamic>;
          return (isLiked: (resultData['isLiked'] ?? false) as bool, likeCount: (resultData['likeCount'] ?? 0) as int);
        }
      }

      throw Exception(response.error?.toString() ?? 'Failed to toggle like');
    });
  }
}
