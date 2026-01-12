import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// Reusable bottom sheet for custom input (tip amount or comment)
class CustomInputBottomSheet extends StatefulWidget {
  final String title;
  final String hintText;
  final CustomInputType inputType;
  final int? maxLength;
  final String? initialValue;
  final Function(String) onConfirm;

  const CustomInputBottomSheet({
    super.key,
    required this.title,
    required this.hintText,
    required this.inputType,
    required this.onConfirm,
    this.maxLength,
    this.initialValue,
  });

  @override
  State<CustomInputBottomSheet> createState() => _CustomInputBottomSheetState();
}

class _CustomInputBottomSheetState extends State<CustomInputBottomSheet> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  int _characterCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue ?? '');
    _focusNode = FocusNode();
    _characterCount = _controller.text.length;

    // Auto-focus the text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _controller.addListener(() {
      setState(() {
        _characterCount = _controller.text.length;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      // Show error for empty input
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(
      //       widget.inputType == CustomInputType.tip ? 'Please enter a tip amount' : 'Please enter a comment',
      //     ),
      //     backgroundColor: context.appColors.error,
      //   ),
      // );
      return;
    }

    // Validate tip amount if it's a tip input
    if (widget.inputType == CustomInputType.tip) {
      final amount = double.tryParse(value);
      if (amount == null || amount <= 0) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: const Text('Please enter a valid amount'), backgroundColor: context.appColors.error),
        // );
        return;
      }
    }

    widget.onConfirm(value);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isTipInput = widget.inputType == CustomInputType.tip;

    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24.r), topRight: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 12.h),
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(color: colors.divider, borderRadius: BorderRadius.circular(2.r)),
          ),

          SizedBox(height: 20.h),

          // Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
                // Show character count for comments
                if (!isTipInput && widget.maxLength != null)
                  Text(
                    '$_characterCount/${widget.maxLength}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: _characterCount > (widget.maxLength ?? 0) ? colors.error : colors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // Input field
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              maxLength: widget.maxLength,
              maxLines: isTipInput ? 1 : 4,
              keyboardType: isTipInput ? TextInputType.number : TextInputType.text,
              inputFormatters: isTipInput ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))] : null,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(color: colors.textSecondary),
                filled: true,
                fillColor: colors.backgroundSecondary,
                counterText: '',
                prefixIcon: isTipInput
                    ? Padding(
                        padding: EdgeInsets.only(left: 16.w, right: 8.w),
                        child: Text(
                          'GHS',
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                      )
                    : null,
                prefixIconConstraints: isTipInput ? const BoxConstraints(minWidth: 0, minHeight: 0) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5.r),
                  borderSide: BorderSide(color: colors.accentOrange, width: 1),
                ),
              ),
              style: TextStyle(color: colors.textPrimary, fontSize: 16.sp),
            ),
          ),

          SizedBox(height: 24.h),

          // Action buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                // Cancel button
                Expanded(
                  child: AppButton(
                    onPressed: Navigator.of(context).pop,
                    backgroundColor: colors.backgroundSecondary,
                    borderRadius: KBorderSize.borderRadius15,
                    buttonText: AppStrings.skip,
                    textStyle: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15.sp),
                  ),
                ),

                SizedBox(width: 12.w),

                // Confirm button
                Expanded(
                  child: AppButton(
                    buttonText: 'Confirm',
                    onPressed: _handleConfirm,
                    backgroundColor: colors.accentOrange,
                    borderRadius: KBorderSize.borderRadius15,
                    textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

/// Type of custom input
enum CustomInputType { tip, comment }

/// Helper function to show the bottom sheet
Future<String?> showCustomInputBottomSheet({
  required BuildContext context,
  required String title,
  required String hintText,
  required CustomInputType inputType,
  int? maxLength,
  String? initialValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: CustomInputBottomSheet(
        title: title,
        hintText: hintText,
        inputType: inputType,
        maxLength: maxLength,
        initialValue: initialValue,
        onConfirm: (value) {
          Navigator.of(context).pop(value);
        },
      ),
    ),
  );
}
