import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:grab_go_rider/features/home/models/partner_models.dart';

class ProfileSliverAppbar extends StatelessWidget {
  final String? riderName;
  final String? riderEmail;
  final PartnerLevel partnerLevel;
  final bool isLoading;

  const ProfileSliverAppbar({
    super.key,
    this.riderName,
    this.riderEmail,
    this.partnerLevel = PartnerLevel.L1,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.4,
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
          final double expandRatio =
              ((constraints.maxHeight - kToolbarHeight) / (MediaQuery.of(context).size.height * 0.35 - kToolbarHeight))
                  .clamp(0.0, 1.0);
          final double reverseRatio = 1.0 - expandRatio;

          return FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accentGreen, colors.accentGreen.withValues(alpha: 0.85)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: kToolbarHeight - 40.h),
                      AnimatedOpacity(
                        opacity: expandRatio,
                        duration: const Duration(milliseconds: 200),
                        child: Transform.scale(
                          scale: expandRatio * 0.2 + 0.8,
                          child: Stack(
                            children: [
                              Container(
                                width: 100.w * expandRatio + 60.w * reverseRatio,
                                height: 100.w * expandRatio + 60.w * reverseRatio,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4 * expandRatio + 2 * reverseRatio),
                                ),
                                child: Center(
                                  child: SvgPicture.asset(
                                    Assets.icons.user,
                                    package: 'grab_go_shared',
                                    width: (50.w * expandRatio + 30.w * reverseRatio),
                                    height: (50.w * expandRatio + 30.w * reverseRatio),
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h * expandRatio + 6.h),
                      AnimatedOpacity(
                        opacity: expandRatio,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isLoading
                              ? "..."
                              : ((riderName != null && riderName!.trim().isNotEmpty)
                                    ? riderName!.trim()
                                    : "GrabGo Partner"),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.sp * expandRatio + 18.sp * reverseRatio,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h * expandRatio),
                      AnimatedOpacity(
                        opacity: expandRatio,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isLoading
                              ? "Loading profile..."
                              : ((riderEmail != null && riderEmail!.trim().isNotEmpty)
                                    ? riderEmail!.trim()
                                    : "rider@grabgo.com"),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14.sp * expandRatio + 12.sp * reverseRatio,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h * expandRatio),
                      AnimatedOpacity(
                        opacity: expandRatio,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius50),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8.w,
                                height: 8.w,
                                decoration: BoxDecoration(
                                  color: _getLevelColor(partnerLevel, colors),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                '${partnerLevelLabel(partnerLevel)} Partner',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
              topLeft: Radius.circular(KBorderSize.borderRadius20),
              topRight: Radius.circular(KBorderSize.borderRadius20),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2)),
            ],
          ),
        ),
      ),
      title: Text(
        "Profile",
        style: TextStyle(
          fontFamily: "Lato",
          package: "grab_go_shared",
          color: Colors.white,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: 10.w),
          child: IconButton(
            icon: SvgPicture.asset(
              Assets.icons.edit,
              package: 'grab_go_shared',
              width: 24.w,
              height: 24.w,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Color _getLevelColor(PartnerLevel level, AppColorsExtension colors) {
    switch (level) {
      case PartnerLevel.L1:
        return Colors.white;
      case PartnerLevel.L2:
        return colors.accentBlue;
      case PartnerLevel.L3:
        return colors.accentOrange;
      case PartnerLevel.L4:
        return colors.accentViolet;
      case PartnerLevel.L5:
        return Colors.amber;
    }
  }
}
