import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/home/model/filter_model.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/view/filter_bottom_sheet.dart';

class HomeSearch extends StatefulWidget {
  final List<FoodCategoryModel> categories;
  final FilterModel? activeFilter;
  final void Function(FilterModel)? onFilterApplied;

  const HomeSearch({super.key, required this.categories, this.activeFilter, this.onFilterApplied});

  @override
  State<HomeSearch> createState() => _HomeSearchState();
}

class _HomeSearchState extends State<HomeSearch> {
  late FilterModel _currentFilter;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.activeFilter?.copyWith() ?? FilterModel();
  }

  @override
  void didUpdateWidget(HomeSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update internal filter state when activeFilter changes from parent
    final newFilter = widget.activeFilter?.copyWith() ?? FilterModel();
    final oldFilter = oldWidget.activeFilter?.copyWith() ?? FilterModel();

    // Check if filter has actually changed by comparing values
    if (newFilter.minPrice != oldFilter.minPrice ||
        newFilter.maxPrice != oldFilter.maxPrice ||
        newFilter.minRating != oldFilter.minRating ||
        newFilter.selectedCategories.length != oldFilter.selectedCategories.length ||
        newFilter.selectedRestaurants.length != oldFilter.selectedRestaurants.length ||
        !_listsEqual(newFilter.selectedCategories, oldFilter.selectedCategories) ||
        !_listsEqual(newFilter.selectedRestaurants, oldFilter.selectedRestaurants)) {
      _currentFilter = newFilter;
    }
  }

  bool _listsEqual(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    final set1 = list1.toSet();
    final set2 = list2.toSet();
    return set1.length == set2.length && set1.containsAll(set2);
  }

  List<String> _getUniqueRestaurants(List<FoodCategoryModel> categories) {
    final restaurants = <String>{};
    for (var category in categories) {
      if (category.items.isNotEmpty) {
        for (var food in category.items) {
          if (food.sellerName.isNotEmpty) {
            restaurants.add(food.sellerName);
          }
        }
      }
    }
    return restaurants.toList()..sort();
  }

  void _showFilterBottomSheet(BuildContext context, List<FoodCategoryModel> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: true,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      builder: (context) => FilterBottomSheet(
        initialFilter: _currentFilter,
        categories: categories,
        restaurants: _getUniqueRestaurants(categories),
        onApply: (FilterModel filter) {
          setState(() {
            _currentFilter = filter.copyWith();
          });
          if (widget.onFilterApplied != null) widget.onFilterApplied!(filter.copyWith());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);
    final isActive = widget.activeFilter?.isActive ?? _currentFilter.isActive;

    return GestureDetector(
      onTap: () => context.push("/search"),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KBorderSize.border),
          color: colors.backgroundPrimary,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(10), spreadRadius: 1, blurRadius: 12, offset: const Offset(0, 4)),
            BoxShadow(color: Colors.black.withAlpha(5), spreadRadius: -1, blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 10.w),
              child: SvgPicture.asset(
                Assets.icons.search,
                package: 'grab_go_shared',
                height: KIconSize.md,
                width: KIconSize.md,
                colorFilter: ColorFilter.mode(colors.textTertiary, BlendMode.srcIn),
              ),
            ),
            SizedBox(width: 5.w),
            Text(
              "Search by name or category...",
              style: TextStyle(color: colors.textTertiary, fontSize: 12.sp, fontWeight: FontWeight.w400),
            ),
            const Spacer(),
            Container(
              width: size.width * 0.24,
              padding: EdgeInsets.all(2.r),
              decoration: BoxDecoration(
                color: colors.accentOrange,
                borderRadius: BorderRadius.circular(KBorderSize.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 10.w),
                    child: Text(
                      "Filter",
                      style: TextStyle(color: colors.backgroundPrimary, fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showFilterBottomSheet(context, widget.categories),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: EdgeInsets.all(7.r),
                          decoration: BoxDecoration(
                            color: colors.backgroundPrimary,
                            borderRadius: BorderRadius.circular(KBorderSize.border),
                          ),
                          child: SvgPicture.asset(
                            Assets.icons.slidersHorizontal,
                            package: 'grab_go_shared',
                            height: KIconSize.sm,
                            width: KIconSize.sm,
                            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                          ),
                        ),
                        if (isActive)
                          Positioned(
                            right: -4.w,
                            top: -4.h,
                            child: Container(
                              width: 10.w,
                              height: 10.h,
                              decoration: BoxDecoration(
                                color: colors.accentOrange,
                                shape: BoxShape.circle,
                                border: Border.all(color: colors.backgroundPrimary, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
