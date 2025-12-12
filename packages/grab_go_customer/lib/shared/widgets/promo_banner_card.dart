import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 160.h,
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(10), spreadRadius: 1, blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
          child: Stack(
            children: [
              // Content
              Padding(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              // Image on the right
              Positioned(
                right: -18.w,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 150.w,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(KBorderSize.borderMedium),
                      bottomRight: Radius.circular(KBorderSize.borderMedium),
                    ),
                    child: CachedImageWidget(imageUrl: imageUrl, fit: BoxFit.cover),
                  ),
                ),
              ),
              // Discount badge
              Positioned(
                right: 8.w,
                top: 8.h,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.pink.shade400, Colors.pink.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                    boxShadow: [BoxShadow(color: Colors.pink.withAlpha(80), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Up to',
                        style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      Text(
                        discount,
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: Colors.white, height: 1),
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
