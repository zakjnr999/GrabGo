import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/home/model/filter_model.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/features/grabmart/viewmodel/grabmart_provider.dart';
import 'package:grab_go_customer/shared/widgets/browse_grid_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/home_search.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class CategoryItemsPage extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String categoryEmoji;
  final String serviceType; // 'food', 'grocery', 'pharmacy', 'convenience'

  const CategoryItemsPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.serviceType,
  });

  bool get isFood => serviceType == 'food';
  bool get isGrocery => serviceType == 'grocery';
  bool get isPharmacy => serviceType == 'pharmacy';
  bool get isGrabMart => serviceType == 'convenience';

  @override
  State<CategoryItemsPage> createState() => _CategoryItemsPageState();
}

class _CategoryItemsPageState extends State<CategoryItemsPage> with TickerProviderStateMixin {
  final Set<String> _selectedQuickFilters = {};
  String _sortBy = 'Recommended';
  final bool _isGridView = true;
  String? _selectedPriceRange;
  String? _selectedRating;
  String? _selectedDeliveryTime;
  String? _selectedDietary;
  FilterModel _comprehensiveFilter = FilterModel();

  late ScrollController _scrollController;
  late AnimationController _fabAnimationController;
  late AnimationController _badgePulseController;
  late Animation<Offset> _fabSlideAnimation;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _badgePulseAnimation;
  bool _isFabVisible = true;
  double _lastScrollOffset = 0.0;
  int _previousCartCount = 0;

  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  static const double _collapsedHeight = 80.0;
  static const double _scrollThreshold = 100.0;

  final List<Map<String, dynamic>> _quickFilters = [
    {'icon': Assets.icons.dollar, 'label': 'Price', 'hasOptions': true},
    {'icon': Assets.icons.badgePercent, 'label': 'On Sale', 'hasOptions': false},
    {'icon': Assets.icons.star, 'label': 'Rating', 'hasOptions': true},
    {'icon': Assets.icons.flame, 'label': 'Popular', 'hasOptions': false},
    {'icon': Assets.icons.clock, 'label': 'Delivery', 'hasOptions': true},
    {'icon': Assets.icons.utensilsCrossed, 'label': 'Dietary', 'hasOptions': true},
    {'icon': Assets.icons.sparkles, 'label': 'New', 'hasOptions': false},
    {'icon': Assets.icons.deliveryTruck, 'label': 'Fast', 'hasOptions': false},
  ];

  final List<String> _priceRanges = ['Under GH₵20', 'GH₵20 - GH₵50', 'GH₵50 - GH₵100', 'Over GH₵100'];
  final List<String> _ratingOptions = ['4.5+ Stars', '4.0+ Stars', '3.5+ Stars', 'Any Rating'];
  final List<String> _deliveryTimeOptions = ['Under 20 min', '20-30 min', '30-45 min', 'Any Time'];
  final List<String> _dietaryOptions = ['Vegetarian', 'Vegan', 'Halal', 'Gluten-Free'];

