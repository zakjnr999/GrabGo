import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/finance/model/vendor_finance_models.dart';
import 'package:grab_go_vendor/features/finance/viewmodel/finance_center_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_store_context_chip.dart';
import 'package:provider/provider.dart';

class FinanceCenterPage extends StatelessWidget {
  const FinanceCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FinanceCenterViewModel(),
      child: const _FinanceCenterView(),
    );
  }
}

class _FinanceCenterView extends StatelessWidget {
  const _FinanceCenterView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<FinanceCenterViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            title: Text(
              'Settlements & Finance',
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
                    'Track settlements, payout status, statements, and export jobs.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: VendorStoreContextChip(compact: false),
                  ),
                  SizedBox(height: 12.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: VendorFinanceRange.values.map((range) {
                        return _RangeChip(
                          label: range.label,
                          selected: viewModel.selectedRange == range,
                          onTap: () => viewModel.setRange(range),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SettlementCard(summary: viewModel.summary),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Payout Controls',
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: viewModel.autoPayoutEnabled,
                          activeThumbColor: colors.vendorPrimaryBlue,
                          title: Text(
                            'Auto Payout',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Automatically release eligible settlements',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                          onChanged: viewModel.setAutoPayoutEnabled,
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: viewModel.emailAdviceEnabled,
                          activeThumbColor: colors.serviceGrocery,
                          title: Text(
                            'Email Advice',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Send payout settlement advice by email',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                          onChanged: viewModel.setEmailAdviceEnabled,
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Text(
                              '${viewModel.pendingPayoutCount} pending payouts',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Payout History',
                    child: Column(
                      children: viewModel.payoutHistory.map((record) {
                        return _PayoutCard(
                          record: record,
                          onAction: () {
                            if (record.status == VendorPayoutStatus.failed) {
                              viewModel.retryPayout(record.id);
                              _showInfo(
                                context,
                                'Retry queued for ${record.reference}.',
                              );
                              return;
                            }
                            if (record.status == VendorPayoutStatus.pending) {
                              viewModel.markPendingAsPaid(record.id);
                              _showInfo(
                                context,
                                'Marked ${record.reference} as paid (UI preview).',
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Statements',
                    child: Column(
                      children: viewModel.statements.map((statement) {
                        return _StatementCard(
                          statement: statement,
                          onDownload: () => _showInfo(
                            context,
                            'Downloading ${statement.periodLabel} statement (UI preview).',
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Export Center',
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              viewModel.createExportJob(
                                'Custom Finance Export',
                              );
                              _showInfo(
                                context,
                                'New export queued in UI preview.',
                              );
                            },
                            icon: Icon(
                              Icons.add_circle_outline_rounded,
                              size: 16.sp,
                            ),
                            label: Text(
                              'New Export',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.vendorPrimaryBlue,
                              ),
                            ),
                          ),
                        ),
                        ...viewModel.exportJobs.map((job) {
                          return _ExportCard(
                            job: job,
                            onAdvance: () {
                              viewModel.advanceExportStatus(job.id);
                            },
                          );
                        }),
                      ],
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

  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Color _payoutColor(AppColorsExtension colors, VendorPayoutStatus status) {
  return switch (status) {
    VendorPayoutStatus.pending => colors.warning,
    VendorPayoutStatus.paid => colors.success,
    VendorPayoutStatus.failed => colors.error,
  };
}

Color _exportColor(AppColorsExtension colors, VendorExportStatus status) {
  return switch (status) {
    VendorExportStatus.queued => colors.warning,
    VendorExportStatus.running => colors.vendorPrimaryBlue,
    VendorExportStatus.completed => colors.success,
    VendorExportStatus.failed => colors.error,
  };
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
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
          color: selected
              ? colors.vendorPrimaryBlue
              : colors.vendorPrimaryBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(
            color: selected ? colors.vendorPrimaryBlue : colors.border,
          ),
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

class _SettlementCard extends StatelessWidget {
  final VendorSettlementSummary summary;

  const _SettlementCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.vendorPrimaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: colors.vendorPrimaryBlue.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: colors.vendorPrimaryBlue,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Net: GHS ${summary.net.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Gross: GHS ${summary.gross.toStringAsFixed(2)} • Fees: GHS ${summary.fees.toStringAsFixed(2)} • Adjustments: GHS ${summary.adjustments.toStringAsFixed(2)}',
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
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
              fontSize: 13.sp,
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

class _PayoutCard extends StatelessWidget {
  final VendorPayoutRecord record;
  final VoidCallback onAction;

  const _PayoutCard({required this.record, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = _payoutColor(colors, record.status);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(10.r),
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
                  record.reference,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  record.status.label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            '${record.dateLabel} • GHS ${record.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: record.status == VendorPayoutStatus.paid
                  ? null
                  : onAction,
              icon: Icon(
                record.status == VendorPayoutStatus.failed
                    ? Icons.refresh_rounded
                    : Icons.done_all_rounded,
                size: 16.sp,
              ),
              label: Text(
                record.status == VendorPayoutStatus.failed
                    ? 'Retry'
                    : record.status == VendorPayoutStatus.pending
                    ? 'Mark Paid'
                    : 'Completed',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  final VendorStatementRecord statement;
  final VoidCallback onDownload;

  const _StatementCard({required this.statement, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(10.r),
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
                  statement.periodLabel,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${statement.generatedLabel} • ${statement.format} • ${statement.sizeLabel}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onDownload,
            icon: Icon(Icons.download_rounded, size: 16.sp),
            label: Text(
              'Download',
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

class _ExportCard extends StatelessWidget {
  final VendorExportJob job;
  final VoidCallback onAdvance;

  const _ExportCard({required this.job, required this.onAdvance});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = _exportColor(colors, job.status);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(10.r),
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
                  job.title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  job.createdLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999.r),
            ),
            child: Text(
              job.status.label,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            onPressed: job.status == VendorExportStatus.completed
                ? null
                : onAdvance,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.skip_next_rounded),
          ),
        ],
      ),
    );
  }
}
