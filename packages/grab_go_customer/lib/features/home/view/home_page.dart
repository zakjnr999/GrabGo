import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_banner_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_deals_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_discovery_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_customer/shared/widgets/area_unavailable_screen.dart';
import 'package:grab_go_customer/shared/widgets/all_categories_sheet.dart';
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
import 'package:grab_go_customer/shared/widgets/promotional_banner_carousel.dart';
import 'package:grab_go_customer/features/home/model/promotional_banner.dart';
import 'package:grab_go_customer/shared/widgets/home_page_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/location_accuracy_popup.dart';
import 'package:grab_go_customer/shared/widgets/no_internet_screen.dart';
import 'package:grab_go_customer/shared/services/connectivity_service.dart';
import 'package:grab_go_customer/shared/services/notification_service.dart';
import 'package:grab_go_customer/features/vendors/viewmodel/vendor_provider.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/features/vendors/widgets/vendor_horizontal_section.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  FoodCategoryModel? _selectedCategory;

  late ScrollController _scrollController;
  late AnimationController _fabAnimationController;
  late AnimationController _badgePulseController;
  bool _isFabVisible = true;
  double _lastScrollOffset = 0.0;
  FilterModel _activeFilter = FilterModel();
  bool _hasNoInternet = false;
  bool _isRefreshingLocation = false;
  bool _isSwipeRefreshing = false;
  bool _isRetrying = false;
  double? _lastLat;
  double? _lastLng;
  int _unreadNotificationCount = 0;
  bool _isOpeningServiceHub = false;

  late final ValueNotifier<double> _scrollOffsetNotifier;
  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;
  static const double _bottomNavHeightFactor = 0.16;
  static const double _headerExtraHeight = 20.0;
  static double _homeHeaderGap(Size size) => (size.shortestSide * 0.008).clamp(2.0, 5.0);
  static double _homeFirstSectionGap(Size size) => (size.shortestSide * 0.006).clamp(1.0, 4.0);
  static double _homeContentTrim(Size size) => (size.shortestSide * 0.018).clamp(8.0, 12.0);

  static double _homeContentTopPadding(Size size) {
    final base = UmbrellaHeaderMetrics.contentTopPaddingFor(size, extra: _headerExtraHeight);
    return base - _homeContentTrim(size) + _homeHeaderGap(size);
  }

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

    if (locationProvider.latitude != null && locationProvider.longitude != null) {
      bool shouldRefresh = false;

      if (_lastLat == null || _lastLng == null) {
        _lastLat = locationProvider.latitude;
        _lastLng = locationProvider.longitude;
      } else {
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
          print('[HOME] Significant location change detected, triggering refresh...');
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

      _refreshUnreadNotificationCount();

      Provider.of<NativeLocationProvider>(context, listen: false).fetchAddress();

      final vendorProvider = Provider.of<VendorProvider>(context, listen: false);
      final locationProvider = Provider.of<NativeLocationProvider>(context, listen: false);
      final foodProvider = Provider.of<FoodProvider>(context, listen: false);
      final hasCachedData = foodProvider.categories.isNotEmpty;

      final hasInternet = await ConnectivityService.hasInternetConnection();

      if (!mounted) return;

      if (!hasInternet && !hasCachedData) {
        setState(() {
          _hasNoInternet = true;
          _isRetrying = false;
        });
        return;
      }

      if (_hasNoInternet || _isRetrying) {
        setState(() {
          _hasNoInternet = false;
          _isRetrying = false;
        });
      }

      if (foodProvider.categories.isNotEmpty && _selectedCategory == null) {
        setState(() {
          _selectedCategory = foodProvider.categories.first;
        });
      }

      foodProvider.refreshAll();

      if (locationProvider.latitude != null && locationProvider.longitude != null) {
        vendorProvider.fetchVendors(VendorType.food, lat: locationProvider.latitude, lng: locationProvider.longitude);
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
    if (!_isRefreshingLocation && mounted) {
      setState(() {
        _isSwipeRefreshing = true;
      });
    }

    final locationProvider = Provider.of<NativeLocationProvider>(context, listen: false);
    final vendorProvider = Provider.of<VendorProvider>(context, listen: false);

    if (kDebugMode) {
      print('[HOME] Refreshing data (all services: $refreshAllServices)...');
      final locationData = CacheService.getUserLocation();
      print('[HOME] Current location: ${locationData?['latitude']}, ${locationData?['longitude']}');
      print('[HOME] Active feed: food');
    }

    try {
      final provider = Provider.of<FoodProvider>(context, listen: false);
      await provider.refreshAll(forceRefresh: true);

      if (locationProvider.latitude != null && locationProvider.longitude != null) {
        await vendorProvider.fetchVendors(
          VendorType.food,
          lat: locationProvider.latitude,
          lng: locationProvider.longitude,
          forceRefresh: true,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HOME] Error refreshing data: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwipeRefreshing = false;
        });
      }
    }

    _refreshUnreadNotificationCount();

    if (kDebugMode) {
      print('[HOME] Data refresh complete!');
    }
  }

  Future<void> _refreshUnreadNotificationCount() async {
    try {
      final count = await NotificationService().getUnreadCount();
      if (!mounted) return;
      if (count != _unreadNotificationCount) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('[HOME] Failed to fetch unread notification count: $e');
      }
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

    bool shouldShowSkeleton = false;
    bool shouldShowEmptyState = false;

    final bool isFoodLoading = foodProvider.isLoading;
    final bool hasNoFood = foodProvider.categories.isEmpty;
    final bool isFoodUnavailable = !isFoodLoading && hasNoFood && foodProvider.hasAttemptedFetch;

    if (isFoodLoading || !foodProvider.hasAttemptedFetch) {
      shouldShowSkeleton = true;
    } else if (isFoodUnavailable) {
      shouldShowEmptyState = true;
    }

    if (_isRefreshingLocation || _isSwipeRefreshing || _isRetrying) {
      shouldShowSkeleton = true;
      shouldShowEmptyState = false;
    }

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarDividerColor: Colors.transparent,
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
                        iconPath: Assets.icons.utensilsCrossed,
                        bgColor: colors.accentOrange,
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: shouldShowSkeleton
                              ? const NeverScrollableScrollPhysics()
                              : const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            if (shouldShowEmptyState)
                              SliverPadding(
                                padding: EdgeInsets.only(top: _homeContentTopPadding(size)),
                                sliver: SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: AreaUnavailableScreen(
                                      serviceName: "Foods",
                                      isAreaUnavailable: isFoodUnavailable,
                                    ),
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: EdgeInsets.only(top: _homeContentTopPadding(size)),
                                sliver: SliverToBoxAdapter(
                                  child: Container(
                                    color: colors.backgroundPrimary,
                                    child: shouldShowSkeleton
                                        ? HomePageSkeleton(firstSectionGap: _homeFirstSectionGap(size))
                                        : Column(
                                            children: [
                                              if (!shouldShowEmptyState) ...[
                                                SizedBox(height: _homeFirstSectionGap(size)),
                                                _buildServiceSelector(),
                                                SizedBox(height: KSpacing.lg.h),
                                                PromotionalBannerCarousel(
                                                  banners: AppPromotionalBanners.getDefaultBanners(
                                                    onReferralTap: () => context.push('/referral'),
                                                    onGrabGoProTap: () => context.push('/subscription'),
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
                                                  key: const ValueKey<String>('home_food_feed'),
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _buildFoodCategories(foodProvider, isDark, size, colors),
                                                    _buildDealsSection(),
                                                    _buildPopularSection(foodProvider),
                                                    _buildOrderAgainSection(),
                                                    _buildNearbyVendorsSection(locationProvider),
                                                    _buildPromoBanners(),
                                                    _buildTopRatedSection(foodProvider),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            if (!shouldShowSkeleton)
                              ..._buildRecommendedSectionSlivers(foodProvider, colors, size, isDark),

                            SliverToBoxAdapter(child: SizedBox(height: bottomContentPadding)),
                          ],
                        ),
                      ),

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

                      ValueListenableBuilder<double>(
                        valueListenable: _scrollOffsetNotifier,
                        builder: (context, scrollOffset, _) {
                          final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);
                          final opacity = (1.0 - (collapseProgress * 2)).clamp(0.0, 1.0);

                          if (opacity == 0 || !locationProvider.shouldShowAccuracyPopup) {
                            return const SizedBox.shrink();
                          }

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
              onSeeAll: () {
                AllCategoriesSheet.show<FoodCategoryModel>(
                  context: context,
                  title: "All Food Categories",
                  categories: categoriesToShow,
                  getName: (cat) => cat.name,
                  getEmoji: (cat) => cat.emoji,
                  getId: (cat) => cat.id,
                  selectedCategoryId: _selectedCategory?.id,
                  accentColor: colors.accentOrange,
                  onCategorySelected: (category) {
                    setState(() {
                      _selectedCategory = category;
                    });
                    context.push(
                      '/categoryItems/${category.id}',
                      extra: {
                        'categoryId': category.id,
                        'categoryName': category.name,
                        'categoryEmoji': category.emoji,
                        'serviceType': 'food',
                      },
                    );
                  },
                );
              },
            ),
            SizedBox(height: 10.h),
            ServiceCategoryList<FoodCategoryModel>(
              categories: categoriesToShow,
              getName: (cat) => cat.name,
              getEmoji: (cat) => cat.emoji,
              getId: (cat) => cat.id,
              initialSelectedCategory: _selectedCategory,
              autoNotify: false,
              onCategorySelected: (FoodCategoryModel category) {
                setState(() {
                  _selectedCategory = category;
                });
                context.push(
                  '/categoryItems/${category.id}',
                  extra: {
                    'categoryId': category.id,
                    'categoryName': category.name,
                    'categoryEmoji': category.emoji,
                    'serviceType': 'food',
                  },
                );
              },
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildServiceSelector() {
    const nonFoodServices = [AppServices.groceries, AppServices.pharmacy, AppServices.convenience, AppServices.parcel];

    return ServiceSelector(
      services: nonFoodServices,
      showSelection: false,
      triggerInitialSelection: false,
      onServiceSelected: (ServiceModel service) {
        if (_isOpeningServiceHub) return;

        if (service.id == 'parcel') {
          _isOpeningServiceHub = true;
          context.push('/parcel').whenComplete(() {
            if (mounted) {
              _isOpeningServiceHub = false;
            }
          });
          return;
        }

        _isOpeningServiceHub = true;
        context.push('/serviceHub/${service.id}').whenComplete(() {
          if (mounted) {
            _isOpeningServiceHub = false;
          }
        });
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

  Widget _buildNearbyVendorsSection(NativeLocationProvider locationProvider) {
    if (!locationProvider.hasLocation) return const SizedBox.shrink();

    const vendorType = VendorType.food;
    final accentColor = Color(vendorType.color);

    return Consumer<VendorProvider>(
      builder: (context, provider, _) {
        final isMatchingType = provider.selectedType == vendorType;

        if (!isMatchingType && !provider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (locationProvider.latitude == null || locationProvider.longitude == null) {
              return;
            }
            provider.fetchVendors(vendorType, lat: locationProvider.latitude, lng: locationProvider.longitude);
          });
          return const SizedBox.shrink();
        }

        final vendors = provider.nearestVendors.take(10).toList();
        if (!provider.isLoading && vendors.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            VendorHorizontalSection(
              title: 'Restaurants Near You',
              icon: Assets.icons.mapPin,
              vendors: vendors,
              isLoading: provider.isLoading,
              accentColor: accentColor,
              showClosedOnImage: true,
              onItemTap: (vendor) => context.push('/vendorDetails', extra: vendor),
            ),
            SizedBox(height: KSpacing.lg.h),
          ],
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

        final expandedHeight = UmbrellaHeaderMetrics.expandedHeightFor(size, extra: _headerExtraHeight);

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
                      final locationChanged = await context.push("/confirm-address?returnTo=previous");

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
                    onTap: () async {
                      await context.push("/notification");
                      if (!mounted) return;
                      _refreshUnreadNotificationCount();
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.r),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          SvgPicture.asset(
                            Assets.icons.bell,
                            package: 'grab_go_shared',
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          ),
                          if (_unreadNotificationCount > 0)
                            Positioned(
                              right: -8.w,
                              top: -8.h,
                              child: Container(
                                constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.h),
                                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: colors.accentOrange, width: 1.5),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _unreadNotificationCount > 99 ? '99+' : _unreadNotificationCount.toString(),
                                  style: TextStyle(
                                    color: colors.accentOrange,
                                    fontSize: 9.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
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

  Widget _buildDealsSection() {
    return Column(
      children: [
        Consumer<FoodDealsProvider>(
          builder: (context, provider, _) {
            return DealsSection(
              dealItems: provider.dealItems.take(10).toList(),
              onSeeAll: () {},
              onItemTap: (item) {
                context.push('/foodDetails', extra: item);
              },
              isLoading: provider.isLoadingDeals,
              useVerticalZigzagTag: true,
            );
          },
        ),
        SizedBox(height: KSpacing.lg.h),
      ],
    );
  }

  Widget _buildOrderAgainSection() {
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

  Widget _buildPopularSection(FoodProvider foodProvider) {
    return Column(
      children: [
        PopularSection(
          popularItems: foodProvider.popularItems,
          useVerticalZigzagTag: true,
          onSeeAll: () {},
          onItemTap: (item) {
            context.push('/foodDetails', extra: item);
          },
          isLoading: foodProvider.isLoadingPopular,
        ),
        SizedBox(height: KSpacing.lg.h),
      ],
    );
  }

  Widget _buildPromoBanners() {
    return Consumer<FoodBannerProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            PromoSection(banners: provider.promotionalBanners, onSeeAll: () {}, isLoading: provider.isLoadingBanners),
            SizedBox(height: KSpacing.lg.h),
          ],
        );
      },
    );
  }

  Widget _buildTopRatedSection(FoodProvider foodProvider) {
    return Column(
      children: [
        TopRatedSection(
          topRatedItems: foodProvider.topRatedItems,
          useVerticalZigzagTag: true,
          onSeeAll: () {},
          onItemTap: (item) => context.push('/foodDetails', extra: item),
          isLoading: foodProvider.isLoadingTopRated,
        ),
        SizedBox(height: KSpacing.lg.h),
      ],
    );
  }

  List<Widget> _buildRecommendedSectionSlivers(
    FoodProvider foodProvider,
    AppColorsExtension colors,
    Size size,
    bool isDark,
  ) {
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
              final bool isInCart = provider.hasItemInCart(item, includeFoodCustomizations: true);
              final bool isItemPending = provider.isItemOperationPendingForDisplay(
                item,
                includeFoodCustomizations: true,
              );
              final itemForAction = provider.resolveItemForCartAction(item, includeFoodCustomizations: true);
              return FoodItemCard(
                item: item,
                onTap: () => context.push('/foodDetails', extra: item),
                trailing: GestureDetector(
                  onTap: () {
                    if (isItemPending) return;
                    if (isInCart && itemForAction != null) {
                      provider.removeItemCompletely(itemForAction);
                    } else {
                      provider.addToCart(item, context: context);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isInCart ? colors.accentOrange : colors.backgroundSecondary,
                    ),
                    child: isItemPending
                        ? SizedBox(
                            width: 16.w,
                            height: 16.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(isInCart ? Colors.white : colors.accentOrange),
                            ),
                          )
                        : SvgPicture.asset(
                            isInCart ? Assets.icons.check : Assets.icons.cart,
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
        }, childCount: recommendedItems.length),
      ),
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
}
