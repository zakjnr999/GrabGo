import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/Pickup/widgets/vendor_details_bottom_sheet.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_category.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/grabmart/viewmodel/grabmart_provider.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_category.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/home/model/promotional_banner.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_category.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/features/services/model/service_display_item.dart';
import 'package:grab_go_customer/features/services/model/service_hub_config.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/features/vendors/viewmodel/vendor_provider.dart';
import 'package:grab_go_customer/features/vendors/widgets/vendor_horizontal_section.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_customer/shared/widgets/area_unavailable_screen.dart';
import 'package:grab_go_customer/shared/widgets/all_categories_sheet.dart';
import 'package:grab_go_customer/shared/widgets/deals_section.dart';
import 'package:grab_go_customer/shared/widgets/popular_section.dart';
import 'package:grab_go_customer/shared/widgets/popular_item_card.dart';
import 'package:grab_go_customer/shared/widgets/promotional_banner_carousel.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_customer/shared/widgets/service_hub_page_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/service_category_list.dart';
import 'package:grab_go_customer/shared/widgets/top_rated_section.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class ServiceHubPage extends StatefulWidget {
  final String serviceId;

  const ServiceHubPage({super.key, required this.serviceId});

  @override
  State<ServiceHubPage> createState() => _ServiceHubPageState();
}

class _ServiceHubPageState extends State<ServiceHubPage> {
  static const double _collapsedHeight = 72.0;
  static const double _scrollThreshold = 140.0;
  static double _headerExtraHeightFor(Size size) => (size.shortestSide * 0.088).clamp(28.0, 42.0);

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  final List<VendorModel> _nearbyServiceVendors = [];
  bool _isLoadingNearbyVendors = false;
  bool _isInitialHubLoadInProgress = true;
  String? _loadedNearbyKey;
  String? _pendingNearbyKey;

  ServiceHubConfig? get _config => ServiceHubConfig.fromServiceId(widget.serviceId);

  Color _serviceAccentColor(AppColorsExtension colors) {
    switch (widget.serviceId) {
      case 'groceries':
        return colors.serviceGrocery;
      case 'pharmacy':
        return colors.servicePharmacy;
      case 'convenience':
        return colors.serviceGrabMart;
      default:
        return colors.serviceFood;
    }
  }

  VendorType? _vendorTypeForServiceId(String serviceId) {
    switch (serviceId) {
      case 'groceries':
        return VendorType.grocery;
      case 'pharmacy':
        return VendorType.pharmacy;
      case 'convenience':
        return VendorType.grabmart;
      default:
        return null;
    }
  }

  String _nearbyStoresTitle(String serviceId) {
    switch (serviceId) {
      case 'groceries':
        return 'Nearby Grocery Stores';
      case 'pharmacy':
        return 'Nearby Pharmacies';
      case 'convenience':
        return 'Nearby GrabMarts';
      default:
        return 'Nearby Stores';
    }
  }

  Future<void> _fetchNearbyVendors({bool forceRefresh = false}) async {
    final vendorType = _vendorTypeForServiceId(widget.serviceId);
    if (vendorType == null) return;

    final locationProvider = context.read<NativeLocationProvider>();
    final lat = locationProvider.latitude;
    final lng = locationProvider.longitude;
    if (lat == null || lng == null) {
      if (mounted) {
        setState(() {
          _nearbyServiceVendors.clear();
        });
      }
      return;
    }

    final requestKey = '${vendorType.id}_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
    if (!forceRefresh && _loadedNearbyKey == requestKey) return;

    if (mounted) {
      setState(() {
        _isLoadingNearbyVendors = true;
        _pendingNearbyKey = requestKey;
      });
    }

    final provider = context.read<VendorProvider>();
    try {
      await provider.getNearbyVendorsByType(vendorType, lat, lng, radius: 8);
    } finally {
      if (!mounted) return;
      setState(() {
        _nearbyServiceVendors
          ..clear()
          ..addAll(provider.selectedType == vendorType ? provider.nearestVendors.take(10) : <VendorModel>[]);
        _isLoadingNearbyVendors = false;
        _loadedNearbyKey = requestKey;
        _pendingNearbyKey = null;
      });
    }
  }

