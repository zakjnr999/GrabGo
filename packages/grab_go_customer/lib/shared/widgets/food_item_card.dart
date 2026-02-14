import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/widgets/vertical_zigzag_tag.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class FoodItemCard extends StatelessWidget {
  final FoodItem item;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final String? deliveryTimeLabel;
  final bool useVerticalZigzagTag;

  const FoodItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.trailing,
    this.margin,
    this.deliveryTimeLabel,
    this.useVerticalZigzagTag = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin ?? EdgeInsets.only(left: 20.w, right: 20.w, bottom: 16),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 1),
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
                    imageUrl: ImageOptimizer.getPreviewUrl(item.image, width: 600),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    memCacheWidth: 600,
                    maxHeightDiskCache: 1200,
                    placeholder: (context, url) => Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.inputBorder.withValues(alpha: 0.3),
                            colors.inputBorder.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.utensilsCrossed,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.3), BlendMode.srcIn),
                          width: 40.w,
                          height: 40,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colors.inputBorder.withValues(alpha: 0.3),
                            colors.inputBorder.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.utensilsCrossed,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.3), BlendMode.srcIn),
                          width: 40.w,
                          height: 40,
                        ),
                      ),
                    ),
                  ),
                ),
                if (item.discountPercentage > 0)
                  Positioned(
                    top: 0,
                    left: useVerticalZigzagTag ? 8.w : 0.w,
                    child: useVerticalZigzagTag
                        ? VerticalZigzagTag(
                            primaryText: "${item.discountPercentage.toStringAsFixed(0)} %",
                            secondaryText: 'OFF',
                            color: colors.accentOrange,
                          )
                        : Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6),
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
                            child: Text(
                              "${item.discountPercentage.toStringAsFixed(0)}% OFF",
                              style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                            ),
                          ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(12.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food Name
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  // Restaurant Name
                  Row(
                    children: [
                      Text(
                        item.sellerName,
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        width: 3.w,
                        height: 3,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        item.isRestaurantOpen ? "We're open" : "We're closed",
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: item.isRestaurantOpen ? colors.accentGreen : colors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Rating + ETA / Closed status
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.starSolid,
                        package: 'grab_go_shared',
                        height: 13,
                        width: 13.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                      if (item.isRestaurantOpen) ...[
                        SizedBox(width: 8.w),
                        Container(
                          width: 3.w,
                          height: 3,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                        ),
                        SizedBox(width: 8.w),
                        SvgPicture.asset(
                          Assets.icons.timer,
                          package: 'grab_go_shared',
                          height: 12,
                          width: 12.w,
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          deliveryTimeLabel ?? item.estimatedDeliveryTime,
                          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Price and Action Button
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.accentOrange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          'GHS ${(item.price * (1 - item.discountPercentage / 100)).toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.accentOrange),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      if (item.discountPercentage > 0)
                        Expanded(
                          child: Text(
                            "GHS ${item.price.toStringAsFixed(2)}",
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      const Spacer(),
                      // Action Button
                      if (trailing != null) trailing!,
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
