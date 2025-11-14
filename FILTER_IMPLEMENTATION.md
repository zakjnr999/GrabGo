# Filter Bottom Sheet Implementation Guide

## Overview

A fully-featured filter bottom sheet has been implemented for the GrabGo customer app, allowing users to filter food items by:

- **Price Range**: Minimum and maximum price slider
- **Rating**: Minimum rating selection (2.0, 3.0, 4.0, 4.5, 5.0 stars)
- **Food Types**: Categories with emojis
- **Restaurants**: Restaurant name selection with checkboxes

## Files Created

### 1. `filter_model.dart`

**Location**: `packages/grab_go_customer/lib/features/home/model/filter_model.dart`

Manages filter state with the following properties:

- `minPrice` / `maxPrice`: Price range filter (default: 0-10000)
- `minRating`: Minimum rating filter (nullable)
- `selectedCategories`: List of selected category IDs
- `selectedRestaurants`: List of selected restaurant names

**Key Methods**:

- `isActive`: Checks if any filter is currently applied
- `reset()`: Resets all filters to default values
- `copyWith()`: Creates a copy of the filter with optional changes

### 2. `filter_bottom_sheet.dart`

**Location**: `packages/grab_go_customer/lib/features/home/view/filter_bottom_sheet.dart`

The main filter UI widget with the following components:

#### Header Section

- Filter title with "Reset" button (visible only when filters are active)
- Close button (X icon)

#### Filter Sections

**Price Range Filter**:

- Range slider with visual feedback
- Shows min/max values in real-time
- Range: $0 - $10,000

**Rating Filter**:

- 5 buttons for different rating thresholds: 2.0, 3.0, 4.0, 4.5, 5.0
- Tap to select/deselect
- Visual highlight in orange when selected

**Food Types Filter**:

- Grid/wrap layout of category chips
- Each chip shows emoji + category name
- Selected categories highlighted in orange
- Tappable for multi-select

**Restaurants Filter**:

- List of restaurant checkboxes
- Custom checkbox design with circular indicators
- Selected restaurants highlighted with orange border and background

#### Bottom Action Buttons

- **"Clear All"**: Resets all filters and applies empty filter
- **"Apply Filters"**: Applies current filter settings and closes bottom sheet

## Integration with UI

### Updated: `home_search.dart`

**Location**: `packages/grab_go_customer/lib/shared/widgets/home_search.dart`

The HomeSearch widget now:

1. Changed from `StatelessWidget` to `StatefulWidget`
2. Maintains current filter state (`_currentFilter`)
3. Shows filter bottom sheet on filter button tap
4. Provides unique restaurant list from all categories

**Key Changes**:

```dart
// On filter button tap:
onTap: () => _showFilterBottomSheet(context, foodProvider.categories)

// Extracts unique restaurant names from all food items
_getUniqueRestaurants(List<FoodCategoryModel> categories)
```

## Usage Example

### Showing the Filter Bottom Sheet

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => FilterBottomSheet(
    initialFilter: _currentFilter,
    categories: foodProvider.categories,
    restaurants: _getUniqueRestaurants(foodProvider.categories),
    onApply: (FilterModel filter) {
      setState(() {
        _currentFilter = filter;
      });
      // Apply filter to food items in FoodProvider
    },
  ),
);
```

### Checking Active Filters

```dart
if (_currentFilter.isActive) {
  // Show indicator or perform filtering
}
```

### Accessing Filter Values

```dart
// Check price range
if (foodItem.price >= _currentFilter.minPrice &&
    foodItem.price <= _currentFilter.maxPrice) {
  // Item matches price filter
}

// Check rating
if (_currentFilter.minRating == null ||
    foodItem.rating >= _currentFilter.minRating!) {
  // Item matches rating filter
}

// Check category
if (_currentFilter.selectedCategories.isEmpty ||
    _currentFilter.selectedCategories.contains(categoryId)) {
  // Item matches category filter
}

// Check restaurant
if (_currentFilter.selectedRestaurants.isEmpty ||
    _currentFilter.selectedRestaurants.contains(foodItem.sellerName)) {
  // Item matches restaurant filter
}
```

## Design Patterns Used

### Animation & Styling

- Uses existing app color scheme (`context.appColors`)
- Orange accent color (`colors.accentOrange`) for active selections
- Consistent border radius and spacing with `KBorderSize` and `KSpacing`
- Smooth transitions and visual feedback for interactions

### State Management

- Uses Provider for accessing FoodProvider data
- Local state management within HomeSearch for current filter
- TODO: Connect to FoodProvider for actual filtering logic

### Component Architecture

- Reusable `_buildSectionHeader()` widget for consistent headers
- Separate builder methods for each filter type:
  - `_buildPriceFilter()`
  - `_buildRatingFilter()`
  - `_buildCategoriesFilter()`
  - `_buildRestaurantsFilter()`

## Next Steps

### 1. Implement Filtering Logic in FoodProvider

Add a method to filter food items based on the FilterModel:

```dart
List<FoodItem> getFilteredItems(FilterModel filter) {
  return _allItems.where((item) {
    // Apply all filter conditions
    if (item.price < filter.minPrice || item.price > filter.maxPrice) {
      return false;
    }
    if (filter.minRating != null && item.rating < filter.minRating!) {
      return false;
    }
    if (filter.selectedCategories.isNotEmpty &&
        !filter.selectedCategories.contains(item.categoryId)) {
      return false;
    }
    if (filter.selectedRestaurants.isNotEmpty &&
        !filter.selectedRestaurants.contains(item.sellerName)) {
      return false;
    }
    return true;
  }).toList();
}
```

### 2. Update HomePage Display

Modify food items display to use filtered results:

```dart
Consumer<FoodProvider>(
  builder: (context, provider, _) {
    final filteredItems = provider.getFilteredItems(_currentFilter);
    // Display filtered items
  },
)
```

### 3. Add Filter Badge/Indicator

Show a badge on the filter button when filters are active:

```dart
if (_currentFilter.isActive)
  Positioned(
    right: 0,
    top: 0,
    child: Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.accentOrange,
      ),
    ),
  )
```

### 4. Persist Filter State (Optional)

Save filter preferences using SharedPreferences:

```dart
_saveFilterToCache(FilterModel filter) {
  // Serialize and save
}

_loadFilterFromCache() {
  // Deserialize and load
}
```

## Styling Notes

### Color Scheme

- Primary text: `colors.textPrimary`
- Secondary text: `colors.textSecondary`
- Input fields: `colors.inputBorder`
- Active state: `colors.accentOrange`
- Background: `colors.backgroundPrimary`

### Responsive Sizing

- Uses `flutter_screenutil` for responsive dimensions
- Price slider: Full width with padding
- Rating buttons: Evenly spaced in row
- Category chips: Flexible wrap layout
- Restaurant checkboxes: Full-width list

## Features Included

✅ Price range slider with real-time value display
✅ Multi-select rating filter with visual highlighting
✅ Category selection with emoji display
✅ Restaurant checkboxes with custom styling
✅ Reset filter functionality
✅ Apply/Cancel actions
✅ Responsive design for all screen sizes
✅ Dark/Light theme support via app colors
✅ Smooth animations and transitions
✅ Professional UI matching existing design patterns
