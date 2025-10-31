import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/app_colors_extension.dart';
import '../utils/constants.dart';

class BlurCircleButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget icon;
  final double padding;

  const BlurCircleButton({
    super.key,
    required this.onTap,
    required this.icon,
    this.padding = 8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      height: KWidgetSize.buttonHeightSmall.h,
      width: KWidgetSize.buttonHeightSmall.w,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: colors.backgroundSecondary.withAlpha(60),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: Colors.black.withAlpha(72),
              child: Padding(padding: EdgeInsets.all(padding), child: icon),
            ),
          ),
        ),
      ),
    );
  }
}


