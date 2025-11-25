import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_customer/features/status/model/status.dart';
import 'package:grab_go_customer/shared/utils/constants.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';

class StatusCard extends StatelessWidget {
  final StatusPost post;
  final bool isDark;

  const StatusCard({super.key, required this.post, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusCategoryColor = categoryColor(post.category, colors);
    final statusCategoryLabel = categoryLabel(post.category);
    final isPromo =
        post.category == StatusCategory.dailySpecial ||
        post.category == StatusCategory.discount ||
        post.category == StatusCategory.newItem;
    final ctaText = isPromo ? 'Order Special' : 'View Story';
    final metaLabel = statusMetaLabel(post.category);

    Widget buildSecondaryAction(String iconData, {VoidCallback? onTap}) {
      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: colors.iconSecondary.withAlpha(40),
          onTap: onTap,
          child: Container(
            width: 40.r,
            height: 40.r,
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.backgroundSecondary,
              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.6), width: 1),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                  spreadRadius: 0,
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SvgPicture.asset(
              iconData,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
            ),
          ),
        ),
      );
    }

    Widget buildPrimaryAction() {
      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: colors.accentOrange.withValues(alpha: 0.25),
          onTap: () {},
          child: Container(
            width: 56.r,
            height: 56.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.accentOrange.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(
                isPromo ? Assets.icons.cart : Assets.icons.mediaVideo,
                package: 'grab_go_shared',
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                height: 26.h,
                width: 26.w,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 14.h,
            left: 12.w,
            right: 12.w,
            child: Opacity(
              opacity: isDark ? 0.16 : 0.12,
              child: Container(
                height: 210.h,
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(12),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: MediaQuery.of(context).size.width * 0.80,
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(14),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(KBorderSize.borderRadius20),
                    topRight: Radius.circular(KBorderSize.borderRadius20),
                  ),
                  child: Stack(
                    children: [
                      post.coverImage.image(
                        height: 220.h,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        package: 'grab_go_shared',
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          height: 90.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.55),
                                Colors.black.withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12.h,
                        left: 12.w,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    statusCategoryColor.withValues(alpha: 0.98),
                                    statusCategoryColor.withValues(alpha: 0.82),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusCategoryColor.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                statusCategoryLabel,
                                style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w700),
                              ),
                            ),
                            if (metaLabel != null) ...[
                              SizedBox(height: 4.h),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [colors.error, colors.accentOrange.withValues(alpha: 0.8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.accentOrange.withValues(alpha: 0.22),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      Assets.icons.fireFlame,
                                      package: "grab_go_shared",
                                      height: 16.h,
                                      width: 16.w,
                                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      metaLabel,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned(
                        left: 12.w,
                        right: 12.w,
                        bottom: 14.h,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18.r,
                              backgroundColor: colors.backgroundSecondary,
                              child: ClipOval(
                                child: post.logoImage.image(
                                  width: 32.w,
                                  height: 32.h,
                                  fit: BoxFit.cover,
                                  package: 'grab_go_shared',
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    post.restaurantName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                  SizedBox(height: 2.h),
                                  Text(
                                    '$statusCategoryLabel • ${post.timeAgo}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11.sp, color: Colors.white.withValues(alpha: 0.9)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildSecondaryAction(Assets.icons.heart, onTap: () {}),
                      SizedBox(width: 24.w),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildPrimaryAction(),
                          SizedBox(height: 4.h),
                          Text(
                            ctaText,
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                        ],
                      ),
                      SizedBox(width: 24.w),
                      buildSecondaryAction(Assets.icons.shareAndroid, onTap: () {}),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? statusMetaLabel(StatusCategory category) {
  switch (category) {
    case StatusCategory.discount:
      return 'Limited offer';
    default:
      return null;
  }
}
