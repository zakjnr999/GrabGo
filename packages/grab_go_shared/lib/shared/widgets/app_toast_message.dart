import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import '../utils/constants.dart';
import '../utils/app_colors_extension.dart';

class AppToastMessage {
  static void show({
    required BuildContext context,
    required String message,
    Color? backgroundColor,
    int? maxLines,
    Duration? duration,
    ToastGravity? gravity,
    double? radius,
    bool showIcon = true,
  }) {
    final colors = context.appColors;
    final fToast = FToast();
    fToast.init(context);

    final isLongMessage = message.length > 50;
    final actualMaxLines = maxLines ?? (isLongMessage ? 3 : 1);
    final actualDuration = duration ?? (isLongMessage ? const Duration(seconds: 4) : const Duration(seconds: 2));
    final actualGravity = gravity ?? ToastGravity.CENTER;

    Widget toast = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85, minWidth: 200.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        borderRadius: radius != null ? BorderRadius.circular(radius) : BorderRadius.circular(KBorderSize.border),
        color: backgroundColor ?? colors.accentViolet,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            showIcon
                ? Container(
                    padding: EdgeInsets.all(5.r),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Image.asset(
                      Assets.icons.appIconCustomer.path,
                      package: "grab_go_shared",
                      height: 20.h,
                      width: 20.w,
                      fit: BoxFit.cover,
                    ),
                  )
                : SizedBox.shrink(),
            SizedBox(width: 12.w),
            Flexible(
              child: Text(
                message,
                style: TextStyle(
                  color: colors.backgroundPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
                maxLines: actualMaxLines,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );

    fToast.showToast(child: toast, gravity: actualGravity, toastDuration: actualDuration);
  }
}
