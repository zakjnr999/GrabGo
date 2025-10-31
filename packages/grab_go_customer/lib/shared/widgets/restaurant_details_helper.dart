import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_customer/features/restaurant/model/restaurants_model.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';

class BuildRestaurantDetails extends StatelessWidget {
  const BuildRestaurantDetails({super.key, 
    required this.colors,
    required this.restaurant,
    required this.icon,
    required this.color,
    required this.text,
  });

  final String text;
  final Color color;
  final String icon;
  final AppColorsExtension colors;
  final RestaurantModel restaurant;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          margin: EdgeInsets.only(top: KSpacing.md.r),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary.withAlpha(60),
            borderRadius: BorderRadius.circular(KBorderSize.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                icon,
                height: 15.h,
                width: 15.w,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              SizedBox(width: KBorderWidth.extraThick.w),
              Text(
                text,
                style: TextStyle(fontSize: 12.sp, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }
}



