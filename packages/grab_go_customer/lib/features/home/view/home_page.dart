import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_category.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/location_provider.dart';
import 'package:grab_go_customer/shared/widgets/app_refresh_indicator.dart';
import 'package:grab_go_customer/shared/widgets/category_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/food_item_skeleton.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/service_category_list.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/home_search.dart';
import 'package:grab_go_customer/shared/widgets/home_banner.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/features/home/model/filter_model.dart';
import 'package:grab_go_customer/features/home/model/service_model.dart';
import 'package:grab_go_customer/shared/widgets/service_selector.dart';
import 'package:grab_go_customer/shared/widgets/deals_section.dart';
import 'package:grab_go_customer/shared/widgets/order_again_section.dart';
import 'package:grab_go_customer/shared/widgets/popular_section.dart';
import 'package:grab_go_customer/shared/widgets/promo_section.dart';
import 'package:grab_go_customer/shared/widgets/top_rated_section.dart';
import 'package:grab_go_customer/shared/widgets/fresh_arrivals_section.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/shared/viewmodels/service_provider.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  FoodCategoryModel? _selectedCategory;
  GroceryCategory? _selectedGroceryCategory;

  late ScrollController _scrollController;
  late AnimationController _fabAnimationController;
  late AnimationController _badgePulseController;
  late Animation<Offset> _fabSlideAnimation;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _badgePulseAnimation;
  bool _isFabVisible = true;
  double _lastScrollOffset = 0.0;
  FilterModel _activeFilter = FilterModel();
  int _previousCartCount = 0;

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
    _initializeData();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _fabAnimationController.dispose();
    _badgePulseController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;
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

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationProvider>(context, listen: false).fetchAddress();
      final provider = Provider.of<FoodProvider>(context, listen: false);
      if (provider.categories.isEmpty) {
        provider.fetchCategories();
        provider.fetchRecentOrderItems();
        provider.fetchPromotionalBanners();
        provider.fetchDeals();
      } else {
        if (provider.categories.isNotEmpty) {
          setState(() {
            _selectedCategory = provider.categories.first;
          });
        }
      }
    });
  }

  Future<void> _refreshData() async {
    final serviceProvider = Provider.of<ServiceProvider>(context, listen: false);

    if (serviceProvider.isFoodService) {
      // Refresh food data
      final provider = Provider.of<FoodProvider>(context, listen: false);
      await Future.wait([
        provider.refreshCategories(),
        provider.fetchRecentOrderItems(),
        provider.fetchPromotionalBanners(),
        provider.fetchDeals(),
      ]);
    } else if (serviceProvider.isGroceryService) {
      // Refresh grocery data
      final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
      await groceryProvider.refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    final locationProvider = Provider.of<LocationProvider>(context);
    final itemsProvider = Provider.of<FoodProvider>(context);
    final serviceProvider = Provider.of<ServiceProvider>(context);

    if (itemsProvider.categories.isNotEmpty && _selectedCategory == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedCategory = itemsProvider.categories.first;
          });
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: _refreshData,
          iconPath: serviceProvider.isFoodService ? Assets.icons.utensilsCrossed : Assets.icons.cart,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHomeHeader(context, size, colors, isDark, locationProvider),
                SizedBox(height: 8.h),
                _buildHomeSearch(itemsProvider),
                SizedBox(height: KSpacing.lg.h),
                _buildServiceSelector(),
                SizedBox(height: KSpacing.lg.h),
                HomeBanner(size: size),
                SizedBox(height: KSpacing.lg.h),
                if (serviceProvider.isFoodService)
                  _buildCategories(itemsProvider, isDark, size, colors)
                else if (serviceProvider.isGroceryService)
                  _buildGroceryCategories(Provider.of<GroceryProvider>(context), isDark, size, colors),

                SizedBox(height: KSpacing.lg.h),

                // Fresh Arrivals (Grocery only)
                if (serviceProvider.isGroceryService) ...[
                  Builder(
                    builder: (context) {
                      final groceryProvider = Provider.of<GroceryProvider>(context);

                      if (groceryProvider.isLoadingFreshArrivals || groceryProvider.freshArrivals.isNotEmpty) {
                        return Column(
                          children: [
                            FreshArrivalsSection(
                              items: groceryProvider.freshArrivals,
                              onSeeAll: () {
                                // TODO: Navigate to full fresh arrivals page
                              },
                              onItemTap: (item) {
                                context.push('/foodDetails', extra: item);
                              },
                              isLoading: groceryProvider.isLoadingFreshArrivals,
                            ),
                            SizedBox(height: KSpacing.xl.h),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],

                // Buy Again (Grocery only)
                if (serviceProvider.isGroceryService) ...[
                  Builder(
                    builder: (context) {
                      final groceryProvider = Provider.of<GroceryProvider>(context);

                      // Show if loading or has items (like Fresh Arrivals)
                      if (groceryProvider.isLoadingBuyAgain || groceryProvider.buyAgainItems.isNotEmpty) {
                        return Column(
                          children: [
                            OrderAgainSection(
                              recentOrders: groceryProvider.buyAgainItems.map((item) => item.toFoodItem()).toList(),
                              onSeeAll: () {
                                // TODO: Navigate to order history page
                              },
                              onItemTap: (foodItem) {
                                // Find original grocery item and navigate
                                final groceryItem = groceryProvider.buyAgainItems.firstWhere(
                                  (item) => item.id == foodItem.id,
                                  orElse: () => groceryProvider.buyAgainItems.first,
                                );
                                context.push('/foodDetails', extra: groceryItem);
                              },
                            ),
                            SizedBox(height: KSpacing.xl.h),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],

                // Deals & Offers
                Builder(
                  builder: (context) {
                    final deals = serviceProvider.isFoodService
                        ? itemsProvider.dealItems
                        : Provider.of<GroceryProvider>(context).deals.map((e) => e.toFoodItem()).toList();

                    final isLoading = serviceProvider.isFoodService
                        ? itemsProvider.isLoadingDeals
                        : Provider.of<GroceryProvider>(context).isLoadingDeals;

                    if (isLoading || deals.isNotEmpty) {
                      return Column(
                        children: [
                          DealsSection(
                            dealItems: deals,
                            onSeeAll: () {},
                            onItemTap: (item) {
                              if (serviceProvider.isGroceryService) {
                                final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
                                final originalItem = groceryProvider.deals.firstWhere(
                                  (g) => g.id == item.id,
                                  orElse: () => groceryProvider.items.firstWhere(
                                    (g) => g.id == item.id,
                                    orElse: () => groceryProvider.deals.first,
                                  ),
                                );
                                context.push('/foodDetails', extra: originalItem);
                              } else {
                                context.push('/foodDetails', extra: item);
                              }
                            },
                            isLoading: isLoading,
                          ),
                          SizedBox(height: KSpacing.xl.h),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Order Again (Food only for now)
                if (serviceProvider.isFoodService && itemsProvider.recentOrderItems.isNotEmpty) ...[
                  OrderAgainSection(
                    recentOrders: itemsProvider.recentOrderItems,
                    onSeeAll: () {},
                    onItemTap: (item) {
                      context.push('/food-details', extra: item);
                    },
                  ),
                  SizedBox(height: KSpacing.xl.h),
                ],

                // Unified Popular Section
                Builder(
                  builder: (context) {
                    List<FoodItem> popularItems = [];
                    bool isLoading = false;

                    if (serviceProvider.isFoodService) {
                      popularItems = itemsProvider.categories
                          .expand((cat) => cat.items)
                          .where((item) => item.rating >= 4.0)
                          .take(6)
                          .toList();
                      isLoading = itemsProvider.isLoading;
                    } else {
                      final groceryProvider = Provider.of<GroceryProvider>(context);
                      popularItems = groceryProvider.items
                          .where((item) => item.rating >= 4.0)
                          .take(6)
                          .map((e) => e.toFoodItem())
                          .toList();
                      isLoading = groceryProvider.isLoadingItems;
                    }

                    return PopularSection(
                      popularItems: popularItems,
                      onSeeAll: () {},
                      onItemTap: (item) {
                        if (serviceProvider.isGroceryService) {
                          final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
                          final originalItem = groceryProvider.items.firstWhere(
                            (g) => g.id == item.id,
                            orElse: () => groceryProvider.items.first,
                          );
                          context.push('/grocery-details', extra: originalItem);
                        } else {
                          context.push('/food-details', extra: item);
                        }
                      },
                      isLoading: isLoading,
                    );
                  },
                ),
                SizedBox(height: KSpacing.xl.h),

                // Unified Banners (Promo Section)
                if (serviceProvider.isFoodService) ...[
                  if (itemsProvider.isLoadingBanners || itemsProvider.promotionalBanners.isNotEmpty) ...[
                    PromoSection(
                      banners: itemsProvider.promotionalBanners,
                      onSeeAll: () {},
                      isLoading: itemsProvider.isLoadingBanners,
                    ),
                    SizedBox(height: KSpacing.xl.h),
                  ],
                ],

                // Unified Top Rated Section
                Builder(
                  builder: (context) {
                    List<FoodItem> topRatedItems = [];
                    bool isLoading = false;

                    if (serviceProvider.isFoodService) {
                      topRatedItems = itemsProvider.categories
                          .expand((cat) => cat.items)
                          .where((item) => item.rating >= 4.5)
                          .take(6)
                          .toList();
                      isLoading = itemsProvider.isLoading;
                    } else {
                      final groceryProvider = Provider.of<GroceryProvider>(context);
                      topRatedItems = groceryProvider.items
                          .where((item) => item.rating >= 4.5)
                          .take(6)
                          .map((e) => e.toFoodItem())
                          .toList();
                      isLoading = groceryProvider.isLoadingItems;
                    }

                    return TopRatedSection(
                      topRatedItems: topRatedItems,
                      onSeeAll: () {},
                      onItemTap: (item) {
                        if (serviceProvider.isGroceryService) {
                          // Find original grocery item by ID
                          final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
                          final originalItem = groceryProvider.items.firstWhere(
                            (g) => g.id == item.id,
                            orElse: () => groceryProvider.items.first,
                          );
                          context.push('/grocery-details', extra: originalItem);
                        } else {
                          context.push('/food-details', extra: item);
                        }
                      },
                      isLoading: isLoading,
                    );
                  },
                ),
                SizedBox(height: KSpacing.xl.h),

                // Recommended (Food Specific or Generic)
                if (serviceProvider.isFoodService) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: colors.accentViolet.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(KBorderSize.border),
                              ),
                              child: SvgPicture.asset(
                                Assets.icons.sparkles,
                                package: 'grab_go_shared',
                                height: 20.h,
                                width: 20.w,
                                colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              "Recommended For You",
                              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                          ],
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: colors.accentViolet.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {},
                              borderRadius: BorderRadius.circular(20.r),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "See All",
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: colors.accentViolet,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  SvgPicture.asset(
                                    Assets.icons.navArrowRight,
                                    package: 'grab_go_shared',
                                    height: 12.h,
                                    width: 12.w,
                                    colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: KSpacing.lg.h),
                  _buildRecommendedFoodItems(itemsProvider, size, colors, isDark),
                ],
              ],
            ),
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
    );
  }

  Builder _buildRecommendedFoodItems(FoodProvider itemsProvider, Size size, AppColorsExtension colors, bool isDark) {
    return Builder(
      builder: (context) {
        List<FoodItem> recommendedFoods = [];

        List<FoodItem> allFoods = [];

        if (itemsProvider.categories.isEmpty) {
          return FoodItemSkeleton(colors: colors, isDark: isDark, size: size);
        }

        List<FoodCategoryModel> categoriesToProcess = itemsProvider.categories;

        if (_selectedCategory != null) {
          final categoryExists = categoriesToProcess.any((cat) => cat.id == _selectedCategory!.id);
          if (categoryExists) {
            categoriesToProcess = categoriesToProcess
                .where((category) => category.id == _selectedCategory!.id)
                .toList();
          } else {
            if (categoriesToProcess.isNotEmpty) {
              final firstCategory = categoriesToProcess.first;
              categoriesToProcess = [firstCategory];
              if (_selectedCategory?.id != firstCategory.id) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedCategory = firstCategory;
                    });
                  }
                });
              }
            }
          }
        } else if (_activeFilter.isActive && _activeFilter.selectedCategories.isNotEmpty) {
          final validCategoryIds = itemsProvider.categories.map((cat) => cat.id).where((id) => id.isNotEmpty).toSet();

          final validSelectedCategories = _activeFilter.selectedCategories
              .where((id) => id.isNotEmpty && validCategoryIds.contains(id))
              .toList();

          if (validSelectedCategories.isNotEmpty) {
            categoriesToProcess = itemsProvider.categories
                .where((category) => validSelectedCategories.contains(category.id))
                .toList();
          } else {
            if (categoriesToProcess.isNotEmpty) {
              categoriesToProcess = [categoriesToProcess.first];
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _activeFilter.selectedCategories.clear();
                });
              }
            });
          }
        } else if (categoriesToProcess.isNotEmpty) {
          final firstCategory = categoriesToProcess.first;
          categoriesToProcess = [firstCategory];
          if (_selectedCategory?.id != firstCategory.id) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedCategory = firstCategory;
                });
              }
            });
          }
        }

        final Set<String> seenItemKeys = {};
        for (var category in categoriesToProcess) {
          if (category.items.isNotEmpty) {
            for (var item in category.items) {
              final key = '${item.id}_${item.sellerId}';
              if (!seenItemKeys.contains(key)) {
                seenItemKeys.add(key);
                allFoods.add(item);
              }
            }
          }
        }

        if (_activeFilter.isActive && allFoods.isNotEmpty) {
          allFoods = _applyFilter(allFoods, itemsProvider.categories, _activeFilter);
        }

        if (allFoods.isNotEmpty) {
          recommendedFoods = allFoods.take(5).toList();
        }

        if (recommendedFoods.isEmpty) {
          return _activeFilter.isActive
              ? Container(
                  height: size.height * 0.15,
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "No items match your filters",
                          style: TextStyle(color: colors.textSecondary, fontSize: 16.sp, fontWeight: FontWeight.w500),
                        ),
                        if (_activeFilter.isActive) ...[
                          SizedBox(height: 8.h),
                          Text(
                            "Try adjusting your filter criteria",
                            style: TextStyle(color: colors.textTertiary, fontSize: 12.sp),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : FoodItemSkeleton(colors: colors, isDark: isDark, size: size);
        }

        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: recommendedFoods.length,
          itemBuilder: (context, index) {
            final item = recommendedFoods[index];

            return Consumer<CartProvider>(
              builder: (context, provider, _) {
                final bool isInCart = provider.cartItems.containsKey(item);

                return FoodItemCard(
                  item: item,
                  onTap: () => context.push("/foodDetails", extra: item),
                  trailing: GestureDetector(
                    onTap: () {
                      if (isInCart) {
                        provider.removeItemCompletely(item);
                      } else {
                        provider.addToCart(item);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isInCart ? colors.accentOrange : colors.backgroundSecondary,
                        border: Border.all(color: isInCart ? colors.accentOrange : colors.inputBorder, width: 1),
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.cart,
                        package: 'grab_go_shared',
                        height: 16.h,
                        width: 16.w,
                        colorFilter: ColorFilter.mode(isInCart ? Colors.white : colors.textPrimary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Builder _buildCategories(FoodProvider itemsProvider, bool isDark, Size size, AppColorsExtension colors) {
    return Builder(
      builder: (context) {
        if (itemsProvider.isLoading) {
          return CategorySkeleton(colors: colors, isDark: isDark, size: size);
        } else if (itemsProvider.error != null) {
          return CategorySkeleton(colors: colors, isDark: isDark, size: size);
        } else if (itemsProvider.categories.isEmpty) {
          return CategorySkeleton(colors: colors, isDark: isDark, size: size);
        }

        List<FoodCategoryModel> categoriesToShow = itemsProvider.categories;
        if (_activeFilter.isActive && _activeFilter.selectedCategories.isNotEmpty) {
          final validCategoryIds = itemsProvider.categories.map((cat) => cat.id).where((id) => id.isNotEmpty).toSet();

          final validSelectedCategories = _activeFilter.selectedCategories
              .where((id) => id.isNotEmpty && validCategoryIds.contains(id))
              .toList();

          if (validSelectedCategories.isNotEmpty) {
            categoriesToShow = itemsProvider.categories
                .where((category) => validSelectedCategories.contains(category.id))
                .toList();
          } else {
            categoriesToShow = itemsProvider.categories;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _activeFilter.selectedCategories.clear();
                });
              }
            });
          }

          if (categoriesToShow.isEmpty) {
            return Container(
              height: 50.h,
              width: double.infinity,
              margin: EdgeInsets.only(left: 10.w, right: 20.w),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              ),
              child: Center(
                child: Text(
                  "No categories match your filter",
                  style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
              ),
            );
          }
        }

        return ServiceCategoryList<FoodCategoryModel>(
          categories: categoriesToShow,
          getName: (cat) => cat.name,
          getEmoji: (cat) => cat.emoji,
          getId: (cat) => cat.id,
          initialSelectedCategory: _selectedCategory,
          onCategorySelected: (FoodCategoryModel category) {
            setState(() {
              _selectedCategory = category;
            });
          },
        );
      },
    );
  }

  HomeSearch _buildHomeSearch(FoodProvider itemsProvider) {
    return HomeSearch(
      categories: itemsProvider.categories,
      activeFilter: _activeFilter,
      onFilterApplied: (FilterModel filter) {
        setState(() {
          _activeFilter = filter.copyWith();
          if (filter.isActive && filter.selectedCategories.isNotEmpty) {
            final validCategoryIds = itemsProvider.categories.map((cat) => cat.id).where((id) => id.isNotEmpty).toSet();

            final validSelectedCategories = filter.selectedCategories
                .where((id) => id.isNotEmpty && validCategoryIds.contains(id))
                .toList();

            if (validSelectedCategories.isNotEmpty) {
              final filteredCategories = itemsProvider.categories
                  .where((cat) => validSelectedCategories.contains(cat.id))
                  .toList();

              if (_selectedCategory != null && !validSelectedCategories.contains(_selectedCategory!.id)) {
                _selectedCategory = filteredCategories.first;
              } else {
                _selectedCategory ??= filteredCategories.first;
              }
            } else {
              _activeFilter.selectedCategories.clear();
              if (_selectedCategory == null && itemsProvider.categories.isNotEmpty) {
                _selectedCategory = itemsProvider.categories.first;
              }
            }
          } else {
            if (itemsProvider.categories.isNotEmpty) {
              if (_selectedCategory == null ||
                  !itemsProvider.categories.any((cat) => cat.id == _selectedCategory!.id)) {
                _selectedCategory = itemsProvider.categories.first;
              }
            }
          }
        });
      },
    );
  }

  Widget _buildServiceSelector() {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);

    /*
    // Uncomment if you need skeleton loading state
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (itemsProvider.isLoading) {
       return ServiceSelectorSkeleton(colors: colors, isDark: isDark);
    }
    */

    return ServiceSelector(
      services: AppServices.all,
      initialSelectedService: serviceProvider.currentService,
      onServiceSelected: (ServiceModel service) {
        debugPrint("Service Selected: ${service.id}");
        serviceProvider.selectService(service);

        // Load data for the selected service
        if (service.id == 'groceries') {
          // Load grocery data
          if (groceryProvider.categories.isEmpty) {
            groceryProvider.fetchCategories();
            groceryProvider.fetchStores();
            groceryProvider.fetchItems();
            groceryProvider.fetchDeals();
          }
        } else if (service.id == 'food') {
          // Load food data (already loaded in initState)
          if (foodProvider.categories.isEmpty) {
            foodProvider.fetchCategories();
            foodProvider.fetchRecentOrderItems();
            foodProvider.fetchPromotionalBanners();
            foodProvider.fetchDeals();
          }
        }
      },
    );
  }

  Padding _buildHomeHeader(
    BuildContext context,
    Size size,
    AppColorsExtension colors,
    bool isDark,
    LocationProvider locationProvider,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                context.push("/paymentComplete");
              },
              child: Container(
                height: size.height * 0.08,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(
                        color: colors.accentOrange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.mapPin,
                        package: 'grab_go_shared',
                        height: 14.h,
                        width: 14.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Deliver to",
                            style: TextStyle(
                              fontFamily: "Lato",
                              package: 'grab_go_shared',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            locationProvider.address.isEmpty ? "Fetching location..." : locationProvider.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    SvgPicture.asset(
                      Assets.icons.navArrowDown,
                      package: 'grab_go_shared',
                      height: 16.h,
                      width: 16.w,
                      colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),

          Container(
            height: size.height * 0.08,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                  spreadRadius: 0,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.push("/notification");
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.r),
                      child: SvgPicture.asset(
                        Assets.icons.bellNotification,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),

                Material(
                  color: Colors.transparent,
                  child: Builder(
                    builder: (context) => InkWell(
                      onTap: () {
                        context.push("/status");
                      },
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: EdgeInsets.all(10.r),
                        child: SvgPicture.asset(
                          Assets.icons.styleBorder,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Apply filter to food items
  /// This applies price, rating, and restaurant filters
  /// Category filtering is handled separately when collecting items
  List<FoodItem> _applyFilter(List<FoodItem> items, List<FoodCategoryModel> categories, FilterModel filter) {
    if (items.isEmpty) return [];

    // Validate filter values
    final validMinPrice = filter.minPrice.isNaN || filter.minPrice.isInfinite || filter.minPrice < 0
        ? 0.0
        : filter.minPrice;
    final validMaxPrice = filter.maxPrice.isNaN || filter.maxPrice.isInfinite || filter.maxPrice < validMinPrice
        ? 10000.0
        : filter.maxPrice;
    final validMinRating =
        filter.minRating != null &&
            (filter.minRating!.isNaN || filter.minRating!.isInfinite || filter.minRating! < 0 || filter.minRating! > 5)
        ? null
        : filter.minRating;

    // Get all available restaurant names for validation
    final availableRestaurants = <String>{};
    for (var category in categories) {
      for (var item in category.items) {
        if (item.sellerName.isNotEmpty) {
          availableRestaurants.add(item.sellerName);
        }
      }
    }

    // Filter out invalid restaurant selections
    final validSelectedRestaurants = filter.selectedRestaurants
        .where((restaurant) => restaurant.isNotEmpty && availableRestaurants.contains(restaurant))
        .toList();

    return items.where((item) {
      // Price filter - check if price is within range
      // Only apply if price range is different from default (0-10000)
      final isPriceFilterActive = validMinPrice != 0 || validMaxPrice != 10000;
      if (isPriceFilterActive) {
        // Ensure price is valid and within range
        if (item.price.isNaN || item.price.isInfinite || item.price < 0) return false;
        if (item.price < validMinPrice || item.price > validMaxPrice) {
          return false;
        }
      }

      // Rating filter - check if rating meets minimum requirement
      if (validMinRating != null) {
        // Ensure rating is valid (0-5 range)
        if (item.rating.isNaN || item.rating.isInfinite || item.rating < 0 || item.rating > 5) return false;
        if (item.rating < validMinRating) {
          return false;
        }
      }

      // Restaurant filter - check if restaurant is selected
      if (validSelectedRestaurants.isNotEmpty) {
        // Ensure sellerName is not empty and matches
        if (item.sellerName.isEmpty || !validSelectedRestaurants.contains(item.sellerName)) {
          return false;
        }
      }

      // Note: Category filtering is handled earlier when collecting items
      // to avoid processing items from unselected categories

      return true;
    }).toList();
  }

  /// Create mock restaurants from food items for Nearby section
  /// This extracts unique restaurants from food items
  List<RestaurantModel> createMockRestaurants(FoodProvider itemsProvider) {
    if (itemsProvider.categories.isEmpty) {
      return [];
    }

    // Collect unique restaurants from food items
    final Map<String, RestaurantModel> restaurantMap = {};

    for (var category in itemsProvider.categories) {
      for (var item in category.items) {
        if (item.restaurantId.isNotEmpty && !restaurantMap.containsKey(item.restaurantId)) {
          // Create mock restaurant from food item data
          restaurantMap[item.restaurantId] = RestaurantModel(
            id: item.sellerId,
            backendId: item.restaurantId,
            name: item.sellerName.isNotEmpty ? item.sellerName : 'Restaurant ${item.sellerId}',
            city: 'Accra',
            foodType: category.name,
            imageUrl: item.restaurantImage.isNotEmpty ? item.restaurantImage : item.image,
            bannerImages: [],
            distance: (restaurantMap.length * 0.5) + 0.5, // Mock distance: 0.5, 1.0, 1.5, etc.
            rating: item.rating,
            totalReviews: 120,
            averageDeliveryTime: '${20 + (restaurantMap.length * 5)}-${30 + (restaurantMap.length * 5)}',
            deliveryFee: 5.0,
            minOrder: 15.0,
            description: 'Delicious ${category.name} and more',
            phone: '+233 XX XXX XXXX',
            email: 'contact@restaurant.com',
            address: 'Accra, Ghana',
            latitude: 5.6037,
            longitude: -0.1870,
            openingHours: '9:00 AM - 10:00 PM',
            isOpen: true,
            paymentMethods: ['Cash', 'Mobile Money'],
            socials: Socials(instagram: '', facebook: ''),
            foods: [],
          );
        }
      }
    }

    // Return up to 6 restaurants
    return restaurantMap.values.take(6).toList();
  }

  /// Build service selector (Food, Groceries, Pharmacy, Stores)
  Widget buildServiceSelector() {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);

    return ServiceSelector(
      services: AppServices.all,
      initialSelectedService: serviceProvider.currentService,
      onServiceSelected: (service) {
        serviceProvider.selectService(service);

        // Load data for the selected service
        if (service.id == 'groceries') {
          // Load grocery data
          if (groceryProvider.categories.isEmpty) {
            groceryProvider.fetchCategories();
            groceryProvider.fetchStores();
            groceryProvider.fetchItems();
            groceryProvider.fetchDeals();
          }
        } else if (service.id == 'food') {
          // Load food data (already loaded in initState)
          if (foodProvider.categories.isEmpty) {
            foodProvider.fetchCategories();
            foodProvider.fetchRecentOrderItems();
            foodProvider.fetchPromotionalBanners();
            foodProvider.fetchDeals();
          }
        }
        // Other services (pharmacy, stores) can be added later
      },
    );
  }

  /// Build grocery content
  /// Build grocery content
  Widget _buildGroceryCategories(GroceryProvider groceryProvider, bool isDark, Size size, AppColorsExtension colors) {
    // Create "All" category
    final allCategory = GroceryCategory(
      id: 'all',
      name: 'All',
      emoji: '🥣',
      description: 'All items',
      image: '',
      sortOrder: 0,
      isActive: true,
    );

    // Combine categories
    final categoriesWithType = [allCategory, ...groceryProvider.categories];

    if (groceryProvider.isLoadingCategories) {
      return CategorySkeleton(colors: colors, isDark: isDark, size: size);
    }

    if (groceryProvider.categories.isNotEmpty) {
      return ServiceCategoryList<GroceryCategory>(
        categories: categoriesWithType,
        getName: (cat) => cat.name,
        getEmoji: (cat) => cat.emoji,
        getId: (cat) => cat.id,
        initialSelectedCategory: _selectedGroceryCategory ?? allCategory,
        onCategorySelected: (category) {
          setState(() {
            _selectedGroceryCategory = category;
          });
        },
      );
    }

    return const SizedBox.shrink();
  }
}
