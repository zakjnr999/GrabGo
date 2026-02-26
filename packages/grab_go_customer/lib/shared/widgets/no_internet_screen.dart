import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class NoInternetScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const NoInternetScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: colors.backgroundPrimary,
        child: SafeArea(
          child: SizedBox.expand(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      Assets.icons.noInternetIcon,
                      package: 'grab_go_shared',
                      width: 180.w,
                      height: 180.w,
                    ),

                    Text(
                      'No Internet Connection',
                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 8.h),

                    Text(
                      'Please check your network settings and try again.',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w400, color: colors.textSecondary),
                      textAlign: TextAlign.center,
                    ),

                    SizedBox(height: 32.h),
                    AppButton(
                      onPressed: onRetry,
                      buttonText: "Try Again",
                      backgroundColor: colors.accentOrange,
                      width: double.infinity,
                      height: KWidgetSize.buttonHeight.h,
                      borderRadius: KBorderSize.borderMedium,
                      textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
