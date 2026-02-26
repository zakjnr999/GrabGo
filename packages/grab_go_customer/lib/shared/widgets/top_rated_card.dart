import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/vertical_zigzag_tag.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class TopRatedCard extends StatelessWidget {
  final FoodItem item;
  final CartItem? cartItem;
  final VoidCallback onTap;
  final bool useVerticalZigzagTag;
  final Color? accentColor;

  const TopRatedCard({
    super.key,
    required this.item,
    this.cartItem,
    required this.onTap,
    this.useVerticalZigzagTag = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveAccentColor = accentColor ?? colors.accentOrange;
    Size size = MediaQuery.sizeOf(context);
    final cardWidth = size.width * 0.5;
    final imageHeight = (cardWidth * 0.62).clamp(96.0, 120.0);
    final isOpen = item.isRestaurantOpen;
    final timeText = item.estimatedDeliveryTime;

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
          children: [
            // Image with rating badge
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
                Positioned(
                  top: 0,
                  left: useVerticalZigzagTag ? 8.w : 0.w,
                  child: useVerticalZigzagTag
                      ? VerticalZigzagTag(
                          primaryText: item.rating.toStringAsFixed(1),
                          secondaryText: 'rated',
                          color: accentColor ?? colors.accentOrange,
                        )
                      : Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: accentColor == null
                                  ? [colors.error, colors.accentOrange]
                                  : [effectiveAccentColor.withValues(alpha: 0.9), effectiveAccentColor],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomRight: Radius.circular(KBorderSize.borderMedium),
                              topLeft: Radius.circular(KBorderSize.borderMedium),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                Assets.icons.star,
                                package: 'grab_go_shared',
                                height: 13,
                                width: 13.w,
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                item.rating.toStringAsFixed(1),
                                style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            // Content
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
                        if (isOpen)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.sellerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                width: 3.w,
                                height: 3,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                              ),
                              SizedBox(width: 6.w),
                              SvgPicture.asset(
                                Assets.icons.timer,
                                package: 'grab_go_shared',
                                height: 12,
                                width: 12.w,
                                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                              ),
                              SizedBox(width: 4.w),
                              Flexible(
                                child: Text(
                                  timeText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            "We're closed",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.error),
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
                      final itemForCart = cartItem ?? item;
                      final bool isInCart = provider.cartItems.containsKey(itemForCart);
                      final bool isItemPending = provider.isItemOperationPending(itemForCart);
                      return GestureDetector(
                        onTap: () {
                          if (isItemPending) return;
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
                            color: isInCart ? (accentColor ?? colors.accentOrange) : colors.backgroundSecondary,
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
}
