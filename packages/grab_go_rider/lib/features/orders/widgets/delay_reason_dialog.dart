import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

import '../service/order_reservation_service.dart';

/// Dialog for riders to select a delay reason when delivery is late
class DelayReasonDialog extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final VoidCallback? onSubmitted;

  const DelayReasonDialog({
    super.key,
    required this.orderId,
    required this.orderNumber,
    this.onSubmitted,
  });

  /// Show the delay reason dialog
  static Future<bool?> show(
    BuildContext context, {
    required String orderId,
    required String orderNumber,
    VoidCallback? onSubmitted,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DelayReasonDialog(
        orderId: orderId,
        orderNumber: orderNumber,
        onSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<DelayReasonDialog> createState() => _DelayReasonDialogState();
}

class _DelayReasonDialogState extends State<DelayReasonDialog> {
  DelayReasonType? _selectedReason;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitReason() async {
    if (_selectedReason == null) {
      setState(() => _error = 'Please select a reason');
      return;
    }

    if (_selectedReason == DelayReasonType.other && 
        _noteController.text.trim().length < 5) {
      setState(() => _error = 'Please provide more details (min 5 characters)');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final service = OrderReservationService();
    final success = await service.submitDelayReason(
      widget.orderId,
      _selectedReason!,
      note: _selectedReason == DelayReasonType.other ? _noteController.text.trim() : null,
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (success) {
      widget.onSubmitted?.call();
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'Failed to submit. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      title: Column(
        children: [
          Icon(
            Icons.schedule,
            color: colors.accentOrange,
            size: 48.sp,
          ),
          SizedBox(height: 12.h),
          Text(
            'Why was this delivery delayed?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Order #${widget.orderNumber}',
            style: TextStyle(
              fontSize: 14.sp,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This helps us understand delays and protects you from unfair penalties.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: colors.textSecondary,
              ),
            ),
            SizedBox(height: 16.h),
            
            // Reason options
            ...DelayReasonType.values.map((reason) => _buildReasonOption(reason, colors)),
            
            // Note field for "Other"
            if (_selectedReason == DelayReasonType.other) ...[
              SizedBox(height: 12.h),
              TextField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Please explain the reason...',
                  hintStyle: TextStyle(color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(12.w),
                ),
                style: TextStyle(color: colors.textPrimary),
              ),
            ],
            
            // Error message
            if (_error != null) ...[
              SizedBox(height: 8.h),
              Text(
                _error!,
                style: TextStyle(
                  color: colors.error,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Skip',
            style: TextStyle(
              color: colors.textSecondary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReason,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accentGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Submit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildReasonOption(DelayReasonType reason, AppColorsExtension colors) {
    final isSelected = _selectedReason == reason;
    
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: InkWell(
        onTap: () => setState(() {
          _selectedReason = reason;
          _error = null;
        }),
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentGreen.withValues(alpha: 0.1) : colors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isSelected ? colors.accentGreen : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Text(
                reason.icon,
                style: TextStyle(fontSize: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  reason.label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: colors.accentGreen,
                  size: 20.sp,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
