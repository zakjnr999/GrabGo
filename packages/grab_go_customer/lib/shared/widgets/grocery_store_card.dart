import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_store.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/shared/utils/image_optimizer.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class GroceryStoreCard extends StatelessWidget {
  final GroceryStore store;
  final VoidCallback onTap;
  final double? distance; // Optional distance in km

  const GroceryStoreCard({super.key, required this.store, required this.onTap, this.distance});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260.w,
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(10),
              spreadRadius: 1,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Store Logo
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.borderMedium),
                bottomLeft: Radius.circular(KBorderSize.borderMedium),
              ),
              child: CachedNetworkImage(
                imageUrl: ImageOptimizer.getPreviewUrl(store.logo, width: 300),
                height: 120.h,
                width: 100.w,
                fit: BoxFit.cover,
                memCacheWidth: 300,
                maxHeightDiskCache: 600,
                placeholder: (context, url) => Container(
                  height: 120.h,
                  width: 100.w,
                  color: colors.inputBorder,
                  child: Center(
                    child: Icon(Icons.storefront, color: colors.textSecondary, size: 30.sp),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 120.h,
                  width: 100.w,
                  color: colors.inputBorder,
                  child: Center(
                    child: Icon(Icons.storefront, color: colors.textSecondary, size: 30.sp),
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      store.storeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    ),
                    SizedBox(height: 8.h),

                    // Rating
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
                          store.rating.toStringAsFixed(1),
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          width: 3.w,
                          height: 3.h,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                        ),
                        SizedBox(width: 8.w),
                        if (distance != null) ...[
                          Text(
                            "${distance!.toStringAsFixed(1)} km",
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                          ),
                        ] else
                          Text(
                            store.address.split(',')[0], // Show city/area if no distance
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),

                    SizedBox(height: 8.h),

                    // Delivery Info
                    Row(
                      children: [
                        Icon(Icons.delivery_dining, size: 14.sp, color: colors.textSecondary),
                        SizedBox(width: 4.w),
                        Text(
                          "GHS ${store.deliveryFee.toStringAsFixed(2)}",
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                        SizedBox(width: 12.w),
                        Container(width: 1.w, height: 10.h, color: colors.textSecondary.withValues(alpha: 0.5)),
                        SizedBox(width: 12.w),
                        Text(
                          "Min GHS ${store.minOrder.toInt()}",
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
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
