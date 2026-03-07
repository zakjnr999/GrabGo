import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/features/vendors/widgets/vendor_card.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _searchAnimationController;
  final FocusNode _searchFocus = FocusNode();
  int selectedTabIndex = 0;
  final List<String> _favoriteTabs = ['My Items', 'Vendors'];
  String _searchQuery = '';
  bool _isSearchActive = false;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(
    0.0,
  );
  static const double _collapsedHeight =
      140.0; // Increased to show tabs when collapsed
  static const double _scrollThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _searchController.dispose();
    _searchAnimationController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollOffsetNotifier.value = _scrollController.offset;
  }

  Future<void> _handleClearAllFavorites() async {
    final shouldClearAll = await AppDialog.show(
      context: context,
      title: 'Clear Favorites',
      message: 'Are you sure you want to clear all favorites?',
      type: AppDialogType.warning,
      primaryButtonText: 'Clear All',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (shouldClearAll == true) {
      try {
        await context.read<FavoritesProvider>().clearFavorites();
      } catch (_) {
        if (context.mounted) {
          AppToastMessage.show(
            context: context,
            backgroundColor: context.appColors.error,
            message: 'Could not clear favorites right now. Please try again.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.backgroundPrimary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          top: false,
          child: ClipRect(
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: AppRefreshIndicator(
                        bgColor: colors.accentOrange,
                        iconPath: Assets.icons.heart,
                        onRefresh: () =>
                            context.read<FavoritesProvider>().syncFromBackend(),
                        child: Consumer<FavoritesProvider>(
                          builder: (context, favoritesProvider, child) {
                            if (!favoritesProvider.hasAnyFavorites) {
                              return _buildEmptyState(colors, size);
                            }

                            final isItemsTab = selectedTabIndex == 0;
                            final filteredItems = isItemsTab
                                ? (_searchQuery.isEmpty
                                      ? favoritesProvider.favoriteItems.toList()
                                      : favoritesProvider.searchFavorites(
                                          _searchQuery,
                                        ))
                                : <FoodItem>[];
                            final filteredVendors = isItemsTab
                                ? <FavoriteVendor>[]
                                : (_searchQuery.isEmpty
                                      ? favoritesProvider.favoriteVendors
                                      : favoritesProvider.searchFavoriteVendors(
                                          _searchQuery,
                                        ));

                            final activeListIsEmpty = isItemsTab
                                ? filteredItems.isEmpty
                                : filteredVendors.isEmpty;
                            if (activeListIsEmpty) {
                              if (_searchQuery.isNotEmpty) {
                                return _buildNoResultsState(colors, size);
                              }
                              return _buildTabEmptyState(
                                colors,
                                size,
                                isItemsTab: isItemsTab,
                              );
                            }

                            if (isItemsTab) {
                              return _buildFavoritesList(
                                colors,
                                filteredItems,
                                size,
                              );
                            }

                            return _buildFavoriteVendorsList(
                              colors,
                              filteredVendors,
                              size,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Collapsible Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildCollapsibleFavoritesHeader(colors, size),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleFavoritesHeader(
    AppColorsExtension colors,
    Size size,
  ) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final dynamicCollapsedHeight = _collapsedHeight + statusBarHeight;

    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(
          0.0,
          1.0,
        );
        final expandedHeight = UmbrellaHeaderMetrics.expandedHeightFor(size);
        final currentHeight =
            expandedHeight -
            ((expandedHeight - dynamicCollapsedHeight) * collapseProgress);
        final contentOpacity = (1.0 - collapseProgress).clamp(0.0, 1.0);

        return SizedBox(
          height: currentHeight,
          child: Column(
            children: [
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 100),
                  opacity: contentOpacity,
                  child: _buildFavoritesHeader(colors),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isSearchActive
                    ? _buildSearchBar(colors)
                    : _buildStickyTabs(colors),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStickyTabs(AppColorsExtension colors) {
    final selectedIndex = selectedTabIndex.clamp(0, _favoriteTabs.length - 1);

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 10.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        border: Border(
          bottom: BorderSide(
            color: colors.inputBorder.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(3.r),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(999.r),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = constraints.maxWidth / _favoriteTabs.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: tabWidth * selectedIndex,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.accentOrange,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                  ),
                ),
                Row(
                  children: List.generate(_favoriteTabs.length, (index) {
                    final selected = index == selectedIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (selectedTabIndex == index) return;
                          setState(() {
                            selectedTabIndex = index;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 12.h,
                            horizontal: 6.w,
                          ),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : colors.textSecondary,
                              fontSize: 11.sp,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontFamily: 'Lato',
                              package: 'grab_go_shared',
                            ),
                            child: Text(
                              _favoriteTabs[index],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFavoritesHeader(AppColorsExtension colors) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, statusBarHeight, 20.w, 10.h),
        child: Row(
          children: [
            _buildHeaderButton(
              icon: Assets.icons.navArrowLeft,
              onTap: () => context.pop(),
              colors: colors,
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                "Favorites",
                style: TextStyle(
                  fontFamily: "Lato",
                  package: 'grab_go_shared',
                  color: colors.textPrimary,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildHeaderButton(
              icon: _isSearchActive ? Assets.icons.xmark : Assets.icons.search,
              onTap: () {
                setState(() {
                  _isSearchActive = !_isSearchActive;
                  if (_isSearchActive) {
                    _searchAnimationController.forward();
                    _searchFocus.requestFocus();
                  } else {
                    _searchAnimationController.reverse();
                    _searchController.clear();
                    _searchQuery = '';
                  }
                });
              },
              colors: colors,
              isActive: _isSearchActive,
            ),
            SizedBox(width: 8.w),
            CustomPopupMenu(
              menuWidth: 280.w,
              showArrow: false,
              items: [
                CustomPopupMenuItem(
                  value: 'sort',
                  label: 'Sort Favorites',
                  icon: Assets.icons.sort,
                  iconColor: colors.textSecondary,
                ),
                CustomPopupMenuItem(
                  value: 'clear',
                  label: 'Clear All Favorites',
                  icon: Assets.icons.brushCleaning,
                  iconColor: colors.textSecondary,
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case "sort":
                    _showSortOptions(colors);
                  case "clear":
                    _handleClearAllFavorites();
                }
              },
              child: _buildHeaderButton(
                icon: Assets.icons.moreVertical,
                colors: colors,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton({
    required String icon,
    VoidCallback? onTap,
    required AppColorsExtension colors,
    bool isActive = false,
  }) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(
                colors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(AppColorsExtension colors) {
    return Container(
      key: const ValueKey('search'),
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: "Search your favorites...",
          hintStyle: TextStyle(
            color: colors.textPrimary.withValues(alpha: 0.6),
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.all(12.r),
            child: SvgPicture.asset(
              Assets.icons.search,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(
                colors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: SvgPicture.asset(
                    Assets.icons.xmark,
                    height: 18.h,
                    width: 18.w,
                    package: "grab_go_shared",
                    colorFilter: ColorFilter.mode(
                      colors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 12.h,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors, Size size) {
    return _buildCenteredFavoriteEmptyState(
      colors,
      size,
      title: "No Favorites Yet",
      description:
          "Start adding your favorite items by tapping the heart icon on any item",
    );
  }

  Widget _buildNoResultsState(AppColorsExtension colors, Size size) {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(
          top: UmbrellaHeaderMetrics.contentPaddingFor(size) + 24.h,
          left: 40.w,
          right: 40.w,
          bottom: 40.h,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "No Results Found",
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
              ),
            ),

            SizedBox(height: 10.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                "Try searching with different keywords",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabEmptyState(
    AppColorsExtension colors,
    Size size, {
    required bool isItemsTab,
  }) {
    return _buildCenteredFavoriteEmptyState(
      colors,
      size,
      title: isItemsTab ? "No Favorite Items" : "No Favorite Vendors",
      description: isItemsTab
          ? "Save items you love and they will appear here."
          : "Save vendors you order from most and they will appear here.",
    );
  }

  Widget _buildCenteredFavoriteEmptyState(
    AppColorsExtension colors,
    Size size, {
    required String title,
    required String description,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.only(
                top: UmbrellaHeaderMetrics.contentPaddingFor(size),
                left: 40.w,
                right: 40.w,
                bottom: 40.h,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      Assets.icons.emptyFavorites,
                      package: 'grab_go_shared',
                      width: 160.w,
                      height: 160.h,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
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

  Widget _buildFavoritesList(
    AppColorsExtension colors,
    List<FoodItem> items,
    Size size,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: UmbrellaHeaderMetrics.contentPaddingFor(size),
        bottom: 8.h,
      ),
      itemCount: items.length,
      physics: const AlwaysScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildFavoriteItem(colors, item);
      },
    );
  }

  Widget _buildFavoriteVendorsList(
    AppColorsExtension colors,
    List<FavoriteVendor> vendors,
    Size size,
  ) {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: UmbrellaHeaderMetrics.contentPaddingFor(size),
        bottom: 8.h,
      ),
      itemBuilder: (context, index) {
        final vendor = vendors[index];
        final vendorModel = _favoriteVendorToVendorModel(vendor);
        return VendorCard(
          vendor: vendorModel,
          onTap: () => context.push('/vendorDetails', extra: vendorModel),
          showDistance: false,
          showClosedOnImage: true,
          margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        );
      },
      itemCount: vendors.length,
    );
  }

  VendorModel _favoriteVendorToVendorModel(FavoriteVendor favorite) {
    final vendorTypeEnum = switch (favorite.type) {
      FavoriteVendorType.restaurant => VendorType.food,
      FavoriteVendorType.groceryStore => VendorType.grocery,
      FavoriteVendorType.pharmacyStore => VendorType.pharmacy,
      FavoriteVendorType.grabMartStore => VendorType.grabmart,
    };

    return VendorModel(
      id: favorite.id,
      storeName: vendorTypeEnum == VendorType.food ? null : favorite.name,
      restaurantName: vendorTypeEnum == VendorType.food ? favorite.name : null,
      name: favorite.name,
      logo: favorite.image.isNotEmpty ? favorite.image : null,
      description: favorite.address,
      phone: '',
      email: '',
      isOpen: favorite.isOpen,
      isAcceptingOrders: favorite.isAcceptingOrders,
      isVerified: favorite.isVerified,
      featured: favorite.featured,
      bannerImages: favorite.bannerImages,
      openingHours: favorite.openingHours != null
          ? OpeningHours.fromJson(favorite.openingHours!)
          : null,
      isGrabGoExclusiveActive: favorite.isGrabGoExclusiveActive,
      lastOnlineAt: favorite.lastOnlineAt,
      deliveryFee: favorite.deliveryFee,
      minOrder: favorite.minOrder,
      rating: favorite.rating,
      totalReviews: favorite.totalReviews,
      categories: favorite.categories.isNotEmpty
          ? favorite.categories
          : [favorite.typeLabel],
      location: VendorLocation(
        lat: 0,
        lng: 0,
        address: favorite.address ?? '',
        city: favorite.city ?? '',
        area: favorite.area,
      ),
      averageDeliveryTime: favorite.averageDeliveryTime,
      vendorType: vendorTypeEnum.id,
      vendorTypeEnum: vendorTypeEnum,
    );
  }

  Widget _buildFavoriteItem(AppColorsExtension colors, FoodItem item) {
    return FoodItemCard(
      item: item,
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
      onTap: () {
        context.push('/foodDetails', extra: item);
      },
      trailing: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          final bool isInCart = cartProvider.hasItemInCart(
            item,
            includeFoodCustomizations: true,
          );
          final bool isItemPending = cartProvider
              .isItemOperationPendingForDisplay(
                item,
                includeFoodCustomizations: true,
              );
          final itemForAction = cartProvider.resolveItemForCartAction(
            item,
            includeFoodCustomizations: true,
          );

          return GestureDetector(
            onTap: () {
              if (isItemPending) return;
              if (isInCart && itemForAction != null) {
                cartProvider.removeItemCompletely(itemForAction);
              } else {
                cartProvider.addToCart(item, context: context);
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
          );
        },
      ),
    );
  }

  void _showSortOptions(AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      elevation: 0,
      enableDrag: true,
      isScrollControlled: true,
      isDismissible: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderRadius20),
            topRight: Radius.circular(KBorderSize.borderRadius20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.inputBorder,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: KSpacing.lg.w,
                vertical: KSpacing.md.h,
              ),
              child: Text(
                'Sort Favorites',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ),

            SizedBox(height: KSpacing.sm.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
              child: Column(
                children: [
                  _buildSortOption(
                    colors: colors,
                    svgIcon: Assets.icons.arrowUpAZ,
                    iconColor: colors.textSecondary,
                    title: 'Name (A-Z)',
                    subtitle: 'Sort alphabetically',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 12.h),

                  _buildSortOption(
                    colors: colors,
                    svgIcon: Assets.icons.cash,
                    iconColor: colors.textSecondary,
                    title: 'Price (Low to High)',
                    subtitle: 'Cheapest first',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 12.h),

                  _buildSortOption(
                    colors: colors,
                    svgIcon: Assets.icons.star,
                    iconColor: colors.textSecondary,
                    title: 'Rating (High to Low)',
                    subtitle: 'Best rated first',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: KSpacing.lg25.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption({
    required AppColorsExtension colors,
    IconData? icon,
    String? svgIcon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius12),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              height: 48.h,
              width: 48.h,
              decoration: BoxDecoration(
                color: colors.backgroundSecondary,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius12),
              ),
              child: Center(
                child: svgIcon != null
                    ? SvgPicture.asset(
                        svgIcon,
                        height: 24.h,
                        width: 24.w,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        icon ?? Icons.settings,
                        size: 24.h,
                        color: iconColor,
                      ),
              ),
            ),
            SizedBox(width: 12.w),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: "grab_go_shared",
              height: 18.h,
              width: 18.w,
              colorFilter: ColorFilter.mode(
                colors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
