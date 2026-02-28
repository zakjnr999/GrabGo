import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/grabmart/repository/grabmart_repository.dart';
import 'package:grab_go_customer/features/groceries/repository/grocery_repository.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/features/pharmacy/repository/pharmacy_repository.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/deal_card.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart'
    hide FoodRepository, FoodService;
import 'package:provider/provider.dart';

class VendorDetailsPage extends StatefulWidget {
  const VendorDetailsPage({super.key, required this.vendor});

  final VendorModel vendor;

  @override
  State<VendorDetailsPage> createState() => _VendorDetailsPageState();
}

class _VendorDetailsPageState extends State<VendorDetailsPage> {
  final List<_VendorDisplayItem> _vendorItems = [];
  bool _isLoadingItems = true;
  String? _itemsError;

  @override
  void initState() {
    super.initState();
    _fetchVendorItems();
  }

  Future<void> _fetchVendorItems() async {
    if (!mounted) return;
    setState(() {
      _isLoadingItems = true;
      _itemsError = null;
    });

    try {
      final vendorId = _vendor.id;
      final vendorType = _vendor.vendorTypeEnum;
      final items = <_VendorDisplayItem>[];

      switch (vendorType) {
        case VendorType.food:
          final foods = await FoodRepository().fetchFoods(
            restaurantId: vendorId,
          );
          items.addAll(
            foods.map(
              (item) => _VendorDisplayItem(
                id: item.id,
                sourceItem: item,
                displayItem: item,
              ),
            ),
          );
          break;
        case VendorType.grocery:
          final groceries = await GroceryRepository().fetchItems(
            store: vendorId,
          );
          items.addAll(
            groceries.map(
              (item) => _VendorDisplayItem(
                id: item.id,
                sourceItem: item,
                displayItem: item.toFoodItem(),
              ),
            ),
          );
          break;
        case VendorType.pharmacy:
          final pharmacyItems = await PharmacyRepository().fetchItems(
            store: vendorId,
          );
          items.addAll(
            pharmacyItems.map(
              (item) => _VendorDisplayItem(
                id: item.id,
                sourceItem: item,
                displayItem: item.toFoodItem(),
              ),
            ),
          );
          break;
        case VendorType.grabmart:
          final grabmartItems = await GrabMartRepository().fetchItems(
            store: vendorId,
          );
          items.addAll(
            grabmartItems.map(
              (item) => _VendorDisplayItem(
                id: item.id,
                sourceItem: item,
                displayItem: item.toFoodItem(),
              ),
            ),
          );
          break;
      }

      items.sort((a, b) {
        final byOrders = b.displayItem.orderCount.compareTo(
          a.displayItem.orderCount,
        );
        if (byOrders != 0) return byOrders;
        final byRating = b.displayItem.rating.compareTo(a.displayItem.rating);
        if (byRating != 0) return byRating;
        return a.displayItem.name.toLowerCase().compareTo(
          b.displayItem.name.toLowerCase(),
        );
      });

      if (!mounted) return;
      setState(() {
        _vendorItems
          ..clear()
          ..addAll(items);
        _isLoadingItems = false;
      });
    } catch (error) {
      debugPrint('VendorDetailsPage: failed to load vendor items: $error');
      if (!mounted) return;
      setState(() {
        _vendorItems.clear();
        _isLoadingItems = false;
        _itemsError = 'Could not load items right now.';
      });
    }
  }

  FavoriteVendorType get _favoriteVendorType {
    switch (_vendor.vendorTypeEnum) {
      case VendorType.food:
        return FavoriteVendorType.restaurant;
      case VendorType.grocery:
        return FavoriteVendorType.groceryStore;
      case VendorType.pharmacy:
        return FavoriteVendorType.pharmacyStore;
      case VendorType.grabmart:
        return FavoriteVendorType.grabMartStore;
    }
  }

