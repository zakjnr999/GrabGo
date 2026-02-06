import 'package:flutter/foundation.dart';

/// Base provider with common state management patterns
abstract class BaseProvider<T> extends ChangeNotifier {
  T _state;
  T get state => _state;

  BaseProvider(this._state);

  /// Update state and notify listeners
  void updateState(T newState) {
    _state = newState;
    notifyListeners();
  }

  /// Safely update state with error handling
  Future<void> safeUpdate(Future<T> Function() update) async {
    try {
      final newState = await update();
      updateState(newState);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating state: $e');
      }
      rethrow;
    }
  }
}

/// Mixin for providers that need caching
mixin CacheMixin<T> on ChangeNotifier {
  /// Load data from cache
  Future<List<Map<String, dynamic>>?> loadFromCache(
    String cacheKey,
    bool Function() isCacheValid,
    List<Map<String, dynamic>> Function() getCachedData,
  ) async {
    try {
      if (isCacheValid()) {
        return getCachedData();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading from cache ($cacheKey): $e');
      }
    }
    return null;
  }

  /// Save data to cache
  Future<void> saveToCache(
    String cacheKey,
    List<Map<String, dynamic>> data,
    void Function(List<Map<String, dynamic>>) saveCachedData,
  ) async {
    try {
      saveCachedData(data);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving to cache ($cacheKey): $e');
      }
    }
  }
}

/// Mixin for providers that need loading states
mixin LoadingStateMixin on ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  /// Set loading state
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Execute with loading state
  Future<R> withLoading<R>(Future<R> Function() action) async {
    setLoading(true);
    setError(null);
    try {
      final result = await action();
      return result;
    } catch (e) {
      setError(e.toString());
      rethrow;
    } finally {
      setLoading(false);
    }
  }
}
