// ignore_for_file:

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> with TickerProviderStateMixin {
  List<FoodCategoryModel> _categories = [];
  FoodCategoryModel? _selectedCategory;
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  late TextEditingController _searchController;
  late AnimationController _animationController;
  late AnimationController _filterAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _filterSlideAnimation;

  String _selectedPriceFilter = 'all';
  bool _showFilterChips = false;
  final List<Map<String, dynamic>> _priceFilters = [
    {'key': 'all', 'label': 'All', 'min': 0, 'max': 1000},
    {'key': 'under_20', 'label': 'Under GHS 20', 'min': 0, 'max': 20},
    {'key': '20_50', 'label': 'GHS 20-50', 'min': 20, 'max': 50},
    {'key': '50_100', 'label': 'GHS 50-100', 'min': 50, 'max': 100},
    {'key': 'over_100', 'label': 'Over GHS 100', 'min': 100, 'max': 1000},
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _animationController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _filterAnimationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _filterSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _filterAnimationController, curve: Curves.easeInOut));

    Future.microtask(() async {
      final provider = Provider.of<FoodProvider>(context, listen: false);
      await provider.fetchCategories();

      if (provider.categories.isNotEmpty && _selectedCategory == null) {
        setState(() {
          _selectedCategory = provider.categories.first;
          _selectedCategoryIndex = 0;
        });
      }
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  void _onCategorySelected(int index) async {
    if (index < _categories.length) {
      setState(() {
        _selectedCategoryIndex = index;
        _selectedCategory = _categories[index];
      });
    }
  }

  List<FoodItem> _getFilteredItems() {
    if (_selectedCategory == null) return [];

    List<FoodItem> items = _selectedCategory!.items;

    if (_searchQuery.isNotEmpty) {
      items = items.where((item) {
        return item.name.toLowerCase().contains(_searchQuery) || item.description.toLowerCase().contains(_searchQuery);
      }).toList();
    }

    if (_selectedPriceFilter != 'all') {
      final priceFilter = _priceFilters.firstWhere((filter) => filter['key'] == _selectedPriceFilter);
      items = items.where((item) {
        return item.price >= priceFilter['min'] && item.price <= priceFilter['max'];
      }).toList();
    }

    return items;
  }

  List<FoodItem> _getPopularItems() {
    if (_selectedCategory == null) return [];

    List<FoodItem> items = _selectedCategory!.items;

    items.sort((a, b) => b.rating.compareTo(a.rating));
    return items.take(3).toList();
  }

  Future<void> _onRefresh() async {
    final provider = Provider.of<FoodProvider>(context, listen: false);
    await provider.refreshCategories();

    if (provider.categories.isNotEmpty && _selectedCategory == null) {
      setState(() {
        _selectedCategory = provider.categories.first;
        _selectedCategoryIndex = 0;
      });
    }
  }

  Widget _buildPriceFilterBar(AppColorsExtension colors) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _priceFilters.map((filter) {
            final isSelected = _selectedPriceFilter == filter['key'];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPriceFilter = filter['key'];
                });
              },
              child: Container(
                margin: EdgeInsets.only(right: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: isSelected ? colors.accentOrange : colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  border: Border.all(color: isSelected ? colors.accentOrange : colors.inputBorder, width: 1),
                ),
                child: Text(
                  filter['label'],
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : colors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFoodItemCard(FoodItem item, AppColorsExtension colors, bool isDark) {
    final popularItems = _getPopularItems();
    final isPopular = popularItems.contains(item);

    return GestureDetector(
      onTap: () => context.push("/foodDetails", extra: item),
      child: Container(
        margin: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 12.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          border: Border.all(color: Colors.transparent, width: 0),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
              spreadRadius: 0,
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(KBorderSize.borderRadius15),
                    bottomLeft: Radius.circular(KBorderSize.borderRadius15),
                  ),
                  child: SizedBox(
                    height: 118.h,
                    width: 118.w,
                    child: CachedImageWidget(
                      imageUrl: item.image,
                      width: 118.w,
                      height: 118.h,
                      fit: BoxFit.cover,
                      placeholder: Container(
                        color: colors.inputBorder,
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.icons.utensilsCrossed,
                            package: 'grab_go_shared',
                            colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                            width: 30.w,
                            height: 30.h,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(12.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 6.h),
                            Row(
                              children: [
                                SvgPicture.asset(
                                  Assets.icons.starSolid,
                                  package: 'grab_go_shared',
                                  height: 13.h,
                                  width: 13.w,
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  item.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  width: 3.w,
                                  height: 3.h,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                                ),
                                SizedBox(width: 8.w),
                                SvgPicture.asset(
                                  Assets.icons.timer,
                                  package: 'grab_go_shared',
                                  height: 12.h,
                                  width: 12.w,
                                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  "${item.deliveryTimeMinutes} min",
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: colors.accentOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                "GHS ${item.price.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                  color: colors.accentOrange,
                                ),
                              ),
                            ),
                            Consumer<FavoritesProvider>(
                              builder: (context, favoritesProvider, _) {
                                final bool isFavorite = favoritesProvider.isFavorite(item);

                                return GestureDetector(
                                  onTap: () {
                                    if (isFavorite) {
                                      favoritesProvider.removeFromFavorites(item);
                                    } else {
                                      favoritesProvider.addToFavorites(item);
                                    }
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(8.r),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isFavorite ? Colors.red : colors.backgroundSecondary,
                                      border: Border.all(color: isFavorite ? Colors.red : colors.inputBorder, width: 1),
                                    ),
                                    child: SvgPicture.asset(
                                      isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                                      height: 16.h,
                                      width: 16.w,
                                      colorFilter: ColorFilter.mode(
                                        isFavorite ? Colors.white : colors.textPrimary,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isPopular)
              Positioned(
                top: 8.h,
                right: 8.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.red, Colors.orange],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.white, size: 12.r),
                      SizedBox(width: 4.w),
                      Text(
                        'Popular',
                        style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w700),
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

  Widget _buildMenuSearchBar(AppColorsExtension colors) {
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
              "Search...",
              style: TextStyle(color: colors.textTertiary, fontSize: 12.sp, fontWeight: FontWeight.w400),
            ),
            const Spacer(),
            Container(
              width: MediaQuery.of(context).size.width * 0.24,
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
                    onTap: () {
                      setState(() {
                        _showFilterChips = !_showFilterChips;
                      });
                      if (_showFilterChips) {
                        _filterAnimationController.forward();
                      } else {
                        _filterAnimationController.reverse();
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.all(7.r),
                      decoration: BoxDecoration(
                        color: _showFilterChips ? colors.accentOrange.withValues(alpha: 0.1) : colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(KBorderSize.border),
                        border: _showFilterChips
                            ? Border.all(color: colors.accentOrange.withValues(alpha: 0.3), width: 1)
                            : null,
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.slidersHorizontal,
                        package: 'grab_go_shared',
                        height: KIconSize.sm,
                        width: KIconSize.sm,
                        colorFilter: ColorFilter.mode(
                          _showFilterChips ? colors.accentOrange : colors.textPrimary,
                          BlendMode.srcIn,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      body: SafeArea(
        child: RefreshIndicator(
          color: colors.accentOrange,
          onRefresh: _onRefresh,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.accentOrange.withValues(alpha: 0.3),
                              spreadRadius: 0,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.squareMenu,
                          package: 'grab_go_shared',
                          height: 24.h,
                          width: 24.w,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${_getGreeting()}!",
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              "Browse Our Menu",
                              style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                _buildMenuSearchBar(colors),

                AnimatedBuilder(
                  animation: _filterSlideAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _filterSlideAnimation,
                      child: _showFilterChips ? _buildPriceFilterBar(colors) : const SizedBox.shrink(),
                    );
                  },
                ),

                SizedBox(height: 16.h),

                Consumer<FoodProvider>(
                  builder: (context, provider, _) {
                    _categories = provider.categories;
                    if (_selectedCategory == null && _categories.isNotEmpty) {
                      _selectedCategory = _categories.first;
                      _selectedCategoryIndex = 0;
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Text(
                            "Categories",
                            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                          ),
                        ),
                        SizedBox(height: 12.h),

                        provider.isLoading && _categories.isNotEmpty
                            ? AnimatedTabBar(
                                tabs: _categories.map((category) => category.name).toList(),
                                selectedIndex: _selectedCategoryIndex,
                                onTabChanged: _onCategorySelected,
                                padding: EdgeInsets.symmetric(horizontal: 12.w),
                              )
                            : Container(
                                height: 50.h,
                                margin: EdgeInsets.symmetric(horizontal: 20.w),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: colors.backgroundPrimary,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                ),
                                child: const Center(child: Text("No categories found...")),
                              ),

                        SizedBox(height: 20.h),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: Text(
                            _selectedCategory?.name ?? "Menu Items",
                            style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                          ),
                        ),
                        SizedBox(height: 12.h),

                        Builder(
                          builder: (context) {
                            final filteredItems = _getFilteredItems();

                            if (filteredItems.isEmpty && (_searchQuery.isNotEmpty || _selectedPriceFilter != 'all')) {
                              return Container(
                                width: double.infinity,
                                margin: EdgeInsets.symmetric(horizontal: 20.w),
                                padding: EdgeInsets.all(40.r),
                                decoration: BoxDecoration(
                                  color: colors.backgroundPrimary,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                  border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(20.r),
                                      decoration: BoxDecoration(
                                        color: colors.accentOrange.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: SvgPicture.asset(
                                        Assets.icons.utensilsCrossed,
                                        package: 'grab_go_shared',
                                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                        width: 40.w,
                                        height: 40.h,
                                      ),
                                    ),
                                    SizedBox(height: 20.h),
                                    Text(
                                      "No items found",
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? "Try adjusting your search terms"
                                          : "Try adjusting your price filter",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14.sp, color: colors.textSecondary, height: 1.4),
                                    ),
                                    SizedBox(height: 20.h),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
                                        ),
                                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.accentOrange.withValues(alpha: 0.4),
                                            blurRadius: 15,
                                            spreadRadius: 0,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: AppButton(
                                        onPressed: () {
                                          setState(() {
                                            _searchQuery = '';
                                            _selectedPriceFilter = 'all';
                                            _searchController.clear();
                                          });
                                        },
                                        backgroundColor: Colors.transparent,
                                        borderRadius: KBorderSize.borderRadius15,
                                        buttonText: "Clear Filters",
                                        textStyle: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else if (filteredItems.isEmpty) {
                              return Container(
                                height: MediaQuery.of(context).size.height * 0.5,
                                margin: EdgeInsets.symmetric(horizontal: 20.w),
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: colors.backgroundPrimary,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                ),
                                child: const Center(child: Text("No items found...")),
                              );
                            }

                            return FadeTransition(
                              opacity: _fadeAnimation,
                              child: Column(
                                children: filteredItems.map((item) {
                                  return _buildFoodItemCard(item, colors, isDark);
                                }).toList(),
                              ),
                            );
                          },
                        ),

                        SizedBox(height: 20.h),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good morning";
    } else if (hour < 17) {
      return "Good afternoon";
    } else {
      return "Good evening";
    }
  }
}
