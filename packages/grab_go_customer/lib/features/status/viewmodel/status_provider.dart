import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_shared/shared/services/chat_socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/status/model/status_model.dart';
import 'package:grab_go_customer/features/status/repository/status_repository.dart';

/// Provider for Status feature state management
class StatusProvider with ChangeNotifier {
  late final StatusRepository _repository;
  final ChatSocketService _socketService = ChatSocketService();

  StatusProvider() {
    _repository = StatusRepository(statusService);
    _startSocketConnectionMonitoring();
  }

  /// Start listening to socket connection state changes
  void _startSocketConnectionMonitoring() {
    // Set initial offline state based on current socket connection
    _isOffline = !_socketService.isConnected;

    // Listen for future changes
    _socketService.addConnectionListener(_onSocketConnectionChanged);
  }

  /// Handle socket connection state changes
  void _onSocketConnectionChanged(ChatSocketConnectionState state) {
    if (kDebugMode) {
      print('🔌 Socket state changed: $state (was offline: $_isOffline)');
    }

    switch (state) {
      case ChatSocketConnectionState.connected:
        if (_isOffline) {
          _isOffline = false;
          if (kDebugMode) {
            print('🌐 Socket connected - hiding offline banner');
          }
          notifyListeners();
        }
        break;
      case ChatSocketConnectionState.disconnected:
        if (!_isOffline) {
          _isOffline = true;
          if (kDebugMode) {
            print('📴 Socket disconnected - showing offline banner');
          }
          notifyListeners();
        }
        break;
      case ChatSocketConnectionState.connecting:
      case ChatSocketConnectionState.reconnecting:
        // Keep current state while connecting/reconnecting
        break;
    }
  }

  @override
  void dispose() {
    _socketService.removeConnectionListener(_onSocketConnectionChanged);
    super.dispose();
  }

  // ============================================================
  // State
  // ============================================================

  // Stories (for story ring) - sorted with unviewed first, then viewed
  List<StoryModel> _stories = [];
  List<StoryModel> get stories => _getSortedStories();

  // All statuses
  List<StatusModel> _statuses = [];
  List<StatusModel> get statuses => _statuses;

  // Filtered statuses by category
  StatusCategory? _selectedCategory;
  StatusCategory? get selectedCategory => _selectedCategory;

  // Current restaurant's statuses (for story viewer)
  List<StatusModel> _currentRestaurantStatuses = [];
  List<StatusModel> get currentRestaurantStatuses => _currentRestaurantStatuses;

  // Loading state for restaurant statuses
  bool _isLoadingRestaurantStatuses = false;
  bool get isLoadingRestaurantStatuses => _isLoadingRestaurantStatuses;

  // Pagination
  StatusPagination? _pagination;
  StatusPagination? get pagination => _pagination;
  bool get hasMore => _pagination?.hasMore ?? false;

  // Loading states
  bool _isLoadingStories = false;
  bool _hasLoadedStories = false; // Track if initial fetch was done
  bool get isLoadingStories => _isLoadingStories || (!_hasLoadedStories && _stories.isEmpty);

  bool _isLoadingStatuses = false;
  bool _hasLoadedStatuses = false; // Track if initial fetch was done
  bool get isLoadingStatuses => _isLoadingStatuses || (!_hasLoadedStatuses && _statuses.isEmpty);

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  // Error state
  String? _error;
  String? get error => _error;

  // Liked status IDs (tracked locally)
  final Set<String> _likedStatusIds = {};
  bool isLiked(String statusId) => _likedStatusIds.contains(statusId);

  // Viewed story restaurant IDs (tracked locally and persisted)
  final Set<String> _viewedRestaurantIds = {};
  static const String _viewedStoriesKey = 'viewed_story_restaurants';

  // Offline mode state
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  // Cached statuses for offline viewing
  List<StatusModel> _cachedViewedStatuses = [];
  List<StatusModel> get cachedViewedStatuses => _cachedViewedStatuses;

  /// Initialize provider - call this on app start
  Future<void> init() async {
    await _loadViewedRestaurants();
    await _checkConnectivity();
    await _loadCachedViewedStatuses();
  }

