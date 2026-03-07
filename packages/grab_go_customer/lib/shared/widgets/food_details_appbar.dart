import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/home/view/item_reviews_page.dart';
import 'package:grab_go_customer/shared/services/auth_guard.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/shared/services/food_share_link.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';

class FoodDetailsAppBar extends StatelessWidget {
  const FoodDetailsAppBar({super.key, required this.foodItem});
  final CartItem foodItem;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.sizeOf(context);
    final double topPadding = MediaQuery.paddingOf(context).top;
    final double expandedHeight = size.height * 0.20;
    final bool isRestaurantClosed = foodItem is FoodItem
        ? !(foodItem as FoodItem).isRestaurantOpen
        : false;

    return SliverAppBar(
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
          final double collapsedHeight = kToolbarHeight + topPadding;
          final double totalRange = (expandedHeight - collapsedHeight).clamp(
            1.0,
            double.infinity,
          );
          final double collapseT =
              (1 - ((constraints.maxHeight - collapsedHeight) / totalRange))
                  .clamp(0.0, 1.0);

          final Color collapsingToolbarColor = Color.lerp(
            Colors.transparent,
            colors.backgroundPrimary.withValues(alpha: 0.96),
            collapseT,
          )!;
          final bool useDarkStatusIcons = !isDarkMode && collapseT > 0.72;

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
                CachedNetworkImage(
                  imageUrl: ImageOptimizer.getFullUrl(
                    foodItem.image,
                    width: 1200,
                  ),
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  maxHeightDiskCache: 600,
                  placeholder: (context, url) => Container(
                    height: size.height * 0.30,
                    width: double.infinity,
                    color: colors.inputBorder,
                    padding: EdgeInsets.all(80.r),
                    child: SvgPicture.asset(
                      foodItem is FoodItem
                          ? Assets.icons.utensilsCrossed
                          : Assets.icons.package,
                      package: 'grab_go_shared',
                      colorFilter: ColorFilter.mode(
                        colors.textSecondary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: size.height * 0.30,
                    width: double.infinity,
                    color: colors.inputBorder,
                    padding: EdgeInsets.all(80.r),
                    child: SvgPicture.asset(
                      foodItem is FoodItem
                          ? Assets.icons.utensilsCrossed
                          : Assets.icons.package,
                      package: 'grab_go_shared',
                      colorFilter: ColorFilter.mode(
                        colors.textSecondary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
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
                if (isRestaurantClosed)
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
            color: colors.backgroundPrimary,
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
      actionsPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
      actions: [
        _buildActionButton(
          context: context,
          onTap: () {
            final router = GoRouter.of(context);
            if (router.canPop()) {
              router.pop();
            } else {
              context.go("/homepage");
            }
          },
          icon: SvgPicture.asset(
            Assets.icons.navArrowLeft,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        const Spacer(),

        _buildActionButton(
          context: context,
          onTap: () async {
            try {
              await FoodShareLinkService.shareFoodItem(
                sellerId: foodItem.providerId,
                foodName: foodItem.name,
                sellerName: foodItem.providerName,
                imageUrl: foodItem.image,
                description: foodItem.description,
              );
            } catch (e) {
              if (context.mounted) {
                AppToastMessage.show(
                  context: context,
                  message: 'Failed to share ${e.toString()}',
                  backgroundColor: colors.error,
                  maxLines: 2,
                );
              }
            }
          },
          icon: SvgPicture.asset(
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
            final isFavorite = favoritesProvider.isFavorite(
              foodItem as dynamic,
            );
            return _buildActionButton(
              context: context,
              onTap: () async {
                final isAuthenticated = await AuthGuard.ensureAuthenticated(
                  context,
                );
                if (!isAuthenticated) return;

                favoritesProvider.toggleFavorite(foodItem as dynamic);
              },
              icon: SvgPicture.asset(
                isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                package: 'grab_go_shared',
                height: 20.h,
                width: 20.w,
                colorFilter: ColorFilter.mode(
                  isFavorite ? Colors.red : Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              isFavorite: isFavorite,
            );
          },
        ),
        SizedBox(width: 10.w),
        _buildActionButton(
          context: context,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ItemReviewsPage()),
          ),
          icon: SvgPicture.asset(
            Assets.icons.moreVertical,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required VoidCallback onTap,
    required Widget icon,
    bool isFavorite = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}
