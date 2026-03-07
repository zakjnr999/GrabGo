import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';

class FractionalStarRating extends StatelessWidget {
  const FractionalStarRating({
    super.key,
    required this.rating,
    this.starCount = 5,
    this.size = 24,
    this.spacing = 2,
  });

  final double rating;
  final int starCount;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final normalizedRating = rating.clamp(0, starCount.toDouble());

    return Row(
      children: List.generate(starCount, (index) {
        final fill = (normalizedRating - index).clamp(0.0, 1.0).toDouble();
        return Padding(
          padding: EdgeInsets.only(
            right: index == starCount - 1 ? 0 : spacing.w,
          ),
          child: SizedBox(
            width: size.w,
            height: size.h,
            child: Stack(
              children: [
                SvgPicture.asset(
                  Assets.icons.starSolid,
                  package: 'grab_go_shared',
                  width: size.w,
                  height: size.h,
                  colorFilter: ColorFilter.mode(
                    colors.divider,
                    BlendMode.srcIn,
                  ),
                ),
                if (fill > 0)
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: fill,
                      child: SvgPicture.asset(
                        Assets.icons.starSolid,
                        package: 'grab_go_shared',
                        width: size.w,
                        height: size.h,
                        colorFilter: ColorFilter.mode(
                          colors.accentOrange,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
