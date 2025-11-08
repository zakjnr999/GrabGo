import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/features/restaurant/view/restaurant_details.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';

class RestaurantDetailsInfoBox extends StatelessWidget {
  const RestaurantDetailsInfoBox({
    super.key,
    required this.size,
    required this.colors,
    required this.widget,
    required this.text,
    required this.subText,
    required this.assetImg,
  });

  final Size size;
  final AppColorsExtension colors;
  final RestaurantDetails widget;
  final String text;
  final String subText;
  final String assetImg;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: size.height * 0.1,
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(4), spreadRadius: 1, blurRadius: 12, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withAlpha(2), spreadRadius: -1, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),

          Text(
            subText,
            style: TextStyle(
              fontSize: KTextSize.extraSmall.sp,
              fontWeight: FontWeight.w400,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: 4.h),

          SvgPicture.asset(
            assetImg,
            package: 'grab_go_shared',
            height: 14.h,
            width: 14.w,
            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }
}
