import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class FoodCategoryList extends StatefulWidget {
  final List<FoodCategoryModel> categories;
  final ValueChanged<FoodCategoryModel> onCategorySelected;
  final FoodCategoryModel? initialSelectedCategory;

  const FoodCategoryList({
    super.key,
    required this.categories,
    required this.onCategorySelected,
    this.initialSelectedCategory,
  });

  @override
  State<FoodCategoryList> createState() => _FoodCategoryListState();
}

class _FoodCategoryListState extends State<FoodCategoryList> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Try to find the initial selected category in the list
    if (widget.initialSelectedCategory != null) {
      final index = widget.categories.indexWhere((cat) => cat.id == widget.initialSelectedCategory!.id);
      selectedIndex = index >= 0 ? index : 0;
    } else {
      selectedIndex = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.categories.isNotEmpty && selectedIndex < widget.categories.length) {
        widget.onCategorySelected(widget.categories[selectedIndex]);
      }
    });
  }

  @override
  void didUpdateWidget(FoodCategoryList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Guard against empty categories
    if (widget.categories.isEmpty) {
      return;
    }

    // Update selected index when categories list changes
    if (widget.categories.length != oldWidget.categories.length ||
        !_categoriesEqual(widget.categories, oldWidget.categories)) {
      int newIndex = selectedIndex;

      // Try to preserve the selected category if it still exists in the new list
      if (widget.initialSelectedCategory != null) {
        final index = widget.categories.indexWhere((cat) => cat.id == widget.initialSelectedCategory!.id);
        if (index >= 0) {
          newIndex = index;
        } else {
          // Selected category not in new list, reset to first
          newIndex = 0;
        }
      } else {
        // Check if current selected index is still valid
        if (selectedIndex >= widget.categories.length) {
          newIndex = 0;
        }
      }

      // Update state and notify parent only if index changed
      if (newIndex != selectedIndex && newIndex < widget.categories.length) {
        setState(() {
          selectedIndex = newIndex;
        });
        // Use post frame callback to ensure widget is still mounted
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && selectedIndex < widget.categories.length) {
            widget.onCategorySelected(widget.categories[selectedIndex]);
          }
        });
      } else if (newIndex < widget.categories.length) {
        // Index is valid, just notify parent
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && newIndex < widget.categories.length) {
            widget.onCategorySelected(widget.categories[newIndex]);
          }
        });
      }
    } else if (widget.initialSelectedCategory != null &&
        widget.initialSelectedCategory!.id != oldWidget.initialSelectedCategory?.id) {
      // Initial selected category changed, update selection
      final index = widget.categories.indexWhere((cat) => cat.id == widget.initialSelectedCategory!.id);
      if (index >= 0 && index != selectedIndex && index < widget.categories.length) {
        setState(() {
          selectedIndex = index;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && selectedIndex < widget.categories.length) {
            widget.onCategorySelected(widget.categories[selectedIndex]);
          }
        });
      }
    }
  }

  bool _categoriesEqual(List<FoodCategoryModel> list1, List<FoodCategoryModel> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i].id != list2[i].id) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);

    return SizedBox(
      height: 95.h,
      child: ListView.builder(
        padding: EdgeInsets.only(left: 20.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final bool isSelected = selectedIndex == index;

          return GestureDetector(
            onTap: () {
              if (index >= 0 && index < widget.categories.length) {
                setState(() {
                  selectedIndex = index;
                });
                widget.onCategorySelected(category);
              }
            },
            child: Padding(
              padding: EdgeInsets.only(right: 20.w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: size.width * 0.22,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)]
                        : [colors.backgroundPrimary, colors.backgroundPrimary.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      spreadRadius: 1,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(5),
                      spreadRadius: -1,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      style: TextStyle(fontSize: 30, color: isSelected ? colors.backgroundPrimary : colors.textPrimary),
                      child: Text(category.emoji),
                    ),
                    SizedBox(height: KSpacing.md.h),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      style: TextStyle(
                        color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5.w),
                        child: Text(
                          category.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            fontFamily: "Lato",
                            package: 'grab_go_shared',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
