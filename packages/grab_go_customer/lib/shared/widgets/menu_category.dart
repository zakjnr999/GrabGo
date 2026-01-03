import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class MenuCategory extends StatefulWidget {
  final List<FoodCategoryModel>? categories;
  final ValueChanged<FoodCategoryModel> onCategorySelected;
  final bool isLoading;

  const MenuCategory({
    super.key,
    required this.onCategorySelected,
    this.categories,
    this.isLoading = false,
  });

  @override
  State<MenuCategory> createState() => _MenuCategoryState();
}

class _MenuCategoryState extends State<MenuCategory> {
  FoodCategoryModel? selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.categories != null && widget.categories!.isNotEmpty) {
      selectedCategory = widget.categories!.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (widget.isLoading) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Row(
          children: List.generate(
            5,
            (index) => Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Container(
                width: 80.w,
                height: 35.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(KBorderSize.border),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.categories == null || widget.categories!.isEmpty) {
      return const Center(child: Text("No categories available"));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: widget.categories!.map((category) {
          final bool isSelected = selectedCategory?.id == category.id;
          return Padding(
            padding: EdgeInsets.only(right: 10.w),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  selectedCategory = category;
                  widget.onCategorySelected(category);
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isSelected ? colors.accentOrange : colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(KBorderSize.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                    fontSize: 12.sp,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  child: Text(category.name),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}



