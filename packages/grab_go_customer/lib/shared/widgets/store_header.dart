import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_store.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_shared/shared/utils/image_optimizer.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

class StoreHeader extends StatelessWidget {
  final GroceryStore store;
  final VoidCallback? onTap;

  const StoreHeader({super.key, required this.store, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.border.withValues(alpha: 0.1), width: 1),
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: ImageOptimizer.getPreviewUrl(store.logo, width: 100),
                  width: 40.w,
                  height: 40.h,
                  fit: BoxFit.cover,
                  memCacheWidth: 100,
                  maxHeightDiskCache: 200,
                  placeholder: (context, url) => Container(
                    color: colors.backgroundSecondary,
                    child: SvgPicture.asset(
                      Assets.icons.store,
                      package: 'grab_go_shared',
                      width: 20.w,
                      height: 20.h,
                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: colors.backgroundSecondary,
                    child: SvgPicture.asset(
                      Assets.icons.store,
                      package: 'grab_go_shared',
                      width: 20.w,
                      height: 20.h,
                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),

            // Store Name and Rating
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.storeName,
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.star,
                        package: 'grab_go_shared',
                        height: 12.h,
                        width: 12.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        store.rating.toStringAsFixed(1),
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow Icon
            if (onTap != null)
              SvgPicture.asset(
                Assets.icons.navArrowRight,
                package: 'grab_go_shared',
                height: 16.h,
                width: 16.w,
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              ),
          ],
        ),
      ),
    );
  }
}
