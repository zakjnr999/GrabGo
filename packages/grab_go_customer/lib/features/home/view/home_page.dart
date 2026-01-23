import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_category.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_category.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/features/grabmart/viewmodel/grabmart_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_banner_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_deals_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_discovery_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_customer/shared/widgets/app_refresh_indicator.dart';
import 'package:grab_go_customer/shared/widgets/category_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/food_item_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
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
import 'package:grab_go_customer/shared/widgets/browse_items_grid.dart';
import 'package:grab_go_customer/shared/widgets/promotional_banner_carousel.dart';
import 'package:grab_go_customer/features/home/model/promotional_banner.dart';
import 'package:grab_go_customer/shared/viewmodels/service_provider.dart';
import 'package:grab_go_customer/shared/widgets/home_page_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/location_accuracy_popup.dart';
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
      Provider.of<NativeLocationProvider>(context, listen: false).fetchAddress();

      // Initialize Food provider
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      if (foodProvider.categories.isEmpty) {
        foodProvider.refreshAll();
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

      // Initialize Pharmacy provider
      final pharmacyProvider = Provider.of<PharmacyProvider>(context, listen: false);
      if (pharmacyProvider.items.isEmpty) {
        pharmacyProvider.refreshAll();
      }

      // Initialize GrabMart provider
      final grabMartProvider = Provider.of<GrabMartProvider>(context, listen: false);
      if (grabMartProvider.items.isEmpty) {
        grabMartProvider.refreshAll();
      }
    });
  }

  Future<void> _refreshData() async {
    final serviceProvider = Provider.of<ServiceProvider>(context, listen: false);

    if (serviceProvider.isFoodService) {
      // Refresh all food data
      final provider = Provider.of<FoodProvider>(context, listen: false);
      await provider.refreshAll(forceRefresh: true);
    } else if (serviceProvider.isGroceryService) {
      // Refresh grocery data
      final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
      await groceryProvider.refreshAll(forceRefresh: true);
    } else if (serviceProvider.isPharmacyService) {
      // Refresh pharmacy data
      final pharmacyProvider = Provider.of<PharmacyProvider>(context, listen: false);
      await pharmacyProvider.refreshAll(forceRefresh: true);
    } else if (serviceProvider.isStoresService) {
      // Refresh GrabMart data
      final grabMartProvider = Provider.of<GrabMartProvider>(context, listen: false);
      await grabMartProvider.refreshAll(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    final locationProvider = Provider.of<NativeLocationProvider>(context);
    final foodProvider = Provider.of<FoodProvider>(context);
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final groceryProvider = Provider.of<GroceryProvider>(context);
    final pharmacyProvider = Provider.of<PharmacyProvider>(context);
    final grabMartProvider = Provider.of<GrabMartProvider>(context);

    bool shouldShowSkeleton = false;
    if (serviceProvider.isGroceryService) {
      shouldShowSkeleton = groceryProvider.items.isEmpty;
    } else if (serviceProvider.isPharmacyService) {
      shouldShowSkeleton = pharmacyProvider.items.isEmpty;
    } else if (serviceProvider.isStoresService) {
      shouldShowSkeleton = grabMartProvider.items.isEmpty;
    } else if (serviceProvider.isFoodService) {
      shouldShowSkeleton = foodProvider.categories.isEmpty;
    }

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
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          top: false,
          child: ClipRect(
            child: Stack(
              children: [
                AppRefreshIndicator(
                  onRefresh: _refreshData,
                  iconPath: serviceProvider.isFoodService ? Assets.icons.utensilsCrossed : Assets.icons.cart,
                  bgColor: colors.accentOrange,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: shouldShowSkeleton
                        ? const NeverScrollableScrollPhysics()
                        : const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.only(top: size.height * 0.16),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            color: colors.backgroundPrimary,
                            child: shouldShowSkeleton
                                ? const HomePageSkeleton()
                                : Column(
                                    children: [
                                      SizedBox(height: KSpacing.lg.h),
                                      _buildServiceSelector(),
                                      SizedBox(height: KSpacing.lg.h),
                                      PromotionalBannerCarousel(
                                        banners: AppPromotionalBanners.getDefaultBanners(
                                          onReferralTap: () => context.push('/referral'),
                                          onWelcomeTap: () {},
                                          onFlashDealTap: () {},
                                          onGrabMartTap: () {},
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
                                            _buildCategories(
                                              serviceProvider,
                                              foodProvider,
                                              groceryProvider,
                                              isDark,
                                              size,
                                              colors,
                                            ),
                                            SizedBox(height: KSpacing.md.h),
                                            // Service-specific sections
                                            if (serviceProvider.isFoodService || serviceProvider.isGroceryService) ...[
                                              _buildDealsSection(serviceProvider, groceryProvider),
                                              _buildFreshArrivalsSection(serviceProvider, groceryProvider),
                                              _buildOrderAgainSection(serviceProvider),
                                              _buildPopularSection(serviceProvider, foodProvider),
                                              _buildBuyAgainSection(serviceProvider, groceryProvider),
                                              _buildPromoBanners(serviceProvider),
                                              _buildTopRatedSection(serviceProvider, foodProvider),
                                              _buildBrowseAllGroceriesSection(serviceProvider, groceryProvider),
                                            ] else if (serviceProvider.isPharmacyService) ...[
                                              _buildPharmacyOnSaleSection(),
                                              _buildPharmacyPopularSection(),
                                              _buildPharmacyTopRatedSection(),
                                              _buildPharmacyItemsGrid(),
                                            ] else if (serviceProvider.isStoresService) ...[
                                              _buildGrabMartSpecialOffersSection(),
                                              _buildGrabMartQuickPicksSection(),
                                              _buildGrabMartTopRatedSection(),
                                              _buildGrabMartItemsGrid(),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      if (!shouldShowSkeleton)
                        ..._buildRecommendedSectionSlivers(serviceProvider, foodProvider, colors, size, isDark),

                      SliverToBoxAdapter(child: SizedBox(height: KSpacing.lg.h)),
                    ],
                  ),
                ),

                // Positioned umbrella header layer
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildCollapsibleHomeHeader(context, size, colors, isDark, locationProvider, foodProvider),
                ),

                // Location accuracy popup (appears below header when needed)
                ValueListenableBuilder<double>(
                  valueListenable: _scrollOffsetNotifier,
                  builder: (context, scrollOffset, _) {
                    final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);
                    final opacity = (1.0 - (collapseProgress * 2)).clamp(0.0, 1.0);

                    if (opacity == 0 || !locationProvider.shouldShowAccuracyPopup) return const SizedBox.shrink();

                    return Positioned(
                      top: MediaQuery.of(context).padding.top + 45.h,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: opacity,
                        child: LocationAccuracyPopup(
                          distanceInMeters: locationProvider.distanceFromSavedLocation ?? 0,
                          onUpdateLocation: () async {
                            await locationProvider.updateToCurrentLocation();
                          },
                          onDismiss: () {
                            locationProvider.dismissAccuracyPopup();
                          },
                        ),
                      ),
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
              title: "Food Categories",
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
    final pharmacyProvider = Provider.of<PharmacyProvider>(context, listen: false);
    final grabMartProvider = Provider.of<GrabMartProvider>(context, listen: false);

    return ServiceSelector(
      services: AppServices.all,
      initialSelectedService: serviceProvider.currentService,
      onServiceSelected: (ServiceModel service) {
        debugPrint("Service Selected: ${service.id}");
        serviceProvider.selectService(service);

        // Load data for the selected service
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (service.id == 'groceries') {
            if (groceryProvider.items.isEmpty) {
              groceryProvider.refreshAll();
            }
          } else if (service.id == 'food') {
            if (foodProvider.categories.isEmpty) {
              foodProvider.refreshAll();
            }
          } else if (service.id == 'pharmacy') {
            if (pharmacyProvider.items.isEmpty) {
              pharmacyProvider.refreshAll();
            }
          } else if (service.id == 'convenience') {
            if (grabMartProvider.items.isEmpty) {
              grabMartProvider.refreshAll();
            }
          }
        });
      },
    );
  }

  Widget _buildCollapsibleHomeHeader(
    BuildContext context,
    Size size,
    AppColorsExtension colors,
    bool isDark,
    NativeLocationProvider locationProvider,
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
    NativeLocationProvider locationProvider,
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
                        Flexible(
                          child: Text(
                            locationProvider.address.isEmpty ? "Fetching location..." : locationProvider.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
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

  /// Build service selector
  Widget buildServiceSelector() {
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
    final foodProvider = Provider.of<FoodProvider>(context, listen: false);

    return ServiceSelector(
      services: AppServices.all,
      initialSelectedService: serviceProvider.currentService,
      onServiceSelected: (service) {
        serviceProvider.selectService(service);

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
          SectionHeader(
            title: "Categories",
            sectionIcon: Assets.icons.viewGrid,
            accentColor: colors.accentOrange,
            sectionTotal: groceryProvider.categories.length.toInt(),
            onSeeAll: () {},
          ),
          SizedBox(height: 10.h),
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

  Widget _buildPharmacyCategories(bool isDark, Size size, AppColorsExtension colors) {
    return Consumer<PharmacyProvider>(
      builder: (context, pharmacyProvider, _) {
        if (pharmacyProvider.isLoadingCategories) {
          return CategorySkeleton(colors: colors, isDark: isDark, size: size);
        }

        if (pharmacyProvider.categories.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: "Categories",
                sectionIcon: Assets.icons.viewGrid,
                accentColor: colors.accentOrange,
                sectionTotal: pharmacyProvider.categories.length.toInt(),
                onSeeAll: () {},
              ),
              SizedBox(height: 10.h),
              ServiceCategoryList<PharmacyCategory>(
                categories: pharmacyProvider.categories,
                getName: (cat) => cat.name,
                getEmoji: (cat) => cat.emoji,
                getId: (cat) => cat.id,
                initialSelectedCategory: null,
                autoNotify: false,
                onCategorySelected: (category) {
                  context.push(
                    '/categoryItems',
                    extra: {
                      'categoryId': category.id,
                      'categoryName': category.name,
                      'categoryEmoji': category.emoji,
                      'serviceType': 'pharmacy',
                    },
                  );
                },
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildGrabMartCategories(bool isDark, Size size, AppColorsExtension colors) {
    return Consumer<GrabMartProvider>(
      builder: (context, grabMartProvider, _) {
        if (grabMartProvider.isLoadingCategories) {
          return CategorySkeleton(colors: colors, isDark: isDark, size: size);
        }

        if (grabMartProvider.categories.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: "Categories",
                sectionIcon: Assets.icons.viewGrid,
                accentColor: colors.accentOrange,
                sectionTotal: grabMartProvider.categories.length.toInt(),
                onSeeAll: () {},
              ),
              SizedBox(height: 10.h),
              ServiceCategoryList<GrabMartCategory>(
                categories: grabMartProvider.categories,
                getName: (cat) => cat.name,
                getEmoji: (cat) => cat.emoji,
                getId: (cat) => cat.id,
                initialSelectedCategory: null,
                autoNotify: false,
                onCategorySelected: (category) {
                  context.push(
                    '/categoryItems',
                    extra: {
                      'categoryId': category.id,
                      'categoryName': category.name,
                      'categoryEmoji': category.emoji,
                      'serviceType': 'convenience',
                    },
                  );
                },
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCategories(
    ServiceProvider serviceProvider,
    FoodProvider foodProvider,
    GroceryProvider groceryProvider,
    bool isDark,
    Size size,
    AppColorsExtension colors,
  ) {
    if (serviceProvider.isFoodService) {
      return _buildFoodCategories(foodProvider, isDark, size, colors);
    } else if (serviceProvider.isGroceryService) {
      return _buildGroceryCategories(groceryProvider, isDark, size, colors);
    } else if (serviceProvider.isPharmacyService) {
      return _buildPharmacyCategories(isDark, size, colors);
    } else if (serviceProvider.isStoresService) {
      return _buildGrabMartCategories(isDark, size, colors);
    }
    return const SizedBox.shrink();
  }

  Widget _buildDealsSection(ServiceProvider serviceProvider, GroceryProvider groceryProvider) {
    return Column(
      children: [
        if (serviceProvider.isFoodService)
          Consumer<FoodDealsProvider>(
            builder: (context, provider, _) {
              return DealsSection(
                dealItems: provider.dealItems.take(10).toList(),
                onSeeAll: () {},
                onItemTap: (item) {
                  context.push('/foodDetails', extra: item);
                },
                isLoading: provider.isLoadingDeals,
              );
            },
          )
        else
          DealsSection(
            dealItems: groceryProvider.deals.take(10).map((e) => e.toFoodItem()).toList(),
            originalItems: groceryProvider.deals.take(10).toList(),
            onSeeAll: () {},
            onItemTap: (item) {
              final gp = Provider.of<GroceryProvider>(context, listen: false);
              GroceryItem? originalItem;
              try {
                originalItem = gp.deals.firstWhere((g) => g.id == item.id);
              } catch (_) {}
              context.push('/foodDetails', extra: originalItem ?? item);
            },
            isLoading: groceryProvider.isLoadingDeals,
          ),
        SizedBox(height: KSpacing.lg.h),
      ],
    );
  }

  Widget _buildFreshArrivalsSection(ServiceProvider serviceProvider, GroceryProvider groceryProvider) {
    if (!serviceProvider.isGroceryService) return const SizedBox.shrink();
    return Column(
      children: [
        FreshArrivalsSection(
          items: groceryProvider.freshArrivals.take(10).toList(),
          onSeeAll: () {},
          onItemTap: (item) {
            context.push('/foodDetails', extra: item);
          },
          isLoading: groceryProvider.isLoadingFreshArrivals,
        ),
        SizedBox(height: KSpacing.lg.h),
      ],
    );
  }

  Widget _buildOrderAgainSection(ServiceProvider serviceProvider) {
    if (!serviceProvider.isFoodService) return const SizedBox.shrink();
    return Consumer<FoodDiscoveryProvider>(
      builder: (context, provider, _) {
        if (provider.orderHistoryItems.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            OrderAgainSection(
              recentOrders: provider.orderHistoryItems.take(10).toList(),
              onSeeAll: () {},
              onItemTap: (item) {
                context.push('/foodDetails', extra: item);
              },
              isLoading: provider.isLoadingOrderHistory,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildPopularSection(ServiceProvider serviceProvider, FoodProvider foodProvider) {
    return Builder(
      builder: (context) {
        List<FoodItem> popularItems = [];
        List<dynamic>? originalPopularItems;
        bool isLoading = false;

        if (serviceProvider.isFoodService) {
          popularItems = foodProvider.popularItems;
          isLoading = foodProvider.isLoadingPopular;
        } else {
          final groceryProvider = Provider.of<GroceryProvider>(context);
          popularItems = groceryProvider.popularItems.map((e) => e.toFoodItem()).toList();
          originalPopularItems = groceryProvider.popularItems;
          isLoading = groceryProvider.isLoadingPopular;
        }

        return Column(
          children: [
            PopularSection(
              popularItems: popularItems,
              originalItems: originalPopularItems,
              onSeeAll: () {},
              onItemTap: (item) {
                if (serviceProvider.isGroceryService) {
                  final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
                  GroceryItem? originalItem;
                  try {
                    originalItem = groceryProvider.popularItems.firstWhere((g) => g.id == item.id);
                  } catch (_) {}
                  context.push('/foodDetails', extra: originalItem ?? item);
                } else {
                  context.push('/foodDetails', extra: item);
                }
              },
              isLoading: isLoading,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildBuyAgainSection(ServiceProvider serviceProvider, GroceryProvider groceryProvider) {
    if (!serviceProvider.isGroceryService || groceryProvider.buyAgainItems.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        OrderAgainSection(
          recentOrders: groceryProvider.buyAgainItems.take(10).map((item) => item.toFoodItem()).toList(),
          originalItems: groceryProvider.buyAgainItems.take(10).toList(),
          onSeeAll: () {},
          onItemTap: (foodItem) {
            GroceryItem? groceryItem;
            try {
              groceryItem = groceryProvider.buyAgainItems.firstWhere((item) => item.id == foodItem.id);
            } catch (_) {}
            context.push('/foodDetails', extra: groceryItem ?? foodItem);
          },
          isLoading: groceryProvider.isLoadingBuyAgain,
        ),
        SizedBox(height: KSpacing.lg.h),
      ],
    );
  }

  Widget _buildPromoBanners(ServiceProvider serviceProvider) {
    if (!serviceProvider.isFoodService) return const SizedBox.shrink();
    return Consumer<FoodBannerProvider>(
      builder: (context, provider, _) {
        return PromoSection(
          banners: provider.promotionalBanners,
          onSeeAll: () {},
          isLoading: provider.isLoadingBanners,
        );
      },
    );
  }

  Widget _buildTopRatedSection(ServiceProvider serviceProvider, FoodProvider foodProvider) {
    return Builder(
      builder: (context) {
        List<FoodItem> topRatedItems = [];
        List<dynamic>? originalTopRatedItems;
        bool isLoading = false;

        if (serviceProvider.isFoodService) {
          topRatedItems = foodProvider.topRatedItems;
          isLoading = foodProvider.isLoadingTopRated;
        } else {
          final groceryProvider = Provider.of<GroceryProvider>(context);
          topRatedItems = groceryProvider.topRatedItems.map((e) => e.toFoodItem()).toList();
          originalTopRatedItems = groceryProvider.topRatedItems;
          isLoading = groceryProvider.isLoadingTopRated;
        }

        return Column(
          children: [
            TopRatedSection(
              topRatedItems: topRatedItems,
              originalItems: originalTopRatedItems,
              onSeeAll: () {},
              onItemTap: (item) {
                if (serviceProvider.isGroceryService) {
                  final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
                  GroceryItem? originalItem;
                  try {
                    originalItem = groceryProvider.topRatedItems.firstWhere((g) => g.id == item.id);
                  } catch (_) {}
                  context.push('/foodDetails', extra: originalItem ?? item);
                } else {
                  context.push('/foodDetails', extra: item);
                }
              },
              isLoading: isLoading,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildBrowseAllGroceriesSection(ServiceProvider serviceProvider, GroceryProvider groceryProvider) {
    if (!serviceProvider.isGroceryService) return const SizedBox.shrink();
    return Column(
      children: [
        BrowseAllGroceriesSection(
          items: groceryProvider.items,
          onItemTap: (item) => context.push('/foodDetails', extra: item),
          isLoading: groceryProvider.isLoadingItems,
        ),
        SizedBox(height: KSpacing.lg.h),
      ],
    );
  }

  List<Widget> _buildRecommendedSectionSlivers(
    ServiceProvider serviceProvider,
    FoodProvider foodProvider,
    AppColorsExtension colors,
    Size size,
    bool isDark,
  ) {
    if (!serviceProvider.isFoodService) return [];

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: "Recommended For You",
              sectionIcon: Assets.icons.sparkles,
              sectionTotal: foodProvider.recommendedItems.length,
              accentColor: colors.accentOrange,
              onSeeAll: () {},
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        ),
      ),
      ..._buildRecommendedFoodItemsSliver(foodProvider, size, colors, isDark),
    ];
  }

  List<Widget> _buildRecommendedFoodItemsSliver(
    FoodProvider itemsProvider,
    Size size,
    AppColorsExtension colors,
    bool isDark,
  ) {
    final recommendedItems = itemsProvider.recommendedItems;
    final isLoading = itemsProvider.isLoadingRecommended;

    // Show skeleton while loading
    if (isLoading && recommendedItems.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: FoodItemSkeleton(colors: colors, isDark: isDark, size: size),
        ),
      ];
    }

    // Show empty state if no items
    if (recommendedItems.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: KSpacing.xl.h),
            child: Center(
              child: Text('No recommendations available', style: TextStyle(color: colors.textSecondary)),
            ),
          ),
        ),
      ];
    }

    final displayedItems = recommendedItems.take(_recommendedDisplayedCount.clamp(0, recommendedItems.length)).toList();

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = displayedItems[index];
          return Consumer<CartProvider>(
            builder: (context, provider, _) {
              final bool isInCart = provider.cartItems.containsKey(item);
              return FoodItemCard(
                item: item,
                onTap: () => context.push('/foodDetails', extra: item),
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
                      colorFilter: ColorFilter.mode(isInCart ? Colors.white : colors.textPrimary, BlendMode.srcIn),
                    ),
                  ),
                ),
              );
            },
          );
        }, childCount: displayedItems.length),
      ),
      if (recommendedItems.length > _recommendedDisplayedCount)
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && recommendedItems.length > _recommendedDisplayedCount) {
                  setState(() {
                    _recommendedDisplayedCount = (_recommendedDisplayedCount + 10).clamp(0, recommendedItems.length);
                  });
                }
              });
              return Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: LoadingMore(colors: colors, spinnerColor: colors.accentOrange, borderColor: colors.accentOrange),
              );
            },
          ),
        ),
    ];
  }

  // ==================== PHARMACY SECTIONS ====================

  // ==================== PHARMACY SECTIONS ====================

  Widget _buildPharmacyOnSaleSection() {
    return Consumer<PharmacyProvider>(
      builder: (context, provider, _) {
        if (provider.onSaleItems.isEmpty) return const SizedBox.shrink();

        // Convert PharmacyItem to FoodItem for DealsSection widget
        final dealItems = provider.onSaleItems.take(10).map((item) {
          return FoodItem(
            id: item.id,
            name: item.name,
            description: item.description,
            price: item.price,
            discountPercentage: item.discountPercentage,
            image: item.image,
            rating: item.rating,
            deliveryTimeMinutes: 30,
            sellerName: item.storeName ?? 'Pharmacy',
            sellerId: item.storeId.hashCode % 1000000,
            restaurantId: item.storeId,
            restaurantImage: item.storeLogo ?? '',
            orderCount: item.orderCount,
          );
        }).toList();

        return Column(
          children: [
            DealsSection(
              title: "Exclusive Medical Deals",
              icon: Assets.icons.tag,
              dealItems: dealItems,
              onSeeAll: () => Provider.of<NavigationProvider>(context, listen: false).setIndex(1),
              onItemTap: (item) {
                final originalItem = provider.items.firstWhere((i) => i.id == item.id);
                context.push('/foodDetails', extra: originalItem);
              },
              isLoading: provider.isLoadingItems,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildPharmacyPopularSection() {
    return Consumer<PharmacyProvider>(
      builder: (context, provider, _) {
        if (provider.popularItems.isEmpty) return const SizedBox.shrink();

        // Convert PharmacyItem to FoodItem for PopularSection widget
        final popularItems = provider.popularItems.take(10).map((item) {
          return FoodItem(
            id: item.id,
            name: item.name,
            description: item.description,
            price: item.price,
            discountPercentage: item.discountPercentage,
            image: item.image,
            rating: item.rating,
            deliveryTimeMinutes: 30,
            sellerName: item.storeName ?? 'Pharmacy',
            sellerId: item.storeId.hashCode % 1000000,
            restaurantId: item.storeId,
            restaurantImage: item.storeLogo ?? '',
            orderCount: item.orderCount,
          );
        }).toList();

        return Column(
          children: [
            PopularSection(
              title: "Daily Health Needs",
              icon: Assets.icons.pharmacyCrossCircle,
              popularItems: popularItems,
              onSeeAll: () => Provider.of<NavigationProvider>(context, listen: false).setIndex(1),
              onItemTap: (item) {
                PharmacyItem? originalItem;
                try {
                  originalItem = provider.popularItems.firstWhere((i) => i.id == item.id);
                } catch (_) {}
                context.push('/foodDetails', extra: originalItem ?? item);
              },
              isLoading: provider.isLoadingItems,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildPharmacyTopRatedSection() {
    return Consumer<PharmacyProvider>(
      builder: (context, provider, _) {
        if (provider.topRatedItems.isEmpty) return const SizedBox.shrink();

        final topRatedItems = provider.topRatedItems.take(10).map((item) {
          return FoodItem(
            id: item.id,
            name: item.name,
            description: item.description,
            price: item.price,
            discountPercentage: item.discountPercentage,
            image: item.image,
            rating: item.rating,
            deliveryTimeMinutes: 30,
            sellerName: item.storeName ?? 'Pharmacy',
            sellerId: item.storeId.hashCode % 1000000,
            restaurantId: item.storeId,
            restaurantImage: item.storeLogo ?? '',
            orderCount: item.orderCount,
          );
        }).toList();

        return Column(
          children: [
            TopRatedSection(
              title: "Highly Rated Wellness",
              icon: Assets.icons.star,
              topRatedItems: topRatedItems,
              onSeeAll: () => Provider.of<NavigationProvider>(context, listen: false).setIndex(1),
              onItemTap: (item) {
                PharmacyItem? originalItem;
                try {
                  originalItem = provider.topRatedItems.firstWhere((i) => i.id == item.id);
                } catch (_) {}
                context.push('/foodDetails', extra: originalItem ?? item);
              },
              isLoading: provider.isLoadingItems,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildPharmacyItemsGrid() {
    return Consumer<PharmacyProvider>(
      builder: (context, provider, _) {
        if (provider.items.isEmpty && !provider.isLoadingItems) return const SizedBox.shrink();

        return Column(
          children: [
            BrowseItemsGrid(
              title: "Browse All Pharmacy",
              icon: Assets.icons.squareMenu,
              items: provider.items,
              onItemTap: (item) => context.push('/foodDetails', extra: item),
              isLoading: provider.isLoadingItems && provider.items.isEmpty,
              accentColor: context.appColors.accentOrange,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  // ==================== GRABMART SECTIONS ====================

  Widget _buildGrabMartSpecialOffersSection() {
    return Consumer<GrabMartProvider>(
      builder: (context, provider, _) {
        if (provider.specialOffers.isEmpty) return const SizedBox.shrink();

        // Convert GrabMartItem to FoodItem for DealsSection widget
        final dealItems = provider.specialOffers.take(10).map((item) {
          return FoodItem(
            id: item.id,
            name: item.name,
            description: item.description,
            price: item.price,
            discountPercentage: item.discountPercentage,
            image: item.image,
            rating: item.rating,
            deliveryTimeMinutes: 20,
            sellerName: item.storeName ?? 'GrabMart',
            sellerId: item.storeId.hashCode % 1000000,
            restaurantId: item.storeId,
            restaurantImage: item.storeLogo ?? '',
            orderCount: item.orderCount,
          );
        }).toList();

        return Column(
          children: [
            DealsSection(
              title: "Groceries & More Deals",
              icon: Assets.icons.tag,
              dealItems: dealItems,
              onSeeAll: () => Provider.of<NavigationProvider>(context, listen: false).setIndex(1),
              onItemTap: (item) {
                GrabMartItem? originalItem;
                try {
                  originalItem = provider.specialOffers.firstWhere((i) => i.id == item.id);
                } catch (_) {}
                context.push('/foodDetails', extra: originalItem ?? item);
              },
              isLoading: provider.isLoadingItems,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildGrabMartQuickPicksSection() {
    return Consumer<GrabMartProvider>(
      builder: (context, provider, _) {
        if (provider.quickPicks.isEmpty) return const SizedBox.shrink();

        // Convert GrabMartItem to FoodItem for PopularSection widget
        final quickPickItems = provider.quickPicks.take(10).map((item) {
          return FoodItem(
            id: item.id,
            name: item.name,
            description: item.description,
            price: item.price,
            discountPercentage: item.discountPercentage,
            image: item.image,
            rating: item.rating,
            deliveryTimeMinutes: 20,
            sellerName: item.storeName ?? 'GrabMart',
            sellerId: item.storeId.hashCode % 1000000,
            restaurantId: item.storeId,
            restaurantImage: item.storeLogo ?? '',
            orderCount: item.orderCount,
          );
        }).toList();

        return Column(
          children: [
            PopularSection(
              title: "Essentials Quick Picks",
              icon: Assets.icons.cart,
              popularItems: quickPickItems,
              onSeeAll: () => Provider.of<NavigationProvider>(context, listen: false).setIndex(1),
              onItemTap: (item) {
                GrabMartItem? originalItem;
                try {
                  originalItem = provider.quickPicks.firstWhere((i) => i.id == item.id);
                } catch (_) {}
                context.push('/foodDetails', extra: originalItem ?? item);
              },
              isLoading: provider.isLoadingItems,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildGrabMartTopRatedSection() {
    return Consumer<GrabMartProvider>(
      builder: (context, provider, _) {
        if (provider.topRatedItems.isEmpty) return const SizedBox.shrink();

        final topRatedItems = provider.topRatedItems.take(10).map((item) {
          return FoodItem(
            id: item.id,
            name: item.name,
            description: item.description,
            price: item.price,
            discountPercentage: item.discountPercentage,
            image: item.image,
            rating: item.rating,
            deliveryTimeMinutes: 20,
            sellerName: item.storeName ?? 'GrabMart',
            sellerId: item.storeId.hashCode % 1000000,
            restaurantId: item.storeId,
            restaurantImage: item.storeLogo ?? '',
            orderCount: item.orderCount,
          );
        }).toList();

        return Column(
          children: [
            TopRatedSection(
              title: "Top Rated Essentials",
              icon: Assets.icons.star,
              topRatedItems: topRatedItems,
              onSeeAll: () => Provider.of<NavigationProvider>(context, listen: false).setIndex(1),
              onItemTap: (item) {
                GrabMartItem? originalItem;
                try {
                  originalItem = provider.topRatedItems.firstWhere((i) => i.id == item.id);
                } catch (_) {}
                context.push('/foodDetails', extra: originalItem ?? item);
              },
              isLoading: provider.isLoadingItems,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildGrabMartItemsGrid() {
    return Consumer<GrabMartProvider>(
      builder: (context, provider, _) {
        if (provider.items.isEmpty && !provider.isLoadingItems) return const SizedBox.shrink();

        return Column(
          children: [
            BrowseItemsGrid(
              title: "Browse All GrabMart",
              icon: Assets.icons.squareMenu,
              items: provider.items,
              onItemTap: (item) => context.push('/foodDetails', extra: item),
              isLoading: provider.isLoadingItems && provider.items.isEmpty,
              accentColor: context.appColors.accentBlue,
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }
}
