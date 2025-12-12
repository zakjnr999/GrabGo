import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String icon;
  final Color accentColor;
  final VoidCallback? onSeeAll;

  const SectionHeader({super.key, required this.title, required this.icon, required this.accentColor, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.border),
                ),
                child: SvgPicture.asset(
                  icon,
                  package: 'grab_go_shared',
                  height: 20.h,
                  width: 20.w,
                  colorFilter: ColorFilter.mode(accentColor, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 10.w),
              Text(
                title,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
              ),
            ],
          ),
          if (onSeeAll != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onSeeAll,
                  borderRadius: BorderRadius.circular(20.r),
                  child: Row(
                    children: [
                      Text(
                        "See All",
                        style: TextStyle(color: accentColor, fontSize: 12.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.arrow_forward_ios_rounded, size: 12.sp, color: accentColor),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
