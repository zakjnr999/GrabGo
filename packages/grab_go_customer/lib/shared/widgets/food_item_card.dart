import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/widgets/vertical_zigzag_tag.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

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
    final reviewCountText = item.reviewCount > 0 ? " (${item.reviewCount})" : "";

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin ?? EdgeInsets.only(left: 20.w, right: 20.w, bottom: 16),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
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
                      color: colors.inputBackground,
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
                if (item.discountPercentage > 0)
                  Positioned(
                    top: 0,
                    left: 8.w,
                    child: VerticalZigzagTag(
                      primaryText: "${item.discountPercentage.toStringAsFixed(0)} %",
                      secondaryText: 'OFF',
                      color: colors.accentOrange,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food Name
                  Row(
                    children: [
                      Expanded(
                        child: Text(
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
                      ),

                      SvgPicture.asset(
                        Assets.icons.starSolid,
                        package: 'grab_go_shared',
                        height: 13,
                        width: 13.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${item.rating.toStringAsFixed(1)}$reviewCountText',
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                      ] else ...[
                        Container(
                          width: 3.w,
                          height: 3,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          "We're closed",
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: item.isRestaurantOpen ? colors.accentGreen : colors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
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
