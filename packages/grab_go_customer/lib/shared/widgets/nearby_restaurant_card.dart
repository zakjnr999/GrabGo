import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class NearbyRestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final double distance; // in km
  final VoidCallback onTap;

  const NearbyRestaurantCard({super.key, required this.restaurant, required this.distance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260.w,
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(10), spreadRadius: 1, blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Restaurant image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.borderMedium),
                bottomLeft: Radius.circular(KBorderSize.borderMedium),
              ),
              child: CachedImageWidget(imageUrl: restaurant.imageUrl, height: 120.h, width: 100.w, fit: BoxFit.cover),
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
                      restaurant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
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
                          restaurant.rating.toStringAsFixed(1),
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14.sp, color: colors.accentGreen),
                        SizedBox(width: 4.w),
                        Text(
                          "${distance.toStringAsFixed(1)} km",
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                        SizedBox(width: 12.w),
                        Icon(Icons.access_time, size: 14.sp, color: colors.textSecondary),
                        SizedBox(width: 4.w),
                        Text(
                          "${restaurant.averageDeliveryTime} min",
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
