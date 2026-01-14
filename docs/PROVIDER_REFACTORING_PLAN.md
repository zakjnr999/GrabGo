# Provider Refactoring Plan - GrabGo Customer App

**Goal:** Refactor all providers to follow best practices for maintainability, performance, and testability.

---

## Current Provider Inventory

| Provider | Lines | Complexity | Priority | Status |
|----------|-------|------------|----------|--------|
| **FoodProvider** | 484 | 🔴 High | P1 | ⏳ Pending |
| **OrderProvider** | 372 | 🔴 High | P1 | ⏳ Pending |
| **CartProvider** | 340 | 🟡 Medium | P2 | ⏳ Pending |
| **RestaurantProvider** | 339 | 🟡 Medium | P2 | ⏳ Pending |
| **GroceryProvider** | 295 | 🟡 Medium | P2 | ⏳ Pending |
| **StatusProvider** | ? | 🟡 Medium | P3 | ⏳ Pending |
| **FavoritesProvider** | ? | 🟢 Low | P3 | ⏳ Pending |
| **LocationProvider** | ? | 🟢 Low | P3 | ⏳ Pending |
| **NavigationProvider** | ? | 🟢 Low | P4 | ⏳ Pending |
| **ServiceProvider** | ? | 🟢 Low | P4 | ⏳ Pending |
| **SettingsProvider** | ? | 🟢 Low | P4 | ⏳ Pending |
| **ThemeProvider** | ? | 🟢 Low | P4 | ⏳ Pending |
| **TrackingProvider** | ? | 🟢 Low | P3 | ⏳ Pending |

---

## Refactoring Strategy

### Phase 1: Foundation (Week 1)
**Goal:** Establish patterns and refactor largest providers

1. ✅ **FoodProvider** (484 lines) - Split into 4 focused providers
2. ✅ **OrderProvider** (372 lines) - Implement state pattern
3. ✅ Create base classes and mixins for common patterns

### Phase 2: Core Features (Week 2)
**Goal:** Refactor business-critical providers

4. ✅ **CartProvider** (340 lines) - Optimize backend sync
5. ✅ **RestaurantProvider** (339 lines) - Improve caching
6. ✅ **GroceryProvider** (295 lines) - Split into focused providers

### Phase 3: Supporting Features (Week 3)
**Goal:** Refactor remaining providers

7. ✅ **StatusProvider** - Optimize real-time updates
8. ✅ **FavoritesProvider** - Implement optimistic updates
9. ✅ **LocationProvider** - Improve error handling
10. ✅ **TrackingProvider** - Optimize map updates

### Phase 4: UI & Settings (Week 4)
**Goal:** Refactor simple providers

11. ✅ **NavigationProvider** - Simplify state
12. ✅ **ServiceProvider** - Clean up
13. ✅ **SettingsProvider** - Add validation
14. ✅ **ThemeProvider** - Optimize

---

## Best Practices to Apply

### 1. State Pattern
```dart
// Immutable state class
class OrderState {
  final List<Order> orders;
  final bool isLoading;
  final String? error;
  
  const OrderState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
  });
  
  OrderState copyWith({
    List<Order>? orders,
    bool? isLoading,
    String? error,
  }) {
    return OrderState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
```

### 2. Split Large Providers
```dart
// Instead of FoodProvider (484 lines)
// Split into:
- FoodCategoryProvider (categories logic)
- FoodBannerProvider (banners logic)
- FoodDealsProvider (deals logic)
- FoodSearchProvider (search logic)
```

### 3. Caching Mixin
```dart
mixin CacheMixin<T> on ChangeNotifier {
  Future<void> loadFromCache(String key);
  Future<void> saveToCache(String key, T data);
}
```

### 4. Error Handling
```dart
class ProviderError {
  final String message;
  final StackTrace? stackTrace;
  final DateTime timestamp;
  
  ProviderError(this.message, [this.stackTrace])
      : timestamp = DateTime.now();
}
```

### 5. Optimistic Updates
```dart
void addToCart(CartItem item) {
  // 1. Update UI immediately
  _items.add(item);
  notifyListeners();
  
  // 2. Sync to backend
  _syncToBackend(item).catchError((error) {
    // 3. Rollback on error
    _items.remove(item);
    notifyListeners();
  });
}
```

---

## Refactoring Checklist (Per Provider)

### Code Quality
- [ ] Split if > 300 lines
- [ ] Implement state pattern
- [ ] Add proper error handling
- [ ] Remove duplicate code
- [ ] Add documentation comments

### Performance
- [ ] Use Selector-friendly state
- [ ] Implement debouncing for API calls
- [ ] Add request cancellation
- [ ] Optimize notifyListeners() calls
- [ ] Implement pagination

### Caching
- [ ] Consistent cache key naming
- [ ] Cache invalidation strategy
- [ ] Background refresh
- [ ] Error recovery from cache

### Testing
- [ ] Unit tests for business logic
- [ ] Mock dependencies
- [ ] Test error scenarios
- [ ] Test cache behavior

---

## Success Metrics

### Code Quality
- ✅ No provider > 300 lines
- ✅ All providers use state pattern
- ✅ 80%+ test coverage
- ✅ Zero duplicate cache logic

### Performance
- ✅ 50% reduction in rebuilds (measured with DevTools)
- ✅ < 100ms for state updates
- ✅ Smooth 60fps animations

### Maintainability
- ✅ New features take < 1 day to add
- ✅ Bugs take < 1 hour to fix
- ✅ Easy to onboard new developers

---

## Next Steps

1. **Start with FoodProvider** (highest complexity)
2. **Create base classes** (reusable patterns)
3. **Refactor one provider per day**
4. **Test thoroughly** before moving to next
5. **Document learnings** for team

---

**Estimated Timeline:** 4 weeks (1 hour/day)
**Risk Level:** Low (incremental changes)
**Impact:** High (better performance, maintainability)
