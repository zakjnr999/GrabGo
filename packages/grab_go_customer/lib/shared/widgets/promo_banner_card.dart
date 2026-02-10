import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
    final double imagePaneWidth = 150.w;
    final double contentRightInset = (imagePaneWidth + 14.w).clamp(130.0, 185.0).toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 150.h,
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: ClipPath(
          clipper: _PromoOfferCardClipper(
            cornerRadius: KBorderSize.borderMedium.r,
            notchDepth: 8.h.clamp(6.0, 10.0).toDouble(),
            notchCount: 1,
          ),
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
                width: imagePaneWidth,
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
                  padding: EdgeInsets.fromLTRB(16.w, 0.h, contentRightInset, 0.h),
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
                  right: 8.w,
                  top: 8.h,
                  child: _UmbrellaDiscountBadge(
                    value: discount,
                    diameter: 46.w.clamp(40.0, 54.0).toDouble(),
                    fillColor: Colors.white.withValues(alpha: 0.95),
                    textColor: colors.accentOrange,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromoOfferCardClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double notchDepth;
  final int notchCount;

  const _PromoOfferCardClipper({required this.cornerRadius, required this.notchDepth, required this.notchCount});

  @override
  Path getClip(Size size) {
    final path = Path();
    final radius = cornerRadius.clamp(8.0, 22.0).toDouble();
    final safeNotchCount = notchCount < 1 ? 1 : notchCount;
    final topStartX = radius;
    final topEndX = size.width - radius;
    final usableTopWidth = (topEndX - topStartX).clamp(1.0, size.width).toDouble();
    final segmentWidth = usableTopWidth / safeNotchCount;

    path.moveTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);

    var cursorX = topStartX;
    for (int index = 0; index < safeNotchCount; index++) {
      final nextX = topStartX + ((index + 1) * segmentWidth);
      final midX = (cursorX + nextX) / 2;
      path.lineTo(cursorX, 0);
      path.quadraticBezierTo(midX, notchDepth, nextX, 0);
      cursorX = nextX;
    }

    path.lineTo(size.width - radius, 0);
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, size.height - radius);
    path.quadraticBezierTo(size.width, size.height, size.width - radius, size.height);

    var bottomCursorX = size.width - radius;
    for (int index = 0; index < safeNotchCount; index++) {
      final nextX = (size.width - radius) - ((index + 1) * segmentWidth);
      final midX = (bottomCursorX + nextX) / 2;
      path.lineTo(bottomCursorX, size.height);
      path.quadraticBezierTo(midX, size.height - notchDepth, nextX, size.height);
      bottomCursorX = nextX;
    }

    path.lineTo(radius, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height - radius);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _PromoOfferCardClipper oldClipper) {
    return oldClipper.cornerRadius != cornerRadius ||
        oldClipper.notchDepth != notchDepth ||
        oldClipper.notchCount != notchCount;
  }
}

class _UmbrellaDiscountBadge extends StatelessWidget {
  final String value;
  final double diameter;
  final Color fillColor;
  final Color textColor;

  const _UmbrellaDiscountBadge({
    required this.value,
    required this.diameter,
    required this.fillColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final scallopRadius = diameter * 0.14;
    final canvasSize = diameter + (scallopRadius * 2.6);
    final center = canvasSize / 2;
    final orbitRadius = (diameter / 2) + (scallopRadius * 0.28);

    return SizedBox(
      width: canvasSize,
      height: canvasSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(12, (index) {
            final angle = (index / 12) * 2 * math.pi;
            final x = center + (math.cos(angle) * orbitRadius) - scallopRadius;
            final y = center + (math.sin(angle) * orbitRadius) - scallopRadius;

            return Positioned(
              left: x,
              top: y,
              child: Container(
                width: scallopRadius * 2,
                height: scallopRadius * 2,
                decoration: BoxDecoration(shape: BoxShape.circle, color: fillColor.withValues(alpha: 0.65)),
              ),
            );
          }),
          Container(
            width: diameter,
            height: diameter,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fillColor),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: FittedBox(
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(color: textColor, fontSize: 12.sp, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
