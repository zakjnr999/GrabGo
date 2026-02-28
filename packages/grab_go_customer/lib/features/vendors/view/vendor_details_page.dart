import 'dart:ui';

import 'package:chopper/chopper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
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
import 'package:grab_go_shared/grub_go_shared.dart' hide FoodRepository, FoodService;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class VendorDetailsPage extends StatefulWidget {
  const VendorDetailsPage({super.key, required this.vendor});

  final VendorModel vendor;

  @override
  State<VendorDetailsPage> createState() => _VendorDetailsPageState();
}

class _VendorDetailsPageState extends State<VendorDetailsPage> {
  final List<_VendorDisplayItem> _vendorItems = [];
  late VendorModel _vendor;
  bool _isLoadingVendorDetails = true;
  bool _isLoadingItems = true;
  String? _itemsError;

  @override
  void initState() {
    super.initState();
    _vendor = widget.vendor;
    _fetchVendorDetails();
    _fetchVendorItems();
  }

  Future<void> _fetchVendorDetails() async {
    try {
      final currentVendor = _vendor;
      late Response<Map<String, dynamic>> response;

      switch (currentVendor.vendorTypeEnum) {
        case VendorType.food:
          response = await vendorService.getRestaurantById(currentVendor.id);
          break;
        case VendorType.grocery:
          response = await vendorService.getGroceryStoreById(currentVendor.id);
          break;
        case VendorType.pharmacy:
          response = await vendorService.getPharmacyStoreById(currentVendor.id);
          break;
        case VendorType.grabmart:
          response = await vendorService.getGrabMartStoreById(currentVendor.id);
          break;
      }

      final body = response.body;
      if (response.isSuccessful && body != null && body['data'] is Map<String, dynamic>) {
        final detailJson = Map<String, dynamic>.from(body['data'] as Map<String, dynamic>);
        final detail = currentVendor.mergeDetailSnapshot(detailJson);

        if (!mounted) return;
        setState(() {
          _vendor = detail;
        });
      }
    } catch (error) {
      debugPrint('VendorDetailsPage: failed to load vendor details: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingVendorDetails = false;
        });
      }
    }
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
          final foods = await FoodRepository().fetchFoods(restaurantId: vendorId);
          items.addAll(foods.map((item) => _VendorDisplayItem(id: item.id, sourceItem: item, displayItem: item)));
          break;
        case VendorType.grocery:
          final groceries = await GroceryRepository().fetchItems(store: vendorId);
          items.addAll(
            groceries.map((item) => _VendorDisplayItem(id: item.id, sourceItem: item, displayItem: item.toFoodItem())),
          );
          break;
        case VendorType.pharmacy:
          final pharmacyItems = await PharmacyRepository().fetchItems(store: vendorId);
          items.addAll(
            pharmacyItems.map(
              (item) => _VendorDisplayItem(id: item.id, sourceItem: item, displayItem: item.toFoodItem()),
            ),
          );
          break;
        case VendorType.grabmart:
          final grabmartItems = await GrabMartRepository().fetchItems(store: vendorId);
          items.addAll(
            grabmartItems.map(
              (item) => _VendorDisplayItem(id: item.id, sourceItem: item, displayItem: item.toFoodItem()),
            ),
          );
          break;
      }

      items.sort((a, b) {
        final byOrders = b.displayItem.orderCount.compareTo(a.displayItem.orderCount);
        if (byOrders != 0) return byOrders;
        final byRating = b.displayItem.rating.compareTo(a.displayItem.rating);
        if (byRating != 0) return byRating;
        return a.displayItem.name.toLowerCase().compareTo(b.displayItem.name.toLowerCase());
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
      isVerified: _vendor.isVerified ?? false,
      featured: _vendor.featured ?? false,
      isAcceptingOrders: _vendor.isAcceptingOrders,
      lastOnlineAt: _vendor.lastOnlineAt,
      type: _favoriteVendorType,
    );
  }

  void _openItemDetails(_VendorDisplayItem item) {
    context.push('/foodDetails', extra: item.sourceItem);
  }

  void _openVendorInfo() {
    context.push('/vendorInfo', extra: _vendor);
  }

  Future<void> _shareVendor() async {
    final buffer = StringBuffer('Check out ${_vendor.displayName} on GrabGo.');
    final address = _vendor.address.trim();
    final website = _vendor.websiteUrl?.trim();

    if (address.isNotEmpty) {
      buffer.write('\n$address');
    }
    if (website != null && website.isNotEmpty) {
      buffer.write('\n$website');
    }

    try {
      await SharePlus.instance.share(ShareParams(text: buffer.toString(), subject: '${_vendor.displayName} on GrabGo'));
    } catch (_) {
      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: 'Unable to share this store right now.',
      );
    }
  }

  String? _heroImageUrlFor(VendorModel vendor, {bool allowLogoFallback = true}) {
    final bannerImage = vendor.bannerImages
        ?.cast<String?>()
        .map((entry) => entry?.trim() ?? '')
        .firstWhere((entry) => entry.isNotEmpty, orElse: () => '');
    if (bannerImage != null && bannerImage.isNotEmpty) return bannerImage;

    if (allowLogoFallback) {
      final logo = vendor.logo?.trim();
      if (logo != null && logo.isNotEmpty) return logo;
    }
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
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );
    final popularItems = _vendorItems.take(5).toList(growable: false);
    final heroImageUrl = _isLoadingVendorDetails
        ? null
        : (_heroImageUrlFor(_vendor, allowLogoFallback: false) ?? _heroImageUrlFor(_vendor));
    final expandedHeight = size.height * 0.20;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: CustomScrollView(
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
                  final totalRange = (expandedHeight - collapsedHeight).clamp(1.0, double.infinity);
                  final collapseT = (1 - ((constraints.maxHeight - collapsedHeight) / totalRange)).clamp(0.0, 1.0);
                  final collapsingToolbarColor = Color.lerp(
                    Colors.transparent,
                    colors.backgroundPrimary.withValues(alpha: 0.96),
                    collapseT,
                  )!;
                  final useDarkStatusIcons = !isDark && collapseT > 0.72;

                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: useDarkStatusIcons ? Brightness.dark : Brightness.light,
                      statusBarBrightness: useDarkStatusIcons ? Brightness.light : Brightness.dark,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.expand,
                      children: [
                        if (heroImageUrl != null)
                          CachedNetworkImage(
                            imageUrl: ImageOptimizer.getFullUrl(heroImageUrl, width: 1200),
                            fit: BoxFit.cover,
                            memCacheWidth: 900,
                            maxHeightDiskCache: 700,
                            placeholder: (context, url) => _buildHeroPlaceholder(colors, accentColor),
                            errorWidget: (context, url, error) => _buildHeroPlaceholder(colors, accentColor),
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
                                  Color.lerp(accentColor.withValues(alpha: 0.22), Colors.transparent, collapseT)!,
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.38, 1.0],
                              ),
                            ),
                          ),
                        ),
                        if (!_isLoadingVendorDetails && !_vendor.isAvailableForOrders)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.45),
                              alignment: Alignment.center,
                              child: Text(
                                _vendor.overlayAvailabilityLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        Positioned.fill(child: ColoredBox(color: collapsingToolbarColor)),
                        Positioned(
                          left: 20.w,
                          right: 20.w,
                          bottom: -34.h,
                          child: Opacity(
                            opacity: (1 - collapseT * 1.8).clamp(0.0, 1.0),
                            child: _buildVendorOverviewCard(colors, accentColor),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              bottom: PreferredSize(preferredSize: Size.fromHeight(72.h), child: const SizedBox.shrink()),
              actionsPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
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
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
                const Spacer(),

                _buildSliverActionButton(
                  onTap: _shareVendor,
                  child: SvgPicture.asset(
                    Assets.icons.shareAndroid,
                    package: 'grab_go_shared',
                    height: 20.h,
                    width: 20.w,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
                SizedBox(width: 10.w),
                Consumer<FavoritesProvider>(
                  builder: (context, favoritesProvider, child) {
                    final isFavorite = favoritesProvider.isVendorFavoriteById(_vendor.id, _favoriteVendorType);
                    return _buildSliverActionButton(
                      onTap: () async {
                        try {
                          await favoritesProvider.toggleVendorFavorite(_asFavoriteVendor());
                        } catch (_) {
                          if (!mounted) return;
                          AppToastMessage.show(
                            context: context,
                            backgroundColor: colors.error,
                            message: 'Unable to update favorites. Please try again.',
                          );
                        }
                      },
                      child: SvgPicture.asset(
                        isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                        package: 'grab_go_shared',
                        height: 20.h,
                        width: 20.w,
                        colorFilter: ColorFilter.mode(isFavorite ? colors.error : Colors.white, BlendMode.srcIn),
                      ),
                    );
                  },
                ),
                SizedBox(width: 10.w),
                _buildSliverActionButton(
                  onTap: _openVendorInfo,
                  child: SvgPicture.asset(
                    Assets.icons.infoCircle,
                    package: 'grab_go_shared',
                    height: 20.h,
                    width: 20.w,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(22.r), topRight: Radius.circular(22.r)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 10.h),
                      Center(
                        child: Container(
                          width: 40.w,
                          height: 4.h,
                          decoration: BoxDecoration(
                            color: colors.textSecondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      _buildQuickStatsCard(colors),
                      SizedBox(height: 16.h),
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
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: popularItems.length,
                                  itemBuilder: (context, index) {
                                    final item = popularItems[index].displayItem;
                                    return Padding(
                                      padding: EdgeInsets.only(right: 12.w),
                                      child: DealCard(
                                        item: item,
                                        discountPercent: item.discountPercentage.toInt(),
                                        deliveryTime: item.estimatedDeliveryTime,
                                        cardWidth: (size.width * 0.62).clamp(200.0, 260.0),
                                        onTap: () => _openItemDetails(popularItems[index]),
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
                            message: 'No items available from this vendor right now.',
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
                                  margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
                                  onTap: () => _openItemDetails(item),
                                ),
                            ],
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
    );
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

  Widget _buildSliverActionButton({required VoidCallback onTap, required Widget child}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: Container(
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.22), shape: BoxShape.circle),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVendorOverviewCard(AppColorsExtension colors, Color accentColor) {
    final displayVendor = _vendor;
    final locationText = displayVendor.address.trim().isNotEmpty
        ? displayVendor.address.trim()
        : [
            displayVendor.area?.trim(),
            displayVendor.city.trim(),
          ].whereType<String>().where((entry) => entry.isNotEmpty).join(', ');
    final summaryPills = <Widget>[
      if (displayVendor.isVerified == true)
        _buildMetaPill(
          colors: colors,
          label: 'Verified',
          backgroundColor: colors.accentGreen.withValues(alpha: 0.12),
          textColor: colors.accentGreen,
        ),
      if (displayVendor.featured == true)
        _buildMetaPill(
          colors: colors,
          label: 'Featured',
          backgroundColor: colors.accentOrange.withValues(alpha: 0.12),
          textColor: colors.accentOrange,
        ),
      if (displayVendor.isExclusive)
        _buildMetaPill(
          colors: colors,
          label: 'GrabGo Exclusive',
          backgroundColor: colors.accentOrange.withValues(alpha: 0.12),
          textColor: colors.accentOrange,
        ),
      if (!_isLoadingVendorDetails && !displayVendor.isAcceptingOrders)
        _buildMetaPill(
          colors: colors,
          label: 'Not accepting orders',
          backgroundColor: colors.error.withValues(alpha: 0.10),
          textColor: colors.error,
        ),
    ];

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: displayVendor.logo != null && displayVendor.logo!.trim().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ImageOptimizer.getFullUrl(displayVendor.logo!, width: 240),
                          fit: BoxFit.cover,
                          memCacheWidth: 240,
                          placeholder: (context, url) => _buildHeroPlaceholder(colors, accentColor),
                          errorWidget: (context, url, error) => _buildHeroPlaceholder(colors, accentColor),
                        )
                      : _buildHeroPlaceholder(colors, accentColor),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayVendor.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
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
                          colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          displayVendor.rating.toStringAsFixed(1),
                          style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                        ),
                        if (displayVendor.totalReviews > 0) ...[
                          SizedBox(width: 4.w),
                          Flexible(
                            child: Text(
                              '(${displayVendor.totalReviews} reviews)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(width: 4.w),
                        GestureDetector(
                          onTap: () => context.push('/vendorRatings'),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: EdgeInsets.all(2.r),
                            child: SvgPicture.asset(
                              Assets.icons.navArrowRight,
                              package: 'grab_go_shared',
                              width: 12.w,
                              height: 12.w,
                              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                            ),
                          ),
                        ),
                        if (_isLoadingVendorDetails) ...[
                          SizedBox(width: 8.w),
                          Container(
                            width: 56.w,
                            height: 10.h,
                            decoration: BoxDecoration(
                              color: colors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(999.r),
                            ),
                          ),
                        ] else ...[
                          SizedBox(width: 8.w),
                          Container(
                            width: 4.w,
                            height: 4.w,
                            decoration: BoxDecoration(
                              color: colors.textSecondary.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: Text(
                              displayVendor.shortAvailabilityLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: displayVendor.isAvailableForOrders ? colors.accentGreen : colors.error,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (locationText.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SvgPicture.asset(
                            Assets.icons.mapPin,
                            package: 'grab_go_shared',
                            width: 14.w,
                            height: 14.w,
                            colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                          ),
                          SizedBox(width: 5.w),
                          Expanded(
                            child: Text(
                              locationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (summaryPills.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Wrap(spacing: 8.w, runSpacing: 8.h, children: summaryPills),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaPill({
    required AppColorsExtension colors,
    required String label,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor ?? colors.textPrimary, fontSize: 11.sp, fontWeight: FontWeight.w700),
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
            _buildStatColumn(colors, 'Delivery Fee', _vendor.deliveryFeeText),
            _buildDivider(colors),
            _buildStatColumn(colors, 'Min Order', _vendor.minOrderText),
            _buildDivider(colors),
            _buildStatColumn(colors, 'ETA', etaText),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(AppColorsExtension colors, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w700),
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
              style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
            ),
          ),
          if (actionText != null && onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Text(
                actionText,
                style: TextStyle(color: colors.accentOrange, fontSize: 12.sp, fontWeight: FontWeight.w700),
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

  const _VendorDisplayItem({required this.id, required this.sourceItem, required this.displayItem});
}
