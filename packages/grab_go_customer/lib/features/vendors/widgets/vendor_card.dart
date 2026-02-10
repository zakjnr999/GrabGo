import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import '../model/vendor_model.dart';

class VendorCard extends StatelessWidget {
  final VendorModel vendor;
  final VoidCallback onTap;
  final bool showDistance;
  final double? width;
  final EdgeInsetsGeometry? margin;

  const VendorCard({
    super.key,
    required this.vendor,
    required this.onTap,
    this.showDistance = true,
    this.width,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final cardWidth = width ?? (size.width - 40.w);
    final imageHeight = (cardWidth * 0.36).clamp(78.0, 100.0);

    return Container(
      width: width ?? double.infinity,
      margin: margin ?? EdgeInsets.symmetric(horizontal: 20.w, vertical: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          child: Container(
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.5), width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.all(1.0.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVendorImage(colors, imageHeight),

                  Padding(
                    padding: EdgeInsets.only(left: 10.r, right: 10.r, top: 10.r),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                vendor.displayName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
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
                                  vendor.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 4),

                        Row(
                          children: [
                            if (vendor.vendorCategories.isNotEmpty)
                              Text(
                                vendor.vendorCategories.first,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (vendor.vendorCategories.isNotEmpty && showDistance && vendor.distanceText.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6.w),
                                child: Text(
                                  "·",
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            if (showDistance && vendor.distanceText.isNotEmpty)
                              Text(
                                vendor.distanceText,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
                              "${vendor.averageDeliveryTime.toString()} mins",
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                SvgPicture.asset(
                                  Assets.icons.deliveryTruck,
                                  package: 'grab_go_shared',
                                  height: 13,
                                  width: 13.w,
                                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  vendor.deliveryFeeText,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (vendor.minOrder > 0) ...[
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                                    child: Text(
                                      "|",
                                      style: TextStyle(color: colors.textTertiary, fontSize: 12.sp),
                                    ),
                                  ),
                                  Text(
                                    "Min: ",
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    "GHS ${vendor.minOrder.toStringAsFixed(0)}",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4),
                              child: Text(
                                vendor.isOpen ? "We're open" : "We're closed",
                                style: TextStyle(
                                  color: vendor.isOpen ? colors.accentGreen : colors.error,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
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
          ),
        ),
      ),
    );
  }

  Widget _buildVendorImage(AppColorsExtension colors, double imageHeight) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderMedium),
            topRight: Radius.circular(KBorderSize.borderMedium),
            bottomLeft: Radius.circular(KBorderSize.borderRadius4),
            bottomRight: Radius.circular(KBorderSize.borderRadius4),
          ),
          child: CachedNetworkImage(
            imageUrl: ImageOptimizer.getPreviewUrl(vendor.logo ?? '', width: 800),
            height: imageHeight,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: imageHeight,
              width: double.infinity,
              color: colors.inputBorder,
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.store,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  width: 30.w,
                  height: 30,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: imageHeight,
              width: double.infinity,
              color: colors.inputBorder,
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.store,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  width: 30.w,
                  height: 30,
                ),
              ),
            ),
          ),
        ),

        Positioned(
          right: 6.r,
          top: 6.r,
          child: GestureDetector(
            onTap: () {},
            child: SvgPicture.asset(
              Assets.icons.heart,
              package: 'grab_go_shared',
              height: 24,
              width: 24.w,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
      ],
    );
  }
}
