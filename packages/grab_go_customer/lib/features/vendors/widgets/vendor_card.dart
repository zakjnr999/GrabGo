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

    return Container(
      width: width,
      margin: margin ?? EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
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
                  // Vendor Image Section (Full Width Top)
                  _buildVendorImage(colors),

                  // Vendor Info Section (Bottom Content)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Name and Rating d
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                vendor.displayName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 17.sp,
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
                                  height: 13.h,
                                  width: 13.w,
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  vendor.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        SizedBox(height: 4.h),

                        // Row 2: Category · Distance text
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
                          ],
                        ),

                        SizedBox(height: 12.h),

                        // Row 3: 🚚 Delivery: GHS 6 | Min: GHS 18       Open Now
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left side: Delivery and Min Order
                            Row(
                              children: [
                                SvgPicture.asset(
                                  Assets.icons.deliveryTruck,
                                  package: 'grab_go_shared',
                                  height: 13.h,
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

                            // Right side: Open Now status
                            vendor.isOpen
                                ? Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: colors.accentGreen.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      "Open Now",
                                      style: TextStyle(
                                        color: colors.accentGreen,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: colors.error.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      "Closed",
                                      style: TextStyle(
                                        color: colors.error,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
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

  Widget _buildVendorImage(AppColorsExtension colors) {
    return Stack(
      children: [
        // Image
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderMedium),
            topRight: Radius.circular(KBorderSize.borderMedium),
            bottomLeft: Radius.circular(KBorderSize.borderRadius4),
            bottomRight: Radius.circular(KBorderSize.borderRadius4),
          ),
          child: CachedNetworkImage(
            imageUrl: ImageOptimizer.getPreviewUrl(vendor.logo ?? '', width: 800),
            height: width != null ? 110.h : 120.h,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              height: width != null ? 110.h : 120.h,
              width: double.infinity,
              color: colors.inputBorder,
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.store,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  width: 30.w,
                  height: 30.h,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: width != null ? 110.h : 120.h,
              width: double.infinity,
              color: colors.inputBorder,
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.store,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  width: 30.w,
                  height: 30.h,
                ),
              ),
            ),
          ),
        ),

        // Closed Overlay
        if (vendor.isOpen == false)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(KBorderSize.borderMedium),
                  topRight: Radius.circular(KBorderSize.borderMedium),
                  bottomLeft: Radius.circular(KBorderSize.borderRadius4),
                  bottomRight: Radius.circular(KBorderSize.borderRadius4),
                ),
              ),
              child: Center(
                child: Text(
                  'CLOSED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),

        // Special Badges (Top Right)
        // Positioned(
        //   top: 6.h,
        //   right: 6.w,
        //   child: Row(
        //     children: [
        //       if (vendor.is24Hours == true || vendor.operatingHours == '24/7')
        //         Container(
        //           padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
        //           decoration: BoxDecoration(
        //             color: Colors.white.withValues(alpha: 0.95),
        //             borderRadius: BorderRadius.circular(8.r),
        //             boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        //           ),
        //           child: Text(
        //             '24/7',
        //             style: TextStyle(fontSize: 12.sp, color: accentColor, fontWeight: FontWeight.w800),
        //           ),
        //         ),
        //       if (vendor.emergencyService == true) ...[
        //         SizedBox(width: 8.w),
        //         Container(
        //           padding: EdgeInsets.all(8.r),
        //           decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.95), shape: BoxShape.circle),
        //           child: Icon(Icons.emergency, size: 16.sp, color: Colors.white),
        //         ),
        //       ],
        //     ],
        //   ),
        // ),
        Positioned(
          right: 6.r,
          top: 6.r,
          child: GestureDetector(
            onTap: () {},
            child: SvgPicture.asset(
              Assets.icons.heart,
              package: 'grab_go_shared',
              height: 24.h,
              width: 24.w,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
      ],
    );
  }
}
