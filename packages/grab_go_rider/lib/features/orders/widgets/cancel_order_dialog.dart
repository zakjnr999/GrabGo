import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// Cancellation reasons for riders
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

/// A dialog for selecting a cancellation reason
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
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(KBorderSize.borderRadius20),
          topRight: Radius.circular(KBorderSize.borderRadius20),
        ),
      ),
      padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 16.h, bottom: bottomPadding + 20.h),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
              // Header
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                    ),
                    child: Icon(Icons.cancel_outlined, color: colors.error, size: 24.w),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
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
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              // Warning message
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: colors.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  border: Border.all(color: colors.accentOrange.withValues(alpha: 0.3), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: colors.accentOrange, size: 20.w),
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
              // Reason selection
              Text(
                'Select a reason',
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12.h),
              ...CancellationReason.values.map((reason) => _buildReasonTile(reason, colors)),
              // Additional notes for "Other"
              if (_selectedReason == CancellationReason.other) ...[
                SizedBox(height: 12.h),
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
              ],
              SizedBox(height: 20.h),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        side: BorderSide(color: colors.border, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
                      ),
                      child: Text(
                        'Go Back',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedReason == null || _isSubmitting
                          ? null
                          : () async {
                              setState(() {
                                _isSubmitting = true;
                              });
                              Navigator.pop(context);
                              widget.onConfirm(
                                _selectedReason!,
                                _selectedReason == CancellationReason.other ? _notesController.text : null,
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: colors.error.withValues(alpha: 0.5),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Cancel Order',
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.error.withValues(alpha: 0.1) : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          border: Border.all(color: isSelected ? colors.error : colors.border, width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? colors.error : colors.textSecondary, width: 2),
                color: isSelected ? colors.error : Colors.transparent,
              ),
              child: isSelected ? Icon(Icons.check, color: Colors.white, size: 12.w) : null,
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
