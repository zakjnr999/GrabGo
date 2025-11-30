import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/status/model/status_model.dart';
import 'package:grab_go_customer/features/status/repository/status_repository.dart';

/// Provider for Status feature state management
class StatusProvider with ChangeNotifier {
  late final StatusRepository _repository;

  StatusProvider() {
    _repository = StatusRepository(statusService);
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

  /// Initialize provider - call this on app start
  Future<void> init() async {
    await _loadViewedRestaurants();
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

  /// Fetch stories for the story ring
  Future<void> fetchStories({int limit = 20, String sortBy = 'recent', bool forceRefresh = false}) async {
    if (_isLoadingStories) return;
    if (_stories.isNotEmpty && !forceRefresh) return;

    _isLoadingStories = true;
    _error = null;
    notifyListeners();

    try {
      final stories = await _repository.fetchStories(limit: limit, sortBy: sortBy);

      // Mark viewed stories
      _stories = stories.map((story) {
        return story.copyWith(isViewed: _viewedRestaurantIds.contains(story.restaurantId));
      }).toList();

      if (kDebugMode) {
        print('✅ Fetched ${_stories.length} stories');
      }
    } catch (e) {
      _error = 'Failed to load stories: ${e.toString()}';
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

  /// Fetch statuses with optional filters
  Future<void> fetchStatuses({
    StatusCategory? category,
    String? restaurantId,
    bool? recommended,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    if (_isLoadingStatuses) return;
    if (_statuses.isNotEmpty && !forceRefresh && category == _selectedCategory) return;

    _isLoadingStatuses = true;
    _error = null;
    _selectedCategory = category;
    notifyListeners();

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

      if (kDebugMode) {
        print('✅ Fetched ${_statuses.length} statuses');
      }
    } catch (e) {
      _error = 'Failed to load statuses: ${e.toString()}';
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
  Future<void> fetchRestaurantStatuses(String restaurantId) async {
    _isLoadingRestaurantStatuses = true;
    _currentRestaurantStatuses = [];
    notifyListeners();

    try {
      _currentRestaurantStatuses = await _repository.fetchRestaurantStatuses(restaurantId);

      // Mark restaurant as viewed and persist
      await _saveViewedRestaurant(restaurantId);

      // Update story's viewed state
      final storyIndex = _stories.indexWhere((s) => s.restaurantId == restaurantId);
      if (storyIndex >= 0) {
        _stories[storyIndex] = _stories[storyIndex].copyWith(isViewed: true);
      }

      if (kDebugMode) {
        print('✅ Fetched ${_currentRestaurantStatuses.length} statuses for restaurant $restaurantId');
      }
    } catch (e) {
      _error = 'Failed to load restaurant statuses: ${e.toString()}';
      if (kDebugMode) {
        print('❌ Error fetching restaurant statuses: $e');
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

  /// Set selected category filter
  void setSelectedCategory(StatusCategory? category) {
    if (_selectedCategory != category) {
      _selectedCategory = category;
      fetchStatuses(category: category, forceRefresh: true);
    }
  }

  /// Clear all filters
  void clearFilters() {
    _selectedCategory = null;
    fetchStatuses(forceRefresh: true);
  }

  // ============================================================
  // Utility Methods
  // ============================================================

  /// Clear all data
  void clearAll() {
    _stories = [];
    _statuses = [];
    _currentRestaurantStatuses = [];
    _pagination = null;
    _selectedCategory = null;
    _error = null;
    _likedStatusIds.clear();
    _viewedRestaurantIds.clear();
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
