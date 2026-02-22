import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_setup_step.dart';
import 'package:grab_go_vendor/features/onboarding/view/widgets/detail_chip.dart';

class StepDetailCard extends StatelessWidget {
  final VendorGuidedSetupStep step;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onResume;

  const StepDetailCard({
    super.key,
    required this.step,
    required this.onStart,
    required this.onComplete,
    required this.onSkip,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final status = step.status;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w900,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              DetailChip(
                label: onboardingStepStatusLabel(status),
                color: _statusColor(colors, status),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            step.subtitle,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: 10.h),
          ...step.checklist.map((entry) {
            return Padding(
              padding: EdgeInsets.only(bottom: 7.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7.w,
                    height: 7.w,
                    margin: EdgeInsets.only(top: 5.h),
                    decoration: BoxDecoration(
                      color: colors.vendorPrimaryBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      entry,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 8.h),
          Row(
            children: [
              if (status != VendorGuidedStepStatus.completed)
                Expanded(
                  child: AppButton(
                    buttonText:
                        status == VendorGuidedStepStatus.skipped ||
                            status == VendorGuidedStepStatus.inProgress
                        ? 'Resume'
                        : 'Start',
                    onPressed:
                        status == VendorGuidedStepStatus.skipped ||
                            status == VendorGuidedStepStatus.inProgress
                        ? onResume
                        : onStart,
                    height: 46,
                    padding: EdgeInsets.zero,
                    backgroundColor: colors.vendorPrimaryBlue.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: KBorderSize.border,
                    textStyle: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.vendorPrimaryBlue,
                    ),
                  ),
                ),
              if (status != VendorGuidedStepStatus.completed)
                SizedBox(width: 8.w),
              Expanded(
                child: IgnorePointer(
                  ignoring: status == VendorGuidedStepStatus.completed,
                  child: Opacity(
                    opacity: status == VendorGuidedStepStatus.completed
                        ? 0.6
                        : 1,
                    child: AppButton(
                      buttonText: status == VendorGuidedStepStatus.completed
                          ? 'Completed'
                          : 'Mark Complete',
                      onPressed: onComplete,
                      height: 46,
                      padding: EdgeInsets.all(0),
                      backgroundColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.border,
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (step.isOptional &&
              status != VendorGuidedStepStatus.completed) ...[
            SizedBox(height: 6.h),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: status == VendorGuidedStepStatus.skipped
                    ? null
                    : onSkip,
                child: Text(
                  status == VendorGuidedStepStatus.skipped
                      ? 'Skipped'
                      : 'Skip Optional Step',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color _statusColor(AppColorsExtension colors, VendorGuidedStepStatus status) {
  return switch (status) {
    VendorGuidedStepStatus.pending => colors.textSecondary,
    VendorGuidedStepStatus.inProgress => colors.warning,
    VendorGuidedStepStatus.completed => colors.success,
    VendorGuidedStepStatus.skipped => colors.error,
  };
}
