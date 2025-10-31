import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class FoodCategoryList extends StatefulWidget {
  final List<FoodCategoryModel> categories;
  final ValueChanged<FoodCategoryModel> onCategorySelected;

  const FoodCategoryList({
    super.key,
    required this.categories,
    required this.onCategorySelected,
  });

  @override
  State<FoodCategoryList> createState() => _FoodCategoryListState();
}

class _FoodCategoryListState extends State<FoodCategoryList> {
  int selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.categories.isNotEmpty) {
        widget.onCategorySelected(widget.categories[selectedIndex]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);

    return SizedBox(
      height: 95.h,
      child: ListView.builder(
        padding: EdgeInsets.only(left: 10.w),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final bool isSelected = selectedIndex == index;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedIndex = index;
              });
              widget.onCategorySelected(category);
            },
            child: Padding(
              padding: EdgeInsets.only(right: 20.w),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: size.width * 0.22,
                decoration: BoxDecoration(
                  color: isSelected ? colors.accentOrange : colors.backgroundPrimary,
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
                      style: TextStyle(
                        fontSize: 30,
                        color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                      ),
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
                      child: Text(
                        category.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w400,
                          fontFamily: "Lato"
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