  void _ensureNearbyVendorsLoaded(NativeLocationProvider locationProvider) {
    final vendorType = _vendorTypeForServiceId(widget.serviceId);
    final lat = locationProvider.latitude;
    final lng = locationProvider.longitude;
    if (vendorType == null || lat == null || lng == null) return;

    final requestKey = '${vendorType.id}_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';
    if (_loadedNearbyKey == requestKey || _pendingNearbyKey == requestKey || _isLoadingNearbyVendors) return;
    _pendingNearbyKey = requestKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchNearbyVendors();
    });
  }

  bool _shouldShowServiceUnavailable(NativeLocationProvider locationProvider) {
    return locationProvider.hasLocation &&
        _loadedNearbyKey != null &&
        !_isLoadingNearbyVendors &&
        _nearbyServiceVendors.isEmpty;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureInitialData();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollOffsetNotifier.value = _scrollController.offset;
  }

  Future<void> _ensureInitialData() async {
    if (!mounted) return;

    try {
      Future<void> serviceDataFuture = Future.value();
      switch (widget.serviceId) {
        case 'groceries':
          final provider = context.read<GroceryProvider>();
          if (provider.items.isEmpty || provider.categories.isEmpty || provider.recommendedItems.isEmpty) {
            serviceDataFuture = provider.refreshAll();
          }
          break;
        case 'pharmacy':
          final provider = context.read<PharmacyProvider>();
          if (provider.items.isEmpty || provider.categories.isEmpty || provider.recommendedItems.isEmpty) {
            serviceDataFuture = provider.refreshAll();
          }
          break;
        case 'convenience':
          final provider = context.read<GrabMartProvider>();
          if (provider.items.isEmpty || provider.categories.isEmpty || provider.recommendedItems.isEmpty) {
            serviceDataFuture = provider.refreshAll();
          }
          break;
        default:
          break;
      }

      await Future.wait([serviceDataFuture, _fetchNearbyVendors()]);
    } finally {
      if (mounted) {
        setState(() {
          _isInitialHubLoadInProgress = false;
        });
      }
    }
  }

  Future<void> _refreshCurrentService() async {
    switch (widget.serviceId) {
      case 'groceries':
        await context.read<GroceryProvider>().refreshAll(forceRefresh: true);
        break;
      case 'pharmacy':
        await context.read<PharmacyProvider>().refreshAll(forceRefresh: true);
        break;
      case 'convenience':
        await context.read<GrabMartProvider>().refreshAll(forceRefresh: true);
        break;
      default:
        break;
    }

    await _fetchNearbyVendors(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final serviceAccentColor = _serviceAccentColor(colors);

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: serviceAccentColor,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarDividerColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    if (config == null) {
      return Scaffold(
        backgroundColor: colors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: serviceAccentColor,
          foregroundColor: Colors.white,
          title: const Text('Service'),
        ),
        body: Center(
          child: Text(
            'Unsupported service',
            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              AppRefreshIndicator(
                bgColor: serviceAccentColor,
                onRefresh: _refreshCurrentService,
                child: _buildContent(config, size, colors, isDark, serviceAccentColor),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildCollapsibleHeader(
                  config: config,
                  size: size,
                  topPadding: topPadding,
                  colors: colors,
                  accentColor: serviceAccentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ServiceHubConfig config, Size size, AppColorsExtension colors, bool isDark, Color accentColor) {
    final groceryProvider = context.watch<GroceryProvider>();
    final pharmacyProvider = context.watch<PharmacyProvider>();
    final grabMartProvider = context.watch<GrabMartProvider>();
    final locationProvider = context.watch<NativeLocationProvider>();
    _ensureNearbyVendorsLoaded(locationProvider);

    final items = _resolveDisplayItems(groceryProvider, pharmacyProvider, grabMartProvider);
    final rawRecommendedItems = _resolveRecommendedDisplayItems(groceryProvider, pharmacyProvider, grabMartProvider);
    final recommendedItems = _withRecommendedFallback(rawRecommendedItems, items);
    final categories = _resolveCategoriesCount(groceryProvider, pharmacyProvider, grabMartProvider);
    final isLoading = _isLoading(groceryProvider, pharmacyProvider, grabMartProvider);
    final isLoadingRecommended = _isLoadingRecommended(groceryProvider, pharmacyProvider, grabMartProvider);
    final hasMoreRecommended = _hasMoreRecommended(groceryProvider, pharmacyProvider, grabMartProvider);
    final hasData = items.isNotEmpty || categories > 0;

    final contentTopPadding = UmbrellaHeaderMetrics.contentPaddingFor(size, extra: _headerExtraHeightFor(size), gap: 8);

    if (_isInitialHubLoadInProgress || (isLoading && !hasData)) {
      return ListView(
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: contentTopPadding, bottom: 24.h),
        children: const [ServiceHubPageSkeleton()],
      );
    }

    final deals = _sortedDeals(items);
    final popular = _sortedPopular(items);
    final topRated = _sortedTopRated(items);
    final banners = _bannersForService(widget.serviceId, accentColor);
    final shouldShowServiceUnavailable = _shouldShowServiceUnavailable(locationProvider);

    if (shouldShowServiceUnavailable) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: contentTopPadding, bottom: 32.h),
        children: [
          AreaUnavailableScreen(serviceName: _config?.title, isAreaUnavailable: false, accentColor: accentColor),
        ],
      );
    }

    final showEmpty =
        deals.isEmpty &&
        popular.isEmpty &&
        topRated.isEmpty &&
        recommendedItems.isEmpty &&
        categories == 0 &&
        _nearbyServiceVendors.isEmpty &&
        !isLoadingRecommended &&
        !_isLoadingNearbyVendors;

    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: contentTopPadding, bottom: 32.h),
      children: [
        if (banners.isNotEmpty) PromotionalBannerCarousel(banners: banners),
        if (banners.isNotEmpty) SizedBox(height: 8.h),
        _buildCategoriesSection(
          config: config,
          accentColor: accentColor,
          groceryProvider: groceryProvider,
          pharmacyProvider: pharmacyProvider,
          grabMartProvider: grabMartProvider,
        ),
        SizedBox(height: KSpacing.lg.h),
        if (deals.isNotEmpty)
          _buildHorizontalItemsSection(items: deals, sectionType: _SectionType.deals, accentColor: accentColor),
        if (deals.isNotEmpty) SizedBox(height: KSpacing.lg.h),
        if (popular.isNotEmpty)
          _buildHorizontalItemsSection(items: popular, sectionType: _SectionType.popular, accentColor: accentColor),
        if (popular.isNotEmpty) SizedBox(height: KSpacing.lg.h),
        if (topRated.isNotEmpty)
          _buildHorizontalItemsSection(items: topRated, sectionType: _SectionType.topRated, accentColor: accentColor),
        if (topRated.isNotEmpty) SizedBox(height: KSpacing.lg.h),
        _buildNearbyServiceStoresSection(accentColor: accentColor, locationProvider: locationProvider),
        if (recommendedItems.isNotEmpty || isLoadingRecommended)
          _buildRecommendedItemsSection(
            items: recommendedItems,
            accentColor: accentColor,
            isLoadingMore: isLoadingRecommended,
            hasMore: hasMoreRecommended,
          ),
        if (showEmpty) _buildEmptyState(colors),
      ],
    );
  }

  List<PromotionalBanner> _bannersForService(String serviceId, Color accentColor) {
    switch (serviceId) {
      case 'groceries':
        return [
          PromotionalBanner(
            id: 'grocery_weekly_deals',
            title: 'Weekly Basket Deals',
            subtitle: 'Save more on staples and fresh produce',
            actionText: 'Shop Deals',
            gradientColors: [accentColor, accentColor],
            emoji: '🛒',
            isDismissible: false,
          ),
          PromotionalBanner(
            id: 'grocery_fresh_fast',
            title: 'Fresh Picks in Minutes',
            subtitle: 'Fruits, veggies, and essentials from nearby stores',
            actionText: 'Shop Fresh',
            gradientColors: [accentColor, accentColor],
            emoji: '🥬',
            isDismissible: false,
          ),
          PromotionalBanner(
            id: 'grocery_restock',
            title: 'Restock Home Essentials',
            subtitle: 'Beverages, snacks, and household must-haves',
            actionText: 'Restock',
            gradientColors: [accentColor, accentColor],
            emoji: '🧺',
            isDismissible: false,
          ),
        ];
      case 'pharmacy':
        return [
          PromotionalBanner(
            id: 'pharmacy_wellness_deals',
            title: 'Wellness Week Offers',
            subtitle: 'Daily savings on vitamins and health essentials',
            actionText: 'View Offers',
            gradientColors: [accentColor, accentColor],
            emoji: '💊',
            isDismissible: false,
          ),
          PromotionalBanner(
            id: 'pharmacy_fast_otc',
            title: 'OTC Delivered Fast',
            subtitle: 'Cold, pain, and daily care items near you',
            actionText: 'Shop OTC',
            gradientColors: [accentColor, accentColor],
            emoji: '🩺',
            isDismissible: false,
          ),
          PromotionalBanner(
            id: 'pharmacy_family_care',
            title: 'Family Care Essentials',
            subtitle: 'Personal care and trusted everyday products',
            actionText: 'Explore',
            gradientColors: [accentColor, accentColor],
            emoji: '🧴',
            isDismissible: false,
          ),
        ];
      case 'convenience':
        return [
          PromotionalBanner(
            id: 'grabmart_late_night',
            title: 'Late-Night Essentials',
            subtitle: 'Quick picks when you need items after hours',
            actionText: 'Shop Now',
            gradientColors: [accentColor, accentColor],
            emoji: '🌙',
            isDismissible: false,
          ),
          PromotionalBanner(
            id: 'grabmart_snacks',
            title: 'Snacks & Drinks Picks',
            subtitle: 'Instant cravings, chilled drinks, and more',
            actionText: 'Grab Picks',
            gradientColors: [accentColor, accentColor],
            emoji: '🥤',
            isDismissible: false,
          ),
          PromotionalBanner(
            id: 'grabmart_home_cleaning',
            title: 'Home & Cleaning Deals',
            subtitle: 'Household basics and cleaning must-haves',
            actionText: 'Browse Deals',
            gradientColors: [accentColor, accentColor],
            emoji: '🧼',
            isDismissible: false,
          ),
        ];
      default:
        return const [];
    }
  }

  Widget _buildCollapsibleHeader({
    required ServiceHubConfig config,
    required Size size,
    required double topPadding,
    required AppColorsExtension colors,
    required Color accentColor,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);
        final expandedHeight = UmbrellaHeaderMetrics.expandedHeightFor(size, extra: _headerExtraHeightFor(size));
        final currentHeight = expandedHeight - ((expandedHeight - _collapsedHeight) * collapseProgress);
        final headerOpacity = (1.0 - (collapseProgress * 0.45)).clamp(0.35, 1.0);
        final searchVisibility = (1.0 - (collapseProgress * 1.8)).clamp(0.0, 1.0);

        return SizedBox(
          height: currentHeight,
          child: UmbrellaHeaderWithShadow(
            curveDepth: 20.h,
            numberOfCurves: 10,
            height: currentHeight,
            backgroundColor: accentColor,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: headerOpacity,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, topPadding + 10.h, 20.w, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => context.pop(),
                                customBorder: const CircleBorder(),
                                child: Padding(
                                  padding: EdgeInsets.all(10.r),
                                  child: SvgPicture.asset(
                                    Assets.icons.navArrowLeft,
                                    package: 'grab_go_shared',
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                config.title,
                                style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                config.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 13.sp),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    ClipRect(
                      child: Align(
                        heightFactor: searchVisibility,
                        alignment: Alignment.topCenter,
                        child: Opacity(
                          opacity: searchVisibility,
                          child: _buildServiceHubSearchBar(colors: colors, accentColor: accentColor, size: size),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceHubSearchBar({
    required AppColorsExtension colors,
    required Color accentColor,
    required Size size,
  }) {
    return GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KBorderSize.border),
          color: colors.backgroundPrimary,
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
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
            ),
            SizedBox(width: 5.w),
            Text(
              "Search & Explore GrabGo... ",
              style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
            ),
            const Spacer(),
            Container(
              width: size.width * 0.24,
              padding: EdgeInsets.all(2.r),
              decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(KBorderSize.border)),
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
                    onTap: () => context.push('/search'),
                    child: Container(
                      padding: EdgeInsets.all(7.r),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(KBorderSize.border),
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.slidersHorizontal,
                        package: 'grab_go_shared',
                        height: KIconSize.sm,
                        width: KIconSize.sm,
                        colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
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

  Widget _buildHorizontalItemsSection({
    required List<ServiceDisplayItem> items,
    required _SectionType sectionType,
    Color? accentColor,
  }) {
    final normalizedItems = items.map(_toFoodItem).toList();
    final originalItems = items.map((item) => item.sourceItem).toList();

    switch (sectionType) {
      case _SectionType.deals:
        return DealsSection(
          dealItems: normalizedItems,
          originalItems: originalItems,
          useVerticalZigzagTag: true,
          accentColor: accentColor,
          onSeeAll: () {},
          onItemTap: (item) => _openItemFromSection(item, items),
        );
      case _SectionType.popular:
        return PopularSection(
          popularItems: normalizedItems,
          originalItems: originalItems,
          useVerticalZigzagTag: true,
          accentColor: accentColor,
          onSeeAll: () {},
          onItemTap: (item) => _openItemFromSection(item, items),
        );
      case _SectionType.topRated:
        return TopRatedSection(
          topRatedItems: normalizedItems,
          originalItems: originalItems,
          useVerticalZigzagTag: true,
          accentColor: accentColor,
          onSeeAll: () {},
          onItemTap: (item) => _openItemFromSection(item, items),
        );
    }
  }

  Widget _buildCategoriesSection({
    required ServiceHubConfig config,
    required Color accentColor,
    required GroceryProvider groceryProvider,
    required PharmacyProvider pharmacyProvider,
    required GrabMartProvider grabMartProvider,
  }) {
    if (widget.serviceId == 'groceries' && groceryProvider.categories.isNotEmpty) {
      return _buildTypedCategoriesSection<GroceryCategory>(
        title: config.categoryTitle,
        categories: groceryProvider.categories,
        getName: (cat) => cat.name,
        getEmoji: (cat) => cat.emoji,
        getId: (cat) => cat.id,
        serviceType: config.categoryServiceType,
        accentColor: accentColor,
      );
    }

    if (widget.serviceId == 'pharmacy' && pharmacyProvider.categories.isNotEmpty) {
      return _buildTypedCategoriesSection<PharmacyCategory>(
        title: config.categoryTitle,
        categories: pharmacyProvider.categories,
        getName: (cat) => cat.name,
        getEmoji: (cat) => cat.emoji,
        getId: (cat) => cat.id,
        serviceType: config.categoryServiceType,
        accentColor: accentColor,
      );
    }

    if (widget.serviceId == 'convenience' && grabMartProvider.categories.isNotEmpty) {
      return _buildTypedCategoriesSection<GrabMartCategory>(
        title: config.categoryTitle,
        categories: grabMartProvider.categories,
        getName: (cat) => cat.name,
        getEmoji: (cat) => cat.emoji,
        getId: (cat) => cat.id,
        serviceType: config.categoryServiceType,
        accentColor: accentColor,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTypedCategoriesSection<T>({
    required String title,
    required List<T> categories,
    required String Function(T) getName,
    required String Function(T) getEmoji,
    required String Function(T) getId,
    required String serviceType,
    required Color accentColor,
  }) {
    return Column(
      children: [
        SizedBox(height: 14.h),
        SectionHeader(
          title: title,
          sectionTotal: categories.length,
          accentColor: accentColor,
          onSeeAll: () {
            AllCategoriesSheet.show<T>(
              context: context,
              title: title,
              categories: categories,
              getName: getName,
              getEmoji: getEmoji,
              getId: getId,
              accentColor: accentColor,
              onCategorySelected: (category) {
                final categoryId = getId(category);
                final categoryName = getName(category);
                final categoryEmoji = getEmoji(category);
                context.push(
                  '/categoryItems/$categoryId',
                  extra: {
                    'categoryId': categoryId,
                    'categoryName': categoryName,
                    'categoryEmoji': categoryEmoji,
                    'serviceType': serviceType,
                  },
                );
              },
            );
          },
        ),
        SizedBox(height: 10.h),
        ServiceCategoryList<T>(
          categories: categories,
          getName: getName,
          getEmoji: getEmoji,
          getId: getId,
          autoNotify: false,
          accentColor: accentColor,
          onCategorySelected: (category) {
            final categoryId = getId(category);
            final categoryName = getName(category);
            final categoryEmoji = getEmoji(category);
            context.push(
              '/categoryItems/$categoryId',
              extra: {
                'categoryId': categoryId,
                'categoryName': categoryName,
                'categoryEmoji': categoryEmoji,
                'serviceType': serviceType,
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildNearbyServiceStoresSection({
    required Color accentColor,
    required NativeLocationProvider locationProvider,
  }) {
    if (!locationProvider.hasLocation) return const SizedBox.shrink();

    final vendorType = _vendorTypeForServiceId(widget.serviceId);
    if (vendorType == null) return const SizedBox.shrink();
    if (_nearbyServiceVendors.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: KSpacing.lg.h),
      child: VendorHorizontalSection(
        title: _nearbyStoresTitle(widget.serviceId),
        icon: Assets.icons.mapPin,
        vendors: _nearbyServiceVendors,
        isLoading: _isLoadingNearbyVendors,
        accentColor: accentColor,
        onItemTap: (vendor) => VendorDetailBottomSheet.show(context: context, vendor: vendor),
      ),
    );
  }

  Widget _buildRecommendedItemsSection({
    required List<ServiceDisplayItem> items,
    required Color accentColor,
    required bool isLoadingMore,
    required bool hasMore,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Recommended for You',
          sectionTotal: items.length,
          accentColor: accentColor,
          onSeeAll: () {},
        ),
        SizedBox(height: KSpacing.lg.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.70,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 16.h,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final displayItem = _toFoodItem(item);

              return PopularItemCard(
                item: displayItem,
                orderCount: item.orderCount,
                deliveryTime: displayItem.estimatedDeliveryTime,
                useVerticalZigzagTag: true,
                accentColor: accentColor,
                onTap: () => context.push('/foodDetails', extra: item.sourceItem),
              );
            },
          ),
        ),
        SizedBox(height: KSpacing.lg.h),
        if (hasMore)
          Builder(
            builder: (context) {
              if (!isLoadingMore) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (!mounted) return;
                  _loadMoreRecommendedItems();
                });
              }
              return Padding(
                padding: EdgeInsets.only(bottom: KSpacing.lg.h),
                child: LoadingMore(colors: context.appColors, spinnerColor: accentColor, borderColor: accentColor),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 22.h),
      decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(14.r)),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, color: colors.textSecondary, size: 26.sp),
          SizedBox(height: 10.h),
          Text(
            'Nothing to show yet',
            style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4.h),
          Text(
            'Pull to refresh or try again shortly.',
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  bool _isLoading(
    GroceryProvider groceryProvider,
    PharmacyProvider pharmacyProvider,
    GrabMartProvider grabMartProvider,
  ) {
    switch (widget.serviceId) {
      case 'groceries':
        return groceryProvider.isLoadingItems || groceryProvider.isLoadingCategories;
      case 'pharmacy':
        return pharmacyProvider.isLoadingItems || pharmacyProvider.isLoadingCategories;
      case 'convenience':
        return grabMartProvider.isLoadingItems || grabMartProvider.isLoadingCategories;
      default:
        return false;
    }
  }

  int _resolveCategoriesCount(
    GroceryProvider groceryProvider,
    PharmacyProvider pharmacyProvider,
    GrabMartProvider grabMartProvider,
  ) {
    switch (widget.serviceId) {
      case 'groceries':
        return groceryProvider.categories.length;
      case 'pharmacy':
        return pharmacyProvider.categories.length;
      case 'convenience':
        return grabMartProvider.categories.length;
      default:
        return 0;
    }
  }

  List<ServiceDisplayItem> _resolveDisplayItems(
    GroceryProvider groceryProvider,
    PharmacyProvider pharmacyProvider,
    GrabMartProvider grabMartProvider,
  ) {
    switch (widget.serviceId) {
      case 'groceries':
        return groceryProvider.items.map(ServiceDisplayItem.fromGroceryItem).toList();
      case 'pharmacy':
        return pharmacyProvider.items.map(ServiceDisplayItem.fromPharmacyItem).toList();
      case 'convenience':
        return grabMartProvider.items.map(ServiceDisplayItem.fromGrabMartItem).toList();
      default:
        return const [];
    }
  }

  List<ServiceDisplayItem> _resolveRecommendedDisplayItems(
    GroceryProvider groceryProvider,
    PharmacyProvider pharmacyProvider,
    GrabMartProvider grabMartProvider,
  ) {
    switch (widget.serviceId) {
      case 'groceries':
        return groceryProvider.recommendedItems.map(ServiceDisplayItem.fromGroceryItem).toList();
      case 'pharmacy':
        return pharmacyProvider.recommendedItems.map(ServiceDisplayItem.fromPharmacyItem).toList();
      case 'convenience':
        return grabMartProvider.recommendedItems.map(ServiceDisplayItem.fromGrabMartItem).toList();
      default:
        return const [];
    }
  }

  bool _isLoadingRecommended(
    GroceryProvider groceryProvider,
    PharmacyProvider pharmacyProvider,
    GrabMartProvider grabMartProvider,
  ) {
    switch (widget.serviceId) {
      case 'groceries':
        return groceryProvider.isLoadingRecommended;
      case 'pharmacy':
        return pharmacyProvider.isLoadingRecommended;
      case 'convenience':
        return grabMartProvider.isLoadingRecommended;
      default:
        return false;
    }
  }

  bool _hasMoreRecommended(
    GroceryProvider groceryProvider,
    PharmacyProvider pharmacyProvider,
    GrabMartProvider grabMartProvider,
  ) {
    switch (widget.serviceId) {
      case 'groceries':
        return groceryProvider.hasMoreRecommended;
      case 'pharmacy':
        return pharmacyProvider.hasMoreRecommended;
      case 'convenience':
        return grabMartProvider.hasMoreRecommended;
      default:
        return false;
    }
  }

  Future<void> _loadMoreRecommendedItems() async {
    switch (widget.serviceId) {
      case 'groceries':
        await context.read<GroceryProvider>().loadMoreRecommendedItems();
        break;
      case 'pharmacy':
        await context.read<PharmacyProvider>().loadMoreRecommendedItems();
        break;
      case 'convenience':
        await context.read<GrabMartProvider>().loadMoreRecommendedItems();
        break;
      default:
        break;
    }
  }

  List<ServiceDisplayItem> _sortedDeals(List<ServiceDisplayItem> items) {
    final filtered = items.where((item) => item.discountPercentage > 0).toList();
    filtered.sort((a, b) => b.discountPercentage.compareTo(a.discountPercentage));
    return filtered.take(10).toList();
  }

  List<ServiceDisplayItem> _sortedPopular(List<ServiceDisplayItem> items) {
    final filtered = [...items];
    filtered.sort((a, b) => b.orderCount.compareTo(a.orderCount));
    return filtered.take(10).toList();
  }

  List<ServiceDisplayItem> _sortedTopRated(List<ServiceDisplayItem> items) {
    final filtered = items.where((item) => item.rating >= 4.0).toList();
    filtered.sort((a, b) => b.rating.compareTo(a.rating));
    return filtered.take(10).toList();
  }

  List<ServiceDisplayItem> _withRecommendedFallback(
    List<ServiceDisplayItem> recommendedItems,
    List<ServiceDisplayItem> allItems,
  ) {
    const minCount = 6;
    const maxCount = 20;

    final uniqueById = <String, ServiceDisplayItem>{};
    for (final item in recommendedItems) {
      uniqueById[item.id] = item;
    }

    if (uniqueById.length >= minCount) {
      return uniqueById.values.take(maxCount).toList();
    }

    final fallbackCandidates = [...allItems];
    fallbackCandidates.sort((a, b) {
      final aScore = (a.orderCount * 3) + (a.rating * 20) + (a.discountPercentage * 2);
      final bScore = (b.orderCount * 3) + (b.rating * 20) + (b.discountPercentage * 2);
      return bScore.compareTo(aScore);
    });

    for (final item in fallbackCandidates) {
      uniqueById.putIfAbsent(item.id, () => item);
      if (uniqueById.length >= minCount) break;
    }

    return uniqueById.values.take(maxCount).toList();
  }

  FoodItem _toFoodItem(ServiceDisplayItem item) {
    final source = item.sourceItem;
    if (source is GroceryItem) return source.toFoodItem();
    if (source is PharmacyItem) return source.toFoodItem();
    if (source is GrabMartItem) return source.toFoodItem();

    return FoodItem(
      id: item.id,
      name: item.name,
      image: item.imageUrl,
      description: item.description,
      sellerName: item.storeName,
      sellerId: item.storeName.hashCode % 1000000,
      restaurantId: item.storeName,
      restaurantImage: '',
      price: item.price,
      rating: item.rating,
      discountPercentage: item.discountPercentage,
      orderCount: item.orderCount,
      isAvailable: item.isAvailable,
    );
  }

  void _openItemFromSection(FoodItem tappedItem, List<ServiceDisplayItem> sectionItems) {
    for (final sectionItem in sectionItems) {
      if (sectionItem.id == tappedItem.id) {
        context.push('/foodDetails', extra: sectionItem.sourceItem);
        return;
      }
    }
    context.push('/foodDetails', extra: tappedItem);
  }
}

enum _SectionType { deals, popular, topRated }
