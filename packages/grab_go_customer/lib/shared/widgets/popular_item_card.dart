import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class PopularItemCard extends StatelessWidget {
  final CartItem item;
  final int orderCount;
  final VoidCallback onTap;
  final String? deliveryTime;
  final bool showDeliveryTime;

  const PopularItemCard({
    super.key,
    required this.item,
    CartItem? cartItem,
    required this.orderCount,
    required this.onTap,
    this.deliveryTime,
    this.showDeliveryTime = true,
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
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.5), width: 1),
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
                    height: 120.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 400,
                    maxHeightDiskCache: 800,
                    placeholder: (context, url) => Container(
                      height: 120.h,
                      color: colors.inputBorder,
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.utensilsCrossed,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                          width: 30.w,
                          height: 30.h,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120.h,
                      color: colors.inputBorder,
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.utensilsCrossed,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                          width: 30.w,
                          height: 30.h,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0.h,
                  left: 0.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.error, colors.accentOrange],
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
                          Assets.icons.flame,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          "$orderCount orders",
                          style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                        ),
                      ],
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
                        onTap: () {
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
                          height: 24.h,
                          width: 24.w,
                          colorFilter: ColorFilter.mode(isFavorite ? colors.error : Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(10.r, 10.r, 10.r, 6.r),
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
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            if (showDeliveryTime) ...[
                              SvgPicture.asset(
                                Assets.icons.timer,
                                package: 'grab_go_shared',
                                height: 12.h,
                                width: 12.w,
                                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                deliveryTime ?? '25-30 min',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: colors.accentOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            "GHS ${item.price.toStringAsFixed(2)}",
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: colors.accentOrange),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Consumer<CartProvider>(
                    builder: (context, provider, _) {
                      final bool isInCart = provider.cartItems.containsKey(item);
                      return GestureDetector(
                        onTap: () {
                          if (isInCart) {
                            provider.removeItemCompletely(item);
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
                            color: isInCart ? AppColors.accentOrange : colors.backgroundSecondary,
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
                              height: 18.h,
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
