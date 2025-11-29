import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:grab_go_customer/features/status/model/status_model.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// Status card widget for displaying status posts in horizontal list
class StatusCardNew extends StatelessWidget {
  final StatusModel status;
  final bool isDark;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final bool isLiked;

  const StatusCardNew({
    super.key,
    required this.status,
    required this.isDark,
    this.onTap,
    this.onLike,
    this.isLiked = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final categoryColor = status.category.getColor(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260.w,
        margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                  child: CachedNetworkImage(
                    imageUrl: status.mediaUrl,
                    height: 180.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180.h,
                      color: colors.inputBorder.withOpacity(0.3),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.accentOrange)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 180.h,
                      color: colors.inputBorder.withOpacity(0.3),
                      child: Icon(Icons.image_not_supported, color: colors.textSecondary, size: 40.r),
                    ),
                  ),
                ),
                // Category badge
                Positioned(
                  top: 12.h,
                  left: 12.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                    decoration: BoxDecoration(color: categoryColor, borderRadius: BorderRadius.circular(20.r)),
                    child: Text(
                      status.category.label,
                      style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Discount badge
                if (status.discountPercentage != null)
                  Positioned(
                    top: 12.h,
                    right: 12.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8.r)),
                      child: Text(
                        '${status.discountPercentage!.toInt()}% OFF',
                        style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                // Video indicator
                if (status.isVideo)
                  Positioned(
                    bottom: 12.h,
                    right: 12.w,
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                      child: Icon(Icons.play_arrow, color: Colors.white, size: 20.r),
                    ),
                  ),
              ],
            ),
            // Content section
            Padding(
              padding: EdgeInsets.all(14.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16.r,
                        backgroundImage: status.restaurant.logo != null
                            ? CachedNetworkImageProvider(status.restaurant.logo!)
                            : null,
                        child: status.restaurant.logo == null ? Icon(Icons.restaurant, size: 16.r) : null,
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              status.restaurant.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                            Text(
                              status.timeAgo,
                              style: TextStyle(fontSize: 11.sp, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Title
                  if (status.title != null) ...[
                    SizedBox(height: 10.h),
                    Text(
                      status.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ],
                  SizedBox(height: 12.h),
                  // Actions row
                  Row(
                    children: [
                      // Like button
                      GestureDetector(
                        onTap: onLike,
                        child: Row(
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : colors.textSecondary,
                              size: 20.r,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              '${status.likeCount}',
                              style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 16.w),
                      // Views
                      Row(
                        children: [
                          Icon(Icons.visibility_outlined, color: colors.textSecondary, size: 20.r),
                          SizedBox(width: 4.w),
                          Text(
                            '${status.viewCount}',
                            style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                          ),
                        ],
                      ),
                      SizedBox(width: 16.w),
                      // Share button
                      GestureDetector(
                        onTap: () => _shareStatus(context),
                        child: Icon(Icons.share_outlined, color: colors.textSecondary, size: 20.r),
                      ),
                      const Spacer(),
                      // Expires in
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: colors.inputBorder.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          status.expiresIn,
                          style: TextStyle(fontSize: 10.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
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
    );
  }

  void _shareStatus(BuildContext context) {
    String shareText = status.restaurant.name;
    if (status.title != null) {
      shareText += '\n${status.title}';
    }
    if (status.discountPercentage != null) {
      shareText += '\n${status.discountPercentage!.toInt()}% OFF!';
    }
    if (status.promoCode != null) {
      shareText += '\nUse code: ${status.promoCode}';
    }
    shareText += '\n\nCheck it out on GrabGo!';

    Share.share(shareText);
  }
}
