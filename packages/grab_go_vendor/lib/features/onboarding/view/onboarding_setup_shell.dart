import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_setup_step.dart';
import 'package:grab_go_vendor/features/onboarding/viewmodel/onboarding_setup_viewmodel.dart';
import 'package:provider/provider.dart';

class OnboardingSetupShell extends StatelessWidget {
  final bool isReplayMode;

  const OnboardingSetupShell({super.key, this.isReplayMode = false});

  @override
  Widget build(BuildContext context) {
    return _OnboardingSetupShellView(isReplayMode: isReplayMode);
  }
}

class _OnboardingSetupShellView extends StatefulWidget {
  final bool isReplayMode;

  const _OnboardingSetupShellView({required this.isReplayMode});

  @override
  State<_OnboardingSetupShellView> createState() =>
      _OnboardingSetupShellViewState();
}

class _OnboardingSetupShellViewState extends State<_OnboardingSetupShellView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<OnboardingSetupViewModel>().markGuideOpened();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Consumer<OnboardingSetupViewModel>(
      builder: (context, viewModel, _) {
        final selectedStep = viewModel.selectedStep;
        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            title: Text(
              'Guided Setup',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 18.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete required setup items and optionally configure advanced operations.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SetupSummaryCard(
                    requiredCompleted: viewModel.requiredCompleted,
                    requiredTotal: viewModel.requiredTotal,
                    optionalCompleted: viewModel.optionalCompleted,
                    optionalTotal: viewModel.optionalTotal,
                    optionalSkipped: viewModel.optionalSkipped,
                    progress: viewModel.requiredProgress,
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    'Setup Steps',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ...viewModel.steps.map((step) {
                    return _SetupStepTile(
                      step: step,
                      selected: step.id == selectedStep.id,
                      onTap: () => viewModel.selectStep(step.id),
                    );
                  }),
                  SizedBox(height: 14.h),
                  _StepDetailCard(
                    step: selectedStep,
                    onStart: viewModel.startSelectedStep,
                    onComplete: viewModel.markSelectedComplete,
                    onSkip: viewModel.skipSelectedStep,
                    onResume: viewModel.resumeSelectedStep,
                  ),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 12.h),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viewModel.allRequiredCompleted
                        ? 'Required setup completed. You can continue.'
                        : '${viewModel.requiredRemaining} required step(s) remaining. You can still continue in UI preview mode.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: viewModel.allRequiredCompleted
                          ? colors.success
                          : colors.warning,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText: widget.isReplayMode
                          ? 'Done'
                          : 'Continue to Login',
                      onPressed: () => _finishSetup(context),
                      backgroundColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.borderRadius12,
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                  if (!viewModel.allRequiredCompleted) ...[
                    SizedBox(height: 6.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: viewModel.focusFirstRequiredGap,
                        child: Text(
                          'Review Required Steps',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: colors.vendorPrimaryBlue,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _finishSetup(BuildContext context) async {
    if (widget.isReplayMode) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    unawaited(CacheService.setFirstLaunchComplete());
    context.go('/login');
  }
}

class _SetupSummaryCard extends StatelessWidget {
  final int requiredCompleted;
  final int requiredTotal;
  final int optionalCompleted;
  final int optionalTotal;
  final int optionalSkipped;
  final double progress;

  const _SetupSummaryCard({
    required this.requiredCompleted,
    required this.requiredTotal,
    required this.optionalCompleted,
    required this.optionalTotal,
    required this.optionalSkipped,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.vendorPrimaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Required Progress',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: colors.vendorPrimaryBlue,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '$requiredCompleted / $requiredTotal completed',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(999.r),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 7.h,
              backgroundColor: colors.vendorPrimaryBlue.withValues(alpha: 0.2),
              color: colors.vendorPrimaryBlue,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Optional: $optionalCompleted / $optionalTotal completed • $optionalSkipped skipped',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupStepTile extends StatelessWidget {
  final VendorGuidedSetupStep step;
  final bool selected;
  final VoidCallback onTap;

  const _SetupStepTile({
    required this.step,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accentColor = _stepAccentColor(colors, step.type, step.serviceHint);
    final statusColor = _statusColor(colors, step.status);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: selected ? accentColor : colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                onboardingStepIcon(step.type),
                color: accentColor,
                size: 19.sp,
              ),
            ),
            SizedBox(width: 9.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: [
                      _Chip(
                        label: step.isOptional ? 'Optional' : 'Required',
                        color: step.isOptional
                            ? colors.serviceGrabMart
                            : colors.vendorPrimaryBlue,
                      ),
                      _Chip(
                        label: onboardingStepStatusLabel(step.status),
                        color: statusColor,
                      ),
                      _Chip(
                        label: step.estimateLabel,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _StepDetailCard extends StatelessWidget {
  final VendorGuidedSetupStep step;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onSkip;
  final VoidCallback onResume;

  const _StepDetailCard({
    required this.step,
    required this.onStart,
    required this.onComplete,
    required this.onSkip,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accentColor = _stepAccentColor(colors, step.type, step.serviceHint);
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
              _Chip(
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
                      color: accentColor,
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
                  child: OutlinedButton(
                    onPressed: status == VendorGuidedStepStatus.skipped
                        ? onResume
                        : onStart,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentColor,
                      side: BorderSide(
                        color: accentColor.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      status == VendorGuidedStepStatus.skipped
                          ? 'Resume'
                          : 'Start',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              if (status != VendorGuidedStepStatus.completed)
                SizedBox(width: 8.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: status == VendorGuidedStepStatus.completed
                      ? null
                      : onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.vendorPrimaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(
                    status == VendorGuidedStepStatus.completed
                        ? 'Completed'
                        : 'Mark Complete',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
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
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
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

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

Color _stepAccentColor(
  AppColorsExtension colors,
  VendorGuidedStepType stepType,
  VendorServiceType? serviceHint,
) {
  if (serviceHint != null) {
    return switch (serviceHint) {
      VendorServiceType.food => colors.serviceFood,
      VendorServiceType.grocery => colors.serviceGrocery,
      VendorServiceType.pharmacy => colors.servicePharmacy,
      VendorServiceType.grabMart => colors.serviceGrabMart,
    };
  }

  return switch (stepType) {
    VendorGuidedStepType.businessProfile => colors.vendorPrimaryBlue,
    VendorGuidedStepType.branchHours => colors.serviceGrocery,
    VendorGuidedStepType.serviceActivation => colors.serviceFood,
    VendorGuidedStepType.payoutSetup => colors.serviceGrabMart,
    VendorGuidedStepType.catalogStarter => colors.serviceFood,
    VendorGuidedStepType.staffInvite => colors.serviceGrocery,
    VendorGuidedStepType.notificationsSetup => colors.warning,
    VendorGuidedStepType.demoOrderRun => colors.info,
    VendorGuidedStepType.complianceReview => colors.servicePharmacy,
  };
}

Color _statusColor(AppColorsExtension colors, VendorGuidedStepStatus status) {
  return switch (status) {
    VendorGuidedStepStatus.pending => colors.textSecondary,
    VendorGuidedStepStatus.inProgress => colors.warning,
    VendorGuidedStepStatus.completed => colors.success,
    VendorGuidedStepStatus.skipped => colors.error,
  };
}
