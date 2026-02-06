import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class AreaUnavailableScreen extends StatelessWidget {
  final String? serviceName;
  final bool isAreaUnavailable;

  const AreaUnavailableScreen({super.key, this.serviceName, this.isAreaUnavailable = true});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final textPrimary = colors.textPrimary;
    final textSecondary = colors.textSecondary;
    final accentOrange = colors.accentOrange;

    final String displayServiceName = serviceName ?? "this service";
    final String title = isAreaUnavailable ? "GrabGo is Not Here Yet" : "Service Unavailable";
    final String description = isAreaUnavailable
        ? "We haven't launched our services in your current location yet. GrabGo is expanding rapidly—check back soon or try changing your address!"
        : "We're sorry! $displayServiceName are not available in your current location yet. Try changing your address to see what we offer elsewhere.";

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 60.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(color: accentOrange.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(
              isAreaUnavailable ? Icons.map_outlined : Icons.location_off_rounded,
              size: 64.r,
              color: accentOrange,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            title,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: textPrimary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          Text(
            description,
            style: TextStyle(fontSize: 14.sp, color: textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 32.h),
          AppButton(
            width: double.infinity,
            onPressed: () => context.push('/address_picker'),
            backgroundColor: colors.accentOrange,
            borderRadius: KBorderSize.borderMedium,
            buttonText: "Change Location",
            textStyle: TextStyle(fontSize: 15.sp, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
