import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/help/model/vendor_help_models.dart';
import 'package:grab_go_vendor/features/help/viewmodel/help_center_viewmodel.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_setup_step.dart';
import 'package:grab_go_vendor/features/onboarding/view/onboarding_main.dart';
import 'package:grab_go_vendor/features/onboarding/view/onboarding_setup_shell.dart';
import 'package:grab_go_vendor/features/onboarding/viewmodel/onboarding_setup_viewmodel.dart';
import 'package:provider/provider.dart';

class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HelpCenterViewModel(),
      child: const _HelpCenterView(),
    );
  }
}

class _HelpCenterView extends StatelessWidget {
  const _HelpCenterView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Consumer2<HelpCenterViewModel, OnboardingSetupViewModel>(
      builder: (context, viewModel, onboardingSetup, _) {
        final articles = viewModel.filteredArticles;
        final modules = viewModel.trainingModules.map((module) {
          final completed = switch (module.id) {
            'train_001' => onboardingSetup.hasGuidedSetupOpened,
            'train_002' => onboardingSetup.isStepCompletedByType(
              VendorGuidedStepType.demoOrderRun,
            ),
            'train_003' => onboardingSetup.isStepCompletedByType(
              VendorGuidedStepType.complianceReview,
            ),
            _ => module.completed,
          };
          return module.copyWith(completed: completed);
        }).toList();

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            title: Text(
              'Help Center',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Support, escalations, policy references, and onboarding replay tools.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Quick Actions',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _replayOnboarding(context),
                                icon: Icon(Icons.replay_rounded, size: 16.sp),
                                label: const Text('Replay Onboarding'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.vendorPrimaryBlue,
                                  side: BorderSide(
                                    color: colors.vendorPrimaryBlue.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showInfo(
                                  context,
                                  'Demo order training launched (UI preview).',
                                ),
                                icon: Icon(
                                  Icons.play_circle_outline_rounded,
                                  size: 16.sp,
                                ),
                                label: const Text('Run Demo Order'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.serviceGrocery,
                                  side: BorderSide(
                                    color: colors.serviceGrocery.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showInfo(
                                  context,
                                  'Support chat shortcut opened (UI preview).',
                                ),
                                icon: Icon(
                                  Icons.support_agent_rounded,
                                  size: 16.sp,
                                ),
                                label: const Text('Contact Support'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.servicePharmacy,
                                  side: BorderSide(
                                    color: colors.servicePharmacy.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Support Preferences',
                    child: Column(
                      children: [
                        _SwitchRow(
                          title: 'Prefer In-App Chat',
                          subtitle: 'Receive support replies directly in app',
                          value: viewModel.preferInAppChat,
                          onChanged: viewModel.setPreferInAppChat,
                        ),
                        _SwitchRow(
                          title: 'Prefer Phone Callback',
                          subtitle: 'Support can call for critical issues',
                          value: viewModel.preferPhoneCall,
                          onChanged: viewModel.setPreferPhoneCall,
                        ),
                        _SwitchRow(
                          title: 'Prefer Email Updates',
                          subtitle: 'Get escalation progress via email',
                          value: viewModel.preferEmail,
                          onChanged: viewModel.setPreferEmail,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: viewModel.searchController,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search help topics and FAQs',
                      hintStyle: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18.sp,
                        color: colors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colors.vendorPrimaryBlue),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      filled: true,
                      fillColor: colors.backgroundPrimary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: viewModel.articleTypeFilter == null,
                          color: colors.vendorPrimaryBlue,
                          onTap: () => viewModel.setArticleTypeFilter(null),
                        ),
                        ...VendorHelpArticleType.values.map((type) {
                          return _FilterChip(
                            label: type.label,
                            selected: viewModel.articleTypeFilter == type,
                            color: _articleTypeColor(colors, type),
                            onTap: () => viewModel.setArticleTypeFilter(type),
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Help Articles',
                    child: articles.isEmpty
                        ? Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: Text(
                              'No help articles match current search/filter.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          )
                        : Column(
                            children: articles.map((article) {
                              return _HelpArticleCard(article: article);
                            }).toList(),
                          ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Escalation Center',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              '${viewModel.unresolvedEscalationCount} unresolved',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () => _showEscalationSheet(context),
                              icon: Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16.sp,
                              ),
                              label: Text(
                                'New Escalation',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.vendorPrimaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        ...viewModel.tickets.map((ticket) {
                          return _EscalationCard(
                            ticket: ticket,
                            onAdvance:
                                ticket.status == VendorEscalationStatus.resolved
                                ? null
                                : () => viewModel.advanceEscalationStatus(
                                    ticket.id,
                                  ),
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Policy Documents',
                    child: Column(
                      children: viewModel.policyDocuments.map((policy) {
                        return _PolicyCard(
                          policy: policy,
                          onOpen: () => _showInfo(
                            context,
                            'Opening "${policy.title}" (UI preview).',
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Training Modules',
                    child: Column(
                      children: modules.map((module) {
                        return _TrainingCard(
                          module: module,
                          onReplay: () {
                            if (module.id == 'train_001') {
                              _replayOnboarding(context);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const OnboardingSetupShell(
                                    isReplayMode: true,
                                  ),
                                ),
                              );
                            }
                          },
                          onToggle: () =>
                              onboardingSetup.toggleTrainingModule(module.id),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _replayOnboarding(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingMain.replay()),
    );
  }

  Future<void> _showEscalationSheet(BuildContext context) async {
    final colors = context.appColors;
    final viewModel = context.read<HelpCenterViewModel>();
    final titleController = TextEditingController();
    final categoryController = TextEditingController();
    var selectedPriority = VendorEscalationPriority.medium;
    String? titleError;
    String? categoryError;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colors.backgroundPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  12.h,
                  16.w,
                  20.h + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New Escalation',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: titleController,
                      onChanged: (_) => setSheetState(() => titleError = null),
                      decoration: InputDecoration(
                        labelText: 'Issue title',
                        hintText: 'Short summary of issue',
                        errorText: titleError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    TextField(
                      controller: categoryController,
                      onChanged: (_) =>
                          setSheetState(() => categoryError = null),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        hintText: 'Example: Orders / Compliance',
                        errorText: categoryError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    DropdownButtonFormField<VendorEscalationPriority>(
                      key: ValueKey<VendorEscalationPriority>(selectedPriority),
                      initialValue: selectedPriority,
                      decoration: InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      items: VendorEscalationPriority.values.map((priority) {
                        return DropdownMenuItem<VendorEscalationPriority>(
                          value: priority,
                          child: Text(priority.label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => selectedPriority = value);
                      },
                    ),
                    SizedBox(height: 14.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        buttonText: 'Submit Escalation',
                        onPressed: () {
                          final title = titleController.text.trim();
                          final category = categoryController.text.trim();
                          var hasError = false;

                          if (title.isEmpty) {
                            titleError = 'Title is required';
                            hasError = true;
                          }
                          if (category.isEmpty) {
                            categoryError = 'Category is required';
                            hasError = true;
                          }

                          if (hasError) {
                            setSheetState(() {});
                            return;
                          }

                          viewModel.addEscalation(
                            title: title,
                            category: category,
                            priority: selectedPriority,
                          );
                          Navigator.pop(sheetContext);
                        },
                        backgroundColor: colors.vendorPrimaryBlue,
                        borderRadius: KBorderSize.borderRadius12,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      titleController.dispose();
      categoryController.dispose();
    }
  }

  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          CustomSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: colors.vendorPrimaryBlue,
            inactiveColor: colors.inputBorder,
            thumbColor: colors.backgroundPrimary,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(color: selected ? color : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _HelpArticleCard extends StatelessWidget {
  final VendorHelpArticle article;

  const _HelpArticleCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typeColor = _articleTypeColor(colors, article.type);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
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
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  article.type.label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening "${article.title}" (UI preview).'),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            article.title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            article.excerpt,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EscalationCard extends StatelessWidget {
  final VendorEscalationTicket ticket;
  final VoidCallback? onAdvance;

  const _EscalationCard({required this.ticket, required this.onAdvance});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final priorityColor = _priorityColor(colors, ticket.priority);
    final statusColor = _statusColor(colors, ticket.status);

    final nextAction = switch (ticket.status) {
      VendorEscalationStatus.open => 'Move to In Progress',
      VendorEscalationStatus.inProgress => 'Resolve',
      VendorEscalationStatus.resolved => 'Resolved',
    };

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
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
            ticket.title,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            ticket.category,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              _Tag(label: ticket.priority.label, color: priorityColor),
              SizedBox(width: 8.w),
              _Tag(label: ticket.status.label, color: statusColor),
              const Spacer(),
              Text(
                ticket.lastUpdateLabel,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(
              onPressed: onAdvance,
              style: OutlinedButton.styleFrom(
                foregroundColor: onAdvance == null
                    ? colors.textSecondary
                    : colors.vendorPrimaryBlue,
                side: BorderSide(
                  color: onAdvance == null
                      ? colors.inputBorder
                      : colors.vendorPrimaryBlue.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
              child: Text(
                nextAction,
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final VendorPolicyDocument policy;
  final VoidCallback onOpen;

  const _PolicyCard({required this.policy, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  policy.title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  policy.summary,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  policy.updatedLabel,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpen,
            icon: Icon(
              Icons.open_in_new_rounded,
              color: colors.vendorPrimaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  final VendorTrainingModule module;
  final VoidCallback onReplay;
  final VoidCallback onToggle;

  const _TrainingCard({
    required this.module,
    required this.onReplay,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Checkbox(
            value: module.completed,
            onChanged: (_) => onToggle(),
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colors.vendorPrimaryBlue;
              }
              return null;
            }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module.title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${module.durationLabel} • ${module.description}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onReplay,
            child: Text(
              module.completed ? 'Replay' : 'Start',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: colors.vendorPrimaryBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
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

Color _articleTypeColor(AppColorsExtension colors, VendorHelpArticleType type) {
  return switch (type) {
    VendorHelpArticleType.onboarding => colors.vendorPrimaryBlue,
    VendorHelpArticleType.operations => colors.serviceFood,
    VendorHelpArticleType.orders => colors.warning,
    VendorHelpArticleType.catalog => colors.serviceGrocery,
    VendorHelpArticleType.policy => colors.servicePharmacy,
    VendorHelpArticleType.payments => colors.serviceGrabMart,
  };
}

Color _priorityColor(
  AppColorsExtension colors,
  VendorEscalationPriority value,
) {
  return switch (value) {
    VendorEscalationPriority.low => colors.serviceGrocery,
    VendorEscalationPriority.medium => colors.warning,
    VendorEscalationPriority.high => colors.error,
    VendorEscalationPriority.critical => colors.error,
  };
}

Color _statusColor(AppColorsExtension colors, VendorEscalationStatus value) {
  return switch (value) {
    VendorEscalationStatus.open => colors.warning,
    VendorEscalationStatus.inProgress => colors.vendorPrimaryBlue,
    VendorEscalationStatus.resolved => colors.success,
  };
}
