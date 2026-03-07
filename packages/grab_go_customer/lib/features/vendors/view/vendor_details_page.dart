import 'dart:ui';

import 'package:chopper/chopper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/grabmart/repository/grabmart_repository.dart';
import 'package:grab_go_customer/features/grabmart/viewmodel/grabmart_provider.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/groceries/repository/grocery_repository.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/repository/food_repository.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/pharmacy/repository/pharmacy_repository.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/features/vendors/widgets/exclusive_stamp_badge.dart';
import 'package:grab_go_customer/shared/services/auth_guard.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/deal_card.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/shared/widgets/section_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart'
    hide FoodRepository, FoodService;
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:share_plus/share_plus.dart';

class VendorDetailsPage extends StatefulWidget {
  const VendorDetailsPage({super.key, required this.vendor});

  final VendorModel vendor;

  @override
  State<VendorDetailsPage> createState() => _VendorDetailsPageState();
}

class _VendorDetailsPageState extends State<VendorDetailsPage> {
  static const String _allMenuCategoryId = '__all__';
  static const String _dealsMenuCategoryId = '__deals__';
  final List<_VendorDisplayItem> _vendorItems = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _menuSearchController = TextEditingController();
  final FocusNode _menuSearchFocusNode = FocusNode();
  late VendorModel _vendor;
  String _selectedMenuCategoryId = _allMenuCategoryId;
  String _menuSearchQuery = '';
  bool _isMenuSearchVisible = false;
  bool _isLoadingVendorDetails = true;
  bool _isLoadingItems = true;
  String? _itemsError;

  @override
  void initState() {
    super.initState();
    _vendor = widget.vendor;
    _scrollController.addListener(_handleScroll);
    _seedVendorItemsFromLocalCatalog();
    _fetchVendorDetails();
    _fetchVendorItems();
  }

