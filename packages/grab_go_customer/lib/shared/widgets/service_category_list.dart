import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// A generic, reusable horizontal category selector widget.
///
/// This widget displays a scrollable list of categories with selection state,
/// smooth animations, and callbacks. It works with any category type through
/// generic type parameters and accessor functions.
///
/// **Type Parameter:**
/// - `T`: The type of category object (e.g., `FoodCategoryModel`, `GroceryCategory`)
///
/// **Features:**
/// - ✅ Type-safe generic implementation
/// - ✅ Smooth selection animations
/// - ✅ Automatic initial selection
/// - ✅ Handles category list changes gracefully
/// - ✅ Preserves selection across rebuilds
/// - ✅ Theme-aware styling
///
/// **Example Usage:**
///
/// ```dart
/// // For Food Categories
/// ServiceCategoryList<FoodCategoryModel>(
///   categories: foodCategories,
///   getName: (cat) => cat.name,
///   getEmoji: (cat) => cat.emoji,
///   getId: (cat) => cat.id,
///   onCategorySelected: (cat) => handleFoodCategorySelected(cat),
///   initialSelectedCategory: selectedFoodCategory,
/// )
///
/// // For Grocery Categories
/// ServiceCategoryList<GroceryCategory>(
///   categories: groceryCategories,
///   getName: (cat) => cat.name,
///   getEmoji: (cat) => cat.emoji,
///   getId: (cat) => cat.id,
///   onCategorySelected: (cat) => handleGroceryCategorySelected(cat),
///   initialSelectedCategory: selectedGroceryCategory,
/// )
/// ```
///
/// **Accessor Functions:**
/// The widget uses accessor functions to extract properties from category objects,
/// making it compatible with any category model structure:
/// - `getName(T)`: Extract the category name
/// - `getEmoji(T)`: Extract the category emoji/icon
/// - `getId(T)`: Extract the unique category identifier
///
/// **State Management:**
/// - Maintains internal selection state
/// - Automatically selects first category on mount
/// - Preserves selection when category list changes
/// - Resets to first category if selected category is removed
///
/// **Performance:**
/// - No runtime overhead from generics (compile-time only)
/// - Efficient list rendering with ListView.builder
/// - Optimized animations with AnimatedContainer
///
class ServiceCategoryList<T> extends StatefulWidget {
  /// List of categories to display
  final List<T> categories;

  /// Function to extract the name from a category
  final String Function(T) getName;

  /// Function to extract the emoji/icon from a category
  final String Function(T) getEmoji;

  /// Function to extract the unique ID from a category
  final String Function(T) getId;

  /// Callback when a category is selected
  final ValueChanged<T> onCategorySelected;

  /// Optional initial selected category
  final T? initialSelectedCategory;

  /// Whether to automatically notify onCategorySelected on build/list change
  final bool autoNotify;

  const ServiceCategoryList({
    super.key,
    required this.categories,
    required this.getName,
    required this.getEmoji,
    required this.getId,
    required this.onCategorySelected,
    this.initialSelectedCategory,
    this.autoNotify = true,
  });

  @override
  State<ServiceCategoryList<T>> createState() => _ServiceCategoryListState<T>();
}

