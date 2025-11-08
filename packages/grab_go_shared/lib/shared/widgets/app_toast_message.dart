import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../utils/constants.dart';
import '../utils/app_colors_extension.dart';

class AppToastMessage {
  static void show({
    required BuildContext context,
    required IconData icon,
    required String message,
    Color? backgroundColor,
    int? maxLines,
    Duration? duration,
    ToastGravity? gravity,
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
        borderRadius: BorderRadius.circular(KBorderSize.border),
        color: backgroundColor ?? colors.accentViolet,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.backgroundPrimary, size: 20.sp),
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
