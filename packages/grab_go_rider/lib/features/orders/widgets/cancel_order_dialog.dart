import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

enum CancellationReason {
  restaurantClosed('Restaurant is closed', 'store_closed'),
  itemsUnavailable('Items unavailable', 'items_unavailable'),
  cantFindLocation('Can\'t find location', 'location_not_found'),
  customerUnreachable('Customer unreachable', 'customer_unreachable'),
  vehicleBreakdown('Vehicle breakdown', 'vehicle_breakdown'),
  trafficConditions('Excessive traffic/delays', 'traffic_delays'),
  safetyConcerns('Safety concerns', 'safety_concerns'),
  personalEmergency('Personal emergency', 'personal_emergency'),
  other('Other reason', 'other');

  final String displayText;
  final String apiValue;

  const CancellationReason(this.displayText, this.apiValue);
}

class CancelOrderDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final Function(CancellationReason reason, String? additionalNotes) onConfirm;

  const CancelOrderDialog({super.key, required this.orderId, required this.orderNumber, required this.onConfirm});

  static Future<void> show({
    required BuildContext context,
    required String orderId,
    required String orderNumber,
    required Function(CancellationReason reason, String? additionalNotes) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CancelOrderDialog(orderId: orderId, orderNumber: orderNumber, onConfirm: onConfirm),
    );
  }

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog> {
  CancellationReason? _selectedReason;
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
                Center(
                  child: Container(
                    width: 40.w,
                    height: 4.h,
                    margin: EdgeInsets.only(bottom: 16.h),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cancel Order',
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
                          'Frequent cancellations may affect your rider rating.',
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

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                children: [
                  ...CancellationReason.values.map((reason) => _buildReasonTile(reason, colors)),
                  if (_selectedReason == CancellationReason.other) ...[
                    SizedBox(height: 4.h),
                    TextField(
                      controller: _notesController,
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
                          borderSide: BorderSide(color: colors.error),
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
                    onPressed: () => Navigator.pop(context),
                    buttonText: "Go Back",
                    backgroundColor: colors.inputBorder,
                    borderRadius: KBorderSize.borderRadius4,
                    textStyle: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                    height: 56.h,
                  ),
                ),

                SizedBox(width: 12.w),
                Expanded(
                  child: AppButton(
                    onPressed: () async {
                      if (_selectedReason == null || _isSubmitting) return;

                      setState(() {
                        _isSubmitting = true;
                      });

                      await widget.onConfirm(
                        _selectedReason!,
                        _selectedReason == CancellationReason.other ? _notesController.text : null,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    buttonText: _isSubmitting ? "Please wait..." : "Cancel Order",
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

  Widget _buildReasonTile(CancellationReason reason, AppColorsExtension colors) {
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
          color: isSelected ? colors.error.withValues(alpha: 0.1) : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Row(
          children: [
            Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? colors.error : colors.textSecondary, width: 1.w),
                color: isSelected ? colors.error : Colors.transparent,
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
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                reason.displayText,
                style: TextStyle(
                  color: isSelected ? colors.error : colors.textPrimary,
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
