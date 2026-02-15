import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/vertical_zigzag_tag.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class DealCard extends StatelessWidget {
  final FoodItem item;
  final String? deliveryTime;
  final CartItem? cartItem;
  final int discountPercent;
  final VoidCallback onTap;
  final double? cardWidth;
  final Color? accentColor;

  const DealCard({
    super.key,
    required this.item,
    this.cartItem,
    required this.discountPercent,
    required this.onTap,
    this.deliveryTime,
    this.cardWidth,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveAccentColor = accentColor ?? colors.accentOrange;
    final size = MediaQuery.sizeOf(context);
    final baseWidth = cardWidth ?? (size.width * 0.78);
    final resolvedWidth = cardWidth == null ? baseWidth.clamp(230.0, 320.0) : baseWidth.clamp(180.0, 320.0);
    final imageHeight = (resolvedWidth * 0.45).clamp(90.0, 125.0);
    final hasDiscount = discountPercent > 0;
    final originalPrice = discountPercent >= 100 ? item.price : item.price / (1 - discountPercent / 100);
    final timeText = deliveryTime ?? item.estimatedDeliveryTime;
    final isOpen = item.isRestaurantOpen;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: resolvedWidth,
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.5), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Consumer<FavoritesProvider>(
                  builder: (context, favoriteProvider, child) {
                    final bool isFavorite = favoriteProvider.isFavorite(item);
                    return Positioned(
                      right: 6.r,
                      top: 6.r,
                      child: GestureDetector(
                        onTap: () {
                          if (isFavorite) {
                            favoriteProvider.removeFromFavorites(item);
                          } else {
                            favoriteProvider.addToFavorites(item);
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
                if (hasDiscount)
                  Positioned(
                    top: 0,
                    left: 8.w,
                    child: VerticalZigzagTag(
                      primaryText: '$discountPercent%',
                      secondaryText: 'OFF',
                      color: effectiveAccentColor,
                    ),
                  ),
              ],
            ),
            // Content
            Padding(
              padding: EdgeInsets.only(left: 10.r, right: 10.r, top: 10.r),
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
                        Row(
                          children: [
                            SvgPicture.asset(
                              Assets.icons.starSolid,
                              package: 'grab_go_shared',
                              height: 13,
                              width: 13.w,
                              colorFilter: ColorFilter.mode(effectiveAccentColor, BlendMode.srcIn),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              item.rating.toStringAsFixed(1),
                              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              width: 3.w,
                              height: 3,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                            ),
                            SizedBox(width: 8.w),
                            if (isOpen) ...[
                              SvgPicture.asset(
                                Assets.icons.timer,
                                package: 'grab_go_shared',
                                height: 12,
                                width: 12.w,
                                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                              ),
                              SizedBox(width: 4.w),

                              Text(
                                timeText,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ] else ...[
                              Text(
                                "We're closed",
                                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.error),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4),
                              decoration: BoxDecoration(
                                color: effectiveAccentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                "GHS ${item.price.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: effectiveAccentColor,
                                ),
                              ),
                            ),
                            if (hasDiscount) ...[
                              SizedBox(width: 8.w),
                              Text(
                                "GHS ${originalPrice.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  Consumer<CartProvider>(
                    builder: (context, provider, _) {
                      final itemForCart = cartItem ?? item;
                      final bool isInCart = provider.cartItems.containsKey(itemForCart);
                      return GestureDetector(
                        onTap: () {
                          if (isInCart) {
                            provider.removeItemCompletely(itemForCart);
                          } else {
                            provider.addToCart(itemForCart, context: context);
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
                            child: SvgPicture.asset(
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
}
