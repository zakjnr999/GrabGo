import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class QuickReorderCard extends StatelessWidget {
  final FoodItem item;
  final int daysAgo;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final bool isInCart;

  const QuickReorderCard({
    super.key,
    required this.item,
    required this.daysAgo,
    required this.onTap,
    required this.onAddToCart,
    required this.isInCart,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260.w,
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
              padding: EdgeInsets.only(left: 10.r, right: 10.r, top: 8.r, bottom: 6.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    daysAgo == 0 ? "Ordered today" : "Ordered $daysAgo ${daysAgo == 1 ? 'day' : 'days'} ago",
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                  ),
                  SizedBox(height: 6.h),
                  // Price and cart button row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "GHS ${item.price.toStringAsFixed(2)}",
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      // Quick add button
                      GestureDetector(
                        onTap: onAddToCart,
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