class _ServiceCategoryListState<T> extends State<ServiceCategoryList<T>> {
  /// Currently selected category index
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeSelection();
    if (widget.autoNotify) {
      _notifyInitialSelection();
    }
  }

  /// Initialize the selected index based on initialSelectedCategory
  void _initializeSelection() {
    final initial = widget.initialSelectedCategory;
    if (initial != null) {
      final index = _findCategoryIndex(initial);
      selectedIndex = index >= 0 ? index : 0;
    } else {
      selectedIndex = 0;
    }
  }

  /// Notify parent of initial selection after first frame
  void _notifyInitialSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.categories.isNotEmpty && selectedIndex < widget.categories.length) {
        widget.onCategorySelected(widget.categories[selectedIndex]);
      }
    });
  }

  @override
  void didUpdateWidget(ServiceCategoryList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Guard against empty categories
    if (widget.categories.isEmpty) {
      return;
    }

    // Handle category list changes
    if (_categoriesChanged(oldWidget.categories)) {
      _handleCategoryListChange(oldWidget);
    }
    // Handle initial selection change
    else if (_initialSelectionChanged(oldWidget)) {
      _handleInitialSelectionChange();
    }
  }

  /// Check if categories list has changed
  bool _categoriesChanged(List<T> oldCategories) {
    if (widget.categories.length != oldCategories.length) return true;
    return !_categoriesEqual(widget.categories, oldCategories);
  }

  /// Check if initial selection has changed
  bool _initialSelectionChanged(ServiceCategoryList<T> oldWidget) {
    final current = widget.initialSelectedCategory;
    final old = oldWidget.initialSelectedCategory;

    if (current == null && old == null) {
      return false;
    }
    if (current == null || old == null) {
      return true;
    }
    return widget.getId(current) != widget.getId(old);
  }

  /// Handle category list changes
  void _handleCategoryListChange(ServiceCategoryList<T> oldWidget) {
    int newIndex = selectedIndex;

    // Try to preserve the selected category if it still exists
    final initial = widget.initialSelectedCategory;
    if (initial != null) {
      final index = _findCategoryIndex(initial);
      newIndex = index >= 0 ? index : 0;
    } else {
      // Check if current selected index is still valid
      if (selectedIndex >= widget.categories.length) {
        newIndex = 0;
      }
    }

    // Update state and notify if index changed
    if (newIndex != selectedIndex && newIndex < widget.categories.length) {
      setState(() {
        selectedIndex = newIndex;
      });
      _notifySelectionChange(newIndex);
    } else if (newIndex < widget.categories.length) {
      // Index is valid, just notify parent
      _notifySelectionChange(newIndex);
    }
  }

  /// Handle initial selection change
  void _handleInitialSelectionChange() {
    final initial = widget.initialSelectedCategory;
    if (initial == null) return;

    final index = _findCategoryIndex(initial);
    if (index >= 0 && index != selectedIndex && index < widget.categories.length) {
      setState(() {
        selectedIndex = index;
      });
      _notifySelectionChange(selectedIndex);
    }
  }

  /// Find the index of a category by ID
  int _findCategoryIndex(T category) {
    final categoryId = widget.getId(category);
    return widget.categories.indexWhere((cat) => widget.getId(cat) == categoryId);
  }

  /// Notify parent of selection change
  void _notifySelectionChange(int index) {
    if (!widget.autoNotify) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && index < widget.categories.length) {
        widget.onCategorySelected(widget.categories[index]);
      }
    });
  }

  /// Check if two category lists are equal (by ID)
  bool _categoriesEqual(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (widget.getId(list1[i]) != widget.getId(list2[i])) return false;
    }
    return true;
  }

  /// Handle category tap
  void _onCategoryTap(int index) {
    if (index >= 0 && index < widget.categories.length) {
      setState(() {
        selectedIndex = index;
      });
      widget.onCategorySelected(widget.categories[index]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      height: 110.h,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final bool isSelected = selectedIndex == index;

          return GestureDetector(
            onTap: () => _onCategoryTap(index),
            child: Padding(
              padding: EdgeInsets.only(right: index == widget.categories.length - 1 ? 0 : 16.w),
              child: _buildCategoryChip(category, isSelected, colors),
            ),
          );
        },
      ),
    );
  }

  /// Build individual category chip with animations
  Widget _buildCategoryChip(T category, bool isSelected, AppColorsExtension colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: _buildEmoji(category, isSelected, colors),
        ),
        SizedBox(height: 8.h),
        _buildName(category, isSelected, colors),
      ],
    );
  }

  /// Build animated emoji
  Widget _buildEmoji(T category, bool isSelected, AppColorsExtension colors) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      style: TextStyle(fontSize: 28, color: colors.textPrimary),
      child: Text(widget.getEmoji(category)),
    );
  }

  /// Build animated category name
  Widget _buildName(T category, bool isSelected, AppColorsExtension colors) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w500, fontSize: 12.sp),
      child: Text(
        widget.getName(category),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, fontFamily: "Lato", package: 'grab_go_shared'),
      ),
    );
  }
}