  FavoriteVendor _asFavoriteVendor() {
    return FavoriteVendor(
      id: _vendor.id,
      name: _vendor.displayName,
      image: _vendor.logo ?? '',
      address: _vendor.address,
      city: _vendor.city,
      area: _vendor.area,
      status: 'approved',
      isOpen: _vendor.isOpen,
      isAcceptingOrders: _vendor.isAcceptingOrders,
      type: _favoriteVendorType,
    );
  }

  String _formatOpeningTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '--';
    final parsed = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
    if (parsed == null) return raw.trim();
    final hour24 = int.tryParse(parsed.group(1)!);
    final minute = parsed.group(2)!;
    if (hour24 == null || hour24 < 0 || hour24 > 23) return raw.trim();
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minute $suffix';
  }

  DaySchedule? _todaySchedule(OpeningHours? openingHours) {
    if (openingHours == null) return null;
    switch (DateTime.now().weekday) {
      case DateTime.monday:
        return openingHours.monday;
      case DateTime.tuesday:
        return openingHours.tuesday;
      case DateTime.wednesday:
        return openingHours.wednesday;
      case DateTime.thursday:
        return openingHours.thursday;
      case DateTime.friday:
        return openingHours.friday;
      case DateTime.saturday:
        return openingHours.saturday;
      case DateTime.sunday:
        return openingHours.sunday;
      default:
        return null;
    }
  }

  String _availabilityText() {
    if (_vendor.is24Hours == true) return 'Open 24 hours';
    final today = _todaySchedule(_vendor.openingHours);
    if (today == null) {
      return _vendor.isOpen ? 'Open now' : 'Closed for now';
    }
    if (today.isClosed) return 'Closed today';
    return _vendor.isOpen
        ? 'Closes at ${_formatOpeningTime(today.close)}'
        : 'Opens at ${_formatOpeningTime(today.open)}';
  }

  void _openItemDetails(_VendorDisplayItem item) {
    context.push('/foodDetails', extra: item.sourceItem);
  }

  String? _heroImageUrl() {
    final bannerImage = _vendor.bannerImages
        ?.cast<String?>()
        .map((entry) => entry?.trim() ?? '')
        .firstWhere((entry) => entry.isNotEmpty, orElse: () => '');
    if (bannerImage != null && bannerImage.isNotEmpty) return bannerImage;

    final logo = _vendor.logo?.trim();
    if (logo != null && logo.isNotEmpty) return logo;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final accentColor = Color(_vendor.vendorTypeEnum.color);
    final statusBarStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
    final popularItems = _vendorItems.take(5).toList(growable: false);
    final heroImageUrl = _heroImageUrl();
    final expandedHeight = size.height * 0.24;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: RefreshIndicator(
          color: accentColor,
          onRefresh: _fetchVendorItems,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: expandedHeight,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                systemOverlayStyle: const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                ),
                elevation: 0,
                pinned: true,
                stretch: false,
                automaticallyImplyLeading: false,
                flexibleSpace: LayoutBuilder(
                  builder: (context, constraints) {
                    final collapsedHeight = kToolbarHeight + topPadding;
                    final totalRange = (expandedHeight - collapsedHeight).clamp(
                      1.0,
                      double.infinity,
                    );
                    final collapseT =
                        (1 -
                                ((constraints.maxHeight - collapsedHeight) /
                                    totalRange))
                            .clamp(0.0, 1.0);
                    final collapsingToolbarColor = Color.lerp(
                      Colors.transparent,
                      colors.backgroundPrimary.withValues(alpha: 0.96),
                      collapseT,
                    )!;
                    final useDarkStatusIcons = !isDark && collapseT > 0.72;

                    return AnnotatedRegion<SystemUiOverlayStyle>(
                      value: SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: useDarkStatusIcons
                            ? Brightness.dark
                            : Brightness.light,
                        statusBarBrightness: useDarkStatusIcons
                            ? Brightness.light
                            : Brightness.dark,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (heroImageUrl != null)
                            CachedNetworkImage(
                              imageUrl: ImageOptimizer.getFullUrl(
                                heroImageUrl,
                                width: 1200,
                              ),
                              fit: BoxFit.cover,
                              memCacheWidth: 900,
                              maxHeightDiskCache: 700,
                              placeholder: (context, url) =>
                                  _buildHeroPlaceholder(colors, accentColor),
                              errorWidget: (context, url, error) =>
                                  _buildHeroPlaceholder(colors, accentColor),
                            )
                          else
                            _buildHeroPlaceholder(colors, accentColor),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color.lerp(
                                      Colors.black.withValues(alpha: 0.58),
                                      Colors.black.withValues(alpha: 0.28),
                                      collapseT,
                                    )!,
                                    Color.lerp(
                                      accentColor.withValues(alpha: 0.22),
                                      Colors.transparent,
                                      collapseT,
                                    )!,
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.38, 1.0],
                                ),
                              ),
                            ),
                          ),
                          if (!_vendor.isOpen)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.45),
                                alignment: Alignment.center,
                                child: Text(
                                  "We're closed",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          Positioned.fill(
                            child: ColoredBox(color: collapsingToolbarColor),
                          ),
                          Positioned(
                            left: 20.w,
                            right: 88.w,
                            bottom: 42.h,
                            child: Opacity(
                              opacity: (1 - collapseT * 1.25).clamp(0.0, 1.0),
                              child: IgnorePointer(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _vendor.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24.sp,
                                        fontWeight: FontWeight.w800,
                                        height: 1.05,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Row(
                                      children: [
                                        SvgPicture.asset(
                                          Assets.icons.starSolid,
                                          package: 'grab_go_shared',
                                          width: 14.w,
                                          height: 14.w,
                                          colorFilter: ColorFilter.mode(
                                            accentColor,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                        SizedBox(width: 4.w),
                                        Text(
                                          _vendor.rating.toStringAsFixed(
                                            1,
                                          ),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (_vendor.totalReviews > 0) ...[
                                          SizedBox(width: 4.w),
                                          Text(
                                            '(${_vendor.totalReviews} reviews)',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.85,
                                              ),
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                        SizedBox(width: 8.w),
                                        Container(
                                          width: 4.w,
                                          height: 4.w,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.7,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            _vendor.isOpen
                                                ? 'Open now'
                                                : 'Closed for now',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _vendor.isOpen
                                                  ? colors.accentGreen
                                                        .withValues(alpha: 0.95)
                                                  : const Color(0xFFFFC9C9),
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(24.h),
                  child: Container(
                    height: 24.h,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20.r),
                        topRight: Radius.circular(20.r),
                      ),
                    ),
                    child: Container(
                      margin: EdgeInsets.only(top: 8.h),
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                  ),
                ),
                actionsPadding: EdgeInsets.symmetric(
                  horizontal: 10.w,
                  vertical: 2.h,
                ),
                actions: [
                  _buildSliverActionButton(
                    onTap: () {
                      final router = GoRouter.of(context);
                      if (router.canPop()) {
                        router.pop();
                      } else {
                        context.go('/homepage');
                      }
                    },
                    child: SvgPicture.asset(
                      Assets.icons.navArrowLeft,
                      package: 'grab_go_shared',
                      height: 20.h,
                      width: 20.w,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, child) {
                      final isFavorite = favoritesProvider.isVendorFavoriteById(
                        _vendor.id,
                        _favoriteVendorType,
                      );
                      return _buildSliverActionButton(
                        onTap: () async {
                          try {
                            await favoritesProvider.toggleVendorFavorite(
                              _asFavoriteVendor(),
                            );
                          } catch (_) {
                            if (!mounted) return;
                            AppToastMessage.show(
                              context: context,
                              backgroundColor: colors.error,
                              message:
                                  'Unable to update favorites. Please try again.',
                            );
                          }
                        },
                        child: SvgPicture.asset(
                          isFavorite
                              ? Assets.icons.heartSolid
                              : Assets.icons.heart,
                          package: 'grab_go_shared',
                          height: 20.h,
                          width: 20.w,
                          colorFilter: ColorFilter.mode(
                            isFavorite ? colors.error : Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildVendorOverviewCard(colors, accentColor),
                      SizedBox(height: 14.h),
                      _buildQuickStatsCard(colors),
                      SizedBox(height: 14.h),
                      if (_hasOpeningHours) ...[
                        _buildOpeningHoursCard(colors),
                        SizedBox(height: 14.h),
                      ],
                      if (_hasTagsOrCategories) ...[
                        _buildTagsSection(colors),
                        SizedBox(height: 14.h),
                      ],
                      if (popularItems.isNotEmpty || _isLoadingItems) ...[
                        SectionHeader(
                          title: 'Popular at ${_vendor.displayName}',
                          sectionTotal: popularItems.length,
                          accentColor: accentColor,
                          onSeeAll: null,
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          height: 225.h,
                          child: _isLoadingItems
                              ? _buildPopularLoadingRow(colors)
                              : ListView.builder(
                                  padding: EdgeInsets.only(left: 20.w),
                                  scrollDirection: Axis.horizontal,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount: popularItems.length,
                                  itemBuilder: (context, index) {
                                    final item =
                                        popularItems[index].displayItem;
                                    return Padding(
                                      padding: EdgeInsets.only(right: 12.w),
                                      child: DealCard(
                                        item: item,
                                        discountPercent: item.discountPercentage
                                            .toInt(),
                                        deliveryTime:
                                            item.estimatedDeliveryTime,
                                        cardWidth: (size.width * 0.62).clamp(
                                          200.0,
                                          260.0,
                                        ),
                                        onTap: () => _openItemDetails(
                                          popularItems[index],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        SizedBox(height: 16.h),
                      ],
                      SectionHeader(
                        title: 'Menu',
                        sectionTotal: _vendorItems.length,
                        accentColor: accentColor,
                        onSeeAll: null,
                      ),
                      SizedBox(height: 10.h),
                      if (_isLoadingItems)
                        _buildMenuLoadingList(colors)
                      else if (_itemsError != null)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: _buildInlineMessage(
                            colors: colors,
                            message: _itemsError!,
                            actionText: 'Retry',
                            onTap: _fetchVendorItems,
                          ),
                        )
                      else if (_vendorItems.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w),
                          child: _buildInlineMessage(
                            colors: colors,
                            message:
                                'No items available from this vendor right now.',
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: Column(
                            children: [
                              for (final item in _vendorItems)
                                FoodItemCard(
                                  item: item.displayItem,
                                  margin: EdgeInsets.symmetric(
                                    horizontal: 4.w,
                                    vertical: 6.h,
                                  ),
                                  onTap: () => _openItemDetails(item),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasOpeningHours {
    return _vendor.openingHours != null;
  }

  bool get _hasTagsOrCategories {
    return _vendor.vendorCategories.isNotEmpty ||
        (_vendor.tags?.isNotEmpty ?? false);
  }

  Widget _buildHeroPlaceholder(AppColorsExtension colors, Color accentColor) {
    return Container(
      color: accentColor.withValues(alpha: 0.92),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        Assets.icons.store,
        package: 'grab_go_shared',
        width: 44.w,
        height: 44.w,
        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      ),
    );
  }

  Widget _buildSliverActionButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44.w,
        height: 44.w,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVendorOverviewCard(
    AppColorsExtension colors,
    Color accentColor,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                _buildInfoChip(
                  colors: colors,
                  backgroundColor: colors.backgroundSecondary,
                  iconAsset: Assets.icons.starSolid,
                  iconColor: accentColor,
                  label: _vendor.totalReviews > 0
                      ? '${_vendor.rating.toStringAsFixed(1)} (${_vendor.totalReviews} reviews)'
                      : _vendor.rating.toStringAsFixed(1),
                ),
                _buildInfoChip(
                  colors: colors,
                  backgroundColor: _vendor.isOpen
                      ? colors.accentGreen.withValues(alpha: 0.12)
                      : colors.error.withValues(alpha: 0.10),
                  label: _availabilityText(),
                  textColor: _vendor.isOpen
                      ? colors.accentGreen
                      : colors.error,
                ),
              ],
            ),
            if (_vendor.address.isNotEmpty) ...[
              SizedBox(height: 10.h),
              Text(
                _vendor.address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
            if ((_vendor.description ?? '').trim().isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                _vendor.description!.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip({
    required AppColorsExtension colors,
    required Color backgroundColor,
    required String label,
    String? iconAsset,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconAsset != null) ...[
            SvgPicture.asset(
              iconAsset,
              package: 'grab_go_shared',
              width: 13.w,
              height: 13.w,
              colorFilter: ColorFilter.mode(
                iconColor ?? colors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 4.w),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor ?? colors.textPrimary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard(AppColorsExtension colors) {
    final etaText = _vendor.averageDeliveryTime != null
        ? '${_vendor.averageDeliveryTime} mins'
        : _vendor.deliveryTimeText;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Row(
          children: [
            _buildStatColumn(
              colors,
              'Delivery Fee',
              _vendor.deliveryFeeText,
            ),
            _buildDivider(colors),
            _buildStatColumn(colors, 'Min Order', _vendor.minOrderText),
            _buildDivider(colors),
            _buildStatColumn(colors, 'ETA', etaText),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    AppColorsExtension colors,
    String label,
    String value,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(AppColorsExtension colors) {
    return Container(
      width: 1,
      height: 30.h,
      margin: EdgeInsets.symmetric(horizontal: 6.w),
      color: colors.inputBorder.withValues(alpha: 0.5),
    );
  }

  Widget _buildOpeningHoursCard(AppColorsExtension colors) {
    final openingHours = _vendor.openingHours;
    if (openingHours == null) return const SizedBox.shrink();

    final dayEntries = <(String, DaySchedule?)>[
      ('Mon', openingHours.monday),
      ('Tue', openingHours.tuesday),
      ('Wed', openingHours.wednesday),
      ('Thu', openingHours.thursday),
      ('Fri', openingHours.friday),
      ('Sat', openingHours.saturday),
      ('Sun', openingHours.sunday),
    ];
    final todayIndex = DateTime.now().weekday - 1;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Opening Hours',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8.h),
            for (int index = 0; index < dayEntries.length; index++) ...[
              _buildOpeningHourRow(
                colors: colors,
                dayLabel: dayEntries[index].$1,
                schedule: dayEntries[index].$2,
                isToday: index == todayIndex,
              ),
              if (index < dayEntries.length - 1) SizedBox(height: 4.h),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOpeningHourRow({
    required AppColorsExtension colors,
    required String dayLabel,
    required DaySchedule? schedule,
    required bool isToday,
  }) {
    final isClosed = schedule == null || schedule.isClosed;
    final value = isClosed
        ? 'Closed'
        : '${_formatOpeningTime(schedule.open)} - ${_formatOpeningTime(schedule.close)}';
    return Row(
      children: [
        SizedBox(
          width: 42.w,
          child: Text(
            dayLabel,
            style: TextStyle(
              color: isToday ? colors.accentOrange : colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isToday ? colors.textPrimary : colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTagsSection(AppColorsExtension colors) {
    final tags = <String>[
      ..._vendor.vendorCategories,
      ...(_vendor.tags ?? const <String>[]),
    ].where((entry) => entry.trim().isNotEmpty).toSet().toList(growable: false);
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          for (final tag in tags)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPopularLoadingRow(AppColorsExtension colors) {
    return ListView.builder(
      padding: EdgeInsets.only(left: 20.w),
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          width: 220.w,
          margin: EdgeInsets.only(right: 12.w),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
        );
      },
    );
  }

  Widget _buildMenuLoadingList(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            height: 210.h,
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 12.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineMessage({
    required AppColorsExtension colors,
    required String message,
    String? actionText,
    VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (actionText != null && onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Text(
                actionText,
                style: TextStyle(
                  color: colors.accentOrange,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VendorDisplayItem {
  final String id;
  final Object sourceItem;
  final FoodItem displayItem;

  const _VendorDisplayItem({
    required this.id,
    required this.sourceItem,
    required this.displayItem,
  });
}
