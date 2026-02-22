import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_setup_step.dart';
import 'package:grab_go_vendor/features/onboarding/view/widgets/detail_chip.dart';
import 'package:grab_go_vendor/features/onboarding/viewmodel/onboarding_setup_viewmodel.dart';
import 'package:provider/provider.dart';

class OnboardingStepWorkspacePage extends StatefulWidget {
  final String stepId;

  const OnboardingStepWorkspacePage({super.key, required this.stepId});

  @override
  State<OnboardingStepWorkspacePage> createState() =>
      _OnboardingStepWorkspacePageState();
}

class _OnboardingStepWorkspacePageState
    extends State<OnboardingStepWorkspacePage> {
  bool _initialized = false;
  late List<_WorkspaceFieldConfig> _fieldConfigs;
  late List<TextEditingController> _fieldControllers;
  List<bool> _checklistStates = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final viewModel = context.read<OnboardingSetupViewModel>();
    final step = _resolveStep(viewModel);
    _fieldConfigs = _fieldsForStep(step.type);
    _fieldControllers = _fieldConfigs
        .map((_) => TextEditingController())
        .toList();
    _checklistStates = List<bool>.filled(step.checklist.length, false);
    _initialized = true;
  }

  @override
  void dispose() {
    for (final controller in _fieldControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Consumer<OnboardingSetupViewModel>(
      builder: (context, viewModel, _) {
        final step = _resolveStep(viewModel);
        final checklistDone = _checklistStates.where((entry) => entry).length;
        final isCompleted = step.status == VendorGuidedStepStatus.completed;
        final statusColor = _statusColor(colors, step.status);

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 430.w),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(top: 12.h, bottom: 12.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor: colors.textSecondary,
                                ),
                                icon: SvgPicture.asset(
                                  Assets.icons.navArrowLeft,
                                  package: 'grab_go_shared',
                                  width: 18.w,
                                  height: 18.w,
                                  colorFilter: ColorFilter.mode(
                                    colors.textSecondary,
                                    BlendMode.srcIn,
                                  ),
                                ),
                                label: Text(
                                  'Back',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(height: 6.h),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.title,
                                          style: TextStyle(
                                            fontSize: 24.sp,
                                            fontWeight: FontWeight.w900,
                                            color: colors.textPrimary,
                                            height: 1.15,
                                          ),
                                        ),
                                        SizedBox(height: 6.h),
                                        Text(
                                          step.subtitle,
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w500,
                                            color: colors.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                children: [
                                  DetailChip(
                                    label: step.isOptional
                                        ? 'Optional'
                                        : 'Required',
                                    color: step.isOptional
                                        ? colors.serviceGrabMart
                                        : colors.vendorPrimaryBlue,
                                  ),
                                  DetailChip(
                                    label: onboardingStepStatusLabel(
                                      step.status,
                                    ),
                                    color: statusColor,
                                  ),
                                  DetailChip(
                                    label: step.estimateLabel,
                                    color: colors.textSecondary,
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              _WorkspaceSectionCard(
                                title: 'Task Checklist',
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '$checklistDone/${step.checklist.length} items done',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w700,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 6.h),
                                    ...step.checklist.asMap().entries.map((
                                      entry,
                                    ) {
                                      final index = entry.key;
                                      final text = entry.value;
                                      final checked = _checklistStates[index];
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: 6.h),
                                        child: InkWell(
                                          onTap: isCompleted
                                              ? null
                                              : () => _toggleChecklist(
                                                  index,
                                                  !checked,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 6.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colors.backgroundPrimary,
                                              borderRadius:
                                                  BorderRadius.circular(10.r),
                                              border: Border.all(
                                                color: colors.border,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Checkbox(
                                                  value: checked,
                                                  onChanged: isCompleted
                                                      ? null
                                                      : (value) =>
                                                            _toggleChecklist(
                                                              index,
                                                              value ?? false,
                                                            ),
                                                  activeColor:
                                                      colors.vendorPrimaryBlue,
                                                  side: BorderSide(
                                                    color: colors.inputBorder,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding: EdgeInsets.only(
                                                      top: 10.h,
                                                      right: 4.w,
                                                    ),
                                                    child: Text(
                                                      text,
                                                      style: TextStyle(
                                                        fontSize: 12.sp,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color:
                                                            colors.textPrimary,
                                                        decoration: checked
                                                            ? TextDecoration
                                                                  .lineThrough
                                                            : null,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12.h),
                              _WorkspaceSectionCard(
                                title: 'Step Inputs',
                                child: Column(
                                  children: [
                                    ..._fieldConfigs.asMap().entries.map((
                                      entry,
                                    ) {
                                      final index = entry.key;
                                      final config = entry.value;
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom:
                                              index == _fieldConfigs.length - 1
                                              ? 0
                                              : 10.h,
                                        ),
                                        child: AppTextInput(
                                          controller: _fieldControllers[index],
                                          label: config.label,
                                          hintText: config.hint,
                                          keyboardType: config.keyboardType,
                                          fillColor: colors.backgroundSecondary,
                                          borderColor: colors.inputBorder,
                                          borderActiveColor:
                                              colors.vendorPrimaryBlue,
                                          borderRadius: KBorderSize.border,
                                          cursorColor: colors.vendorPrimaryBlue,
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              SizedBox(height: 12.h),
                              _WorkspaceSectionCard(
                                title: 'Execution Notes',
                                child: Text(
                                  'Complete inputs and checklist, then mark this step complete. You can leave this screen at any time and continue later.',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        child: Column(
                          children: [
                            if (step.isOptional && !isCompleted) ...[
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _skipAndClose(viewModel),
                                  child: Text(
                                    'Skip Optional Step',
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 6.h),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    buttonText: 'Save & Exit',
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    backgroundColor: colors.vendorPrimaryBlue
                                        .withValues(alpha: 0.12),
                                    borderRadius: KBorderSize.border,
                                    textStyle: TextStyle(
                                      color: colors.vendorPrimaryBlue,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: IgnorePointer(
                                    ignoring: isCompleted,
                                    child: Opacity(
                                      opacity: isCompleted ? 0.6 : 1,
                                      child: AppButton(
                                        buttonText: isCompleted
                                            ? 'Completed'
                                            : 'Mark Complete',
                                        onPressed: () =>
                                            _completeAndClose(viewModel),
                                        backgroundColor:
                                            colors.vendorPrimaryBlue,
                                        borderRadius: KBorderSize.border,
                                        textStyle: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  VendorGuidedSetupStep _resolveStep(OnboardingSetupViewModel viewModel) {
    for (final step in viewModel.steps) {
      if (step.id == widget.stepId) {
        return step;
      }
    }
    return viewModel.selectedStep;
  }

  void _toggleChecklist(int index, bool value) {
    setState(() {
      _checklistStates[index] = value;
    });
  }

  void _completeAndClose(OnboardingSetupViewModel viewModel) {
    viewModel.selectStep(widget.stepId);
    viewModel.markSelectedComplete();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _skipAndClose(OnboardingSetupViewModel viewModel) {
    viewModel.selectStep(widget.stepId);
    viewModel.skipSelectedStep();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _WorkspaceSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _WorkspaceSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }
}

class _WorkspaceFieldConfig {
  final String label;
  final String hint;
  final TextInputType keyboardType;

  const _WorkspaceFieldConfig({
    required this.label,
    required this.hint,
    required this.keyboardType,
  });
}

List<_WorkspaceFieldConfig> _fieldsForStep(VendorGuidedStepType type) {
  return switch (type) {
    VendorGuidedStepType.businessProfile => const [
      _WorkspaceFieldConfig(
        label: 'Business Display Name',
        hint: 'Enter display name',
        keyboardType: TextInputType.text,
      ),
      _WorkspaceFieldConfig(
        label: 'Support Contact',
        hint: 'Enter support phone or email',
        keyboardType: TextInputType.emailAddress,
      ),
      _WorkspaceFieldConfig(
        label: 'Branch Address',
        hint: 'Enter branch location',
        keyboardType: TextInputType.streetAddress,
      ),
    ],
    VendorGuidedStepType.branchHours => const [
      _WorkspaceFieldConfig(
        label: 'Weekday Opening Time',
        hint: 'e.g. 08:00 AM',
        keyboardType: TextInputType.datetime,
      ),
      _WorkspaceFieldConfig(
        label: 'Weekday Closing Time',
        hint: 'e.g. 10:00 PM',
        keyboardType: TextInputType.datetime,
      ),
      _WorkspaceFieldConfig(
        label: 'Weekend Schedule',
        hint: 'e.g. 09:00 AM - 11:00 PM',
        keyboardType: TextInputType.text,
      ),
    ],
    VendorGuidedStepType.serviceActivation => const [
      _WorkspaceFieldConfig(
        label: 'Active Services',
        hint: 'e.g. Food, Grocery',
        keyboardType: TextInputType.text,
      ),
      _WorkspaceFieldConfig(
        label: 'Auto-Accept Rule',
        hint: 'Define acceptance policy',
        keyboardType: TextInputType.text,
      ),
      _WorkspaceFieldConfig(
        label: 'Target Prep SLA (mins)',
        hint: 'e.g. 20',
        keyboardType: TextInputType.number,
      ),
    ],
    VendorGuidedStepType.payoutSetup => const [
      _WorkspaceFieldConfig(
        label: 'Account Holder Name',
        hint: 'Enter payout account name',
        keyboardType: TextInputType.name,
      ),
      _WorkspaceFieldConfig(
        label: 'Bank Name',
        hint: 'Enter bank name',
        keyboardType: TextInputType.text,
      ),
      _WorkspaceFieldConfig(
        label: 'Account Number',
        hint: 'Enter account number',
        keyboardType: TextInputType.number,
      ),
    ],
    VendorGuidedStepType.catalogStarter => const [
      _WorkspaceFieldConfig(
        label: 'First Category',
        hint: 'e.g. Best Sellers',
        keyboardType: TextInputType.text,
      ),
      _WorkspaceFieldConfig(
        label: 'Sample Item Name',
        hint: 'Enter starter item',
        keyboardType: TextInputType.text,
      ),
      _WorkspaceFieldConfig(
        label: 'Sample Item Price',
        hint: 'Enter amount',
        keyboardType: TextInputType.number,
      ),
    ],
    VendorGuidedStepType.staffInvite => const [
      _WorkspaceFieldConfig(
        label: 'Staff Email',
        hint: 'operator@business.com',
        keyboardType: TextInputType.emailAddress,
      ),
      _WorkspaceFieldConfig(
        label: 'Assigned Role',
        hint: 'e.g. Shift Supervisor',
        keyboardType: TextInputType.text,
      ),
      _WorkspaceFieldConfig(
        label: 'Shift Window',
        hint: 'e.g. Morning Shift',
        keyboardType: TextInputType.text,
      ),
    ],
    VendorGuidedStepType.notificationsSetup => const [
      _WorkspaceFieldConfig(
        label: 'Alert Destination',
        hint: 'Enter email or phone',
        keyboardType: TextInputType.emailAddress,
      ),
      _WorkspaceFieldConfig(
        label: 'SLA Warning Threshold',
        hint: 'e.g. 15 minutes',
        keyboardType: TextInputType.number,
      ),
      _WorkspaceFieldConfig(
        label: 'Escalation Contact',
        hint: 'Enter fallback contact',
        keyboardType: TextInputType.phone,
      ),
    ],
    VendorGuidedStepType.demoOrderRun => const [
      _WorkspaceFieldConfig(
        label: 'Demo Scenario Name',
        hint: 'Enter scenario label',
        keyboardType: TextInputType.text,
      ),
      _WorkspaceFieldConfig(
        label: 'Handover Notes',
        hint: 'Enter rider handover notes',
        keyboardType: TextInputType.text,
      ),
      _WorkspaceFieldConfig(
        label: 'Expected Runtime',
        hint: 'e.g. 12 mins',
        keyboardType: TextInputType.text,
      ),
    ],
    VendorGuidedStepType.complianceReview => const [
      _WorkspaceFieldConfig(
        label: 'Compliance Owner',
        hint: 'Enter responsible person',
        keyboardType: TextInputType.name,
      ),
      _WorkspaceFieldConfig(
        label: 'License Reference',
        hint: 'Enter policy/license reference',
        keyboardType: TextInputType.text,
      ),
      _WorkspaceFieldConfig(
        label: 'Next Review Date',
        hint: 'Select next review date',
        keyboardType: TextInputType.datetime,
      ),
    ],
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
