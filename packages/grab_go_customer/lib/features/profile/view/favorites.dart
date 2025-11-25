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

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: colors.backgroundSecondary,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          backgroundColor: colors.backgroundSecondary,
          title: Row(
            children: [
              Container(
                height: 44.h,
                width: 44.w,
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
                        colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                      child: SvgPicture.asset(
                        Assets.icons.heart,
                        package: 'grab_go_shared',
                        height: 16.h,
                        width: 16.w,
                        colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "My Favorites",
                      style: TextStyle(
                        fontFamily: "Lato",
                        package: 'grab_go_shared',
                        color: colors.textPrimary,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Consumer<FavoritesProvider>(
                builder: (context, favoritesProvider, child) {
                  if (favoritesProvider.favoriteItems.isEmpty) {
                    return SizedBox(width: 44.w);
                  }

                  return AppPopupMenu(
                    items: [
                      AppPopupMenuItem(
                        value: 'sort',
                        label: 'Sort Favorites',
                        icon: Assets.icons.slidersHorizontal,
                        iconColor: colors.accentOrange,
                        backgroundColor: colors.accentOrange.withValues(alpha: 0.1),
                      ),
                      AppPopupMenuItem(
                        value: 'clear_all',
                        label: 'Clear All Favorites',
                        icon: Assets.icons.binMinusIn,
                        isDanger: true,
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'sort':
                          _showSortOptions(colors);
                          break;
                        case 'clear_all':
                          _showClearAllDialog(colors);
                          break;
                      }
                    },
                    child: Container(
                      height: 44.h,
                      width: 44.w,
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                            spreadRadius: 0,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(10.r),
                        child: Icon(Icons.more_vert, size: 20.sp, color: colors.textPrimary),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Consumer<FavoritesProvider>(
            builder: (context, favoritesProvider, child) {
              if (favoritesProvider.favoriteItems.isEmpty) {
                return _buildEmptyState(colors, size);
              }

              final filteredItems = _searchQuery.isEmpty
                  ? favoritesProvider.favoriteItems.toList()
                  : favoritesProvider.searchFavorites(_searchQuery);

              if (filteredItems.isEmpty) {
                return Column(
                  children: [
                    _buildSearchBar(colors),
                    Expanded(child: _buildNoResultsState(colors, size)),
                  ],
                );
              }

              return Column(
                children: [
                  SizedBox(height: 12.h),
                  _buildSearchBar(colors),
                  Expanded(child: _buildFavoritesList(colors, filteredItems)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(colors) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), spreadRadius: 0, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: "Search your favorites...",
          hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
          prefixIcon: Padding(
            padding: EdgeInsets.all(14.r),
            child: SvgPicture.asset(
              Assets.icons.search,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
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
                  icon: Icon(Icons.close, color: colors.textSecondary, size: 20.sp),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        ),
      ),
    );
  }

  Widget _buildEmptyState(colors, size) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(30.r),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: SvgPicture.asset(
                Assets.icons.heart,
                package: 'grab_go_shared',
                width: 40.w,
                height: 40.w,
                colorFilter: ColorFilter.mode(Colors.red.withValues(alpha: 0.5), BlendMode.srcIn),
              ),
            ),

            SizedBox(height: 32.h),

            Text(
              "No Favorites Yet",
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w800),
            ),

            SizedBox(height: 12.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Text(
                "Start adding your favorite foods by tapping the heart icon on any food item",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),

            SizedBox(height: 40.h),

            GestureDetector(
              onTap: () {
                context.pop();
                context.go('/homepage');
                Provider.of<NavigationProvider>(context, listen: false).navigateToMenu();
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentOrange.withValues(alpha: 0.3),
                      spreadRadius: 0,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      Assets.icons.utensilsCrossed,
                      package: 'grab_go_shared',
                      height: 20.h,
                      width: 20.w,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      "Browse Foods",
                      style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState(colors, size) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: SvgPicture.asset(
                Assets.icons.search,
                package: 'grab_go_shared',
                width: 60.w,
                height: 60.w,
                colorFilter: ColorFilter.mode(colors.accentOrange.withOpacity(0.5), BlendMode.srcIn),
              ),
            ),

            SizedBox(height: 28.h),

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

  Widget _buildFavoritesList(colors, List<FoodItem> items) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildFavoriteItem(colors, item);
      },
    );
  }

  Widget _buildFavoriteItem(colors, FoodItem item) {
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
                    color: colors.error.withOpacity(0.1),
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
                    cartProvider.addToCart(item);
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

  void _showSortOptions(colors) {
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(color: colors.inputBorder, borderRadius: BorderRadius.circular(2.r)),
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
                    iconColor: colors.accentViolet,
                    title: 'Name (A-Z)',
                    subtitle: 'Sort alphabetically',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 12.h),

                  _buildSortOption(
                    colors: colors,
                    svgIcon: Assets.icons.dollar,
                    iconColor: colors.accentGreen,
                    title: 'Price (Low to High)',
                    subtitle: 'Cheapest first',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  SizedBox(height: 12.h),

                  _buildSortOption(
                    colors: colors,
                    svgIcon: Assets.icons.starSolid,
                    iconColor: colors.accentOrange,
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
    required colors,
    IconData? icon,
    String? svgIcon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          border: Border.all(color: colors.inputBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              height: 48.h,
              width: 48.h,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
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

            Icon(Icons.arrow_forward_ios, size: 16.h, color: colors.textSecondary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  void _showClearAllDialog(colors) async {
    final shouldClear = await AppDialog.show(
      context: context,
      title: 'Clear All Favorites',
      message: 'Are you sure you want to remove all items from your favorites? This action cannot be undone.',
      type: AppDialogType.warning,
      icon: Assets.icons.heart,
      primaryButtonText: 'Clear All',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (shouldClear == true) {
      context.read<FavoritesProvider>().clearFavorites();
      AppToastMessage.show(
        context: context,
        icon: Icons.delete_sweep,
        message: 'All favorites cleared',
        backgroundColor: colors.accentGreen,
      );
    }
  }
}
