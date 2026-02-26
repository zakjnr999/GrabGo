import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import '../model/vendor_model.dart';

class VendorCard extends StatelessWidget {
  final VendorModel vendor;
  final VoidCallback onTap;
  final bool showDistance;
  final double? width;
  final EdgeInsetsGeometry? margin;
  final bool showClosedOnImage;

  const VendorCard({
    super.key,
    required this.vendor,
    required this.onTap,
    this.showDistance = true,
    this.width,
    this.margin,
    this.showClosedOnImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final cardWidth = width ?? (size.width - 40.w);
    final imageHeight = (cardWidth * 0.45).clamp(90.0, 125.0);
    final reviewCountText = vendor.totalReviews > 0
        ? " (${vendor.totalReviews})"
        : "";

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
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: EdgeInsets.all(1.0.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVendorImage(colors, imageHeight),
                  Padding(
                    padding: EdgeInsets.only(top: 10.r),
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
                                  colorFilter: ColorFilter.mode(
                                    colors.accentOrange,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${vendor.rating.toStringAsFixed(1)}$reviewCountText',
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
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Wrap(
                              spacing: 6.w,
                              runSpacing: 2.h,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (vendor.vendorCategories.isNotEmpty)
                                  Text(
                                    vendor.vendorCategories.first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (vendor.vendorCategories.isNotEmpty &&
                                    showDistance &&
                                    vendor.distanceText.isNotEmpty)
                                  Text(
                                    "·",
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                if (showDistance &&
                                    vendor.distanceText.isNotEmpty)
                                  Text(
                                    vendor.distanceText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(width: 8.w),
                            Container(
                              width: 3.w,
                              height: 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.textSecondary,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            SvgPicture.asset(
                              Assets.icons.timer,
                              package: 'grab_go_shared',
                              height: 12,
                              width: 12.w,
                              colorFilter: ColorFilter.mode(
                                colors.textSecondary,
                                BlendMode.srcIn,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                "${vendor.averageDeliveryTime} mins",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6.w,
                                runSpacing: 2.h,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SvgPicture.asset(
                                        Assets.icons.deliveryTruck,
                                        package: 'grab_go_shared',
                                        height: 13,
                                        width: 13.w,
                                        colorFilter: ColorFilter.mode(
                                          colors.textPrimary,
                                          BlendMode.srcIn,
                                        ),
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
                                    ],
                                  ),
                                  if (vendor.minOrder > 0) ...[
                                    Text(
                                      "|",
                                      style: TextStyle(
                                        color: colors.textTertiary,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                    Text(
                                      "Min:",
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
                            ),
                            if (vendor.isOpen || !showClosedOnImage) ...[
                              SizedBox(width: 8.w),
                              Text(
                                vendor.isOpen ? "We're open" : "We're closed",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: vendor.isOpen
                                      ? colors.accentGreen
                                      : colors.error,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
            imageUrl: ImageOptimizer.getPreviewUrl(
              vendor.logo ?? '',
              width: 800,
            ),
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
                  colorFilter: ColorFilter.mode(
                    colors.textSecondary,
                    BlendMode.srcIn,
                  ),
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
                  colorFilter: ColorFilter.mode(
                    colors.textSecondary,
                    BlendMode.srcIn,
                  ),
                  width: 30.w,
                  height: 30,
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
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        if (!vendor.isOpen && showClosedOnImage)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(KBorderSize.borderMedium),
                  topRight: Radius.circular(KBorderSize.borderMedium),
                  bottomLeft: Radius.circular(KBorderSize.borderRadius4),
                  bottomRight: Radius.circular(KBorderSize.borderRadius4),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                "We're closed",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
