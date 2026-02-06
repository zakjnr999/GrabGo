import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class Orders extends StatefulWidget {
  const Orders({super.key});

  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.accentOrange,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(20.r),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.accentOrange.withValues(alpha: 0.4),
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.squareMenu,
                        package: 'grab_go_shared',
                        height: 20.h,
                        width: 20.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(top: 0, left: 0, right: 0, child: _buildCollapsibleUmbrellaHeader(colors, size)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsibleUmbrellaHeader(AppColorsExtension colors, Size size) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);

        final expandedHeight = size.height * 0.20;

        final currentHeight = expandedHeight - ((expandedHeight - _collapsedHeight) * collapseProgress);

        final contentOpacity = (1.0 - collapseProgress).clamp(0.0, 1.0);

        return SizedBox(
          height: currentHeight,
          child: UmbrellaHeaderWithShadow(
            curveDepth: 25.h,
            numberOfCurves: 10,
            height: currentHeight,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: contentOpacity,
              child: _buildAccountHeader(colors),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountHeader(AppColorsExtension colors) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: statusBarHeight + 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Account",
              style: TextStyle(
                fontFamily: "Lato",
                package: 'grab_go_shared',
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              "Manage your profile, orders, and settings",
              style: TextStyle(
                fontFamily: "Lato",
                package: 'grab_go_shared',
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
