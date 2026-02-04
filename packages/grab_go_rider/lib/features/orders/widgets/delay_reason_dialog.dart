import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

import '../service/order_reservation_service.dart';

class DelayReasonDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final VoidCallback? onSubmitted;

  const DelayReasonDialog({super.key, required this.orderId, required this.orderNumber, this.onSubmitted});

  static Future<bool?> show(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    VoidCallback? onSubmitted,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => DelayReasonDialog(orderId: orderId, orderNumber: orderNumber, onSubmitted: onSubmitted),
    );
  }

  @override
  State<DelayReasonDialog> createState() => _DelayReasonDialogState();
}

class _DelayReasonDialogState extends State<DelayReasonDialog> {
  DelayReasonType? _selectedReason;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitReason() async {
    if (_selectedReason == null || _isSubmitting) return;

    if (_selectedReason == DelayReasonType.other && _noteController.text.trim().length < 5) {
      return;
    }

    setState(() => _isSubmitting = true);

    final service = OrderReservationService();
    final success = await service.submitDelayReason(
      widget.orderId,
      _selectedReason!,
      note: _selectedReason == DelayReasonType.other ? _noteController.text.trim() : null,
    );

    if (!mounted) return;

    if (success) {
      widget.onSubmitted?.call();
      Navigator.of(context).pop(true);
    } else {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.paddingOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(KBorderSize.borderRadius20),
          topRight: Radius.circular(KBorderSize.borderRadius20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Why was this delayed?',
                          style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          widget.orderNumber,
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: colors.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.warningCircle,
                        package: "grab_go_shared",
                        width: 20.w,
                        height: 20.w,
                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'This helps us understand delays and protects you from unfair penalties.',
                          style: TextStyle(color: colors.accentOrange, fontSize: 12.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  'Select a reason :',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),

          // Reason list
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  ...DelayReasonType.values.map((reason) => _buildReasonTile(reason, colors)),
                  if (_selectedReason == DelayReasonType.other) ...[
                    SizedBox(height: 4.h),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Please provide more details...',
                        hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
                        filled: true,
                        fillColor: colors.backgroundSecondary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          borderSide: BorderSide(color: colors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          borderSide: BorderSide(color: colors.accentOrange),
                        ),
                      ),
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
                    ),
                    SizedBox(height: 8.h),
                  ],
                ],
              ),
            ),
          ),

          // Bottom buttons
          Container(
            padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 16.h, bottom: padding.bottom + 20.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              boxShadow: [
                BoxShadow(color: colors.shadow.withValues(alpha: 0.1), blurRadius: 5, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () => Navigator.pop(context, false),
                    buttonText: "Skip",
                    backgroundColor: colors.inputBorder,
                    borderRadius: KBorderSize.borderRadius4,
                    textStyle: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    height: 56.h,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AppButton(
                    onPressed: _submitReason,
                    buttonText: _isSubmitting ? "Please wait..." : "Submit",
                    backgroundColor: _selectedReason != null && !_isSubmitting
                        ? colors.accentGreen
                        : colors.accentGreen.withValues(alpha: 0.5),
                    borderRadius: KBorderSize.borderRadius4,
                    textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    height: 56.h,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonTile(DelayReasonType reason, AppColorsExtension colors) {
    final isSelected = _selectedReason == reason;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedReason = reason;
        });
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentOrange.withValues(alpha: 0.1) : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Row(
          children: [
            Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? colors.accentOrange : colors.textSecondary, width: 1.w),
                color: isSelected ? colors.accentOrange : Colors.transparent,
              ),
              child: isSelected
                  ? SvgPicture.asset(
                      Assets.icons.check,
                      package: "grab_go_shared",
                      width: 12.w,
                      height: 12.w,
                      colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    )
                  : null,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                reason.label,
                style: TextStyle(
                  color: isSelected ? colors.accentOrange : colors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
