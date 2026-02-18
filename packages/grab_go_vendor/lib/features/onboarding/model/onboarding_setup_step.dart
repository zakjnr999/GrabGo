import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';

enum VendorGuidedStepType {
  businessProfile,
  branchHours,
  serviceActivation,
  payoutSetup,
  catalogStarter,
  staffInvite,
  notificationsSetup,
  demoOrderRun,
  complianceReview,
}

enum VendorGuidedStepStatus { pending, inProgress, completed, skipped }

class VendorGuidedSetupStep {
  final String id;
  final VendorGuidedStepType type;
  final String title;
  final String subtitle;
  final String estimateLabel;
  final List<String> checklist;
  final bool isOptional;
  final VendorGuidedStepStatus status;
  final VendorServiceType? serviceHint;

  const VendorGuidedSetupStep({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.estimateLabel,
    required this.checklist,
    required this.isOptional,
    required this.status,
    this.serviceHint,
  });

  VendorGuidedSetupStep copyWith({VendorGuidedStepStatus? status}) {
    return VendorGuidedSetupStep(
      id: id,
      type: type,
      title: title,
      subtitle: subtitle,
      estimateLabel: estimateLabel,
      checklist: checklist,
      isOptional: isOptional,
      status: status ?? this.status,
      serviceHint: serviceHint,
    );
  }
}

IconData onboardingStepIcon(VendorGuidedStepType stepType) {
  return switch (stepType) {
    VendorGuidedStepType.businessProfile => Icons.storefront_rounded,
    VendorGuidedStepType.branchHours => Icons.schedule_rounded,
    VendorGuidedStepType.serviceActivation => Icons.tune_rounded,
    VendorGuidedStepType.payoutSetup => Icons.account_balance_wallet_outlined,
    VendorGuidedStepType.catalogStarter => Icons.inventory_2_outlined,
    VendorGuidedStepType.staffInvite => Icons.group_add_outlined,
    VendorGuidedStepType.notificationsSetup =>
      Icons.notifications_active_outlined,
    VendorGuidedStepType.demoOrderRun => Icons.play_circle_outline_rounded,
    VendorGuidedStepType.complianceReview => Icons.shield_outlined,
  };
}

String onboardingStepStatusLabel(VendorGuidedStepStatus status) {
  return switch (status) {
    VendorGuidedStepStatus.pending => 'Pending',
    VendorGuidedStepStatus.inProgress => 'In Progress',
    VendorGuidedStepStatus.completed => 'Completed',
    VendorGuidedStepStatus.skipped => 'Skipped',
  };
}

List<VendorGuidedSetupStep> mockVendorGuidedSetupSteps() {
  return const [
    VendorGuidedSetupStep(
      id: 'step_business_profile',
      type: VendorGuidedStepType.businessProfile,
      title: 'Complete Business Profile',
      subtitle: 'Confirm name, contact details, and branch identity.',
      estimateLabel: '3 mins',
      checklist: [
        'Confirm business name and support contact',
        'Add branch location and visible operating address',
        'Upload brand logo for storefront',
      ],
      isOptional: false,
      status: VendorGuidedStepStatus.inProgress,
    ),
    VendorGuidedSetupStep(
      id: 'step_branch_hours',
      type: VendorGuidedStepType.branchHours,
      title: 'Set Operating Hours',
      subtitle: 'Define daily open/close windows and break periods.',
      estimateLabel: '2 mins',
      checklist: [
        'Set weekday and weekend schedules',
        'Configure temporary closure handling',
      ],
      isOptional: false,
      status: VendorGuidedStepStatus.pending,
    ),
    VendorGuidedSetupStep(
      id: 'step_service_activation',
      type: VendorGuidedStepType.serviceActivation,
      title: 'Activate Service Channels',
      subtitle: 'Enable only services your store will fulfill.',
      estimateLabel: '2 mins',
      checklist: [
        'Enable relevant services (food/grocery/pharmacy/grabmart)',
        'Set service-level acceptance rules',
      ],
      isOptional: false,
      status: VendorGuidedStepStatus.pending,
    ),
    VendorGuidedSetupStep(
      id: 'step_payout_setup',
      type: VendorGuidedStepType.payoutSetup,
      title: 'Add Payout Details',
      subtitle: 'Prepare settlement destination for earnings.',
      estimateLabel: '2 mins',
      checklist: [
        'Add preferred payout account',
        'Review settlement and fee summary',
      ],
      isOptional: false,
      status: VendorGuidedStepStatus.pending,
    ),
    VendorGuidedSetupStep(
      id: 'step_catalog_starter',
      type: VendorGuidedStepType.catalogStarter,
      title: 'Create Starter Catalog',
      subtitle: 'Add first categories and key sellable items.',
      estimateLabel: '4 mins',
      checklist: [
        'Create at least one category',
        'Add three sample items with prices',
      ],
      isOptional: true,
      status: VendorGuidedStepStatus.pending,
    ),
    VendorGuidedSetupStep(
      id: 'step_staff_invite',
      type: VendorGuidedStepType.staffInvite,
      title: 'Invite Staff Members',
      subtitle: 'Assign manager or operator roles for operations.',
      estimateLabel: '2 mins',
      checklist: ['Invite one operator account', 'Review role permissions'],
      isOptional: true,
      status: VendorGuidedStepStatus.pending,
    ),
    VendorGuidedSetupStep(
      id: 'step_notifications',
      type: VendorGuidedStepType.notificationsSetup,
      title: 'Tune Notification Rules',
      subtitle: 'Set priority alerts for orders and outage risks.',
      estimateLabel: '2 mins',
      checklist: [
        'Enable high-priority order alerts',
        'Enable SLA and outage reminders',
      ],
      isOptional: true,
      status: VendorGuidedStepStatus.pending,
    ),
    VendorGuidedSetupStep(
      id: 'step_demo_order',
      type: VendorGuidedStepType.demoOrderRun,
      title: 'Run Demo Order Drill',
      subtitle: 'Practice accept → prepare → handover flow.',
      estimateLabel: '3 mins',
      checklist: [
        'Open demo order scenario',
        'Mark order through full lifecycle',
      ],
      isOptional: true,
      status: VendorGuidedStepStatus.pending,
    ),
    VendorGuidedSetupStep(
      id: 'step_compliance',
      type: VendorGuidedStepType.complianceReview,
      title: 'Review Compliance Rules',
      subtitle: 'Confirm policy references for regulated items.',
      estimateLabel: '2 mins',
      checklist: [
        'Read policy summary and escalation paths',
        'Confirm restricted-item handling awareness',
      ],
      isOptional: true,
      status: VendorGuidedStepStatus.pending,
      serviceHint: VendorServiceType.pharmacy,
    ),
  ];
}
