import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';

class HomeSliverAppbar extends StatelessWidget {
  const HomeSliverAppbar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);

    return SliverAppBar(
      expandedHeight: size.height * 0.40,
      backgroundColor: colors.accentGreen,
      surfaceTintColor: colors.accentGreen.withValues(alpha: 0.2),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      elevation: 0,
      pinned: true,
      stretch: true,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double expandRatio = ((constraints.maxHeight - kToolbarHeight) / (size.height * 0.40 - kToolbarHeight))
              .clamp(0.0, 1.0);
          final double reverseRatio = 1.0 - expandRatio;

          return FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
            background: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.accentGreen,
                        colors.accentGreen.withValues(alpha: 0.85),
                        colors.accentGreen.withValues(alpha: 0.75),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

                Positioned(
                  top: -50 * reverseRatio,
                  right: -30 * reverseRatio,
                  child: Container(
                    width: 200.w * (1 - reverseRatio * 0.5),
                    height: 200.w * (1 - reverseRatio * 0.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08 * expandRatio),
                    ),
                  ),
                ),
                Positioned(
                  top: 80.h * expandRatio,
                  right: -60.w * reverseRatio,
                  child: Container(
                    width: 150.w * (1 - reverseRatio * 0.6),
                    height: 150.w * (1 - reverseRatio * 0.6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06 * expandRatio),
                    ),
                  ),
                ),

                SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: EdgeInsets.only(left: 20.w, right: 16.w, top: 40.h, bottom: 20.h),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedOpacity(
                                opacity: expandRatio,
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius50),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6.w,
                                        height: 6.w,
                                        decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        "Level 4",
                                        style: TextStyle(
                                          color: colors.accentGreen,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h * expandRatio + 4.h),

                              AnimatedOpacity(
                                opacity: expandRatio,
                                duration: const Duration(milliseconds: 200),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Welcome back,",
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      "Rider Zak!",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 28.sp * expandRatio + 18.sp * reverseRatio,
                                        height: 1.2,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 26.h * expandRatio + 12.h),

                              AnimatedOpacity(
                                opacity: expandRatio,
                                duration: const Duration(milliseconds: 200),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "YOUR EARNINGS",
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(alpha: 0.8),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "GHC",
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.9),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 18.sp,
                                            height: 1,
                                          ),
                                        ),
                                        SizedBox(width: 4.w),
                                        Flexible(
                                          child: Text(
                                            "184.90",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 32.sp * expandRatio + 24.sp * reverseRatio,
                                              height: 1,
                                              letterSpacing: -1,
                                            ),
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
                      ),

                      Expanded(
                        flex: 2,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: size.width * 0.42 * expandRatio + size.width * 0.30 * reverseRatio,
                                height: size.width * 0.42 * expandRatio + size.width * 0.30 * reverseRatio,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.15 * expandRatio),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            Positioned(
                              bottom: -10.h * reverseRatio,
                              right: -10.w * reverseRatio,
                              child: Transform.scale(
                                scale: expandRatio * 0.2 + 0.8,
                                child: Assets.images.deliveryGuy.image(
                                  package: "grab_go_shared",
                                  height: size.height * 0.48 * expandRatio + size.height * 0.35 * reverseRatio,
                                  width: size.width * 0.48 * expandRatio + size.width * 0.35 * reverseRatio,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),

      bottom: PreferredSize(
        preferredSize: Size.fromHeight(20.h),
        child: Container(
          height: 20.h,
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(KBorderSize.borderRadius12),
              topRight: Radius.circular(KBorderSize.borderRadius12),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2)),
            ],
          ),
        ),
      ),

      leadingWidth: 60.w,
      leading: Material(
        color: Colors.transparent,
        child: Builder(
          builder: (context) => InkWell(
            onTap: () {
              Scaffold.of(context).openDrawer();
            },
            customBorder: const CircleBorder(),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              margin: EdgeInsets.all(8.r),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Padding(
                padding: EdgeInsets.all(12.r),
                child: SvgPicture.asset(
                  Assets.icons.menu,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),

      actions: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push("/notifications");
            },
            customBorder: const CircleBorder(),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              margin: EdgeInsets.all(8.r),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.all(12.r),
                    child: SvgPicture.asset(
                      Assets.icons.bell,
                      package: 'grab_go_shared',
                      width: 20.w,
                      height: 20.w,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 8.w),
      ],
    );
  }
}
