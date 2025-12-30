import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/utils/image_optimizer.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class FoodItemCard extends StatelessWidget {
  final FoodItem item;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;
  final String? deliveryTimeLabel;

  const FoodItemCard({super.key, required this.item, this.onTap, this.trailing, this.margin, this.deliveryTimeLabel});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin ?? EdgeInsets.only(left: 20.w, right: 20.w, bottom: 12.h),
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
              spreadRadius: 0,
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.borderRadius15),
                bottomLeft: Radius.circular(KBorderSize.borderRadius15),
              ),
              child: CachedNetworkImage(
                imageUrl: ImageOptimizer.getPreviewUrl(item.image, width: 400),
                height: size.height * 0.14,
                width: size.width * 0.32,
                fit: BoxFit.cover,
                memCacheWidth: 400, // Optimize memory usage
                maxHeightDiskCache: 800, // Limit disk cache size
                placeholder: (context, url) => Container(
                  height: size.height * 0.14,
                  width: size.width * 0.32,
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
                  height: size.height * 0.14,
                  width: size.width * 0.32,
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
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.r, vertical: 8.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            SvgPicture.asset(
                              Assets.icons.starSolid,
                              package: 'grab_go_shared',
                              height: 13.h,
                              width: 13.w,
                              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              item.rating.toStringAsFixed(1),
                              style: TextStyle(fontSize: 12.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              width: 3.w,
                              height: 3.h,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                            ),
                            SizedBox(width: 8.w),
                            SvgPicture.asset(
                              Assets.icons.timer,
                              package: 'grab_go_shared',
                              height: 12.h,
                              width: 12.w,
                              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              deliveryTimeLabel ?? '25-30 min',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: colors.accentOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            'GHS ${item.price.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: colors.accentOrange),
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
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
}