  final List<String> _sortOptions = ['Popularity'];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _fabAnimationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);

    _fabSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut));

    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut));

    _badgePulseController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);

    _badgePulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(tween: Tween<double>(begin: 1.3, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_badgePulseController);

    _fabAnimationController.forward();

    // Fetch items for specific service if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isPharmacy) {
        final provider = Provider.of<PharmacyProvider>(context, listen: false);
        if (provider.items.isEmpty) {
          provider.fetchItems();
        }
      } else if (widget.isGrabMart) {
        final provider = Provider.of<GrabMartProvider>(context, listen: false);
        if (provider.items.isEmpty) {
          provider.fetchItems();
        }
      } else if (widget.isFood) {
        final provider = Provider.of<FoodProvider>(context, listen: false);
        if (provider.categories.isEmpty) {
          provider.fetchCategories();
        }
      } else if (widget.isGrocery) {
        final provider = Provider.of<GroceryProvider>(context, listen: false);
        if (provider.items.isEmpty) {
          provider.fetchItems();
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _fabAnimationController.dispose();
    _badgePulseController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;

    _scrollOffsetNotifier.value = currentOffset;

    final scrollDelta = currentOffset - _lastScrollOffset;

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

    if (scrollDelta.abs() > 12 && currentOffset > 50) {
      if (scrollDelta > 0) {
        if (_isFabVisible) {
          setState(() {
            _isFabVisible = false;
          });
          _fabAnimationController.reverse();
        }
      } else {
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundSecondary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        body: SafeArea(
          top: false,
          child: ClipRect(
            child: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: SizedBox(height: size.height * 0.20)),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyHeaderDelegate(
                        minHeight: _calculateStickyHeaderHeight(),
                        maxHeight: _calculateStickyHeaderHeight(),
                        child: Container(
                          color: colors.backgroundSecondary,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.isFood)
                                Consumer<FoodProvider>(
                                  builder: (context, foodProvider, _) {
                                    final categoryList = foodProvider.categories
                                        .where((cat) => cat.id == widget.categoryId)
                                        .toList();
                                    return HomeSearch(
                                      categories: categoryList,
                                      activeFilter: _comprehensiveFilter,
                                      hintText: "Find your food item...",
                                      onFilterApplied: (FilterModel filter) {
                                        setState(() {
                                          _comprehensiveFilter = filter.copyWith();
                                        });
                                      },
                                      isFood: true,
                                    );
                                  },
                                )
                              else if (widget.isGrocery)
                                Consumer<GroceryProvider>(
                                  builder: (context, groceryProvider, _) {
                                    final groceryCategories = groceryProvider.categories
                                        .where((cat) => cat.id == widget.categoryId)
                                        .map(
                                          (cat) => FoodCategoryModel(
                                            id: cat.id,
                                            name: cat.name,
                                            emoji: cat.emoji,
                                            description: cat.description,
                                            isActive: cat.isActive,
                                            items: groceryProvider.items
                                                .where((item) => item.categoryId == cat.id)
                                                .map((item) => item.toFoodItem())
                                                .toList(),
                                          ),
                                        )
                                        .toList();
                                    return HomeSearch(
                                      categories: groceryCategories,
                                      activeFilter: _comprehensiveFilter,
                                      hintText: "Find your grocery item...",
                                      onFilterApplied: (FilterModel filter) {
                                        setState(() {
                                          _comprehensiveFilter = filter.copyWith();
                                        });
                                      },
                                      isFood: false,
                                    );
                                  },
                                )
                              else if (widget.isPharmacy)
                                Consumer<PharmacyProvider>(
                                  builder: (context, pharmacyProvider, _) {
                                    final pharmacyCategories = pharmacyProvider.categories
                                        .where((cat) => cat.id == widget.categoryId)
                                        .map(
                                          (cat) => FoodCategoryModel(
                                            id: cat.id,
                                            name: cat.name,
                                            emoji: cat.emoji,
                                            description: '',
                                            isActive: true,
                                            items: pharmacyProvider.items
                                                .where((item) => item.categoryId == cat.id)
                                                .map((item) => item.toFoodItem())
                                                .toList(),
                                          ),
                                        )
                                        .toList();
                                    return HomeSearch(
                                      categories: pharmacyCategories,
                                      activeFilter: _comprehensiveFilter,
                                      hintText: "Search medications...",
                                      onFilterApplied: (FilterModel filter) {
                                        setState(() {
                                          _comprehensiveFilter = filter.copyWith();
                                        });
                                      },
                                      isFood: false,
                                    );
                                  },
                                )
                              else if (widget.isGrabMart)
                                Consumer<GrabMartProvider>(
                                  builder: (context, grabMartProvider, _) {
                                    final grabMartCategories = grabMartProvider.categories
                                        .where((cat) => cat.id == widget.categoryId)
                                        .map(
                                          (cat) => FoodCategoryModel(
                                            id: cat.id,
                                            name: cat.name,
                                            emoji: cat.emoji,
                                            description: '',
                                            isActive: true,
                                            items: grabMartProvider.items
                                                .where((item) => item.categoryId == cat.id)
                                                .map((item) => item.toFoodItem())
                                                .toList(),
                                          ),
                                        )
                                        .toList();
                                    return HomeSearch(
                                      categories: grabMartCategories,
                                      activeFilter: _comprehensiveFilter,
                                      hintText: "Search essentials...",
                                      onFilterApplied: (FilterModel filter) {
                                        setState(() {
                                          _comprehensiveFilter = filter.copyWith();
                                        });
                                      },
                                      isFood: false,
                                    );
                                  },
                                ),
                              _buildQuickFilters(colors),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (widget.isFood)
                      _buildFoodItemsSliver(colors, isDark)
                    else if (widget.isGrocery)
                      _buildGroceryItemsSliver(colors, isDark)
                    else if (widget.isPharmacy)
                      _buildPharmacyItemsSliver(colors, isDark)
                    else if (widget.isGrabMart)
                      _buildGrabMartItemsSliver(colors, isDark),
                  ],
                ),

                Positioned(top: 0, left: 0, right: 0, child: _buildCollapsibleCategoryHeader(colors, size, isDark)),
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

                        if (currentCount != _previousCartCount && _previousCartCount > 0) {
                          _badgePulseController.forward(from: 0);
                        }

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
      ),
    );
  }

  Widget _buildQuickFilters(AppColorsExtension colors) {
    // Filter out Dietary chip for Groceries service
    final visibleFilters = _quickFilters.where((filter) {
      if (filter['label'] == 'Dietary' && !widget.isFood) {
        return false;
      }
      return true;
    }).toList();

    return Container(
      height: 40.h,
      margin: EdgeInsets.only(top: 18.h, bottom: 4.h),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: 20.w),
        physics: const BouncingScrollPhysics(),
        itemCount: visibleFilters.length,
        itemBuilder: (context, index) {
          final filter = visibleFilters[index];
          final isSelected = _selectedQuickFilters.contains(filter['label']);

          return GestureDetector(
            onTap: () {
              if (filter['hasOptions'] == true) {
                _showFilterOptions(filter['label']!, colors);
              } else {
                setState(() {
                  if (isSelected) {
                    _selectedQuickFilters.remove(filter['label']!);
                  } else {
                    _selectedQuickFilters.add(filter['label']!);
                  }
                });
              }
            },
            child: Padding(
              padding: EdgeInsets.only(right: 20.w),
              child: AnimatedContainer(
                key: ValueKey('filter_${filter['label']}'),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)]
                        : [colors.backgroundPrimary, colors.backgroundPrimary],
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      filter['icon']!,
                      package: 'grab_go_shared',
                      height: 16.h,
                      width: 16.w,
                      colorFilter: ColorFilter.mode(
                        isSelected ? colors.backgroundPrimary : colors.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? colors.backgroundPrimary : colors.textPrimary,
                      ),
                      child: Text(
                        filter['label']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontFamily: "Lato",
                          package: 'grab_go_shared',
                        ),
                      ),
                    ),
                    if (filter['hasOptions'] == true) ...[
                      SizedBox(width: 4.w),
                      SvgPicture.asset(
                        Assets.icons.navArrowDown,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(
                          isSelected ? Colors.white : colors.textSecondary,
                          BlendMode.srcIn,
                        ),
                        width: 16.w,
                        height: 16.h,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFoodItemsSliver(AppColorsExtension colors, bool isDark) {
    final padding = MediaQuery.paddingOf(context);
    return Consumer<FoodProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return SliverToBoxAdapter(
            child: BrowseGridSkeleton(colors: colors, isDark: isDark, isGridView: _isGridView),
          );
        }

        final items = _getFilteredFoodItems(provider);

        if (items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No items found',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Try adjusting your filters',
                    style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 8.h, bottom: padding.bottom + 16.h),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _isGridView ? 2 : 1,
              childAspectRatio: _isGridView ? 0.7 : 1.8,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 16.h,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return PopularItemCard(
                item: item,
                orderCount: item.orderCount,
                onTap: () => context.push('/foodDetails', extra: item),
              );
            }, childCount: items.length),
          ),
        );
      },
    );
  }

  Widget _buildGroceryItemsSliver(AppColorsExtension colors, bool isDark) {
    final padding = MediaQuery.paddingOf(context);
    return Consumer<GroceryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingItems) {
          return SliverToBoxAdapter(
            child: BrowseGridSkeleton(colors: colors, isDark: isDark, isGridView: _isGridView),
          );
        }

        final items = _getFilteredGroceryItems(provider);

        if (items.isEmpty) {
          return _buildEmptyState(colors);
        }

        return SliverPadding(
          padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 8.h, bottom: padding.bottom + 16.h),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _isGridView ? 2 : 1,
              childAspectRatio: _isGridView ? 0.7 : 1.8,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 16.h,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return PopularItemCard(
                item: item.toFoodItem(),
                orderCount: item.orderCount,
                onTap: () => context.push('/foodDetails', extra: item),
              );
            }, childCount: items.length),
          ),
        );
      },
    );
  }

  Widget _buildPharmacyItemsSliver(AppColorsExtension colors, bool isDark) {
    final padding = MediaQuery.paddingOf(context);
    return Consumer<PharmacyProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingItems) {
          return SliverToBoxAdapter(
            child: BrowseGridSkeleton(colors: colors, isDark: isDark, isGridView: _isGridView),
          );
        }

        final items = provider.items.where((item) => item.categoryId == widget.categoryId).toList();

        if (items.isEmpty) {
          return _buildEmptyState(colors);
        }

        return SliverPadding(
          padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 8.h, bottom: padding.bottom + 16.h),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _isGridView ? 2 : 1,
              childAspectRatio: _isGridView ? 0.7 : 1.8,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 16.h,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return PopularItemCard(
                item: item.toFoodItem(),
                orderCount: item.orderCount,
                onTap: () => context.push('/foodDetails', extra: item),
              );
            }, childCount: items.length),
          ),
        );
      },
    );
  }

  Widget _buildGrabMartItemsSliver(AppColorsExtension colors, bool isDark) {
    final padding = MediaQuery.paddingOf(context);
    return Consumer<GrabMartProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingItems) {
          return SliverToBoxAdapter(
            child: BrowseGridSkeleton(colors: colors, isDark: isDark, isGridView: _isGridView),
          );
        }

        final items = provider.items.where((item) => item.categoryId == widget.categoryId).toList();

        if (items.isEmpty) {
          return _buildEmptyState(colors);
        }

        return SliverPadding(
          padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 8.h, bottom: padding.bottom + 16.h),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _isGridView ? 2 : 1,
              childAspectRatio: _isGridView ? 0.7 : 1.8,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 16.h,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return PopularItemCard(
                item: item.toFoodItem(),
                orderCount: item.orderCount,
                onTap: () => context.push('/foodDetails', extra: item),
              );
            }, childCount: items.length),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.shopping_basket_outlined, size: 40.sp, color: colors.accentOrange),
            ),
            SizedBox(height: 16.h),
            Text(
              'No items found',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
            SizedBox(height: 8.h),
            Text(
              'Try adjusting your filters',
              style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  List<FoodItem> _getFilteredFoodItems(FoodProvider provider) {
    List<FoodItem> items = [];

    // Get items from the selected category
    try {
      final selectedCategory = provider.categories.firstWhere((cat) => cat.id == widget.categoryId);
      items = List.from(selectedCategory.items);
    } catch (e) {
      items = [];
    }

    // Apply comprehensive filter from HomeSearch
    if (_comprehensiveFilter.isActive) {
      // Apply price filter
      if (_comprehensiveFilter.minPrice != 0 || _comprehensiveFilter.maxPrice != 10000) {
        items = items.where((item) {
          return item.price >= _comprehensiveFilter.minPrice && item.price <= _comprehensiveFilter.maxPrice;
        }).toList();
      }

      // Apply rating filter
      if (_comprehensiveFilter.minRating != null) {
        items = items.where((item) => item.rating >= _comprehensiveFilter.minRating!).toList();
      }

      // Apply on sale filter
      if (_comprehensiveFilter.onSale) {
        items = items.where((item) => item.discountPercentage > 0).toList();
      }

      // Apply new items filter
      if (_comprehensiveFilter.isNew) {
        items = items.where((item) => item.orderCount < 10).toList();
      }

      // Apply fast delivery filter
      if (_comprehensiveFilter.fast) {
        items = items.where((item) => item.deliveryTimeMinutes <= 30).toList();
      }

      // Apply dietary filter
      if (_comprehensiveFilter.dietary != null && _comprehensiveFilter.dietary!.isNotEmpty) {
        items = items.where((item) => item.dietaryTags.contains(_comprehensiveFilter.dietary)).toList();
      }
    }

    // Apply quick filters
    for (final filterName in _selectedQuickFilters) {
      switch (filterName) {
        case 'On Sale':
          items = items.where((item) => item.discountPercentage > 0).toList();
          break;
        case 'Top Rated':
          items = items.where((item) => item.rating >= 4.5).toList();
          break;
        case 'New':
          items = items.where((item) => item.orderCount < 10).toList();
          break;
        case 'Fast':
          items = items.where((item) => item.deliveryTimeMinutes <= 30).toList();
          break;
        case 'Popular':
          items = items.where((item) => item.orderCount >= 50).toList();
          break;
        case 'Price':
          if (_selectedPriceRange != null) {
            items = items.where((item) {
              switch (_selectedPriceRange) {
                case 'Under GH₵20':
                  return item.price < 20;
                case 'GH₵20 - GH₵50':
                  return item.price >= 20 && item.price <= 50;
                case 'GH₵50 - GH₵100':
                  return item.price > 50 && item.price <= 100;
                case 'Over GH₵100':
                  return item.price > 100;
                default:
                  return true;
              }
            }).toList();
          }
          break;
        case 'Rating':
          if (_selectedRating != null) {
            items = items.where((item) {
              switch (_selectedRating) {
                case '4.5+ Stars':
                  return item.rating >= 4.5;
                case '4.0+ Stars':
                  return item.rating >= 4.0;
                case '3.5+ Stars':
                  return item.rating >= 3.5;
                case 'Any Rating':
                default:
                  return true;
              }
            }).toList();
          }
          break;
        case 'Delivery':
          if (_selectedDeliveryTime != null) {
            items = items.where((item) {
              switch (_selectedDeliveryTime) {
                case 'Under 20 min':
                  return item.deliveryTimeMinutes < 20;
                case '20-30 min':
                  return item.deliveryTimeMinutes >= 20 && item.deliveryTimeMinutes <= 30;
                case '30-45 min':
                  return item.deliveryTimeMinutes > 30 && item.deliveryTimeMinutes <= 45;
                case 'Any Time':
                default:
                  return true;
              }
            }).toList();
          }
          break;
        case 'Dietary':
          if (_selectedDietary != null) {
            items = items.where((item) {
              try {
                return item.dietaryTags.contains(_selectedDietary);
              } catch (e) {
                return false;
              }
            }).toList();
          }
          break;
      }
    }

    // Apply sort
    _applySortToFoodItems(items);

    return items;
  }

  List<GroceryItem> _getFilteredGroceryItems(GroceryProvider provider) {
    List<GroceryItem> items = provider.items.where((item) => item.categoryId == widget.categoryId).toList();

    // Apply comprehensive filter from HomeSearch
    if (_comprehensiveFilter.isActive) {
      // Apply price filter
      if (_comprehensiveFilter.minPrice != 0 || _comprehensiveFilter.maxPrice != 10000) {
        items = items.where((item) {
          return item.price >= _comprehensiveFilter.minPrice && item.price <= _comprehensiveFilter.maxPrice;
        }).toList();
      }

      // Apply rating filter
      if (_comprehensiveFilter.minRating != null) {
        items = items.where((item) => item.rating >= _comprehensiveFilter.minRating!).toList();
      }

      // Apply on sale filter
      if (_comprehensiveFilter.onSale) {
        items = items.where((item) => item.discountPercentage > 0).toList();
      }

      // Apply new items filter
      if (_comprehensiveFilter.isNew) {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        items = items.where((item) => item.createdAt.isAfter(sevenDaysAgo)).toList();
      }
    }

    for (final filterName in _selectedQuickFilters) {
      switch (filterName) {
        case 'On Sale':
          items = items.where((item) => item.discountPercentage > 0).toList();
          break;
        case 'Top Rated':
          items = items.where((item) => item.rating >= 4.5).toList();
          break;
        case 'New':
          final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
          items = items.where((item) => item.createdAt.isAfter(sevenDaysAgo)).toList();
          break;
        case 'Popular':
          items = items.where((item) => item.orderCount >= 100).toList();
          break;
        case 'Price':
          if (_selectedPriceRange != null) {
            items = items.where((item) {
              switch (_selectedPriceRange) {
                case 'Under GH₵20':
                  return item.price < 20;
                case 'GH₵20 - GH₵50':
                  return item.price >= 20 && item.price <= 50;
                case 'GH₵50 - GH₵100':
                  return item.price > 50 && item.price <= 100;
                case 'Over GH₵100':
                  return item.price > 100;
                default:
                  return true;
              }
            }).toList();
          }
          break;
        case 'Rating':
          if (_selectedRating != null) {
            items = items.where((item) {
              switch (_selectedRating) {
                case '4.5+ Stars':
                  return item.rating >= 4.5;
                case '4.0+ Stars':
                  return item.rating >= 4.0;
                case '3.5+ Stars':
                  return item.rating >= 3.5;
                case 'Any Rating':
                default:
                  return true;
              }
            }).toList();
          }
          break;
      }
    }

    // Apply sort
    _applySortToGroceryItems(items);

    return items;
  }

  void _applySortToFoodItems(List<FoodItem> items) {
    switch (_sortBy) {
      case 'Price: Low to High':
        items.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        items.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Rating: High to Low':
        items.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Popularity':
        items.sort((a, b) => b.orderCount.compareTo(a.orderCount));
        break;
      case 'Delivery Time':
        items.sort((a, b) => a.deliveryTimeMinutes.compareTo(b.deliveryTimeMinutes));
        break;
    }
  }

  void _applySortToGroceryItems(List<GroceryItem> items) {
    switch (_sortBy) {
      case 'Price: Low to High':
        items.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        items.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Rating: High to Low':
        items.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'Popularity':
        items.sort((a, b) => b.orderCount.compareTo(a.orderCount));
        break;
    }
  }

  void _showFilterOptions(String filterType, AppColorsExtension colors) {
    List<String> options = [];
    String? currentSelection;

    switch (filterType) {
      case 'Price':
        options = _priceRanges;
        currentSelection = _selectedPriceRange;
        break;
      case 'Rating':
        options = _ratingOptions;
        currentSelection = _selectedRating;
        break;
      case 'Delivery':
        options = _deliveryTimeOptions;
        currentSelection = _selectedDeliveryTime;
        break;
      case 'Dietary':
        options = _dietaryOptions;
        currentSelection = _selectedDietary;
        break;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: colors.inputBorder, borderRadius: BorderRadius.circular(2.r)),
                ),
              ),
              SizedBox(height: KSpacing.md.h),
              Text(
                'Select $filterType',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              SizedBox(height: 16.h),
              ...options.map((option) {
                final isSelected = currentSelection == option;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.accentOrange : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check_circle, color: colors.accentOrange, size: 24.sp) : null,
                  onTap: () {
                    setState(() {
                      switch (filterType) {
                        case 'Price':
                          _selectedPriceRange = isSelected ? null : option;
                          if (_selectedPriceRange != null) {
                            _selectedQuickFilters.add('Price');
                          } else {
                            _selectedQuickFilters.remove('Price');
                          }
                          break;
                        case 'Rating':
                          _selectedRating = isSelected ? null : option;
                          if (_selectedRating != null) {
                            _selectedQuickFilters.add('Rating');
                          } else {
                            _selectedQuickFilters.remove('Rating');
                          }
                          break;
                        case 'Delivery':
                          _selectedDeliveryTime = isSelected ? null : option;
                          if (_selectedDeliveryTime != null) {
                            _selectedQuickFilters.add('Delivery');
                          } else {
                            _selectedQuickFilters.remove('Delivery');
                          }
                          break;
                        case 'Dietary':
                          _selectedDietary = isSelected ? null : option;
                          if (_selectedDietary != null) {
                            _selectedQuickFilters.add('Dietary');
                          } else {
                            _selectedQuickFilters.remove('Dietary');
                          }
                          break;
                      }
                    });
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _showSortOptions() {
    final colors = context.appColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.r))),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20.r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort by',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
              SizedBox(height: 16.h),
              ..._sortOptions.map((option) {
                final isSelected = _sortBy == option;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? colors.accentOrange : colors.textPrimary,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check, color: colors.accentOrange, size: 20.sp) : null,
                  onTap: () {
                    setState(() => _sortBy = option);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  double _calculateStickyHeaderHeight() {
    double height = 54.h;
    height += 40.h + 16.h;
    return height;
  }

  Widget _buildCollapsibleCategoryHeader(AppColorsExtension colors, Size size, bool isDark) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);
        final expandedHeight = size.height * 0.18;
        final currentHeight = expandedHeight - ((expandedHeight - _collapsedHeight) * collapseProgress);
        final contentOpacity = (1.0 - collapseProgress).clamp(0.0, 1.0);

        return SizedBox(
          height: currentHeight,
          child: UmbrellaHeaderWithShadow(
            curveDepth: 25.h,
            numberOfCurves: 10,
            height: currentHeight,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: contentOpacity,
              child: _buildCategoryHeader(colors, isDark),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryHeader(AppColorsExtension colors, bool isDark) {
    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, MediaQuery.of(context).padding.top.h, 20.w, 16.h),
        child: Row(
          children: [
            Container(
              height: 40.h,
              width: 40.w,
              decoration: BoxDecoration(color: colors.backgroundPrimary.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.pop(),
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: SvgPicture.asset(
                      Assets.icons.navArrowLeft,
                      package: 'grab_go_shared',
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      width: 24.w,
                      height: 24.h,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.categoryName,
                    style: TextStyle(
                      fontFamily: "Lato",
                      package: 'grab_go_shared',
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  if (widget.isFood)
                    Consumer<FoodProvider>(
                      builder: (context, provider, _) {
                        final items = _getFilteredFoodItems(provider);
                        return Text(
                          '${items.length} options available',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        );
                      },
                    )
                  else if (widget.isGrocery)
                    Consumer<GroceryProvider>(
                      builder: (context, provider, _) {
                        final items = _getFilteredGroceryItems(provider);
                        return Text(
                          '${items.length} options available',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        );
                      },
                    )
                  else if (widget.isPharmacy)
                    Consumer<PharmacyProvider>(
                      builder: (context, provider, _) {
                        final items = provider.items.where((item) => item.categoryId == widget.categoryId).toList();
                        return Text(
                          '${items.length} options available',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        );
                      },
                    )
                  else if (widget.isGrabMart)
                    Consumer<GrabMartProvider>(
                      builder: (context, provider, _) {
                        final items = provider.items.where((item) => item.categoryId == widget.categoryId).toList();
                        return Text(
                          '${items.length} options available',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        );
                      },
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

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({required this.minHeight, required this.maxHeight, required this.child});

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight || minHeight != oldDelegate.minHeight || child != oldDelegate.child;
  }
}
