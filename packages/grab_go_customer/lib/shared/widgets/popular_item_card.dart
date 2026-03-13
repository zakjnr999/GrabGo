import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/shared/services/auth_guard.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/vertical_zigzag_tag.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class PopularItemCard extends StatelessWidget {
  final CartItem item;
  final int orderCount;
  final VoidCallback onTap;
  final String? deliveryTime;
  final bool showDeliveryTime;
  final bool useVerticalZigzagTag;
  final Color? accentColor;

  const PopularItemCard({
    super.key,
    required this.item,
    CartItem? cartItem,
    required this.orderCount,
    required this.onTap,
    this.deliveryTime,
    this.showDeliveryTime = true,
    this.useVerticalZigzagTag = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveAccentColor = accentColor ?? colors.accentOrange;
    final reviewCount = _resolveReviewCount(item);
    final reviewCountText = reviewCount > 0 ? " (${_formatReviewCount(reviewCount)})" : "";
    final shouldShowOrderTag = !useVerticalZigzagTag || orderCount > 0;
    Size size = MediaQuery.sizeOf(context);
    final cardWidth = size.width * 0.5;
    final imageHeight = (cardWidth * 0.62).clamp(96.0, 120.0);
    final isOpen = item is FoodItem ? (item as FoodItem).isRestaurantOpen : true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                    imageUrl: ImageOptimizer.getPreviewUrl(item.image, width: 400),
                    height: imageHeight,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    maxHeightDiskCache: 800,
                    placeholder: (context, url) => Container(
                      height: imageHeight,
                      color: colors.inputBorder,
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.utensilsCrossed,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                          width: 30.w,
                          height: 30,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: imageHeight,
                      color: colors.inputBorder,
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.utensilsCrossed,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                          width: 30.w,
                          height: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                if (shouldShowOrderTag)
                  Positioned(
                    top: 0,
                    left: 8.w,
                    child: VerticalZigzagTag(
                      primaryText: orderCount.toString(),
                      secondaryText: 'orders',
                      color: accentColor ?? colors.accentOrange,
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
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(KBorderSize.borderMedium)),
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
                    final bool isFavorite = item is FoodItem ? favoriteProvider.isFavorite(item as FoodItem) : false;
                    return Positioned(
                      right: 6.r,
                      top: 6.r,
                      child: GestureDetector(
                        onTap: () async {
                          final isAuthenticated = await AuthGuard.ensureAuthenticated(context);
                          if (!isAuthenticated) return;

                          if (item is FoodItem) {
                            if (isFavorite) {
                              favoriteProvider.removeFromFavorites(item as FoodItem);
                            } else {
                              favoriteProvider.addToFavorites(item as FoodItem);
                            }
                          } else {
                            // TODO: Implement favorites for non-food items if needed
                          }
                        },
                        child: SvgPicture.asset(
                          isFavorite ? Assets.icons.heartSolid : Assets.icons.heart,
                          package: 'grab_go_shared',
                          height: 24,
                          width: 24.w,
                          colorFilter: ColorFilter.mode(isFavorite ? colors.error : Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        if (showDeliveryTime)
                          isOpen
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.providerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w500,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8.w),
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                                    ),
                                    SizedBox(width: 8.w),
                                    SvgPicture.asset(
                                      Assets.icons.starSolid,
                                      package: 'grab_go_shared',
                                      height: 11,
                                      width: 11.w,
                                      colorFilter: ColorFilter.mode(effectiveAccentColor, BlendMode.srcIn),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      '${item.rating.toStringAsFixed(1)}$reviewCountText',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        "We're closed",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                          color: colors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        const SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4),
                          decoration: BoxDecoration(
                            color: effectiveAccentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            "GHS ${item.price.toStringAsFixed(2)}",
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: effectiveAccentColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Consumer<CartProvider>(
                    builder: (context, provider, _) {
                      final bool includeFoodCustomizations = item is FoodItem;
                      final bool isInCart = provider.hasItemInCart(
                        item,
                        includeFoodCustomizations: includeFoodCustomizations,
                      );
                      final bool isItemPending = provider.isItemOperationPendingForDisplay(
                        item,
                        includeFoodCustomizations: includeFoodCustomizations,
                      );
                      final actionItem = provider.resolveItemForCartAction(
                        item,
                        includeFoodCustomizations: includeFoodCustomizations,
                      );
                      return GestureDetector(
                        onTap: () {
                          if (isItemPending) return;
                          if (isInCart && actionItem != null) {
                            provider.removeItemCompletely(actionItem);
                          } else {
                            provider.addToCart(item, context: context);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isInCart ? effectiveAccentColor : colors.backgroundSecondary,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) {
                              return ScaleTransition(scale: animation, child: child);
                            },
                            child: isItemPending
                                ? SizedBox(
                                    key: const ValueKey('pending'),
                                    width: 18.w,
                                    height: 18.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        isInCart ? Colors.white : colors.accentOrange,
                                      ),
                                    ),
                                  )
                                : SvgPicture.asset(
                                    isInCart ? Assets.icons.check : Assets.icons.cart,
                                    key: ValueKey(isInCart),
                                    package: 'grab_go_shared',
                                    height: 18,
                                    width: 18.w,
                                    colorFilter: ColorFilter.mode(
                                      isInCart ? Colors.white : colors.textPrimary,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _resolveReviewCount(CartItem item) {
    if (item is FoodItem) return item.reviewCount;
    if (item is GroceryItem) return item.reviewCount;
    if (item is PharmacyItem) return item.reviewCount;
    if (item is GrabMartItem) return item.reviewCount;
    return 0;
  }

  String _formatReviewCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 10000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000).round()}k';
  }
}
