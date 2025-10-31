import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class HomeSearch extends StatelessWidget {
  const HomeSearch({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    Size size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onTap: () => context.push("/search"),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: EdgeInsets.all(2.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(KBorderSize.border),
          color: colors.backgroundPrimary,

          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              spreadRadius: 1,
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withAlpha(5),
              spreadRadius: -1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),

        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 10.w),
              child: SvgPicture.asset(
                Assets.icons.search,
                            package: 'grab_go_shared',
                height: KIconSize.md, width: KIconSize.md,
                colorFilter: ColorFilter.mode(
                          colors.textTertiary,
                  BlendMode.srcIn,
                ),
              ),
            ),

            SizedBox(width: 5.w),

            Text(
              "Search...",
              style: TextStyle(
                color: colors.textTertiary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),

          Container(
            width: size.width * 0.24,
            padding: EdgeInsets.all(2.r),
            decoration: BoxDecoration(
              color: colors.accentOrange,
              borderRadius: BorderRadius.circular(KBorderSize.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 10.w),
                  child: Text(
                    "Filter",
                    style: TextStyle(
                      color: colors.backgroundPrimary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push("/orderTracking"),
                  child: Container(
                    padding: EdgeInsets.all(7.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(KBorderSize.border),
                    ),
                    child: SvgPicture.asset(
                      Assets.icons.slidersHorizontal,
                            package: 'grab_go_shared',
                      height: KIconSize.sm, width: KIconSize.sm,
                      colorFilter: ColorFilter.mode(
                          colors.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}


