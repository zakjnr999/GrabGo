import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/curved_side_clipper.dart';

class PromoBannerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final String discount;
  final Color backgroundColor;
  final VoidCallback onTap;

  const PromoBannerCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.discount,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final bool isLightBg = backgroundColor.computeLuminance() > 0.6;
    final Color textColor = isLightBg ? Colors.black : Colors.white;
    final Color subTextColor = textColor.withValues(alpha: 0.75);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 150.h,
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(backgroundColor, Colors.white, 0.08)!,
                        Color.lerp(backgroundColor, Colors.black, 0.18)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -30.h,
                right: -20.w,
                child: Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                ),
              ),
              Positioned(
                bottom: -40.h,
                left: -20.w,
                child: Container(
                  width: 140.w,
                  height: 140.w,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 150.w,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipPath(
                        clipper: CurvedSideClipper(),
                        child: CachedNetworkImage(
                          imageUrl: ImageOptimizer.getFullUrl(imageUrl, width: 600),
                          fit: BoxFit.cover,
                          memCacheWidth: 600,
                          maxHeightDiskCache: 400,
                          placeholder: (context, url) => Container(color: Colors.grey.shade200),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.error, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.25)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0.h, 120.w, 0.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: textColor, height: 1.15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: subTextColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: isLightBg ? 0.75 : 0.2),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Shop now",
                              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: textColor),
                            ),
                            SizedBox(width: 6.w),
                            Icon(Icons.arrow_forward_rounded, color: textColor, size: 14.sp),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (discount.isNotEmpty)
                Positioned(
                  right: 12.w,
                  top: 12.h,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accentOrange, colors.error],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          Assets.icons.tag,
                          package: 'grab_go_shared',
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          width: 14.sp,
                          height: 14.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          discount,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
