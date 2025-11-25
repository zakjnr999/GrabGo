import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/model/filter_model.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class FilterBottomSheet extends StatefulWidget {
  final FilterModel initialFilter;
  final List<FoodCategoryModel> categories;
  final List<String> restaurants;
  final Function(FilterModel) onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialFilter,
    required this.categories,
    required this.restaurants,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> with SingleTickerProviderStateMixin {
  late FilterModel _filter;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter.copyWith();
    _cleanupStaleFilterData();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _cleanupStaleFilterData() {
    final validCategoryIds = widget.categories.map((cat) => cat.id).where((id) => id.isNotEmpty).toSet();
    _filter.selectedCategories.removeWhere((id) => !validCategoryIds.contains(id));

    final validRestaurants = widget.restaurants.where((r) => r.isNotEmpty).toSet();
    _filter.selectedRestaurants.removeWhere((restaurant) => !validRestaurants.contains(restaurant));
  }

  void _handleDismiss() {
    _animationController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.9),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Your Search',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      GestureDetector(
                        onTap: _handleDismiss,
                        child: Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: colors.inputBorder,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(Icons.close, size: 16.r, color: colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(color: colors.inputBorder, height: 1),

                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSectionHeader('Price Range', colors),
                        _buildPriceFilter(colors, size),

                        SizedBox(height: 20.h),

                        _buildSectionHeader('Minimum Rating', colors),
                        _buildRatingFilter(colors),

                        SizedBox(height: 20.h),

                        _buildSectionHeader('Categories', colors),
                        _buildCategoriesFilter(colors, size),

                        SizedBox(height: 20.h),

                        _buildSectionHeader('Restaurants', colors),
                        _buildRestaurantsFilter(colors, size),

                        SizedBox(height: 20.h),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.all(16.r),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 56.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: colors.inputBorder, width: 1.5),
                            gradient: LinearGradient(
                              colors: [
                                colors.backgroundSecondary.withValues(alpha: 0.08),
                                colors.backgroundSecondary.withValues(alpha: 0.03),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _filter.reset();
                              });
                              _animationController.reverse().then((_) {
                                if (mounted) {
                                  widget.onApply(_filter.copyWith());
                                  Navigator.pop(context);
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.backgroundSecondary,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                            ),
                            child: Text(
                              "Clear All",
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Container(
                          height: 56.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16.r),
                            gradient: LinearGradient(
                              colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.accentOrange.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              _animationController.reverse().then((_) {
                                if (mounted) {
                                  widget.onApply(_filter.copyWith());
                                  Navigator.pop(context);
                                }
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                            ),
                            child: Text(
                              "Apply Filter",
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildPriceFilter(AppColorsExtension colors, Size size) {
    final List<Map<String, dynamic>> priceFilters = [
      {'key': 'all', 'label': 'All', 'min': 0, 'max': 10000},
      {'key': 'under_20', 'label': 'Under GHS 20', 'min': 0, 'max': 20},
      {'key': '20_50', 'label': 'GHS 20-50', 'min': 20, 'max': 50},
      {'key': '50_100', 'label': 'GHS 50-100', 'min': 50, 'max': 100},
      {'key': 'over_100', 'label': 'Over GHS 100', 'min': 100, 'max': 10000},
    ];

    String currentPriceFilter = 'all';
    for (var filter in priceFilters) {
      final filterMin = (filter['min'] as num).toDouble();
      final filterMax = (filter['max'] as num).toDouble();
      if ((_filter.minPrice - filterMin).abs() < 0.01 && (_filter.maxPrice - filterMax).abs() < 0.01) {
        currentPriceFilter = filter['key'];
        break;
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: SingleChildScrollView(
        scrollDirection: .horizontal,
        child: Row(
          spacing: 8.w,
          mainAxisAlignment: .spaceBetween,
          children: [
            for (var filter in priceFilters)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _filter.minPrice = (filter['min'] as num).toDouble();
                    _filter.maxPrice = (filter['max'] as num).toDouble();
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: currentPriceFilter == filter['key'] ? colors.accentOrange : Colors.transparent,
                    gradient: LinearGradient(
                      colors: currentPriceFilter == filter['key']
                          ? [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)]
                          : [colors.backgroundPrimary, colors.backgroundPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: currentPriceFilter == filter['key'] ? colors.accentOrange : colors.inputBorder,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    filter['label'],
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: currentPriceFilter == filter['key'] ? colors.backgroundPrimary : colors.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingFilter(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: SingleChildScrollView(
        scrollDirection: .horizontal,
        child: Row(
          spacing: 8.w,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (double rating in [2.0, 3.0, 4.0, 4.5, 5.0])
              GestureDetector(
                onTap: () {
                  setState(() {
                    _filter.minRating = (_filter.minRating == rating) ? null : rating;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: _filter.minRating == rating ? colors.accentOrange : Colors.transparent,
                    gradient: LinearGradient(
                      colors: _filter.minRating == rating
                          ? [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)]
                          : [colors.backgroundPrimary, colors.backgroundPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: _filter.minRating == rating ? colors.accentOrange : colors.inputBorder,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: _filter.minRating == rating ? colors.backgroundPrimary : colors.textPrimary,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      SvgPicture.asset(
                        Assets.icons.star,
                        package: 'grab_go_shared',
                        height: 14.h,
                        width: 14.w,
                        colorFilter: ColorFilter.mode(
                          _filter.minRating == rating ? colors.backgroundPrimary : colors.textPrimary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesFilter(AppColorsExtension colors, Size size) {
    if (widget.categories.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Text(
          "No categories available",
          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
        ),
      );
    }

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: [
        for (var category in widget.categories)
          GestureDetector(
            onTap: () {
              if (category.id.isEmpty) return;
              setState(() {
                if (_filter.selectedCategories.contains(category.id)) {
                  _filter.selectedCategories.remove(category.id);
                } else {
                  _filter.selectedCategories.add(category.id);
                }
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _filter.selectedCategories.contains(category.id)
                      ? [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)]
                      : [colors.backgroundPrimary, colors.backgroundPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                color: _filter.selectedCategories.contains(category.id) ? colors.accentOrange : Colors.transparent,
                border: Border.all(
                  color: _filter.selectedCategories.contains(category.id) ? colors.accentOrange : colors.inputBorder,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.emoji, style: TextStyle(fontSize: 16.sp)),
                  SizedBox(width: 6.w),
                  Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: _filter.selectedCategories.contains(category.id)
                          ? colors.backgroundPrimary
                          : colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRestaurantsFilter(AppColorsExtension colors, Size size) {
    if (widget.restaurants.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Text(
          "No restaurants available",
          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        children: [
          for (var restaurant in widget.restaurants)
            Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (_filter.selectedRestaurants.contains(restaurant)) {
                      _filter.selectedRestaurants.remove(restaurant);
                    } else {
                      _filter.selectedRestaurants.add(restaurant);
                    }
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: _filter.selectedRestaurants.contains(restaurant)
                        ? colors.accentOrange.withAlpha(25)
                        : Colors.transparent,
                    border: Border.all(
                      color: _filter.selectedRestaurants.contains(restaurant)
                          ? colors.accentOrange.withValues(alpha: 0.4)
                          : colors.inputBorder,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20.w,
                        height: 20.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _filter.selectedRestaurants.contains(restaurant)
                                ? colors.accentOrange
                                : colors.inputBorder,
                            width: 2,
                          ),
                        ),
                        child: _filter.selectedRestaurants.contains(restaurant)
                            ? Center(
                                child: Container(
                                  width: 10.w,
                                  height: 10.h,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        restaurant,
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
