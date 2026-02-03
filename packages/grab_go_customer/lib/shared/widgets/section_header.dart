import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final int sectionTotal;
  final Color accentColor;
  final VoidCallback? onSeeAll;
  final bool? showIcon;

  const SectionHeader({
    super.key,
    required this.title,
    required this.sectionTotal,
    required this.accentColor,
    this.onSeeAll,
    this.showIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          if (onSeeAll != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onSeeAll,
                borderRadius: BorderRadius.circular(20.r),
                child: Row(
                  children: [
                    Text(
                      "See All ($sectionTotal)",
                      style: TextStyle(color: accentColor, fontSize: 12.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(width: 4.w),
                    SvgPicture.asset(
                      Assets.icons.navArrowRight,
                      package: 'grab_go_shared',
                      height: 16.h,
                      width: 16.w,
                      colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
