/// A lightweight, generic, in-memory cache with per-key TTL expiry.
///
/// Usage:
/// ```dart
/// final data = await MemoryCache.getOrFetch<MyModel>(
///   'partner_dashboard',
///   fetch: () => api.loadPartnerDashboard(),
///   ttl: Duration(minutes: 5),
/// );
/// ```
///
/// Invalidate a specific key:
/// ```dart
/// MemoryCache.invalidate('partner_dashboard');
/// ```
///
/// Invalidate a group of related keys:
/// ```dart
/// MemoryCache.invalidatePrefix('partner_');
/// ```
class MemoryCache {
  MemoryCache._();

  static final Map<String, _CacheEntry<dynamic>> _store = {};

  /// Default TTL – 5 minutes.  Callers can override per-call.
  static const Duration defaultTtl = Duration(minutes: 5);

  // ───────────────── core API ─────────────────

  /// Return cached value if still valid, otherwise call [fetch],
  /// store the result, and return it.
  ///
  /// If [forceRefresh] is true the cache is bypassed and [fetch] is always
  /// called (the result still gets cached for subsequent reads).
  static Future<T> getOrFetch<T>(
    String key, {
    required Future<T> Function() fetch,
    Duration ttl = defaultTtl,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final entry = _store[key];
      if (entry != null && !entry.isExpired) {
        return entry.value as T;
      }
    }

    final value = await fetch();
    _store[key] = _CacheEntry<T>(value: value, ttl: ttl);
    return value;
  }

  /// Returns the cached value **only** if it exists and hasn't expired.
  /// Does NOT trigger a fetch.  Useful for showing stale-while-revalidate UI.
  static T? peek<T>(String key) {
    final entry = _store[key];
    if (entry != null && !entry.isExpired) {
      return entry.value as T;
    }
    return null;
  }

  /// Put a value in the cache directly (e.g. after a write operation
  /// that returns the updated object).
  static void put<T>(String key, T value, {Duration ttl = defaultTtl}) {
    _store[key] = _CacheEntry<T>(value: value, ttl: ttl);
  }

  // ───────────────── invalidation ─────────────────

  /// Remove a single key.
  static void invalidate(String key) => _store.remove(key);

  /// Remove all keys that start with [prefix].
  /// Handy for wiping a whole domain, e.g. `MemoryCache.invalidatePrefix('partner_')`.
  static void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Remove everything.
  static void clear() => _store.clear();

  /// How many entries are currently cached (debug / tests).
  static int get length => _store.length;
}

// ─────────────────────────────────────────────────────────────────────

class _CacheEntry<T> {
  _CacheEntry({required this.value, required Duration ttl}) : _expiresAt = DateTime.now().add(ttl);

  final T value;
  final DateTime _expiresAt;

  bool get isExpired => DateTime.now().isAfter(_expiresAt);
}
