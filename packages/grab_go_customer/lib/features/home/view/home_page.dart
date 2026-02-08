import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
import 'package:grab_go_customer/shared/widgets/area_unavailable_screen.dart';
import 'package:grab_go_customer/shared/widgets/category_skeleton.dart';
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
import 'package:grab_go_customer/shared/widgets/no_internet_screen.dart';
import 'package:grab_go_customer/shared/services/connectivity_service.dart';
import 'package:grab_go_customer/features/vendors/viewmodel/vendor_provider.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/features/vendors/widgets/vendor_horizontal_section.dart';
import 'package:grab_go_customer/features/Pickup/widgets/vendor_details_bottom_sheet.dart';
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
  bool _isFabVisible = true;
  double _lastScrollOffset = 0.0;
  FilterModel _activeFilter = FilterModel();
  int _previousCartCount = 0;
  bool _hasNoInternet = false;
  bool _isRefreshingLocation = false;
  bool _isSwipeRefreshing = false;
  bool _isRetrying = false;
  double? _lastLat;
  double? _lastLng;
  VendorType? _previousVendorType;

  late final ValueNotifier<double> _scrollOffsetNotifier;
  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;
  static const double _bottomNavHeightFactor = 0.16;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _scrollOffsetNotifier = ValueNotifier<double>(0.0);

    _fabAnimationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _badgePulseController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);

    _fabAnimationController.forward();
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locationProvider = Provider.of<NativeLocationProvider>(context);

    // Detect significant location change and refresh if needed
    if (locationProvider.latitude != null && locationProvider.longitude != null) {
      bool shouldRefresh = false;

      if (_lastLat == null || _lastLng == null) {
        // Initial coordinates acquisition
        _lastLat = locationProvider.latitude;
        _lastLng = locationProvider.longitude;
        // No refresh here because _initializeData handles it
      } else {
        // Simple coordinate delta as a fast, synchronous proxy for distance
        // 0.005 degrees is roughly 550 meters
        final latDelta = (locationProvider.latitude! - _lastLat!).abs();
        final lngDelta = (locationProvider.longitude! - _lastLng!).abs();

        if (latDelta > 0.005 || lngDelta > 0.005) {
          shouldRefresh = true;
          _lastLat = locationProvider.latitude;
          _lastLng = locationProvider.longitude;
        }
      }

      if (shouldRefresh) {
        if (kDebugMode) {
          print('📍 [HOME] Significant location change detected, triggering refresh...');
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _refreshData(refreshAllServices: true);
        });
      }
    }
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      Provider.of<NativeLocationProvider>(context, listen: false).fetchAddress();

      final vendorProvider = Provider.of<VendorProvider>(context, listen: false);
      final serviceProvider = Provider.of<ServiceProvider>(context, listen: false);
      final locationProvider = Provider.of<NativeLocationProvider>(context, listen: false);
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
      final pharmacyProvider = Provider.of<PharmacyProvider>(context, listen: false);
      final grabMartProvider = Provider.of<GrabMartProvider>(context, listen: false);

      // Check if we have any cached data at all
      final hasCachedData =
          foodProvider.categories.isNotEmpty ||
          groceryProvider.items.isNotEmpty ||
          pharmacyProvider.items.isNotEmpty ||
          grabMartProvider.items.isNotEmpty;

      // Check connectivity
      final hasInternet = await ConnectivityService.hasInternetConnection();

      if (!mounted) return;

      // No internet and no cached data → show no internet screen
      if (!hasInternet && !hasCachedData) {
        setState(() {
          _hasNoInternet = true;
          _isRetrying = false;
        });
        return;
      }

      // Clear states if we have connectivity or cache
      if (_hasNoInternet || _isRetrying) {
        setState(() {
          _hasNoInternet = false;
          _isRetrying = false;
        });
      }

      // Set initial selected category from existing data
      if (foodProvider.categories.isNotEmpty && _selectedCategory == null) {
        setState(() {
          _selectedCategory = foodProvider.categories.first;
        });
      }

      // Always refresh all providers — they handle cache-first display internally
      foodProvider.refreshAll();
      groceryProvider.refreshAll();
      pharmacyProvider.refreshAll();
      grabMartProvider.refreshAll();

      if (locationProvider.latitude != null && locationProvider.longitude != null) {
        final vendorType = _getVendorTypeFromService(serviceProvider.currentService.id);
        _previousVendorType = vendorType;
        vendorProvider.fetchVendors(vendorType, lat: locationProvider.latitude, lng: locationProvider.longitude);
      }
    });
  }

  void _onRetry() {
    setState(() {
      _hasNoInternet = false;
      _isRetrying = true;
    });
    _initializeData();
  }

  Future<void> _refreshData({bool refreshAllServices = false}) async {
    // Only set swipe refresh if we're not already refreshing from location change
    if (!_isRefreshingLocation && mounted) {
      setState(() {
        _isSwipeRefreshing = true;
      });
    }

    final serviceProvider = Provider.of<ServiceProvider>(context, listen: false);
    final locationProvider = Provider.of<NativeLocationProvider>(context, listen: false);
    final vendorProvider = Provider.of<VendorProvider>(context, listen: false);

    if (kDebugMode) {
      print('🔄 [HOME] Refreshing data (all services: $refreshAllServices)...');
      final locationData = CacheService.getUserLocation();
      print('📍 [HOME] Current location: ${locationData?['latitude']}, ${locationData?['longitude']}');
      print('🏪 [HOME] Active service: ${serviceProvider.currentService}');
    }

    try {
      if (refreshAllServices) {
        // Refresh EVERYTHING when location changes
        final foodProvider = Provider.of<FoodProvider>(context, listen: false);
        final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
        final pharmacyProvider = Provider.of<PharmacyProvider>(context, listen: false);
        final grabMartProvider = Provider.of<GrabMartProvider>(context, listen: false);

        await Future.wait([
          foodProvider.refreshAll(forceRefresh: true),
          groceryProvider.refreshAll(forceRefresh: true),
          pharmacyProvider.refreshAll(forceRefresh: true),
          grabMartProvider.refreshAll(forceRefresh: true),
        ]);
      } else if (serviceProvider.isFoodService) {
        // Refresh only active service
        final provider = Provider.of<FoodProvider>(context, listen: false);
        await provider.refreshAll(forceRefresh: true);
      } else if (serviceProvider.isGroceryService) {
        // Refresh only active service
        final groceryProvider = Provider.of<GroceryProvider>(context, listen: false);
        await groceryProvider.refreshAll(forceRefresh: true);
      } else if (serviceProvider.isPharmacyService) {
        // Refresh only active service
        final pharmacyProvider = Provider.of<PharmacyProvider>(context, listen: false);
        await pharmacyProvider.refreshAll(forceRefresh: true);
      } else if (serviceProvider.isStoresService) {
        // Refresh only active service
        final grabMartProvider = Provider.of<GrabMartProvider>(context, listen: false);
        await grabMartProvider.refreshAll(forceRefresh: true);
      }

      if (locationProvider.latitude != null && locationProvider.longitude != null) {
        final vendorType = _getVendorTypeFromService(serviceProvider.currentService.id);
        _previousVendorType = vendorType;
        await vendorProvider.fetchVendors(
          vendorType,
          lat: locationProvider.latitude,
          lng: locationProvider.longitude,
          forceRefresh: true,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [HOME] Error refreshing data: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwipeRefreshing = false;
        });
      }
    }

    if (kDebugMode) {
      print('✅ [HOME] Data refresh complete!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);
    final bottomNavHeight = size.height * _bottomNavHeightFactor;
    final bottomContentPadding = bottomNavHeight + 16.h;

    final locationProvider = Provider.of<NativeLocationProvider>(context);
    final foodProvider = Provider.of<FoodProvider>(context);
    final serviceProvider = Provider.of<ServiceProvider>(context);
    final groceryProvider = Provider.of<GroceryProvider>(context);
    final pharmacyProvider = Provider.of<PharmacyProvider>(context);
    final grabMartProvider = Provider.of<GrabMartProvider>(context);

    bool shouldShowSkeleton = false;
    bool shouldShowEmptyState = false;

    // Check if main service (Food) is available first
    final bool isFoodLoading = foodProvider.isLoading;
    final bool hasNoFood = foodProvider.categories.isEmpty;
    final bool isFoodUnavailable = !isFoodLoading && hasNoFood && foodProvider.hasAttemptedFetch;

    if (isFoodLoading) {
      // Globally show skeleton if we haven't finished determining the status
      shouldShowSkeleton = true;
    } else if (isFoodUnavailable) {
      shouldShowEmptyState = true;
    } else {
      // Otherwise, show state based on the current service
      if (serviceProvider.isGroceryService) {
        shouldShowSkeleton =
            (groceryProvider.isLoadingItems || !groceryProvider.hasAttemptedFetch) && groceryProvider.items.isEmpty;
        shouldShowEmptyState =
            !groceryProvider.isLoadingItems && groceryProvider.categories.isEmpty && groceryProvider.hasAttemptedFetch;
      } else if (serviceProvider.isPharmacyService) {
        shouldShowSkeleton =
            (pharmacyProvider.isLoadingItems || !pharmacyProvider.hasAttemptedFetch) && pharmacyProvider.items.isEmpty;
        shouldShowEmptyState =
            !pharmacyProvider.isLoadingItems &&
            pharmacyProvider.categories.isEmpty &&
            pharmacyProvider.hasAttemptedFetch;
      } else if (serviceProvider.isStoresService) {
        shouldShowSkeleton =
            (grabMartProvider.isLoadingItems || !grabMartProvider.hasAttemptedFetch) && grabMartProvider.items.isEmpty;
        shouldShowEmptyState =
            !grabMartProvider.isLoadingItems &&
            grabMartProvider.categories.isEmpty &&
            grabMartProvider.hasAttemptedFetch;
      } else if (serviceProvider.isFoodService) {
        shouldShowSkeleton = (isFoodLoading || !foodProvider.hasAttemptedFetch) && hasNoFood;
        shouldShowEmptyState = hasNoFood && foodProvider.hasAttemptedFetch;
      }
    }

    // Force skeleton if refreshing location, swipe refresh, or retrying
    if (_isRefreshingLocation || _isSwipeRefreshing || _isRetrying) {
      shouldShowSkeleton = true;
      shouldShowEmptyState = false;
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
        body: _hasNoInternet
            ? SafeArea(child: NoInternetScreen(onRetry: _onRetry))
            : SafeArea(
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
                            if (shouldShowEmptyState)
                              SliverPadding(
                                padding: EdgeInsets.only(top: size.height * 0.16),
                                sliver: SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: AreaUnavailableScreen(
                                      serviceName: serviceProvider.isFoodService
                                          ? "Foods"
                                          : serviceProvider.isGroceryService
                                          ? "Groceries"
                                          : serviceProvider.isPharmacyService
                                          ? "Pharmacy"
                                          : "GrabMart",
                                      isAreaUnavailable: isFoodUnavailable,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: EdgeInsets.only(top: size.height * 0.16),
                                sliver: SliverToBoxAdapter(
                                  child: Container(
                                    color: colors.backgroundPrimary,
                                    child: shouldShowSkeleton
                                        ? const HomePageSkeleton()
                                        : Column(
                                            children: [
                                              if (!isFoodUnavailable) ...[
                                                SizedBox(height: KSpacing.lg.h),
                                                _buildServiceSelector(),
                                              ],
                                              if (!shouldShowEmptyState) ...[
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
                                              ],
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
                                                    if (serviceProvider.isFoodService ||
                                                        serviceProvider.isGroceryService) ...[
                                                      _buildDealsSection(serviceProvider, groceryProvider),
                                                      _buildFreshArrivalsSection(serviceProvider, groceryProvider),
                                                      _buildPopularSection(serviceProvider, foodProvider),
                                                      _buildOrderAgainSection(serviceProvider),
                                                      _buildNearbyVendorsSection(serviceProvider, locationProvider),
                                                      SizedBox(height: KSpacing.md.h),
                                                      _buildBuyAgainSection(serviceProvider, groceryProvider),
                                                      _buildPromoBanners(serviceProvider),
                                                      _buildTopRatedSection(serviceProvider, foodProvider),
                                                      _buildBrowseAllGroceriesSection(serviceProvider, groceryProvider),
                                                    ] else if (serviceProvider.isPharmacyService) ...[
                                                      _buildPharmacyOnSaleSection(),
                                                      _buildPharmacyPopularSection(),
                                                      _buildNearbyVendorsSection(serviceProvider, locationProvider),
                                                      SizedBox(height: KSpacing.md.h),
                                                      _buildPharmacyTopRatedSection(),
                                                      _buildPharmacyItemsGrid(),
                                                    ] else if (serviceProvider.isStoresService) ...[
                                                      _buildGrabMartSpecialOffersSection(),
                                                      _buildGrabMartQuickPicksSection(),
                                                      _buildNearbyVendorsSection(serviceProvider, locationProvider),
                                                      SizedBox(height: KSpacing.md.h),
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

                            SliverToBoxAdapter(child: SizedBox(height: bottomContentPadding)),
                          ],
                        ),
                      ),

                      // Positioned umbrella header layer
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildCollapsibleHomeHeader(
                          context,
                          size,
                          colors,
                          isDark,
                          locationProvider,
                          foodProvider,
                        ),
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
    final vendorProvider = Provider.of<VendorProvider>(context, listen: false);
    final locationProvider = Provider.of<NativeLocationProvider>(context, listen: false);

    return ServiceSelector(
      services: AppServices.all,
      initialSelectedService: serviceProvider.currentService,
      onServiceSelected: (ServiceModel service) {
        debugPrint("Service Selected: ${service.id}");
        serviceProvider.selectService(service);

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

          if (locationProvider.latitude != null && locationProvider.longitude != null) {
            final vendorType = _getVendorTypeFromService(service.id);
            _previousVendorType = vendorType;
            vendorProvider.fetchVendors(vendorType, lat: locationProvider.latitude, lng: locationProvider.longitude);
          }
        });
      },
    );
  }

  VendorType _getVendorTypeFromService(String serviceId) {
    switch (serviceId) {
      case 'food':
        return VendorType.food;
      case 'groceries':
        return VendorType.grocery;
      case 'pharmacy':
        return VendorType.pharmacy;
      case 'convenience':
        return VendorType.grabmart;
      default:
        return VendorType.food;
    }
  }

  String _nearbyTitleForService(String serviceId) {
    switch (serviceId) {
      case 'food':
        return 'Restaurants Near You';
      case 'groceries':
        return 'Groceries Near You';
      case 'pharmacy':
        return 'Pharmacies Near You';
      case 'convenience':
        return 'GrabMart Near You';
      default:
        return 'Restaurants Near You';
    }
  }

  Widget _buildNearbyVendorsSection(ServiceProvider serviceProvider, NativeLocationProvider locationProvider) {
    if (!locationProvider.hasLocation) return const SizedBox.shrink();

    final vendorType = _getVendorTypeFromService(serviceProvider.currentService.id);
    final accentColor = Color(vendorType.color);

    return Consumer<VendorProvider>(
      builder: (context, provider, _) {
        final isMatchingType = provider.selectedType == vendorType;

        if (!isMatchingType && !provider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (locationProvider.latitude == null || locationProvider.longitude == null) return;
            _previousVendorType = vendorType;
            provider.fetchVendors(vendorType, lat: locationProvider.latitude, lng: locationProvider.longitude);
          });
          return const SizedBox.shrink();
        }

        final vendors = provider.nearestVendors.take(10).toList();
        if (!provider.isLoading && vendors.isEmpty) return const SizedBox.shrink();

        return VendorHorizontalSection(
          title: _nearbyTitleForService(serviceProvider.currentService.id),
          icon: Assets.icons.mapPin,
          vendors: vendors,
          isLoading: provider.isLoading,
          accentColor: accentColor,
          onItemTap: (vendor) => VendorDetailBottomSheet.show(context: context, vendor: vendor),
        );
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
            padding: EdgeInsets.fromLTRB(20.w, MediaQuery.of(context).padding.top + 10.h, 10.w, 6.h),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final locationChanged = await context.push("/confirm-address");

                      if (locationChanged == true && mounted) {
                        setState(() {
                          _isRefreshingLocation = true;
                        });

                        try {
                          await _refreshData();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Location updated - showing nearby items'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isRefreshingLocation = false;
                            });
                          }
                        }
                      }
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
          // Load food data
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
    if (foodProvider.recommendedItems.isEmpty) return [];

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: "Recommended for You",
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
    final hasMore = itemsProvider.hasMoreRecommended;

    if (recommendedItems.isEmpty) return [];

    return [
      SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = recommendedItems[index];
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
        }, childCount: recommendedItems.length),
      ),
      // Load more indicator
      if (hasMore)
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              // Trigger load more when this widget is built
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && hasMore && !isLoading) {
                  final provider = Provider.of<FoodDiscoveryProvider>(context, listen: false);
                  provider.loadMoreRecommendedItems();
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
