import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/services/auth_guard.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class QuickReorderCard extends StatelessWidget {
  final FoodItem item;
  final int daysAgo;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final bool isInCart;
  final bool isLoading;

  const QuickReorderCard({
    super.key,
    required this.item,
    required this.daysAgo,
    required this.onTap,
    required this.onAddToCart,
    required this.isInCart,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size.width * 0.5,
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(KBorderSize.borderMedium),
                    topRight: Radius.circular(KBorderSize.borderMedium),
                    bottomLeft: Radius.circular(KBorderSize.borderRadius4),
                    bottomRight: Radius.circular(KBorderSize.borderRadius4),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: ImageOptimizer.getPreviewUrl(
                      item.image,
                      width: 400,
                    ),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    maxHeightDiskCache: 800,
                    placeholder: (context, url) => Container(
                      height: 120,
                      color: colors.inputBorder,
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.utensilsCrossed,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(
                            colors.textSecondary,
                            BlendMode.srcIn,
                          ),
                          width: 30.w,
                          height: 30,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      color: colors.inputBorder,
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.utensilsCrossed,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(
                            colors.textSecondary,
                            BlendMode.srcIn,
                          ),
                          width: 30.w,
                          height: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 2.h,
                  right: 2.w,
                  child: IgnorePointer(
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(KBorderSize.borderMedium),
                        ),
                        gradient: RadialGradient(
                          center: const Alignment(1.0, -1.0),
                          radius: 1.15,
                          colors: [
                            Colors.black.withValues(alpha: 0.28),
                            Colors.black.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                Consumer<FavoritesProvider>(
                  builder: (context, favoriteProvider, child) {
                    final bool isFavorite = favoriteProvider.isFavorite(item);
                    return Positioned(
                      right: 6.r,
                      top: 6.r,
                      child: GestureDetector(
                        onTap: () async {
                          final isAuthenticated =
                              await AuthGuard.ensureAuthenticated(context);
                          if (!isAuthenticated) return;

                          if (isFavorite) {
                            favoriteProvider.removeFromFavorites(item);
                          } else {
                            favoriteProvider.addToFavorites(item);
                          }
                        },
                        child: SvgPicture.asset(
                          isFavorite
                              ? Assets.icons.heartSolid
                              : Assets.icons.heart,
                          package: 'grab_go_shared',
                          height: 24,
                          width: 24.w,
                          colorFilter: ColorFilter.mode(
                            isFavorite ? colors.error : Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            // Content
            Padding(
              padding: EdgeInsets.only(top: 10.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    daysAgo == 0
                        ? "Ordered today"
                        : "Ordered $daysAgo ${daysAgo == 1 ? 'day' : 'days'} ago",
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Price and cart button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          "GHS ${item.price.toStringAsFixed(2)}",
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: colors.accentOrange,
                          ),
                        ),
                      ),
                      // Quick add button
                      GestureDetector(
                        onTap: isLoading ? null : onAddToCart,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isInCart
                                ? AppColors.accentOrange
                                : colors.backgroundSecondary,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(
                                scale: animation,
                                child: child,
                              );
                            },
                            child: isLoading
                                ? SizedBox(
                                    key: const ValueKey('pending'),
                                    width: 18.w,
                                    height: 18.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isInCart
                                            ? Colors.white
                                            : colors.accentOrange,
                                      ),
                                    ),
                                  )
                                : SvgPicture.asset(
                                    isInCart
                                        ? Assets.icons.check
                                        : Assets.icons.cart,
                                    key: ValueKey(isInCart),
                                    package: 'grab_go_shared',
                                    height: 18,
                                    width: 18.w,
                                    colorFilter: ColorFilter.mode(
                                      isInCart
                                          ? Colors.white
                                          : colors.textPrimary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
