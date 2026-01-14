import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_banner_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_deals_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_discovery_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/location_provider.dart';
import 'package:grab_go_customer/shared/widgets/app_refresh_indicator.dart';
import 'package:grab_go_customer/shared/widgets/category_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/food_item_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_customer/shared/widgets/store_specials_section.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/service_category_list.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/home_search.dart';
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
import 'package:grab_go_customer/shared/widgets/browse_all_groceries_section.dart';
import 'package:grab_go_customer/shared/widgets/promotional_banner_carousel.dart';
import 'package:grab_go_customer/features/home/model/promotional_banner.dart';
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
  int _recommendedDisplayedCount = 10;
  int _previousCartCount = 0;

  // Scroll tracking for collapsing header
  late final ValueNotifier<double> _scrollOffsetNotifier;
  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _scrollOffsetNotifier = ValueNotifier<double>(0.0);

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
    _scrollOffsetNotifier.dispose();
    _fabAnimationController.dispose();
    _badgePulseController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final currentOffset = _scrollController.offset;

    // Update scroll offset for collapsing header WITHOUT setState to avoid lagging
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

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<LocationProvider>(context, listen: false).fetchAddress();

      // Initialize Food provider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      if (foodProvider.categories.isEmpty) {
        foodProvider.fetchCategories();
        foodProvider.fetchOrderHistory();
        foodProvider.fetchPromotionalBanners();
        foodProvider.fetchDeals();
        foodProvider.fetchPopularItems();
        foodProvider.fetchTopRatedItems();
      } else {
        if (foodProvider.categories.isNotEmpty) {
          setState(() {
            _selectedCategory = foodProvider.categories.first;
          });
        }
      }

      // Initialize Grocery provider
      final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
      if (groceryProvider.items.isEmpty) {
        groceryProvider.refreshAll();
      }
    });
  }

  Future<void> _refreshData() async {
    final serviceProvider = Provider.of<ServiceProvider>(context, listen: false);

    if (serviceProvider.isFoodService) {
      // Refresh all food data using the new refreshAll() method
      final provider = Provider.of<FoodProvider>(context, listen: false);
      await provider.refreshAll();
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
    final foodProvider = Provider.of<FoodProvider>(context);
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final groceryProvider = Provider.of<GroceryProvider>(context);

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundSecondary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    if (foodProvider.categories.isNotEmpty && _selectedCategory == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedCategory = foodProvider.categories.first;
          });
        }
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        body: SafeArea(
          top: false,
          child: ClipRect(
            child: Stack(
              children: [
                AppRefreshIndicator(
                  onRefresh: _refreshData,
                  iconPath: serviceProvider.isFoodService ? Assets.icons.utensilsCrossed : Assets.icons.cart,
                  bgColor: colors.accentOrange,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(top: size.height * 0.16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          color: colors.backgroundSecondary,
                          child: Column(
                            children: [
                              SizedBox(height: KSpacing.lg.h),
                              _buildServiceSelector(),
                              SizedBox(height: KSpacing.lg.h),
                              PromotionalBannerCarousel(
                                banners: AppPromotionalBanners.getDefaultBanners(
                                  onReferralTap: () => context.push('/referral'),
                                  onWelcomeTap: () {
                                    // Handle welcome offer tap
                                  },
                                  onFlashDealTap: () {
                                    // Handle flash deal tap
                                  },
                                  onGrabMartTap: () {
                                    // Handle GrabMart tap
                                  },
                                ),
                              ),
                              SizedBox(height: KSpacing.lg.h),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeInOut,
                                switchOutCurve: Curves.easeInOut,
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.0, 0.02),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Column(
                                  key: ValueKey<bool>(serviceProvider.isFoodService),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Categories
                                    if (serviceProvider.isFoodService)
                                      _buildFoodCategories(foodProvider, isDark, size, colors)
                                    else if (serviceProvider.isGroceryService)
                                      _buildGroceryCategories(groceryProvider, isDark, size, colors),

                                    SizedBox(height: KSpacing.md.h),
                                    // 3. Deals & Offers (Unified for both Food & Grocery)
                                    Builder(
                                      builder: (context) {
                                        final groceryProvider = Provider.of<GroceryProvider>(context);

                                        return Column(
                                          children: [
                                            if (serviceProvider.isFoodService)
                                              Consumer<FoodDealsProvider>(
                                                builder: (context, provider, _) {
                                                  return DealsSection(
                                                    dealItems: provider.dealItems.take(10).toList(),
                                                    onSeeAll: () {},
                                                    onItemTap: (item) {
                                                      context.push('/food-details', extra: item);
                                                    },
                                                    isLoading: provider.isLoadingDeals,
                                                  );
                                                },
                                              )
                                            else
                                              DealsSection(
                                                dealItems: groceryProvider.deals
                                                    .take(10)
                                                    .map((e) => e.toFoodItem())
                                                    .toList(),
                                                originalItems: groceryProvider.deals.take(10).toList(),
                                                onSeeAll: () {},
                                                onItemTap: (item) {
                                                  final gp = Provider.of<GroceryProvider>(context, listen: false);
                                                  GroceryItem? originalItem;
                                                  try {
                                                    originalItem = gp.deals.firstWhere((g) => g.id == item.id);
                                                  } catch (_) {}
                                                  context.push('/grocery-details', extra: originalItem ?? item);
                                                },
                                                isLoading: groceryProvider.isLoadingDeals,
                                              ),
                                            SizedBox(height: KSpacing.lg.h),
                                          ],
                                        );
                                      },
                                    ),

                                    // 4. Fresh Arrivals (Grocery only)
                                    if (serviceProvider.isGroceryService) ...[
                                      Column(
                                        children: [
                                          FreshArrivalsSection(
                                            items: groceryProvider.freshArrivals.take(10).toList(),
                                            onSeeAll: () {},
                                            onItemTap: (item) {
                                              context.push('/grocery-details', extra: item);
                                            },
                                            isLoading: groceryProvider.isLoadingFreshArrivals,
                                          ),
                                          SizedBox(height: KSpacing.lg.h),
                                        ],
                                      ),
                                    ],

                                    // Order Again (Food only - CONDITIONAL: only show if user has order history)
                                    if (serviceProvider.isFoodService) ...[
                                      Consumer<FoodDiscoveryProvider>(
                                        builder: (context, provider, _) {
                                          if (provider.orderHistoryItems.isEmpty) return const SizedBox.shrink();
                                          return Column(
                                            children: [
                                              OrderAgainSection(
                                                recentOrders: provider.orderHistoryItems.take(10).toList(),
                                                onSeeAll: () {},
                                                onItemTap: (item) {
                                                  context.push('/food-details', extra: item);
                                                },
                                                isLoading: provider.isLoadingOrderHistory,
                                              ),
                                              SizedBox(height: KSpacing.lg.h),
                                            ],
                                          );
                                        },
                                      ),
                                    ],

                                    // 5. Popular Right Now (Unified for both Food & Grocery)
                                    Builder(
                                      builder: (context) {
                                        List<FoodItem> popularItems = [];
                                        List<dynamic>? originalPopularItems;
                                        bool isLoading = false;

                                        if (serviceProvider.isFoodService) {
                                          // Use backend popular items (sorted by orderCount)
                                          popularItems = foodProvider.popularItems;
                                          isLoading = foodProvider.isLoadingPopular;
                                        } else {
                                          final groceryProvider = Provider.of<GroceryProvider>(context);
                                          // Use backend popular items (sorted by orderCount)
                                          popularItems = groceryProvider.popularItems
                                              .map((e) => e.toFoodItem())
                                              .toList();
                                          originalPopularItems = groceryProvider.popularItems;
                                          isLoading = groceryProvider.isLoadingPopular;
                                        }

                                        return PopularSection(
                                          popularItems: popularItems,
                                          originalItems: originalPopularItems,
                                          onSeeAll: () {},
                                          onItemTap: (item) {
                                            if (serviceProvider.isGroceryService) {
                                              final groceryProvider = Provider.of<GroceryProvider>(
                                                context,
                                                listen: false,
                                              );
                                              // Safely find original item or use converted item
                                              GroceryItem? originalItem;
                                              try {
                                                originalItem = groceryProvider.popularItems.firstWhere(
                                                  (g) => g.id == item.id,
                                                );
                                              } catch (_) {
                                                // Item not found in popular, use converted item
                                              }
                                              context.push('/grocery-details', extra: originalItem ?? item);
                                            } else {
                                              context.push('/food-details', extra: item);
                                            }
                                          },
                                          isLoading: isLoading,
                                        );
                                      },
                                    ),
                                    SizedBox(height: KSpacing.lg.h),

                                    // 6. Buy Again (Grocery only - CONDITIONAL: only show if user has order history)
                                    if (serviceProvider.isGroceryService &&
                                        groceryProvider.buyAgainItems.isNotEmpty) ...[
                                      Column(
                                        children: [
                                          OrderAgainSection(
                                            recentOrders: groceryProvider.buyAgainItems
                                                .take(10)
                                                .map((item) => item.toFoodItem())
                                                .toList(),
                                            originalItems: groceryProvider.buyAgainItems.take(10).toList(),
                                            onSeeAll: () {},
                                            onItemTap: (foodItem) {
                                              // Safely find original grocery item
                                              GroceryItem? groceryItem;
                                              try {
                                                groceryItem = groceryProvider.buyAgainItems.firstWhere(
                                                  (item) => item.id == foodItem.id,
                                                );
                                              } catch (_) {
                                                // Item not found, use converted item
                                              }
                                              context.push('/grocery-details', extra: groceryItem ?? foodItem);
                                            },
                                            isLoading: groceryProvider.isLoadingBuyAgain,
                                          ),
                                          SizedBox(height: KSpacing.lg.h),
                                        ],
                                      ),
                                    ],

                                    // Unified Banners (Promo Section - Food only)
                                    if (serviceProvider.isFoodService) ...[
                                      Consumer<FoodBannerProvider>(
                                        builder: (context, provider, _) {
                                          return PromoSection(
                                            banners: provider.promotionalBanners,
                                            onSeeAll: () {},
                                            isLoading: provider.isLoadingBanners,
                                          );
                                        },
                                      ),
                                    ],

                                    // 7. Top Rated Dishes (Unified for both Food & Grocery)
                                    Builder(
                                      builder: (context) {
                                        List<FoodItem> topRatedItems = [];
                                        List<dynamic>? originalTopRatedItems;
                                        bool isLoading = false;

                                        if (serviceProvider.isFoodService) {
                                          // Use backend top-rated items (sorted by rating)
                                          topRatedItems = foodProvider.topRatedItems;
                                          isLoading = foodProvider.isLoadingTopRated;
                                        } else {
                                          final groceryProvider = Provider.of<GroceryProvider>(context);
                                          // Use backend top-rated items (sorted by rating)
                                          topRatedItems = groceryProvider.topRatedItems
                                              .map((e) => e.toFoodItem())
                                              .toList();
                                          originalTopRatedItems = groceryProvider.topRatedItems;
                                          isLoading = groceryProvider.isLoadingTopRated;
                                        }

                                        return TopRatedSection(
                                          topRatedItems: topRatedItems,
                                          originalItems: originalTopRatedItems,
                                          onSeeAll: () {},
                                          onItemTap: (item) {
                                            if (serviceProvider.isGroceryService) {
                                              // Safely find original grocery item by ID
                                              final groceryProvider = Provider.of<GroceryProvider>(
                                                context,
                                                listen: false,
                                              );
                                              GroceryItem? originalItem;
                                              try {
                                                originalItem = groceryProvider.topRatedItems.firstWhere(
                                                  (g) => g.id == item.id,
                                                );
                                              } catch (_) {
                                                // Item not found in top rated, use converted item
                                              }
                                              context.push('/grocery-details', extra: originalItem ?? item);
                                            } else {
                                              context.push('/food-details', extra: item);
                                            }
                                          },
                                          isLoading: isLoading,
                                        );
                                      },
                                    ),
                                    SizedBox(height: KSpacing.lg.h),

                                    // 8. Store Specials (Grocery only)
                                    if (serviceProvider.isGroceryService) ...[
                                      Column(
                                        children: [
                                          StoreSpecialsSection(
                                            storeSpecials: groceryProvider.storeSpecials,
                                            isLoading: groceryProvider.isLoadingStoreSpecials,
                                            onSeeAll: () {
                                              // TODO: Navigate to all store specials
                                            },
                                            onItemTap: (item) {
                                              context.push('/grocery-details', extra: item);
                                            },
                                            onStoreTap: (store) {
                                              // TODO: Navigate to store page
                                            },
                                          ),
                                          SizedBox(height: KSpacing.lg.h),
                                        ],
                                      ),
                                    ],

                                    // 9. Browse All Groceries (Grocery only)
                                    if (serviceProvider.isGroceryService) ...[
                                      Builder(
                                        builder: (context) {
                                          final groceryProvider = Provider.of<GroceryProvider>(context);

                                          return BrowseAllGroceriesSection(
                                            items: groceryProvider.items,
                                            onItemTap: (item) {
                                              context.push('/grocery-details', extra: item);
                                            },
                                            isLoading: groceryProvider.isLoadingItems,
                                          );
                                        },
                                      ),
                                      SizedBox(height: KSpacing.lg.h),
                                    ],
                                  ],
                                ),
                              ),

                              // Recommended (Food Specific or Generic)
                              if (serviceProvider.isFoodService) ...[
                                SectionHeader(
                                  title: "Recommended For You",
                                  sectionIcon: Assets.icons.sparkles,
                                  sectionTotal: 1,
                                  accentColor: colors.accentOrange,
                                  onSeeAll: () {},
                                ),
                                SizedBox(height: KSpacing.lg.h),
                                _buildRecommendedFoodItems(foodProvider, size, colors, isDark),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Positioned umbrella header layer (collapsible)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildCollapsibleHomeHeader(context, size, colors, isDark, locationProvider, foodProvider),
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

  Builder _buildRecommendedFoodItems(FoodProvider itemsProvider, Size size, AppColorsExtension colors, bool isDark) {
    return Builder(
      builder: (context) {
        List<FoodItem> recommendedFoods = [];

        List<FoodItem> allFoods = [];

        // Show skeleton only when categories are empty (initial load or empty state)
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

        if (allFoods.isNotEmpty) {
          recommendedFoods = allFoods.take(_recommendedDisplayedCount.clamp(0, allFoods.length)).toList();
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

        return Column(
          children: [
            ListView.builder(
              padding: EdgeInsets.zero,
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
                            provider.addToCart(item, context: context);
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
                            colorFilter: ColorFilter.mode(
                              isInCart ? Colors.white : colors.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // Loading more indicator
            if (allFoods.length > _recommendedDisplayedCount) ...[
              Builder(
                builder: (context) {
                  // Auto-load more items after a delay
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted && allFoods.length > _recommendedDisplayedCount) {
                      setState(() {
                        _recommendedDisplayedCount = (_recommendedDisplayedCount + 10).clamp(0, allFoods.length);
                      });
                    }
                  });

                  return LoadingMore(
                    colors: colors,
                    spinnerColor: colors.accentOrange,
                    borderColor: colors.accentOrange,
                  );
                },
              ),
              SizedBox(height: 16.h),
            ],
          ],
        );
      },
    );
  }

  Builder _buildFoodCategories(FoodProvider itemsProvider, bool isDark, Size size, AppColorsExtension colors) {
    return Builder(
      builder: (context) {
        if (itemsProvider.isLoading && itemsProvider.categories.isEmpty) {
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: "Categories",
              sectionIcon: Assets.icons.viewGrid,
              accentColor: colors.accentOrange,
              sectionTotal: categoriesToShow.length.toInt(),
              onSeeAll: () {},
            ),
            SizedBox(height: 10.h),
            ServiceCategoryList<FoodCategoryModel>(
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
            ),
          ],
        );
      },
    );
  }

  HomeSearch _buildHomeSearch(FoodProvider itemsProvider) {
    return HomeSearch(
      categories: itemsProvider.categories,
      activeFilter: _activeFilter,
      hintText: "Search & Explore GrabGo... ",
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

    // // Uncomment if you need skeleton loading state
    // final colors = context.appColors;
    // final isDark = Theme.of(context).brightness == Brightness.dark;
    // if (itemsProvider.isLoading) {
    //    return ServiceSelectorSkeleton(colors: colors, isDark: isDark);
    // }

    return ServiceSelector(
      services: AppServices.all,
      initialSelectedService: serviceProvider.currentService,
      onServiceSelected: (ServiceModel service) {
        debugPrint("Service Selected: ${service.id}");
        serviceProvider.selectService(service);

        // Load data for the selected service
        if (service.id == 'groceries') {
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

  Widget _buildCollapsibleHomeHeader(
    BuildContext context,
    Size size,
    AppColorsExtension colors,
    bool isDark,
    LocationProvider locationProvider,
    FoodProvider foodProvider,
  ) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);

        final expandedHeight = size.height * 0.22;

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
              child: _buildHomeHeader(context, size, colors, isDark, locationProvider, foodProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeHeader(
    BuildContext context,
    Size size,
    AppColorsExtension colors,
    bool isDark,
    LocationProvider locationProvider,
    FoodProvider foodProvider,
  ) {
    return SizedBox.expand(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, MediaQuery.of(context).padding.top + 10.h, 20.w, 6.h),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      context.push("/location-picker");
                    },
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          Assets.icons.mapPin,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          locationProvider.address.isEmpty ? "Fetching location..." : locationProvider.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        SizedBox(width: 6.w),
                        SvgPicture.asset(
                          Assets.icons.navArrowDown,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12.w),

                Row(
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
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          _buildHomeSearch(foodProvider),
        ],
      ),
    );
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
  Widget _buildGroceryCategories(GroceryProvider groceryProvider, bool isDark, Size size, AppColorsExtension colors) {
    // Combine categories
    final categoriesWithType = [...groceryProvider.categories];

    if (groceryProvider.isLoadingCategories) {
      return CategorySkeleton(colors: colors, isDark: isDark, size: size);
    }

    if (groceryProvider.categories.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Categories",
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Navigate to browse page or all categories
                    },
                    borderRadius: BorderRadius.circular(20.r),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "See All",
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.accentOrange),
                        ),
                        SizedBox(width: 4.w),
                        SvgPicture.asset(
                          Assets.icons.navArrowRight,
                          package: 'grab_go_shared',
                          height: 14.h,
                          width: 14.w,
                          colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: KSpacing.md.h),
          ServiceCategoryList<GroceryCategory>(
            categories: categoriesWithType,
            getName: (cat) => cat.name,
            getEmoji: (cat) => cat.emoji,
            getId: (cat) => cat.id,
            initialSelectedCategory: _selectedGroceryCategory,
            onCategorySelected: (category) {
              setState(() {
                _selectedGroceryCategory = category;
              });
            },
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