  /// Check internet connectivity
  /// Uses socket connection state as the source of truth for offline banner
  /// DNS lookup is only used to determine if we should try fetching from API
  Future<bool> _checkConnectivity() async {
    // Socket connection state determines the offline banner
    _isOffline = !_socketService.isConnected;

    // For API calls, also check if we have actual internet
    if (_isOffline) {
      // Socket not connected - check if we have internet via DNS
      try {
        final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
        // We have internet but socket not connected - still try API
        // but keep banner showing until socket connects
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on SocketException catch (_) {
        return false;
      } on TimeoutException catch (_) {
        return false;
      } catch (_) {
        return false;
      }
    }

    return true; // Socket connected = online
  }

  /// Load cached viewed statuses for offline mode
  Future<void> _loadCachedViewedStatuses() async {
    _cachedViewedStatuses = await _repository.getCachedViewedStatuses();
    if (kDebugMode && _cachedViewedStatuses.isNotEmpty) {
      print('📦 Loaded ${_cachedViewedStatuses.length} cached statuses for offline viewing');
    }
  }

  /// Preload images for offline viewing
  Future<void> preloadStatusImages(BuildContext context, List<StatusModel> statuses) async {
    for (final status in statuses) {
      try {
        // Preload main media
        await precacheImage(CachedNetworkImageProvider(status.mediaUrl), context);

        // Preload thumbnail if available
        if (status.thumbnailUrl != null) {
          await precacheImage(CachedNetworkImageProvider(status.thumbnailUrl!), context);
        }

        // Preload restaurant logo if available
        if (status.restaurant.logo != null) {
          await precacheImage(CachedNetworkImageProvider(status.restaurant.logo!), context);
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Failed to preload image for status ${status.id}: $e');
        }
      }
    }
  }

  Future<void> _loadViewedRestaurants() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewed = prefs.getStringList(_viewedStoriesKey) ?? [];
      _viewedRestaurantIds.addAll(viewed);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading viewed restaurants: $e');
      }
    }
  }

  Future<void> _saveViewedRestaurant(String restaurantId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _viewedRestaurantIds.add(restaurantId);
      await prefs.setStringList(_viewedStoriesKey, _viewedRestaurantIds.toList());
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving viewed restaurant: $e');
      }
    }
  }

  // ============================================================
  // Stories Methods
  // ============================================================

  /// Get stories sorted like WhatsApp: unviewed first, then viewed at the end
  List<StoryModel> _getSortedStories() {
    final unviewed = _stories.where((s) => !s.isViewed).toList();
    final viewed = _stories.where((s) => s.isViewed).toList();
    return [...unviewed, ...viewed];
  }

  /// Fetch stories for the story ring (with offline support)
  Future<void> fetchStories({int limit = 20, String sortBy = 'recent', bool forceRefresh = false}) async {
    if (_isLoadingStories) return;
    // Skip if already loaded and not forcing refresh
    if (_hasLoadedStories && _stories.isNotEmpty && !forceRefresh) return;

    _isLoadingStories = true;
    _error = null;

    // Load cached data first for instant UI
    if (_stories.isEmpty) {
      try {
        final cachedStories = await _repository.fetchStories(limit: limit, sortBy: sortBy, useCache: true);
        if (cachedStories.isNotEmpty) {
          _stories = cachedStories.map((story) {
            return story.copyWith(isViewed: _viewedRestaurantIds.contains(story.restaurantId));
          }).toList();
          _isLoadingStories = false;
          _hasLoadedStories = true;
          notifyListeners();
          if (kDebugMode) {
            print('📦 Loaded ${_stories.length} cached stories instantly');
          }
        }
      } catch (_) {
        // No cached data available
      }
    }

    // Check connectivity
    final hasInternet = await _checkConnectivity();
    notifyListeners();

    // If offline, we're done (already loaded cache above)
    if (!hasInternet) {
      _isLoadingStories = false;
      _hasLoadedStories = true;
      notifyListeners();
      return;
    }

    // Online: fetch fresh data from API
    try {
      final stories = await _repository.fetchStories(limit: limit, sortBy: sortBy, useCache: false);

      // Mark viewed stories
      _stories = stories.map((story) {
        return story.copyWith(isViewed: _viewedRestaurantIds.contains(story.restaurantId));
      }).toList();

      if (kDebugMode) {
        print('✅ Fetched ${_stories.length} fresh stories from API');
      }
    } catch (e) {
      // On error, keep using cached data if available
      if (_stories.isEmpty) {
        _error = 'No stories available. Please check your connection.';
      }
      if (kDebugMode) {
        print('❌ Error fetching stories: $e');
      }
    } finally {
      _isLoadingStories = false;
      _hasLoadedStories = true;
      notifyListeners();
    }
  }

  /// Refresh stories
  Future<void> refreshStories() async {
    await fetchStories(forceRefresh: true);
  }

  // ============================================================
  // Statuses Methods
  // ============================================================

  /// Fetch statuses with optional filters (with offline support)
  Future<void> fetchStatuses({
    StatusCategory? category,
    String? restaurantId,
    bool? recommended,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    if (_isLoadingStatuses) return;
    // Skip if already loaded and not forcing refresh
    if (_hasLoadedStatuses && _statuses.isNotEmpty && !forceRefresh) return;

    _isLoadingStatuses = true;
    _error = null;
    _selectedCategory = category;

    // Load cached data first for instant UI
    if (_statuses.isEmpty) {
      if (kDebugMode) {
        print('🔍 Attempting to load cached statuses...');
      }
      await _loadCachedViewedStatuses();
      if (_cachedViewedStatuses.isNotEmpty) {
        _statuses = _cachedViewedStatuses;
        _isLoadingStatuses = false;
        _hasLoadedStatuses = true;
        notifyListeners();
        if (kDebugMode) {
          print('📦 Loaded ${_statuses.length} cached statuses instantly');
        }
        // Don't return - still fetch fresh data in background if online
      } else {
        if (kDebugMode) {
          print('⚠️ No cached statuses found');
        }
      }
    }

    // Check connectivity
    final hasInternet = await _checkConnectivity();
    notifyListeners();

    // If offline, we're done (already loaded cache above)
    if (!hasInternet) {
      _isLoadingStatuses = false;
      _hasLoadedStatuses = true;
      notifyListeners();
      return;
    }

    // Online: fetch fresh data from API (in background if cache was loaded)
    try {
      final result = await _repository.fetchStatuses(
        category: category,
        restaurantId: restaurantId,
        recommended: recommended,
        limit: limit,
        page: 1,
      );

      _statuses = result.statuses;
      _pagination = result.pagination;

      // Cache statuses for offline viewing
      for (final status in _statuses) {
        await _repository.cacheViewedStatus(status);
      }

      if (kDebugMode) {
        print('✅ Fetched ${_statuses.length} fresh statuses from API');
      }
    } catch (e) {
      // On error, keep using cached data if available
      if (_statuses.isEmpty) {
        _error = 'No statuses available. Please check your connection.';
      }
      if (kDebugMode) {
        print('❌ Error fetching statuses: $e');
      }
    } finally {
      _isLoadingStatuses = false;
      _hasLoadedStatuses = true;
      notifyListeners();
    }
  }

  /// Load more statuses (pagination)
  Future<void> loadMoreStatuses() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = (_pagination?.currentPage ?? 0) + 1;

      final result = await _repository.fetchStatuses(
        category: _selectedCategory,
        limit: _pagination?.itemsPerPage ?? 50,
        page: nextPage,
      );

      _statuses.addAll(result.statuses);
      _pagination = result.pagination;

      if (kDebugMode) {
        print('✅ Loaded ${result.statuses.length} more statuses');
      }
    } catch (e) {
      _error = 'Failed to load more statuses: ${e.toString()}';
      if (kDebugMode) {
        print('❌ Error loading more statuses: $e');
      }
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Get filtered statuses by category
  List<StatusModel> getFilteredStatuses(StatusCategory? category) {
    if (category == null) return _statuses;
    return _statuses.where((s) => s.category == category).toList();
  }

  /// Get recommended statuses
  List<StatusModel> get recommendedStatuses {
    return _statuses.where((s) => s.isRecommended).toList();
  }

  /// Refresh statuses
  Future<void> refreshStatuses() async {
    await fetchStatuses(category: _selectedCategory, forceRefresh: true);
  }

  // ============================================================
  // Restaurant Statuses Methods
  // ============================================================

  /// Fetch all statuses for a specific restaurant (for story viewer)
  /// Supports offline mode by using cached data without re-fetching
  Future<void> fetchRestaurantStatuses(String restaurantId, {BuildContext? context}) async {
    // Check connectivity first
    final hasInternet = await _checkConnectivity();

    // If offline, try to use cached data immediately without showing loading
    if (!hasInternet) {
      final cachedStatuses = await _repository.getCachedRestaurantStatuses(restaurantId);

      if (cachedStatuses != null && cachedStatuses.isNotEmpty) {
        _currentRestaurantStatuses = cachedStatuses;
        _isLoadingRestaurantStatuses = false;

        // Mark restaurant as viewed
        await _saveViewedRestaurant(restaurantId);
        final storyIndex = _stories.indexWhere((s) => s.restaurantId == restaurantId);
        if (storyIndex >= 0) {
          _stories[storyIndex] = _stories[storyIndex].copyWith(isViewed: true);
        }

        if (kDebugMode) {
          print('📦 Using ${cachedStatuses.length} cached statuses for restaurant $restaurantId (offline)');
        }
        notifyListeners();
        return; // Use cached data, don't show loading or try API
      }
    }

    _isLoadingRestaurantStatuses = true;
    _currentRestaurantStatuses = [];
    notifyListeners();

    try {
      // Fetch from API
      _currentRestaurantStatuses = await _repository.fetchRestaurantStatuses(restaurantId);

      // Cache for offline viewing
      await _repository.cacheRestaurantStatuses(restaurantId, _currentRestaurantStatuses);

      // Preload images for offline viewing if context is available
      if (context != null && context.mounted) {
        preloadStatusImages(context, _currentRestaurantStatuses);
      }

      if (kDebugMode) {
        print('✅ Fetched ${_currentRestaurantStatuses.length} statuses for restaurant $restaurantId');
      }

      // Mark restaurant as viewed and persist
      await _saveViewedRestaurant(restaurantId);

      // Update story's viewed state
      final storyIndex = _stories.indexWhere((s) => s.restaurantId == restaurantId);
      if (storyIndex >= 0) {
        _stories[storyIndex] = _stories[storyIndex].copyWith(isViewed: true);
      }
    } catch (e) {
      // On error, try to load from cache
      final cachedStatuses = await _repository.getCachedRestaurantStatuses(restaurantId);

      if (cachedStatuses != null && cachedStatuses.isNotEmpty) {
        _currentRestaurantStatuses = cachedStatuses;
        if (kDebugMode) {
          print('📦 Fallback to ${cachedStatuses.length} cached statuses for restaurant $restaurantId');
        }

        // Mark restaurant as viewed
        await _saveViewedRestaurant(restaurantId);
        final storyIndex = _stories.indexWhere((s) => s.restaurantId == restaurantId);
        if (storyIndex >= 0) {
          _stories[storyIndex] = _stories[storyIndex].copyWith(isViewed: true);
        }
      } else {
        _error = 'No statuses available. Please check your connection.';
        if (kDebugMode) {
          print('❌ Error fetching restaurant statuses: $e');
        }
      }
    } finally {
      _isLoadingRestaurantStatuses = false;
      notifyListeners();
    }
  }

  /// Clear current restaurant statuses
  void clearCurrentRestaurantStatuses() {
    _currentRestaurantStatuses = [];
    notifyListeners();
  }

  /// Mark a story as viewed and move it to the end of the list
  Future<void> markStoryAsViewed(String restaurantId) async {
    final storyIndex = _stories.indexWhere((s) => s.restaurantId == restaurantId);
    if (storyIndex >= 0 && !_stories[storyIndex].isViewed) {
      // Mark as viewed
      _stories[storyIndex] = _stories[storyIndex].copyWith(isViewed: true);

      // Persist the viewed state
      await _saveViewedRestaurant(restaurantId);

      // Notify to trigger UI reorder
      notifyListeners();

      if (kDebugMode) {
        print('✅ Marked story as viewed: $restaurantId');
      }
    }
  }

  // ============================================================
  // Engagement Methods
  // ============================================================

  /// Record a view on a status
  Future<void> recordView(String statusId, {int duration = 0}) async {
    try {
      await _repository.recordView(statusId, duration: duration);

      if (kDebugMode) {
        print('✅ Recorded view for status $statusId (duration: ${duration}ms)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error recording view: $e');
      }
    }
  }

  /// Record batch views (for story swipe-through)
  Future<void> recordBatchViews(List<BatchViewItem> views) async {
    if (views.isEmpty) return;

    try {
      await _repository.recordBatchViews(views);

      if (kDebugMode) {
        print('✅ Recorded ${views.length} batch views');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error recording batch views: $e');
      }
    }
  }

  /// Toggle like on a status
  Future<void> toggleLike(String statusId) async {
    // Optimistic update
    final wasLiked = _likedStatusIds.contains(statusId);
    if (wasLiked) {
      _likedStatusIds.remove(statusId);
    } else {
      _likedStatusIds.add(statusId);
    }
    notifyListeners();

    try {
      final result = await _repository.toggleLike(statusId);

      // Update with server response
      if (result.isLiked) {
        _likedStatusIds.add(statusId);
      } else {
        _likedStatusIds.remove(statusId);
      }

      // Update status in lists
      _updateStatusLikeCount(statusId, result.likeCount);

      if (kDebugMode) {
        print('✅ Toggled like for status $statusId: ${result.isLiked}');
      }
    } catch (e) {
      // Revert optimistic update
      if (wasLiked) {
        _likedStatusIds.add(statusId);
      } else {
        _likedStatusIds.remove(statusId);
      }
      notifyListeners();

      if (kDebugMode) {
        print('❌ Error toggling like: $e');
      }
    }
  }

  void _updateStatusLikeCount(String statusId, int likeCount) {
    // Update in statuses list
    final statusIndex = _statuses.indexWhere((s) => s.id == statusId);
    if (statusIndex >= 0) {
      _statuses[statusIndex] = _statuses[statusIndex].copyWith(likeCount: likeCount);
    }

    // Update in current restaurant statuses
    final restaurantStatusIndex = _currentRestaurantStatuses.indexWhere((s) => s.id == statusId);
    if (restaurantStatusIndex >= 0) {
      _currentRestaurantStatuses[restaurantStatusIndex] = _currentRestaurantStatuses[restaurantStatusIndex].copyWith(
        likeCount: likeCount,
      );
    }

    notifyListeners();
  }

  // ============================================================
  // Filter Methods
  // ============================================================

  /// Set selected category filter (filters locally, no server fetch)
  void setSelectedCategory(StatusCategory? category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      notifyListeners(); // Just notify to update UI with local filtering
    }
  }

  /// Clear all filters
  void clearFilters() {
    if (_selectedCategory != null) {
      _selectedCategory = null;
      notifyListeners();
    }
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Clear all data
  void clearAll() {
    _stories = [];
    _statuses = [];
    _currentRestaurantStatuses = [];
    _cachedViewedStatuses = [];
    _pagination = null;
    _selectedCategory = null;
    _error = null;
    _isOffline = false;
    _likedStatusIds.clear();
    _viewedRestaurantIds.clear();
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh connectivity status
  Future<void> refreshConnectivity() async {
    final wasOffline = _isOffline;
    await _checkConnectivity();

    if (wasOffline && !_isOffline) {
      // Back online - refresh data
      if (kDebugMode) {
        print('🌐 Back online - refreshing data');
      }
    } else if (!wasOffline && _isOffline) {
      // Went offline
      if (kDebugMode) {
        print('📴 Went offline - using cached data');
      }
    }

    // Always notify to update UI
    notifyListeners();
  }

  /// Clear all offline caches
  Future<void> clearOfflineCache() async {
    await _repository.clearAllOfflineCache();
    _cachedViewedStatuses = [];
    notifyListeners();

    if (kDebugMode) {
      print('🗑️ Cleared all offline caches');
    }
  }

  /// Get offline cache info
  Future<({int statusCount, bool hasCache})> getOfflineCacheInfo() async {
    final cachedStatuses = await _repository.getCachedViewedStatuses();
    return (statusCount: cachedStatuses.length, hasCache: cachedStatuses.isNotEmpty);
  }
}
