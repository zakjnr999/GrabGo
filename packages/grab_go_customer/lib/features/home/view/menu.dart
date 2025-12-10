// ignore_for_file:

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/widgets/food_item_skeleton.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:shimmer/shimmer.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> with TickerProviderStateMixin {
  FoodCategoryModel? _selectedCategory;
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  late TextEditingController _searchController;
  late AnimationController _animationController;
  late AnimationController _filterAnimationController;
  late AnimationController _fabAnimationController;
  late AnimationController _badgePulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _filterSlideAnimation;
  late Animation<Offset> _fabSlideAnimation;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _badgePulseAnimation;
  late ScrollController _scrollController;
  bool _isFabVisible = true;
  double _lastScrollOffset = 0.0;
  int _previousCartCount = 0;

  String _selectedPriceFilter = 'all';
  bool _showFilterChips = false;
  int _itemsToShow = 10;
  final int _itemsPerPage = 10;
  bool _isLoadingMore = false;
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
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _animationController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _filterAnimationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);

    // Initialize FAB animations
    _fabAnimationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    _filterSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _filterAnimationController, curve: Curves.easeInOut));

    _fabSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut));

    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut));

    // Initialize badge pulse animation
    _badgePulseController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);

    _badgePulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_badgePulseController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FoodProvider>(context, listen: false);
      if (provider.categories.isEmpty) {
        provider.fetchCategories().then((_) {
          if (mounted && provider.categories.isNotEmpty) {
            setState(() {
              _selectedCategory = provider.categories.first;
              _selectedCategoryIndex = 0;
            });
          }
        });
      } else if (provider.categories.isNotEmpty) {
        if (mounted) {
          setState(() {
            _selectedCategory = provider.categories.first;
            _selectedCategoryIndex = 0;
          });
        }
      }
      _animationController.forward();
      _fabAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    _filterAnimationController.dispose();
    _fabAnimationController.dispose();
    _badgePulseController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
    final scrollDelta = currentOffset - _lastScrollOffset;

    // Load more when scrolled to 90% of the content
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore) {
        _loadMoreItems();
      }
    }

    // Always show FAB at top of page
    if (currentOffset <= 0) {
      if (!_isFabVisible) {
        setState(() {
          _isFabVisible = true;
        });
        _fabAnimationController.forward();
      }
      _lastScrollOffset = currentOffset;
      return;
    }

    // Increased threshold from 5px to 12px for smoother transitions
    if (scrollDelta.abs() > 12 && currentOffset > 50) {
      if (scrollDelta > 0) {
        // Scrolling down - hide FAB
        if (_isFabVisible) {
          setState(() {
            _isFabVisible = false;
          });
          _fabAnimationController.reverse();
        }
      } else {
        // Scrolling up - show FAB
        if (!_isFabVisible) {
          setState(() {
            _isFabVisible = true;
          });
          _fabAnimationController.forward();
        }
      }
    }

    _lastScrollOffset = currentOffset;
  }

  void _loadMoreItems() {
    setState(() {
      _isLoadingMore = true;
    });

    // Simulate loading delay for smooth UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _itemsToShow += _itemsPerPage;
          _isLoadingMore = false;
        });
      }
    });
  }

  void _onCategorySelected(int index, List<FoodCategoryModel> categories) {
    if (index < categories.length) {
      setState(() {
        _selectedCategoryIndex = index;
        _selectedCategory = categories[index];
        _itemsToShow = _itemsPerPage; // Reset items to show when category changes
      });

      if (_selectedCategory != null && _selectedCategory!.items.isEmpty) {
        final provider = Provider.of<FoodProvider>(context, listen: false);
        provider.fetchFoodsForCategory(_selectedCategory!.id).then((_) {
          if (mounted) {
            final updatedCategories = provider.categories;
            if (index < updatedCategories.length && updatedCategories[index].id == _selectedCategory!.id) {
              setState(() {
                _selectedCategory = updatedCategories[index];
              });
            }
          }
        });
      }
    }
  }

  List<FoodItem> _getFilteredItems() {
    if (_selectedCategory == null) return [];

    final provider = Provider.of<FoodProvider>(context, listen: false);
    final currentCategory = provider.categories.firstWhere(
      (cat) => cat.id == _selectedCategory!.id,
      orElse: () => _selectedCategory!,
    );

    final Set<String> seenItems = {};
    List<FoodItem> items = currentCategory.items.where((item) {
      final key = '${item.name}_${item.sellerId}';
      if (seenItems.contains(key)) {
        return false;
      }
      seenItems.add(key);
      return true;
    }).toList();

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

    final provider = Provider.of<FoodProvider>(context, listen: false);
    final currentCategory = provider.categories.firstWhere(
      (cat) => cat.id == _selectedCategory!.id,
      orElse: () => _selectedCategory!,
    );

    final Set<String> seenItems = {};
    List<FoodItem> items = currentCategory.items.where((item) {
      final key = '${item.name}_${item.sellerId}';
      if (seenItems.contains(key)) {
        return false;
      }
      seenItems.add(key);
      return true;
    }).toList();

    items.sort((a, b) => b.rating.compareTo(a.rating));
    return items.take(3).toList();
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
    final colors = context.appColors;

    return Stack(
      children: [
        FoodItemCard(
          item: item,
          onTap: () => context.push("/foodDetails", extra: item),
          trailing: Consumer<FavoritesProvider>(
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
                    color: isFavorite ? colors.error.withValues(alpha: 0.1) : colors.backgroundSecondary,
                    border: Border.all(color: isFavorite ? colors.error : colors.inputBorder, width: 1),
                  ),
                  child: SvgPicture.asset(
                    isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                    package: 'grab_go_shared',
                    height: 16.h,
                    width: 16.w,
                    colorFilter: ColorFilter.mode(isFavorite ? colors.error : colors.textPrimary, BlendMode.srcIn),
                  ),
                ),
              );
            },
          ),
        ),
        if (isPopular)
          Positioned(
            top: 8.h,
            right: 24.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.error, colors.accentOrange.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [
                  BoxShadow(color: colors.error.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    Assets.icons.fireFlame,
                    package: "grab_go_shared",
                    height: 16.h,
                    width: 16.w,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
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
    final size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
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
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
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

                      provider.categories.isNotEmpty
                          ? AnimatedTabBar(
                              tabs: provider.categories.map((category) => category.name).toList(),
                              selectedIndex: _selectedCategoryIndex,
                              onTabChanged: (index) => _onCategorySelected(index, provider.categories),
                              padding: EdgeInsets.symmetric(horizontal: 12.w),
                            )
                          : Shimmer.fromColors(
                              baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                              highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
                              child: Container(
                                height: 50.h,
                                margin: EdgeInsets.symmetric(horizontal: 20.w),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                ),
                              ),
                            ),

                      SizedBox(height: 20.h),

                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Text(
                          _selectedCategory?.description ?? "Menu Items",
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
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
                                      color: colors.textSecondary,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
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
                                          _itemsToShow = _itemsPerPage;
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
                            FoodItemSkeleton(colors: colors, isDark: isDark, size: size);
                          }

                          final displayedItems = filteredItems.take(_itemsToShow).toList();
                          final hasMoreItems = filteredItems.length > _itemsToShow;

                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Column(
                              children: [
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: displayedItems.length + (hasMoreItems && _isLoadingMore ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index >= displayedItems.length) {
                                      LoadingMore(
                                        colors: colors,
                                        spinnerColor: colors.accentOrange,
                                        borderColor: colors.accentOrange,
                                      );
                                    }
                                    return _buildFoodItemCard(displayedItems[index], colors, isDark);
                                  },
                                ),
                              ],
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

      floatingActionButton: Provider.of<CartProvider>(context, listen: true).cartItems.isNotEmpty
          ? SlideTransition(
              position: _fabSlideAnimation,
              child: ScaleTransition(
                scale: _fabScaleAnimation,
                child: Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    final currentCount = cartProvider.cartItems.length;

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;

                      // Trigger pulse animation when cart count changes
                      if (currentCount != _previousCartCount && _previousCartCount > 0) {
                        _badgePulseController.forward(from: 0);
                      }

                      // Auto-show FAB when items are added to cart
                      // Also handle first item (when _previousCartCount == 0)
                      if (currentCount > _previousCartCount) {
                        if (!_isFabVisible || _previousCartCount == 0) {
                          setState(() {
                            _isFabVisible = true;
                          });
                          _fabAnimationController.forward();
                        }
                      }

                      _previousCartCount = currentCount;
                    });

                    return ScaleTransition(
                      scale: _badgePulseAnimation,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(KBorderSize.border),
                          boxShadow: [
                            BoxShadow(
                              color: colors.accentOrange.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: FloatingActionButton.extended(
                          onPressed: () => context.push("/cart"),
                          extendedPadding: EdgeInsets.all(10.r),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.border)),
                          backgroundColor: colors.accentOrange,
                          elevation: 0,
                          label: Text(
                            "${cartProvider.cartItems.length} ${cartProvider.cartItems.length > 1 ? "items in cart" : "item in cart"}",
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.backgroundPrimary,
                            ),
                          ),
                          icon: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
                            child: SvgPicture.asset(
                              Assets.icons.cart,
                              height: 20.h,
                              width: 20.w,
                              package: 'grab_go_shared',
                              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          : const SizedBox.shrink(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
