import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_shared/shared/services/chat_socket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/status/model/status_model.dart';
import 'package:grab_go_customer/features/status/model/comment_model.dart';
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

  // ============================================================
  // Comment State
  // ============================================================

  // Comment state
  final Map<String, List<CommentModel>> _commentsCache = {};
  final Map<String, bool> _loadingComments = {};
  final Map<String, String?> _commentErrors = {};
  final Map<String, CommentPagination?> _commentPagination = {};

  // Reply state
  final Map<String, List<CommentModel>> _repliesCache = {};
  final Map<String, bool> _loadingReplies = {};
  final Map<String, String?> _replyErrors = {};

  // Reaction state
  final Map<String, ReactionSummary> _reactionCache = {};

  // Getters for comment state
  List<CommentModel> getComments(String statusId) => _commentsCache[statusId] ?? [];
  bool isLoadingComments(String statusId) => _loadingComments[statusId] ?? false;
  String? getCommentError(String statusId) => _commentErrors[statusId];
  bool canLoadMoreComments(String statusId) => _commentPagination[statusId]?.hasMore ?? false;

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
      // Always set error message for user feedback
      if (_stories.isEmpty) {
        _error = 'No stories available. Please check your connection.';
      } else {
        _error = 'Failed to refresh stories. Showing cached data.';
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
      // Always set error message for user feedback
      if (_statuses.isEmpty) {
        _error = 'No statuses available. Please check your connection.';
      } else {
        _error = 'Failed to refresh statuses. Showing cached data.';
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
  Future<void> fetchRestaurantStatuses(String restaurantId, {BuildContext? context, bool forceRefresh = false}) async {
    // Cache-first: if we have cached data and not forcing refresh, use it immediately
    if (!forceRefresh) {
      final cachedStatuses = await _repository.getCachedRestaurantStatuses(restaurantId);
      if (cachedStatuses != null && cachedStatuses.isNotEmpty) {
        _currentRestaurantStatuses = cachedStatuses;
        _isLoadingRestaurantStatuses = false;

        // Mark restaurant as viewed and persist
        await _saveViewedRestaurant(restaurantId);
        final storyIndex = _stories.indexWhere((s) => s.restaurantId == restaurantId);
        if (storyIndex >= 0) {
          _stories[storyIndex] = _stories[storyIndex].copyWith(isViewed: true);
        }

        // Preload images if possible
        if (context != null && context.mounted) {
          preloadStatusImages(context, _currentRestaurantStatuses);
        }

        if (kDebugMode) {
          print('📦 Using ${cachedStatuses.length} cached statuses for restaurant $restaurantId (cache-first)');
        }
        notifyListeners();
        return;
      }
    }

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

  // ============================================================
  // Comment Methods
  // ============================================================

  /// Fetch comments for a status
  Future<void> fetchComments(String statusId, {int page = 1}) async {
    try {
      _loadingComments[statusId] = true;
      _commentErrors[statusId] = null;
      notifyListeners();

      final response = await statusService.getComments(statusId, page: page, limit: 20);

      if (kDebugMode) {
        print('📡 Comment API response: ${response.body}');
      }

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;

        final commentsData = data['comments'];
        final comments = <CommentModel>[];

        if (commentsData is List) {
          for (var json in commentsData) {
            try {
              comments.add(CommentModel.fromJson(json as Map<String, dynamic>));
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Skipping invalid comment: $e');
              }
            }
          }
        }

        final pagination = CommentPagination.fromJson(data['pagination'] as Map<String, dynamic>);

        if (page == 1) {
          _commentsCache[statusId] = comments;
        } else {
          _commentsCache[statusId] = [...(_commentsCache[statusId] ?? []), ...comments];
        }
        _commentPagination[statusId] = pagination;

        // Fetch reactions for all comments (await to ensure they load)
        await Future.wait(comments.map((comment) => _fetchReactionsForComment(comment.id)));

        // Fetch first 2 replies for comments with replies (for preview)
        final commentsWithReplies = comments.where((c) => c.replyCount > 0);
        await Future.wait(commentsWithReplies.map((comment) => fetchReplies(comment.id, page: 1)));

        if (kDebugMode) {
          print('✅ Fetched ${comments.length} comments for status $statusId');
        }
      } else {
        _commentErrors[statusId] = 'Failed to load comments';
      }
    } catch (e) {
      _commentErrors[statusId] = 'Error loading comments';
      if (kDebugMode) {
        print('❌ Error fetching comments: $e');
      }
    } finally {
      _loadingComments[statusId] = false;
      notifyListeners();
    }
  }

  /// Add a comment to a status
  Future<bool> addComment(String statusId, String text) async {
    if (text.trim().isEmpty) return false;

    try {
      // Optimistic update - add temporary comment
      final tempComment = CommentModel(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        statusId: statusId,
        user: CommentUser(id: 'current_user', name: 'You', email: null, profileImage: null),
        text: text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _commentsCache[statusId] = [tempComment, ...(_commentsCache[statusId] ?? [])];
      notifyListeners();

      final response = await statusService.addComment(statusId, {'text': text.trim()});

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        final newComment = CommentModel.fromJson(data['comment'] as Map<String, dynamic>);

        // Replace temp comment with real one
        final comments = _commentsCache[statusId] ?? [];
        final index = comments.indexWhere((c) => c.id == tempComment.id);
        if (index != -1) {
          comments[index] = newComment;
          _commentsCache[statusId] = List.from(comments);
        }

        notifyListeners();

        if (kDebugMode) {
          print('✅ Comment added successfully');
        }
        return true;
      } else {
        // Remove temp comment on failure
        _commentsCache[statusId] = (_commentsCache[statusId] ?? []).where((c) => c.id != tempComment.id).toList();
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error adding comment: $e');
      }
      // Remove temp comment on error
      _commentsCache[statusId] = (_commentsCache[statusId] ?? []).where((c) => !c.id.startsWith('temp_')).toList();
      notifyListeners();
      return false;
    }
  }

  /// Delete a comment
  Future<bool> deleteComment(String statusId, String commentId) async {
    try {
      // Optimistic update - remove comment immediately
      final originalComments = List<CommentModel>.from(_commentsCache[statusId] ?? []);
      _commentsCache[statusId] = originalComments.where((c) => c.id != commentId).toList();
      notifyListeners();

      final response = await statusService.deleteComment(commentId);

      if (response.isSuccessful) {
        if (kDebugMode) {
          print('✅ Comment deleted successfully');
        }
        return true;
      } else {
        // Restore comment on failure
        _commentsCache[statusId] = originalComments;
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting comment: $e');
      }
      // Restore comments on error
      notifyListeners();
      return false;
    }
  }

  /// Clear comments cache for a status
  void clearComments(String statusId) {
    _commentsCache.remove(statusId);
    _commentPagination.remove(statusId);
    _commentErrors.remove(statusId);
    _loadingComments.remove(statusId);
    notifyListeners();
  }

  // ============================================================
  // Reply Methods
  // ============================================================

  /// Get replies for a comment
  List<CommentModel> getReplies(String commentId) => _repliesCache[commentId] ?? [];
  bool isLoadingReplies(String commentId) => _loadingReplies[commentId] ?? false;

  /// Fetch replies for a comment
  Future<void> fetchReplies(String commentId, {int page = 1}) async {
    try {
      _loadingReplies[commentId] = true;
      _replyErrors[commentId] = null;
      notifyListeners();

      final response = await statusService.getReplies(commentId, page: page, limit: 10);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        final repliesData = data['replies'];
        final replies = <CommentModel>[];

        if (repliesData is List) {
          for (var json in repliesData) {
            try {
              replies.add(CommentModel.fromJson(json as Map<String, dynamic>));
            } catch (e) {
              if (kDebugMode) print('⚠️ Skipping invalid reply: $e');
            }
          }
        }

        _repliesCache[commentId] = replies;
      } else {
        _replyErrors[commentId] = 'Failed to load replies';
      }
    } catch (e) {
      _replyErrors[commentId] = 'Error loading replies';
      if (kDebugMode) print('❌ Error fetching replies: $e');
    } finally {
      _loadingReplies[commentId] = false;
      notifyListeners();
    }
  }

  /// Add a reply to a comment
  Future<bool> addReply(String commentId, String statusId, String text) async {
    if (text.trim().isEmpty) return false;

    try {
      // Optimistic update
      final tempReply = CommentModel(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        statusId: statusId,
        user: CommentUser(id: 'current_user', name: 'You'),
        text: text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        parentCommentId: commentId,
      );

      _repliesCache[commentId] = [tempReply, ...(_repliesCache[commentId] ?? [])];
      notifyListeners();

      final response = await statusService.addReply(commentId, {'text': text.trim()});

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['reply'] != null) {
          final realReply = CommentModel.fromJson(data['reply'] as Map<String, dynamic>);
          _repliesCache[commentId] = _repliesCache[commentId]!
              .map((r) => r.id == tempReply.id ? realReply : r)
              .toList();

          // Update parent comment's reply count in comments cache
          for (var statusId in _commentsCache.keys) {
            final comments = _commentsCache[statusId];
            if (comments != null) {
              final index = comments.indexWhere((c) => c.id == commentId);
              if (index != -1) {
                final updatedComment = CommentModel(
                  id: comments[index].id,
                  statusId: comments[index].statusId,
                  user: comments[index].user,
                  text: comments[index].text,
                  createdAt: comments[index].createdAt,
                  updatedAt: comments[index].updatedAt,
                  parentCommentId: comments[index].parentCommentId,
                  replyCount: comments[index].replyCount + 1,
                  replies: comments[index].replies,
                  reactions: comments[index].reactions,
                );
                _commentsCache[statusId]![index] = updatedComment;
                break;
              }
            }
          }

          notifyListeners();
          return true;
        }
      }

      // Revert on failure
      _repliesCache[commentId] = _repliesCache[commentId]!.where((r) => r.id != tempReply.id).toList();
      notifyListeners();
      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Error adding reply: $e');
      return false;
    }
  }

  // ============================================================
  // Reaction Methods
  // ============================================================

  /// Get reactions for a comment
  ReactionSummary getReactions(String commentId) => _reactionCache[commentId] ?? ReactionSummary.empty();

  /// Toggle reaction on a comment
  Future<bool> toggleReaction(String commentId, ReactionType type) async {
    // Save current state for rollback
    final current = _reactionCache[commentId] ?? ReactionSummary.empty();

    try {
      // Optimistic update
      final isRemoving = current.userReaction == type;

      // Update cache optimistically
      if (isRemoving) {
        // Remove reaction
        _reactionCache[commentId] = ReactionSummary(
          like: type == ReactionType.like ? current.like - 1 : current.like,
          love: type == ReactionType.love ? current.love - 1 : current.love,
          haha: type == ReactionType.haha ? current.haha - 1 : current.haha,
          wow: type == ReactionType.wow ? current.wow - 1 : current.wow,
          sad: type == ReactionType.sad ? current.sad - 1 : current.sad,
          angry: type == ReactionType.angry ? current.angry - 1 : current.angry,
          total: current.total - 1,
          userReaction: null,
        );
      } else {
        // Add or change reaction
        var newLike = current.like;
        var newLove = current.love;
        var newHaha = current.haha;
        var newWow = current.wow;
        var newSad = current.sad;
        var newAngry = current.angry;
        var newTotal = current.total;

        // Remove old reaction if exists
        if (current.userReaction != null) {
          switch (current.userReaction!) {
            case ReactionType.like:
              newLike--;
              break;
            case ReactionType.love:
              newLove--;
              break;
            case ReactionType.haha:
              newHaha--;
              break;
            case ReactionType.wow:
              newWow--;
              break;
            case ReactionType.sad:
              newSad--;
              break;
            case ReactionType.angry:
              newAngry--;
              break;
          }
          newTotal--;
        }

        // Add new reaction
        switch (type) {
          case ReactionType.like:
            newLike++;
            break;
          case ReactionType.love:
            newLove++;
            break;
          case ReactionType.haha:
            newHaha++;
            break;
          case ReactionType.wow:
            newWow++;
            break;
          case ReactionType.sad:
            newSad++;
            break;
          case ReactionType.angry:
            newAngry++;
            break;
        }
        newTotal++;

        _reactionCache[commentId] = ReactionSummary(
          like: newLike,
          love: newLove,
          haha: newHaha,
          wow: newWow,
          sad: newSad,
          angry: newAngry,
          total: newTotal,
          userReaction: type,
        );
      }
      notifyListeners();

      final response = await statusService.toggleReaction(commentId, {'type': type.name});

      if (kDebugMode) {
        print('🔍 Response successful: ${response.isSuccessful}');
        print('🔍 Response body: ${response.body}');
        print('🔍 Response status code: ${response.statusCode}');
      }

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (kDebugMode) print('🔍 Toggle reaction response: $data');

        if (data['success'] == true && data['data'] != null) {
          final responseData = data['data'] as Map<String, dynamic>;
          final reactions = responseData['reactions'] as Map<String, dynamic>;
          _reactionCache[commentId] = ReactionSummary.fromJson(reactions);
          if (kDebugMode) print('✅ Reaction cached: ${_reactionCache[commentId]}');
          notifyListeners();
          return true;
        } else {
          if (kDebugMode) print('❌ Response missing success or data field');
        }
      } else {
        if (kDebugMode) print('❌ Response not successful or body is null');
      }

      // Revert on failure
      if (kDebugMode) print('❌ Reaction toggle failed, reverting');
      _reactionCache[commentId] = current;
      notifyListeners();
      return false;
    } catch (e) {
      if (kDebugMode) print('❌ Error toggling reaction: $e');
      // Revert on error
      _reactionCache[commentId] = current;
      notifyListeners();
      return false;
    }
  }

  /// Fetch reactions for a comment (internal helper, no UI updates)
  Future<void> _fetchReactionsForComment(String commentId) async {
    try {
      final response = await statusService.getReactions(commentId);
      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['reactions'] != null) {
          _reactionCache[commentId] = ReactionSummary.fromJson(data['reactions'] as Map<String, dynamic>);
          // Don't call notifyListeners here - parent will call it after all reactions are loaded
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Error fetching reactions for $commentId: $e');
    }
  }
}