  void _handleScroll() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _menuSearchController.dispose();
    _menuSearchFocusNode.dispose();
    super.dispose();
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
      if (response.isSuccessful &&
          body != null &&
          body['data'] is Map<String, dynamic>) {
        final detailJson = Map<String, dynamic>.from(
          body['data'] as Map<String, dynamic>,
        );
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

  void _seedVendorItemsFromLocalCatalog() {
    final vendorId = _vendor.id;
    final seededItems = <_VendorDisplayItem>[];

    switch (_vendor.vendorTypeEnum) {
      case VendorType.food:
        final provider = context.read<FoodProvider>();
        for (final category in provider.categories) {
          for (final item in category.items) {
            if (item.restaurantId != vendorId) continue;
            seededItems.add(
              _VendorDisplayItem(
                id: item.id,
                sourceItem: item,
                displayItem: item,
              ),
            );
          }
        }
        break;
      case VendorType.grocery:
        final provider = context.read<GroceryProvider>();
        for (final item in provider.items) {
          if (item.storeId != vendorId) continue;
          seededItems.add(
            _VendorDisplayItem(
              id: item.id,
              sourceItem: item,
              displayItem: item.toFoodItem(),
            ),
          );
        }
        break;
      case VendorType.pharmacy:
        final provider = context.read<PharmacyProvider>();
        for (final item in provider.items) {
          if (item.storeId != vendorId) continue;
          seededItems.add(
            _VendorDisplayItem(
              id: item.id,
              sourceItem: item,
              displayItem: item.toFoodItem(),
            ),
          );
        }
        break;
      case VendorType.grabmart:
        final provider = context.read<GrabMartProvider>();
        for (final item in provider.items) {
          if (item.storeId != vendorId) continue;
          seededItems.add(
            _VendorDisplayItem(
              id: item.id,
              sourceItem: item,
              displayItem: item.toFoodItem(),
            ),
          );
        }
        break;
    }

    if (seededItems.isEmpty) return;
    _sortVendorItems(seededItems);
    final resolvedMenuCategories = _resolveMenuCategories(seededItems);
    _vendorItems
      ..clear()
      ..addAll(seededItems);
    if (!resolvedMenuCategories.any(
      (category) => category.id == _selectedMenuCategoryId,
    )) {
      _selectedMenuCategoryId = _allMenuCategoryId;
    }
    _isLoadingItems = false;
    _itemsError = null;
  }

  void _sortVendorItems(List<_VendorDisplayItem> items) {
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
  }

  Future<void> _fetchVendorItems() async {
    if (!mounted) return;
    final hasSeededItems = _vendorItems.isNotEmpty;
    setState(() {
      if (!hasSeededItems) {
        _isLoadingItems = true;
      }
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

      _sortVendorItems(items);

      if (!mounted) return;
      final resolvedMenuCategories = _resolveMenuCategories(items);
      setState(() {
        _vendorItems
          ..clear()
          ..addAll(items);
        if (!resolvedMenuCategories.any(
          (category) => category.id == _selectedMenuCategoryId,
        )) {
          _selectedMenuCategoryId = _allMenuCategoryId;
        }
        _isLoadingItems = false;
      });
    } catch (error) {
      debugPrint('VendorDetailsPage: failed to load vendor items: $error');
      if (!mounted) return;
      setState(() {
        _isLoadingItems = false;
        if (_vendorItems.isEmpty) {
          _itemsError = 'Could not load items right now.';
        }
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

  void _toggleMenuSearch() {
    setState(() {
      _isMenuSearchVisible = !_isMenuSearchVisible;
      if (!_isMenuSearchVisible) {
        _menuSearchQuery = '';
        _menuSearchController.clear();
        _menuSearchFocusNode.unfocus();
      }
    });

    if (_isMenuSearchVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _menuSearchFocusNode.requestFocus();
        }
      });
    }
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
      await SharePlus.instance.share(
        ShareParams(
          text: buffer.toString(),
          subject: '${_vendor.displayName} on GrabGo',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: 'Unable to share this store right now.',
      );
    }
  }

  String? _heroImageUrlFor(
    VendorModel vendor, {
    bool allowLogoFallback = true,
  }) {
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
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
    final popularItems = _vendorItems.take(5).toList(growable: false);
    final menuCategories = _resolveMenuCategories(_vendorItems);
    final filteredMenuItems = _filterMenuItems(_vendorItems);
    final majorSectionSpacing = 24.h;
    final sectionInnerSpacing = 12.h;
    final sheetTopSpacing = (size.height * 0.026).clamp(20.0, 24.0);
    final overviewCardOverlap = (size.height * 0.055).clamp(44.0, 52.0);
    final overviewCardVisibleHeight = 112.h;
    final overviewCardBodySpacing =
        (overviewCardVisibleHeight - overviewCardOverlap - 28.h).clamp(
          28.h,
          44.h,
        );
    final popularCardWidth = (size.width * 0.78).clamp(230.0, 320.0);
    final popularCardImageHeight = (popularCardWidth * 0.45).clamp(90.0, 125.0);
    final popularSectionHeight = popularCardImageHeight + 106.h;
    final expandedHeight = size.height * 0.20;
    final overviewCardTop = expandedHeight - overviewCardOverlap + 40.h;
    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final showFloatingOverviewCard = scrollOffset < 60.0;
    final heroImageUrl = _isLoadingVendorDetails
        ? _heroImageUrlFor(widget.vendor, allowLogoFallback: false)
        : (_heroImageUrlFor(_vendor, allowLogoFallback: false) ??
              _heroImageUrlFor(_vendor));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        bottomNavigationBar: _buildCartBar(colors),
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (notification) {
                notification.disallowIndicator();
                return false;
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
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
                        final totalRange = (expandedHeight - collapsedHeight)
                            .clamp(1.0, double.infinity);
                        final collapseT =
                            (1 -
                                    ((constraints.maxHeight - collapsedHeight) /
                                        totalRange))
                                .clamp(0.0, 1.0);
                        final collapsingToolbarColor = Color.lerp(
                          Colors.transparent,
                          colors.backgroundPrimary.withValues(alpha: 0.6),
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
                            clipBehavior: Clip.none,
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
                                      _buildHeroPlaceholder(
                                        colors,
                                        accentColor,
                                      ),
                                  errorWidget: (context, url, error) =>
                                      _buildHeroPlaceholder(
                                        colors,
                                        accentColor,
                                      ),
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
                                          Colors.black.withValues(alpha: 0.56),
                                          Colors.black.withValues(alpha: 0.24),
                                          collapseT,
                                        )!,
                                        Color.lerp(
                                          Colors.black.withValues(alpha: 0.18),
                                          Colors.transparent,
                                          collapseT,
                                        )!,
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.35, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              if (!_isLoadingVendorDetails &&
                                  !_vendor.isAvailableForOrders)
                                Positioned.fill(
                                  child: Container(
                                    padding: EdgeInsets.only(top: 20.h),
                                    color: Colors.black.withValues(alpha: 0.55),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _buildHeroOverlayMessage(),
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
                                child: ColoredBox(
                                  color: collapsingToolbarColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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

                      _buildSliverActionButton(
                        onTap: _shareVendor,
                        child: SvgPicture.asset(
                          Assets.icons.shareAndroid,
                          package: 'grab_go_shared',
                          height: 20.h,
                          width: 20.w,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Consumer<FavoritesProvider>(
                        builder: (context, favoritesProvider, child) {
                          final isFavorite = favoritesProvider
                              .isVendorFavoriteById(
                                _vendor.id,
                                _favoriteVendorType,
                              );
                          return _buildSliverActionButton(
                            onTap: () async {
                              final isAuthenticated =
                                  await AuthGuard.ensureAuthenticated(context);
                              if (!isAuthenticated) return;

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
                      SizedBox(width: 10.w),
                      _buildSliverActionButton(
                        onTap: _toggleMenuSearch,
                        child: SvgPicture.asset(
                          Assets.icons.search,
                          package: 'grab_go_shared',
                          height: 20.h,
                          width: 20.w,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      _buildSliverActionButton(
                        onTap: _openVendorInfo,
                        child: SvgPicture.asset(
                          Assets.icons.infoCircle,
                          package: 'grab_go_shared',
                          height: 20.h,
                          width: 20.w,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: menuCategories.length > 1 ? 0 : 24.h,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(22.r),
                            topRight: Radius.circular(22.r),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: sheetTopSpacing),
                            SizedBox(height: overviewCardBodySpacing),
                            _buildQuickStatsCard(colors),
                            if ((_vendor.description?.trim().isNotEmpty ??
                                false)) ...[
                              SizedBox(height: 10.h),
                              _buildDescriptionSection(colors),
                            ],
                            if (popularItems.isNotEmpty || _isLoadingItems) ...[
                              SizedBox(height: majorSectionSpacing),
                              SectionHeader(
                                title: 'Popular at ${_vendor.displayName}',
                                sectionTotal: popularItems.length,
                                accentColor: accentColor,
                                onSeeAll: null,
                              ),
                              SizedBox(height: sectionInnerSpacing),
                              SizedBox(
                                height: popularSectionHeight,
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
                                            padding: EdgeInsets.only(
                                              right: 12.w,
                                            ),
                                            child: DealCard(
                                              item: item,
                                              discountPercent: item
                                                  .discountPercentage
                                                  .toInt(),
                                              deliveryTime:
                                                  item.estimatedDeliveryTime,
                                              cardWidth: popularCardWidth,
                                              onTap: () => _openItemDetails(
                                                popularItems[index],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                            SizedBox(height: 10.h),
                            SectionHeader(
                              title: 'Menu',
                              sectionTotal: filteredMenuItems.length,
                              accentColor: accentColor,
                              onSeeAll: null,
                            ),
                            if (_isMenuSearchVisible) ...[
                              SizedBox(height: sectionInnerSpacing),
                              _buildMenuSearchField(colors),
                            ],
                            if (menuCategories.length > 1) ...[
                              SizedBox(height: sectionInnerSpacing),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (menuCategories.length > 1)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PinnedHeaderDelegate(
                        minHeight: 44.h,
                        maxHeight: 44.h,
                        child: Container(
                          color: colors.backgroundPrimary,
                          child: _buildMenuCategoryTabs(colors, menuCategories),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: menuCategories.length > 1
                          ? sectionInnerSpacing
                          : 24.h,
                    ),
                  ),
                  if (_isLoadingItems)
                    SliverToBoxAdapter(child: _buildMenuLoadingList(colors))
                  else if (_itemsError != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: _buildInlineMessage(
                          colors: colors,
                          message: _itemsError!,
                          actionText: 'Retry',
                          onTap: _fetchVendorItems,
                        ),
                      ),
                    )
                  else if (_vendorItems.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: _buildInlineMessage(
                          colors: colors,
                          message:
                              'No items available from this vendor right now.',
                        ),
                      ),
                    )
                  else if (filteredMenuItems.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: _buildInlineMessage(
                          colors: colors,
                          message: _menuSearchQuery.isNotEmpty
                              ? 'No menu items match "$_menuSearchQuery".'
                              : 'No items found in this category right now.',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = filteredMenuItems[index];
                          return FoodItemCard(
                            item: item.displayItem,
                            margin: EdgeInsets.symmetric(
                              horizontal: 4.w,
                              vertical: 6.h,
                            ),
                            onTap: () => _openItemDetails(item),
                            trailing: _buildVendorMenuCardTrailing(
                              colors,
                              item.sourceItem is CartItem
                                  ? item.sourceItem as CartItem
                                  : item.displayItem,
                            ),
                          );
                        }, childCount: filteredMenuItems.length),
                      ),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                ],
              ),
            ),
            Positioned(
              left: 20.w,
              right: 20.w,
              top: overviewCardTop,
              child: IgnorePointer(
                ignoring: !showFloatingOverviewCard,
                child: AnimatedSlide(
                  offset: showFloatingOverviewCard
                      ? Offset.zero
                      : const Offset(0, -0.08),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: AnimatedOpacity(
                    opacity: showFloatingOverviewCard ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: _buildVendorOverviewCard(colors, accentColor),
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

  Widget _buildSliverActionButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
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

  Widget _buildCartBar(AppColorsExtension colors) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        if (cartProvider.cartItems.isEmpty) return const SizedBox.shrink();

        final itemCount = cartProvider.totalQuantity;
        final totalAmount = cartProvider.total;
        final isLocked = cartProvider.isCartInteractionLocked;
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: colors.backgroundPrimary,
              child: SizedBox(
                height: 64.h,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(18.r),
                  ),
                  child: IgnorePointer(
                    ignoring: isLocked,
                    child: GestureDetector(
                      onTap: () => context.push("/cart"),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isLocked ? 0.82 : 1,
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: colors.accentOrange,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(18.r),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: SvgPicture.asset(
                                  Assets.icons.cart,
                                  height: 18.h,
                                  width: 18.w,
                                  package: 'grab_go_shared',
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isLocked
                                          ? "Updating cart..."
                                          : "View cart",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(height: 2.h),
                                    Text(
                                      "$itemCount ${itemCount == 1 ? "item" : "items"} in cart",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isLocked)
                                Padding(
                                  padding: EdgeInsets.only(right: 12.w),
                                  child: SizedBox(
                                    width: 18.w,
                                    height: 18.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              Text(
                                "${AppStrings.currencySymbol} ${totalAmount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (bottomInset > 0)
              Container(height: bottomInset, color: colors.accentOrange),
          ],
        );
      },
    );
  }

  Widget _buildVendorMenuCardTrailing(
    AppColorsExtension colors,
    CartItem cartItem,
  ) {
    return Consumer<CartProvider>(
      builder: (context, provider, _) {
        final includeFoodCustomizations = cartItem is FoodItem;
        final isInCart = provider.hasItemInCart(
          cartItem,
          includeFoodCustomizations: includeFoodCustomizations,
        );
        final isItemPending = provider.isItemOperationPendingForDisplay(
          cartItem,
          includeFoodCustomizations: includeFoodCustomizations,
        );
        final itemForAction = provider.resolveItemForCartAction(
          cartItem,
          includeFoodCustomizations: includeFoodCustomizations,
        );

        return GestureDetector(
          onTap: () {
            if (isItemPending) return;
            if (isInCart && itemForAction != null) {
              provider.removeItemCompletely(itemForAction);
            } else {
              provider.addToCart(cartItem, context: context);
            }
          },
          child: Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isInCart
                  ? colors.accentOrange
                  : colors.backgroundSecondary,
            ),
            child: isItemPending
                ? SizedBox(
                    width: 16.w,
                    height: 16.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isInCart ? Colors.white : colors.accentOrange,
                      ),
                    ),
                  )
                : SvgPicture.asset(
                    isInCart ? Assets.icons.check : Assets.icons.cart,
                    package: 'grab_go_shared',
                    width: 16.w,
                    height: 16.h,
                    colorFilter: ColorFilter.mode(
                      isInCart ? Colors.white : colors.textSecondary,
                      BlendMode.srcIn,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildVendorOverviewCard(
    AppColorsExtension colors,
    Color accentColor,
  ) {
    final displayVendor = _vendor;
    final locationText = displayVendor.address.trim().isNotEmpty
        ? displayVendor.address.trim()
        : [
            displayVendor.area?.trim(),
            displayVendor.city.trim(),
          ].whereType<String>().where((entry) => entry.isNotEmpty).join(', ');

    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.backgroundTertiary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
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
                  child:
                      displayVendor.logo != null &&
                          displayVendor.logo!.trim().isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ImageOptimizer.getFullUrl(
                            displayVendor.logo!,
                            width: 240,
                          ),
                          fit: BoxFit.cover,
                          memCacheWidth: 240,
                          placeholder: (context, url) =>
                              _buildHeroPlaceholder(colors, accentColor),
                          errorWidget: (context, url, error) =>
                              _buildHeroPlaceholder(colors, accentColor),
                        )
                      : _buildHeroPlaceholder(colors, accentColor),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: displayVendor.displayName),
                          if (displayVendor.isExclusive)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(left: 6.w),
                                child: ExclusiveStampBadge.compact(
                                  width: 18.w,
                                  height: 18.w,
                                ),
                              ),
                            ),
                        ],
                      ),
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
                          colorFilter: ColorFilter.mode(
                            accentColor,
                            BlendMode.srcIn,
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          displayVendor.rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
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
                              colorFilter: ColorFilter.mode(
                                colors.textPrimary,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
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
                            colorFilter: ColorFilter.mode(
                              colors.textSecondary,
                              BlendMode.srcIn,
                            ),
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
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(AppColorsExtension colors) {
    final descriptionText = _vendor.description?.trim() ?? '';
    if (descriptionText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          ReadMoreText(
            descriptionText,
            trimMode: TrimMode.Line,
            trimLines: 3,
            colorClickableText: colors.accentOrange,
            trimCollapsedText: ' Show more',
            trimExpandedText: ' Show less',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w400,
              color: colors.textSecondary,
              height: 1.5,
            ),
            moreStyle: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: colors.accentOrange,
            ),
            lessStyle: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: colors.accentOrange,
            ),
          ),
        ],
      ),
    );
  }

  String _buildHeroOverlayMessage() {
    if (_vendor.isTemporarilyUnavailableButOpen) {
      return 'Not accepting\norders right now';
    }

    final nextOpening = _findNextOpeningDateTime(DateTime.now());
    if (nextOpening == null) {
      return 'Closed now';
    }

    return 'Closed now\n${_formatNextOpeningLabel(nextOpening, DateTime.now(), includePeriod: false)}';
  }

  DaySchedule? _scheduleForWeekday(int weekday) {
    final openingHours = _vendor.openingHours;
    if (openingHours == null) return null;
    switch (weekday) {
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
    }
    return null;
  }

  DateTime? _resolveScheduleDateTime({
    required DateTime baseDate,
    required String? timeValue,
  }) {
    if (timeValue == null || timeValue.trim().isEmpty) return null;
    final parts = timeValue.trim().split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
  }

  DateTime? _findNextOpeningDateTime(DateTime now) {
    for (var offset = 0; offset < 7; offset++) {
      final candidateDate = now.add(Duration(days: offset));
      final schedule = _scheduleForWeekday(candidateDate.weekday);
      if (schedule == null || schedule.isClosed) continue;

      final openingTime = _resolveScheduleDateTime(
        baseDate: candidateDate,
        timeValue: schedule.open,
      );
      if (openingTime == null) continue;

      if (offset > 0 || openingTime.isAfter(now)) {
        return openingTime;
      }
    }

    return null;
  }

  String _formatNextOpeningLabel(
    DateTime openingTime,
    DateTime now, {
    bool includePeriod = true,
  }) {
    final timeText = intl.DateFormat('h:mm a').format(openingTime);
    final today = DateTime(now.year, now.month, now.day);
    final openingDay = DateTime(
      openingTime.year,
      openingTime.month,
      openingTime.day,
    );
    final dayDifference = openingDay.difference(today).inDays;
    final suffix = includePeriod ? '.' : '';

    if (dayDifference <= 0) {
      return 'Opens at $timeText$suffix';
    }
    if (dayDifference == 1) {
      return 'Opens tomorrow at $timeText$suffix';
    }
    return 'Opens ${intl.DateFormat('EEE').format(openingTime)} at $timeText$suffix';
  }

  List<_VendorMenuCategory> _resolveMenuCategories(
    List<_VendorDisplayItem> items,
  ) {
    final categories = <_VendorMenuCategory>[];
    final seenIds = <String>{};

    if (items.any(_itemHasActiveDeal)) {
      categories.add(
        const _VendorMenuCategory(
          id: _dealsMenuCategoryId,
          label: 'Deals',
          showsTagIcon: true,
        ),
      );
      seenIds.add(_dealsMenuCategoryId);
    }

    categories.add(
      const _VendorMenuCategory(id: _allMenuCategoryId, label: 'All'),
    );
    seenIds.add(_allMenuCategoryId);

    for (final item in items) {
      final categoryId = item.displayItem.categoryId.trim();
      final categoryLabel = item.displayItem.categoryName?.trim() ?? '';
      if (categoryId.isEmpty ||
          categoryLabel.isEmpty ||
          seenIds.contains(categoryId)) {
        continue;
      }

      categories.add(_VendorMenuCategory(id: categoryId, label: categoryLabel));
      seenIds.add(categoryId);
    }

    return categories;
  }

  List<_VendorDisplayItem> _filterMenuItems(List<_VendorDisplayItem> items) {
    final itemsByCategory = _filterMenuItemsByCategory(items);
    final query = _menuSearchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return itemsByCategory;
    }

    return itemsByCategory
        .where((item) {
          final displayItem = item.displayItem;
          final searchable = [
            displayItem.name,
            displayItem.description,
            displayItem.sellerName,
            displayItem.categoryName,
          ].whereType<String>().join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  List<_VendorDisplayItem> _filterMenuItemsByCategory(
    List<_VendorDisplayItem> items,
  ) {
    if (_selectedMenuCategoryId == _dealsMenuCategoryId) {
      return items.where(_itemHasActiveDeal).toList(growable: false);
    }
    if (_selectedMenuCategoryId == _allMenuCategoryId) {
      return items;
    }

    return items
        .where(
          (item) =>
              item.displayItem.categoryId.trim() == _selectedMenuCategoryId,
        )
        .toList(growable: false);
  }

  Widget _buildMenuSearchField(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        height: 44.h,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.border),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              Assets.icons.search,
              package: 'grab_go_shared',
              width: 18.w,
              height: 18.h,
              colorFilter: ColorFilter.mode(
                colors.textTertiary,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: TextField(
                controller: _menuSearchController,
                focusNode: _menuSearchFocusNode,
                onChanged: (value) {
                  setState(() {
                    _menuSearchQuery = value.trim();
                  });
                },
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search this menu',
                  hintStyle: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ),
            if (_menuSearchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _menuSearchController.clear();
                    _menuSearchQuery = '';
                  });
                  _menuSearchFocusNode.requestFocus();
                },
                child: Icon(
                  Icons.close,
                  color: colors.textTertiary,
                  size: 18.sp,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCategoryTabs(
    AppColorsExtension colors,
    List<_VendorMenuCategory> categories,
  ) {
    return Container(
      height: 44.h,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.inputBorder.withValues(alpha: 0.75),
            width: 1,
          ),
        ),
      ),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, separatorIndex) => SizedBox(width: 18.w),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.id == _selectedMenuCategoryId;
          final labelStyle = TextStyle(
            color: isSelected ? colors.accentOrange : colors.textSecondary,
            fontSize: 14.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          );
          final underlineWidth = _measureTabLabelWidth(
            context,
            category.label,
            labelStyle,
            includeTagIcon: category.showsTagIcon,
          );
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (_selectedMenuCategoryId == category.id) return;
                setState(() {
                  _selectedMenuCategoryId = category.id;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(horizontal: 2.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (category.showsTagIcon) ...[
                              SvgPicture.asset(
                                Assets.icons.tag,
                                package: 'grab_go_shared',
                                width: 13.w,
                                height: 13.w,
                                colorFilter: ColorFilter.mode(
                                  isSelected
                                      ? colors.accentOrange
                                      : colors.textSecondary,
                                  BlendMode.srcIn,
                                ),
                              ),
                              SizedBox(width: 5.w),
                            ],
                            Text(
                              category.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: labelStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: underlineWidth,
                      height: 2.5.h,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.accentOrange
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _itemHasActiveDeal(_VendorDisplayItem item) {
    final foodItem = item.displayItem;
    return foodItem.discountPercentage > 0;
  }

  double _measureTabLabelWidth(
    BuildContext context,
    String label,
    TextStyle style, {
    bool includeTagIcon = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final extraWidth = includeTagIcon ? (13.w + 5.w) : 0.0;
    return (painter.width + extraWidth).clamp(16.w, 140.w).toDouble();
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

class _VendorMenuCategory {
  final String id;
  final String label;
  final bool showsTagIcon;

  const _VendorMenuCategory({
    required this.id,
    required this.label,
    this.showsTagIcon = false,
  });
}

class _PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _PinnedHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedHeaderDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}
