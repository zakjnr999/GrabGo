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
  final bool isFood; // True for Food service, false for Groceries

  const FilterBottomSheet({
    super.key,
    required this.initialFilter,
    required this.categories,
    required this.restaurants,
    required this.onApply,
    this.isFood = true, // Default to Food service
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
                        _buildSectionHeader('Quick Filters', colors),
                        _buildQuickFilters(colors),

                        SizedBox(height: 20.h),

                        _buildSectionHeader('Price Range', colors),
                        _buildPriceFilter(colors, size),

                        SizedBox(height: 20.h),

                        _buildSectionHeader('Minimum Rating', colors),
                        _buildRatingFilter(colors),

                        SizedBox(height: 20.h),

                        _buildSectionHeader('Delivery Time', colors),
                        _buildDeliveryTimeFilter(colors),

                        SizedBox(height: 20.h),

                        if (widget.isFood) ...[
                          _buildSectionHeader('Dietary Preferences', colors),
                          _buildDietaryFilter(colors),
                          SizedBox(height: 20.h),
                        ],

                        _buildSectionHeader('Distance', colors),
                        _buildDistanceFilter(colors),

                        SizedBox(height: 20.h),

                        _buildSectionHeader('Categories', colors),
                        _buildCategoriesFilter(colors, size),

                        SizedBox(height: 20.h),

                        _buildSectionHeader(widget.isFood ? 'Restaurants' : "Grocery Stores", colors),
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
                        child: AppButton(
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

                          backgroundColor: colors.backgroundSecondary,
                          borderRadius: KBorderSize.borderRadius15,
                          buttonText: "Clear All",
                          textStyle: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.sp),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: AppButton(
                          onPressed: () {
                            _animationController.reverse().then((_) {
                              if (mounted) {
                                widget.onApply(_filter.copyWith());
                                Navigator.pop(context);
                              }
                            });
                          },

                          backgroundColor: colors.accentOrange,
                          borderRadius: KBorderSize.borderRadius15,
                          buttonText: "Apply Filter",
                          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
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

  Widget _buildQuickFilters(AppColorsExtension colors) {
    final quickFilters = [
      {'key': 'onSale', 'label': 'On Sale', 'value': _filter.onSale},
      {'key': 'popular', 'label': 'Popular', 'value': _filter.popular},
      {'key': 'isNew', 'label': 'New', 'value': _filter.isNew},
      {'key': 'fast', 'label': 'Fast Delivery', 'value': _filter.fast},
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: quickFilters.map((filter) {
          final isSelected = filter['value'] as bool;
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 56.w) / 2, // 2 columns with spacing
            child: GestureDetector(
              onTap: () {
                setState(() {
                  switch (filter['key']) {
                    case 'onSale':
                      _filter.onSale = !_filter.onSale;
                      break;
                    case 'popular':
                      _filter.popular = !_filter.popular;
                      break;
                    case 'isNew':
                      _filter.isNew = !_filter.isNew;
                      break;
                    case 'fast':
                      _filter.fast = !_filter.fast;
                      break;
                  }
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? colors.accentOrange : Colors.transparent,
                  border: Border.all(color: isSelected ? colors.accentOrange : colors.inputBorder, width: 1.5),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? colors.backgroundPrimary : colors.inputBorder, width: 2),
                        color: isSelected ? colors.backgroundPrimary : Colors.transparent,
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 8.w,
                                height: 8.h,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      filter['label'] as String,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDeliveryTimeFilter(AppColorsExtension colors) {
    final deliveryTimes = ['Under 20 min', '20-30 min', '30-45 min', 'Any Time'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: deliveryTimes.map((time) {
          final isSelected = _filter.deliveryTime == time;
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 56.w) / 2, // 2 columns
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _filter.deliveryTime = isSelected ? null : time;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? colors.accentOrange : Colors.transparent,
                  border: Border.all(color: isSelected ? colors.accentOrange : colors.inputBorder, width: 1.5),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? colors.backgroundPrimary : colors.inputBorder, width: 2),
                        color: isSelected ? colors.backgroundPrimary : Colors.transparent,
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 8.w,
                                height: 8.h,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDietaryFilter(AppColorsExtension colors) {
    final dietaryOptions = ['Vegetarian', 'Vegan', 'Halal', 'Gluten-Free'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: dietaryOptions.map((option) {
          final isSelected = _filter.dietary == option;
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 56.w) / 2, // 2 columns
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _filter.dietary = isSelected ? null : option;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? colors.accentOrange : Colors.transparent,
                  border: Border.all(color: isSelected ? colors.accentOrange : colors.inputBorder, width: 1.5),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? colors.backgroundPrimary : colors.inputBorder, width: 2),
                        color: isSelected ? colors.backgroundPrimary : Colors.transparent,
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 8.w,
                                height: 8.h,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      option,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDistanceFilter(AppColorsExtension colors) {
    final distances = ['Under 1 km', '1-3 km', '3-5 km', 'Any Distance'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: distances.map((distance) {
          final isSelected = _filter.distance == distance;
          return SizedBox(
            width: (MediaQuery.of(context).size.width - 56.w) / 2, // 2 columns
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _filter.distance = isSelected ? null : distance;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? colors.accentOrange : Colors.transparent,
                  border: Border.all(color: isSelected ? colors.accentOrange : colors.inputBorder, width: 1.5),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? colors.backgroundPrimary : colors.inputBorder, width: 2),
                        color: isSelected ? colors.backgroundPrimary : Colors.transparent,
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 8.w,
                                height: 8.h,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      distance,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
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
                  border: Border.all(
                    color: currentPriceFilter == filter['key'] ? colors.accentOrange : colors.inputBorder,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentPriceFilter == filter['key'] ? colors.backgroundPrimary : Colors.transparent,
                        border: Border.all(
                          color: currentPriceFilter == filter['key'] ? colors.backgroundPrimary : colors.inputBorder,
                          width: 2,
                        ),
                      ),
                      child: currentPriceFilter == filter["key"]
                          ? Center(
                              child: Container(
                                width: 8.w,
                                height: 8.h,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      filter['label'],
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: currentPriceFilter == filter['key'] ? colors.backgroundPrimary : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRatingFilter(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
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
                  border: Border.all(
                    color: _filter.minRating == rating ? colors.accentOrange : colors.inputBorder,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _filter.minRating == rating ? colors.backgroundPrimary : Colors.transparent,
                        border: Border.all(
                          color: _filter.minRating == rating ? colors.backgroundPrimary : colors.inputBorder,
                          width: 2,
                        ),
                      ),
                      child: _filter.minRating == rating
                          ? Center(
                              child: Container(
                                width: 8.w,
                                height: 8.h,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 4.w),
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Wrap(
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
                  color: _filter.selectedCategories.contains(category.id) ? colors.accentOrange : Colors.transparent,
                  border: Border.all(
                    color: _filter.selectedCategories.contains(category.id) ? colors.accentOrange : colors.inputBorder,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16.w,
                      height: 16.h,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _filter.selectedCategories.contains(category.id)
                            ? colors.backgroundPrimary
                            : Colors.transparent,
                        border: Border.all(
                          color: _filter.selectedCategories.contains(category.id)
                              ? colors.backgroundPrimary
                              : colors.inputBorder,
                          width: 2,
                        ),
                      ),
                      child: _filter.selectedCategories.contains(category.id)
                          ? Center(
                              child: Container(
                                width: 8.w,
                                height: 8.h,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                              ),
                            )
                          : null,
                    ),
                    SizedBox(width: 8.w),
                    Text(category.emoji, style: TextStyle(fontSize: 12.sp)),
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
      ),
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
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _filter.selectedRestaurants.contains(restaurant)
                          ? [colors.accentOrange, colors.accentOrange]
                          : [colors.backgroundPrimary, colors.backgroundPrimary],
                    ),
                    border: Border.all(
                      color: _filter.selectedRestaurants.contains(restaurant)
                          ? colors.accentOrange
                          : colors.inputBorder,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 16.w,
                        height: 16.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _filter.selectedRestaurants.contains(restaurant)
                                ? colors.backgroundPrimary
                                : colors.inputBorder,
                            width: 2,
                          ),
                          color: _filter.selectedRestaurants.contains(restaurant)
                              ? colors.backgroundPrimary
                              : Colors.transparent,
                        ),
                        child: _filter.selectedRestaurants.contains(restaurant)
                            ? Center(
                                child: Container(
                                  width: 8.w,
                                  height: 8.h,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                                ),
                              )
                            : null,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        restaurant,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: _filter.selectedRestaurants.contains(restaurant)
                              ? colors.backgroundPrimary
                              : colors.textPrimary,
                        ),
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
