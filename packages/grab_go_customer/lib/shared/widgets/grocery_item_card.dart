import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class GroceryItemCard extends StatelessWidget {
  final GroceryItem item;
  final VoidCallback? onTap;
  final Widget? trailing;
  final EdgeInsetsGeometry? margin;

  const GroceryItemCard({super.key, required this.item, this.onTap, this.trailing, this.margin});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final bool hasDiscount = item.hasDiscount;
    final double displayPrice = item.discountedPrice;
    final double originalPrice = item.price;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin ?? EdgeInsets.only(left: 20.w, right: 20.w, bottom: 12),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(KBorderSize.borderRadius15),
                bottomLeft: Radius.circular(KBorderSize.borderRadius15),
              ),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: ImageOptimizer.getPreviewUrl(item.image, width: 300),
                    height: 110,
                    width: 110.w,
                    fit: BoxFit.cover,
                    memCacheWidth: 300,
                    maxHeightDiskCache: 600,
                    placeholder: (context, url) => Container(
                      height: 110,
                      width: 110.w,
                      color: colors.inputBorder,
                      child: Center(
                        child: Icon(Icons.shopping_basket_outlined, color: colors.textSecondary, size: 30.sp),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 110,
                      width: 110.w,
                      color: colors.inputBorder,
                      child: Center(
                        child: Icon(Icons.broken_image_outlined, color: colors.textSecondary, size: 30.sp),
                      ),
                    ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2),
                        decoration: BoxDecoration(color: colors.accentOrange, borderRadius: BorderRadius.circular(4.r)),
                        child: Text(
                          '-${item.discountPercentage.toInt()}%',
                          style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: EdgeInsets.all(12.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand and Name
                        if (item.brand.isNotEmpty)
                          Text(
                            item.brand.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          item.name,
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // Rating and Unit
                        Row(
                          children: [
                            if (item.rating > 0) ...[
                              SvgPicture.asset(
                                Assets.icons.starSolid,
                                package: 'grab_go_shared',
                                height: 12,
                                width: 12.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                item.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Container(
                                width: 3.w,
                                height: 3,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                              ),
                              SizedBox(width: 8.w),
                            ],
                            // Unit display
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.inputBackground,
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                              child: Text(
                                item.unit,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Price Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasDiscount)
                              Text(
                                'GHS ${originalPrice.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              'GHS ${displayPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: colors.accentOrange,
                              ),
                            ),
                          ],
                        ),

                        if (trailing != null)
                          trailing!
                        else if (!item.isAvailable)
                          Text(
                            'Sold Out',
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: colors.textSecondary),
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
