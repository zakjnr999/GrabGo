import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import '../model/vendor_type.dart';
import '../viewmodel/vendor_provider.dart';
import '../widgets/vendor_card.dart';
import '../../../shared/viewmodels/service_provider.dart';
import '../../../shared/viewmodels/native_location_provider.dart';
import '../../../shared/widgets/umbrella_header.dart';
import '../../../shared/widgets/home_search.dart';
import '../../../shared/widgets/section_header.dart';
import '../widgets/vendor_horizontal_section.dart';
import '../../home/model/filter_model.dart';
import '../../home/model/food_category.dart';
import '../../home/viewmodel/food_provider.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(
    0.0,
  );
  FilterModel _activeFilter = FilterModel();

  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;

  @override
  void initState() {
    super.initState();
    // In account.dart, they use NotificationListener instead of adding a listener to ScrollController directly
    // but both work. Adding it here for completeness if we want to use the notifier.
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vendorProvider = context.read<VendorProvider>();
      final serviceProvider = context.read<ServiceProvider>();
      final locationProvider = context.read<NativeLocationProvider>();
      final vendorType = _getVendorTypeFromService(
        serviceProvider.currentService.id,
      );
      vendorProvider.fetchVendors(
        vendorType,
        lat: locationProvider.latitude,
        lng: locationProvider.longitude,
      );
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollOffsetNotifier.value = _scrollController.offset;
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

  VendorType? _previousVendorType;
  double? _previousLat;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final serviceProvider = context.watch<ServiceProvider>();
    final locationProvider = context.watch<NativeLocationProvider>();
    final currentVendorType = _getVendorTypeFromService(
      serviceProvider.currentService.id,
    );

    final bool typeChanged =
        _previousVendorType != null && _previousVendorType != currentVendorType;
    final bool locationLoaded =
        _previousLat == null && locationProvider.latitude != null;

    if (typeChanged || locationLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final vendorProvider = context.read<VendorProvider>();
        vendorProvider.fetchVendors(
          currentVendorType,
          lat: locationProvider.latitude,
          lng: locationProvider.longitude,
        );
      });
    }

    _previousVendorType = currentVendorType;
    _previousLat = locationProvider.latitude;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Consumer2<ServiceProvider, NativeLocationProvider>(
        builder: (context, serviceProvider, locationProvider, _) {
          final vendorType = _getVendorTypeFromService(
            serviceProvider.currentService.id,
          );
          final accentColor = Color(vendorType.color);

          final systemUiOverlayStyle = SystemUiOverlayStyle(
            statusBarColor: accentColor,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: colors.backgroundSecondary,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          );

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: systemUiOverlayStyle,
            child: Consumer<VendorProvider>(
              builder: (context, provider, child) {
                return Stack(
                  children: [
                    // Scrollable Content
                    Positioned.fill(
                      child: _buildMainContent(
                        colors,
                        accentColor,
                        provider,
                        vendorType,
                        size,
                        serviceProvider,
                        locationProvider,
                      ),
                    ),

                    // Collapsible Umbrella Header
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildCollapsibleHeader(
                        colors,
                        accentColor,
                        provider,
                        vendorType,
                        size,
                        serviceProvider,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(
    AppColorsExtension colors,
    Color accentColor,
    VendorProvider provider,
    VendorType vendorType,
    Size size,
    ServiceProvider serviceProvider,
    NativeLocationProvider locationProvider,
  ) {
    final expandedContentPadding = UmbrellaHeaderMetrics.contentPaddingFor(
      size,
    );

    return AppRefreshIndicator(
      onRefresh: () => provider.fetchVendors(
        vendorType,
        lat: locationProvider.latitude,
        lng: locationProvider.longitude,
      ),
      bgColor: colors.accentOrange,
      iconPath: Assets.icons.store,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: expandedContentPadding),
        child: Column(
          children: [
            // Vendor Content
            if (provider.isLoading && provider.filteredVendors.isEmpty)
              _buildLoadingContent()
            else if (provider.error != null)
              _buildErrorContent(colors, provider)
            else if (provider.filteredVendors.isEmpty)
              _buildEmptyContent(colors, vendorType, size)
            else ...[
              // 1. GrabGo Exclusives
              VendorHorizontalSection(
                title: "GrabGo Exclusives",
                icon: Assets.icons.tag,
                vendors: provider.exclusiveVendors,
                onItemTap: (vendor) =>
                    context.push('/vendorDetails', extra: vendor),
                isLoading: provider.isLoading,
                accentColor: colors.accentOrange,
              ),
              SizedBox(height: KSpacing.lg.h),

              // 2. New on GrabGo
              VendorHorizontalSection(
                title: "New on GrabGo",
                icon: Assets.icons.sparkles,
                vendors: provider.newVendors,
                onItemTap: (vendor) =>
                    context.push('/vendorDetails', extra: vendor),
                isLoading: provider.isLoading,
                accentColor: colors.accentOrange,
              ),
              SizedBox(height: KSpacing.lg.h),

              // 3. Fastest Near You
              VendorHorizontalSection(
                title: "Fastest Near You",
                icon: Assets.icons.timer,
                vendors: provider.nearestVendors,
                onItemTap: (vendor) =>
                    context.push('/vendorDetails', extra: vendor),
                isLoading: provider.isLoading,
                accentColor: colors.accentOrange,
              ),
              SizedBox(height: KSpacing.lg.h),

              // 4. Budget Friendly
              VendorHorizontalSection(
                title: "Budget Friendly",
                icon: Assets.icons.cash,
                vendors: provider.budgetFriendlyVendors,
                onItemTap: (vendor) =>
                    context.push('/vendorDetails', extra: vendor),
                isLoading: provider.isLoading,
                accentColor: colors.accentOrange,
              ),
              SizedBox(height: KSpacing.lg.h),

              // 5. All Vendors
              SectionHeader(
                title: "All ${vendorType.displayName}s",
                sectionTotal: provider.filteredVendors.length,
                accentColor: colors.accentOrange,
                onSeeAll: () {},
              ),
              _buildVendorList(provider),
            ],

            SizedBox(height: KSpacing.lg.h),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleHeader(
    AppColorsExtension colors,
    Color accentColor,
    VendorProvider provider,
    VendorType vendorType,
    Size size,
    ServiceProvider serviceProvider,
  ) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(
          0.0,
          1.0,
        );
        // Match home_page.dart expanded height
        final expandedHeight = UmbrellaHeaderMetrics.expandedHeightFor(size);
        final currentHeight =
            expandedHeight -
            ((expandedHeight - _collapsedHeight) * collapseProgress);
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
              child: _buildHeaderContent(colors, vendorType, serviceProvider),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderContent(
    AppColorsExtension colors,
    VendorType vendorType,
    ServiceProvider serviceProvider,
  ) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final foodProvider = context.watch<FoodProvider>();

    // Prepare categories for HomeSearch
    List<FoodCategoryModel> categories = [];
    if (serviceProvider.isFoodService) {
      categories = foodProvider.categories;
    } else if (serviceProvider.isGroceryService) {
      // Map GroceryCategory to FoodCategoryModel if needed or pass empty
      // Currently HomeSearch expects FoodCategoryModel
      // We can pass empty for now or a filtered list
    }

    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: 20.w,
              right: 20.w,
              top: statusBarHeight + 10.h,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${vendorType.displayName}s',
                      style: TextStyle(
                        fontFamily: "Lato",
                        package: 'grab_go_shared',
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  "Find the best ${vendorType.displayName.toLowerCase()}s near you",
                  style: TextStyle(
                    fontFamily: "Lato",
                    package: 'grab_go_shared',
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          HomeSearch(
            categories: categories,
            activeFilter: _activeFilter,
            hintText: "Search ${vendorType.displayName.toLowerCase()}s...",
            isFood: serviceProvider.isFoodService,
            onFilterApplied: (filter) {
              setState(() {
                _activeFilter = filter;
                // Update VendorProvider with filter values
                final provider = context.read<VendorProvider>();
                if (filter.minRating != null) {
                  provider.setMinRating(filter.minRating);
                }
                // Map other filters if VendorProvider supports them
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVendorList(VendorProvider provider) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: 10.h),
      itemCount: provider.filteredVendors.length,
      itemBuilder: (context, index) {
        final vendor = provider.filteredVendors[index];
        return VendorCard(
          vendor: vendor,
          onTap: () => context.push('/vendorDetails', extra: vendor),
        );
      },
    );
  }

  Widget _buildLoadingContent() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(vertical: 10.h),
      itemCount: 6,
      itemBuilder: (context, index) => const VendorCardSkeleton(),
    );
  }

  Widget _buildEmptyContent(
    AppColorsExtension colors,
    VendorType vendorType,
    Size size,
  ) {
    return Container(
      height: size.height * 0.5,
      padding: EdgeInsets.symmetric(horizontal: 40.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(vendorType.emoji, style: TextStyle(fontSize: 64.sp)),
          SizedBox(height: 16.h),
          Text(
            'No ${vendorType.displayName.toLowerCase()}s found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Try adjusting your filters or search terms',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorContent(
    AppColorsExtension colors,
    VendorProvider provider,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 60.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64.sp, color: colors.error),
          SizedBox(height: 16.h),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            provider.error ?? 'Unknown error',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: () => provider.refreshVendors(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accentOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class VendorCardSkeleton extends StatelessWidget {
  const VendorCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(
          color: colors.inputBorder.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Skeleton (Full Width)
          Container(
            height: 140.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.inputBorder.withValues(alpha: 0.3),
            ),
          ),

          // Info Skeleton (Three Rows)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Name and Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 18.h,
                      width: 140.w,
                      decoration: BoxDecoration(
                        color: colors.inputBorder.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    Container(
                      height: 18.h,
                      width: 40.w,
                      decoration: BoxDecoration(
                        color: colors.inputBorder.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                // Row 2: Category and Distance
                Container(
                  height: 14.h,
                  width: 180.w,
                  decoration: BoxDecoration(
                    color: colors.inputBorder.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 16.h),
                // Row 3: Delivery Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 14.h,
                      width: 160.w,
                      decoration: BoxDecoration(
                        color: colors.inputBorder.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    Container(
                      height: 14.h,
                      width: 60.w,
                      decoration: BoxDecoration(
                        color: colors.inputBorder.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
