import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class PopularItemCard extends StatelessWidget {
  final FoodItem item;
  final int orderCount;
  final VoidCallback onTap;

  const PopularItemCard({super.key, required this.item, required this.orderCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280.w,
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(10), spreadRadius: 1, blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.borderMedium),
                topRight: Radius.circular(KBorderSize.borderMedium),
              ),
              child: CachedImageWidget(imageUrl: item.image, height: 120.h, width: double.infinity, fit: BoxFit.cover),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(10.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.starSolid,
                        package: 'grab_go_shared',
                        height: 14.h,
                        width: 14.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "GHS ${item.price.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                            SizedBox(height: 6.h),
                            // Popular badge
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: AppColors.errorRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    Assets.icons.flame,
                                    package: 'grab_go_shared',
                                    height: 16.h,
                                    width: 16.w,
                                    colorFilter: const ColorFilter.mode(AppColors.errorRed, BlendMode.srcIn),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    "$orderCount orders",
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.errorRed,
                                    ),
                                  ),
                                ],
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
                                provider.addToCart(item);
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
