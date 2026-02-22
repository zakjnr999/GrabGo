import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_setup_step.dart';
import 'package:grab_go_vendor/features/onboarding/view/onboarding_step_workspace_page.dart';
import 'package:grab_go_vendor/features/onboarding/view/widgets/detail_chip.dart';
import 'package:grab_go_vendor/features/onboarding/view/widgets/step_detail_card.dart';
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
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Launch Checklist",
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Complete required setup items and optionally configure advanced operations.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                      height: 1.4,
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
                      onTap: () =>
                          _openStepWorkspace(context, viewModel, step.id),
                    );
                  }),
                  SizedBox(height: 14.h),
                  StepDetailCard(
                    step: selectedStep,
                    onStart: () => _openStepWorkspace(
                      context,
                      viewModel,
                      selectedStep.id,
                      intent: _StepWorkspaceIntent.start,
                    ),
                    onComplete: viewModel.markSelectedComplete,
                    onSkip: viewModel.skipSelectedStep,
                    onResume: () => _openStepWorkspace(
                      context,
                      viewModel,
                      selectedStep.id,
                      intent: _StepWorkspaceIntent.resume,
                    ),
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
                        : '${viewModel.requiredRemaining} required step(s) remaining.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: viewModel.allRequiredCompleted
                          ? colors.success
                          : colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText: widget.isReplayMode ? 'Done' : 'Continue',
                      onPressed: () => _finishSetup(context),
                      backgroundColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.border,
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
                            decoration: TextDecoration.underline,
                            color: colors.textSecondary,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
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
    context.go('/vendorPreview');
  }

  Future<void> _openStepWorkspace(
    BuildContext context,
    OnboardingSetupViewModel viewModel,
    String stepId, {
    _StepWorkspaceIntent intent = _StepWorkspaceIntent.view,
  }) async {
    viewModel.selectStep(stepId);
    switch (intent) {
      case _StepWorkspaceIntent.start:
        viewModel.startSelectedStep();
        break;
      case _StepWorkspaceIntent.resume:
        viewModel.resumeSelectedStep();
        break;
      case _StepWorkspaceIntent.view:
        break;
    }

    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: viewModel,
          child: OnboardingStepWorkspacePage(stepId: stepId),
        ),
      ),
    );
  }
}

enum _StepWorkspaceIntent { view, start, resume }

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
          border: Border.all(
            color: selected ? colors.vendorPrimaryBlue : colors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      DetailChip(
                        label: step.isOptional ? 'Optional' : 'Required',
                        color: step.isOptional
                            ? colors.serviceGrabMart
                            : colors.vendorPrimaryBlue,
                      ),
                      DetailChip(
                        label: onboardingStepStatusLabel(step.status),
                        color: statusColor,
                      ),
                      DetailChip(
                        label: step.estimateLabel,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: 'grab_go_shared',
              height: 18,
              width: 18,
              colorFilter: ColorFilter.mode(
                colors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
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
