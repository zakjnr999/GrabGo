import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/food_item_card.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  late AnimationController _searchAnimationController;
  final FocusNode _searchFocus = FocusNode();
  int selectedTabIndex = 0;
  String _searchQuery = '';
  bool _isSearchActive = false;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  static const double _collapsedHeight = 140.0; // Increased to show tabs when collapsed
  static const double _scrollThreshold = 100.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          selectedTabIndex = _tabController.index;
        });
      }
    });
    _searchAnimationController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _searchController.dispose();
    _tabController.dispose();
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
      debugPrint("clear favorites");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.paddingOf(context);
    Size size = MediaQuery.sizeOf(context);

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.accentOrange,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: colors.backgroundSecondary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        body: SafeArea(
          top: false,
          child: ClipRect(
            child: Stack(
              children: [
                // Main Content
                Column(
                  children: [
                    Expanded(
                      child: Consumer<FavoritesProvider>(
                        builder: (context, favoritesProvider, child) {
                          if (favoritesProvider.favoriteItems.isEmpty) {
                            return _buildEmptyState(colors, size);
                          }

                          final filteredItems = _searchQuery.isEmpty
                              ? favoritesProvider.favoriteItems.toList()
                              : favoritesProvider.searchFavorites(_searchQuery);

                          if (filteredItems.isEmpty) {
                            return _buildNoResultsState(colors, size);
                          }

                          return _buildFavoritesList(colors, filteredItems, size);
                        },
                      ),
                    ),
                  ],
                ),

                // Collapsible Header
                Positioned(top: 0, left: 0, right: 0, child: _buildCollapsibleFavoritesHeader(colors, size)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleFavoritesHeader(AppColorsExtension colors, Size size) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final dynamicCollapsedHeight = _collapsedHeight + statusBarHeight; // Add status bar height

    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);
        final expandedHeight = size.height * 0.26;
        final currentHeight = expandedHeight - ((expandedHeight - dynamicCollapsedHeight) * collapseProgress);
        final contentOpacity = (1.0 - collapseProgress).clamp(0.0, 1.0);

        return SizedBox(
          height: currentHeight,
          child: UmbrellaHeaderWithShadow(
            curveDepth: 25.h,
            numberOfCurves: 10,
            height: currentHeight,
            child: Padding(
              padding: EdgeInsets.only(bottom: 50.h), // Add padding to keep tabs above curves
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
                    child: _isSearchActive ? _buildSearchBar(colors) : _buildStickyTabs(colors, contentOpacity),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStickyTabs(AppColorsExtension colors, double opacity) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10.r)),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: colors.accentOrange,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.8),
        labelStyle: TextStyle(
          fontFamily: "Lato",
          package: "grab_go_shared",
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: "Lato",
          package: 'grab_go_shared',
          fontSize: 13.sp,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: "My Items"),
          Tab(text: "Vendors"),
        ],
      ),
    );
  }

  Widget _buildFavoritesHeader(AppColorsExtension colors) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, statusBarHeight.h, 20.w, 10.h),
        child: Row(
          children: [
            _buildHeaderButton(icon: Assets.icons.navArrowLeft, onTap: () => context.pop(), colors: colors),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                "Favorites",
                style: TextStyle(
                  fontFamily: "Lato",
                  package: 'grab_go_shared',
                  color: Colors.white,
                  fontSize: 24.sp,
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
              child: _buildHeaderButton(icon: Assets.icons.moreVertical, colors: colors),
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
      height: 44.h,
      width: 44.w,
      decoration: BoxDecoration(
        color: colors.backgroundPrimary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: isActive ? 1.5 : 0.0),
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
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
        color: colors.backgroundPrimary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w500),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: "Search your favorites...",
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.all(12.r),
            child: SvgPicture.asset(
              Assets.icons.search,
              package: 'grab_go_shared',
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors, Size size) {
    return Padding(
      padding: EdgeInsets.only(top: size.height * 0.20 + 40.h, left: 40.w, right: 40.w),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "No Favorites Yet",
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w800),
            ),

            SizedBox(height: 12.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                "Start adding your favorite items by tapping the heart icon on any item",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),

            // SizedBox(height: 40.h),

            // GestureDetector(
            //   onTap: () {
            //     context.pop();
            //     context.go('/homepage');
            //     Provider.of<NavigationProvider>(context, listen: false).navigateToMenu();
            //   },
            //   child: Container(
            //     padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
            //     decoration: BoxDecoration(
            //       gradient: LinearGradient(
            //         colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
            //         begin: Alignment.centerLeft,
            //         end: Alignment.centerRight,
            //       ),
            //       borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
            //       boxShadow: [
            //         BoxShadow(
            //           color: colors.accentOrange.withValues(alpha: 0.3),
            //           spreadRadius: 0,
            //           blurRadius: 12,
            //           offset: const Offset(0, 4),
            //         ),
            //       ],
            //     ),
            //     child: Row(
            //       mainAxisSize: MainAxisSize.min,
            //       children: [
            //         SvgPicture.asset(
            //           Assets.icons.utensilsCrossed,
            //           package: 'grab_go_shared',
            //           height: 20.h,
            //           width: 20.w,
            //           colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            //         ),
            //         SizedBox(width: 10.w),
            //         Text(
            //           "Browse Foods",
            //           style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(AppColorsExtension colors, Size size) {
    return SingleChildScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.only(top: size.height * 0.26 + 40.h, left: 40.w, right: 40.w, bottom: 40.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "No Results Found",
              style: TextStyle(color: colors.textPrimary, fontSize: 22.sp, fontWeight: FontWeight.w800),
            ),

            SizedBox(height: 10.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                "Try searching with different keywords",
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesList(AppColorsExtension colors, List<FoodItem> items, Size size) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: size.height * 0.26 + 10.h, // Space for expanded header
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

  Widget _buildFavoriteItem(AppColorsExtension colors, FoodItem item) {
    return FoodItemCard(
      item: item,
      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
      onTap: () {
        context.push('/foodDetails', extra: item);
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<FavoritesProvider>(
            builder: (context, favoritesProvider, child) {
              return GestureDetector(
                onTap: () {
                  favoritesProvider.removeFromFavorites(item);
                },
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.error.withValues(alpha: 0.1),
                    border: Border.all(color: colors.error, width: 1),
                  ),
                  child: SvgPicture.asset(
                    Assets.icons.heartSolid,
                    package: 'grab_go_shared',
                    height: 16.h,
                    width: 16.w,
                    colorFilter: ColorFilter.mode(colors.error, BlendMode.srcIn),
                  ),
                ),
              );
            },
          ),
          SizedBox(width: 8.w),
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              final bool isInCart = cartProvider.cartItems.containsKey(item);

              return GestureDetector(
                onTap: () {
                  if (isInCart) {
                    cartProvider.removeItemCompletely(item);
                  } else {
                    cartProvider.addToCart(item, context: context);
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
              );
            },
          ),
        ],
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
                decoration: BoxDecoration(color: colors.inputBorder, borderRadius: BorderRadius.circular(2.r)),
              ),
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.md.h),
              child: Text(
                'Sort Favorites',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
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
                        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                      )
                    : Icon(icon ?? Icons.settings, size: 24.h, color: iconColor),
              ),
            ),
            SizedBox(width: 12.w),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w400, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: "grab_go_shared",
              height: 18.h,
              width: 18.w,
              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}
