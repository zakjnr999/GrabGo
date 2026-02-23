import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class ServiceCategoryList<T> extends StatefulWidget {
  final List<T> categories;

  final String Function(T) getName;

  final String Function(T) getEmoji;

  final String Function(T) getId;

  final ValueChanged<T> onCategorySelected;

  final T? initialSelectedCategory;

  final bool autoNotify;

  final Color? accentColor;

  const ServiceCategoryList({
    super.key,
    required this.categories,
    required this.getName,
    required this.getEmoji,
    required this.getId,
    required this.onCategorySelected,
    this.initialSelectedCategory,
    this.autoNotify = true,
    this.accentColor,
  });

  @override
  State<ServiceCategoryList<T>> createState() => _ServiceCategoryListState<T>();
}

class _ServiceCategoryListState<T> extends State<ServiceCategoryList<T>> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeSelection();
    if (widget.autoNotify) {
      _notifyInitialSelection();
    }
  }

  void _initializeSelection() {
    final initial = widget.initialSelectedCategory;
    if (initial != null) {
      final index = _findCategoryIndex(initial);
      selectedIndex = index >= 0 ? index : 0;
    } else {
      selectedIndex = 0;
    }
  }

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

    if (widget.categories.isEmpty) {
      return;
    }

    if (_categoriesChanged(oldWidget.categories)) {
      _handleCategoryListChange(oldWidget);
    } else if (_initialSelectionChanged(oldWidget)) {
      _handleInitialSelectionChange();
    }
  }

  bool _categoriesChanged(List<T> oldCategories) {
    if (widget.categories.length != oldCategories.length) return true;
    return !_categoriesEqual(widget.categories, oldCategories);
  }

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

  void _handleCategoryListChange(ServiceCategoryList<T> oldWidget) {
    int newIndex = selectedIndex;

    final initial = widget.initialSelectedCategory;
    if (initial != null) {
      final index = _findCategoryIndex(initial);
      newIndex = index >= 0 ? index : 0;
    } else {
      if (selectedIndex >= widget.categories.length) {
        newIndex = 0;
      }
    }

    if (newIndex != selectedIndex && newIndex < widget.categories.length) {
      setState(() {
        selectedIndex = newIndex;
      });
      _notifySelectionChange(newIndex);
    } else if (newIndex < widget.categories.length) {
      _notifySelectionChange(newIndex);
    }
  }

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

  int _findCategoryIndex(T category) {
    final categoryId = widget.getId(category);
    return widget.categories.indexWhere((cat) => widget.getId(cat) == categoryId);
  }

  void _notifySelectionChange(int index) {
    if (!widget.autoNotify) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && index < widget.categories.length) {
        widget.onCategorySelected(widget.categories[index]);
      }
    });
  }

  bool _categoriesEqual(List<T> list1, List<T> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (widget.getId(list1[i]) != widget.getId(list2[i])) return false;
    }
    return true;
  }

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

  Widget _buildCategoryChip(T category, bool isSelected, AppColorsExtension colors) {
    final chipColor = widget.accentColor ?? colors.accentOrange;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(color: chipColor.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: _buildEmoji(category, isSelected, colors),
        ),
        SizedBox(height: 8.h),
        _buildName(category, isSelected, colors),
      ],
    );
  }

  Widget _buildEmoji(T category, bool isSelected, AppColorsExtension colors) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      style: TextStyle(fontSize: 28, color: colors.textPrimary),
      child: Text(widget.getEmoji(category)),
    );
  }

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
