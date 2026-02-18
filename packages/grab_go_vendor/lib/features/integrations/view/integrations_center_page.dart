import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/integrations/model/vendor_integrations_models.dart';
import 'package:grab_go_vendor/features/integrations/viewmodel/integrations_center_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_store_context_chip.dart';
import 'package:provider/provider.dart';

class IntegrationsCenterPage extends StatelessWidget {
  const IntegrationsCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => IntegrationsCenterViewModel(),
      child: const _IntegrationsCenterView(),
    );
  }
}

class _IntegrationsCenterView extends StatelessWidget {
  const _IntegrationsCenterView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<IntegrationsCenterViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            title: Text(
              'Integrations',
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
                    'Configure printer setup, KDS routing, and run test prints.',
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
                  _SectionCard(
                    title: 'Print Routing',
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: viewModel.autoPrintKitchen,
                          activeThumbColor: colors.vendorPrimaryBlue,
                          title: Text(
                            'Auto Print Kitchen Tickets',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Print ticket when order reaches preparation status',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                          onChanged: viewModel.setAutoPrintKitchen,
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: viewModel.autoPrintCustomerCopy,
                          activeThumbColor: colors.serviceGrocery,
                          title: Text(
                            'Auto Print Customer Copy',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            'Generate customer receipt after completion',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                          onChanged: viewModel.setAutoPrintCustomerCopy,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Printer Setup',
                    child: Column(
                      children: viewModel.printers.map((printer) {
                        return _PrinterCard(
                          printer: printer,
                          onConnectToggle: () =>
                              viewModel.cyclePrinterStatus(printer.id),
                          onTestPrint: () {
                            viewModel.runPrinterTest(printer.id);
                            _showInfo(
                              context,
                              'Test print requested for ${printer.name}.',
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'KDS Setup',
                    child: Column(
                      children: viewModel.kdsStations.map((station) {
                        return _KdsCard(
                          station: station,
                          onStatusCycle: () =>
                              viewModel.cycleKdsStatus(station.id),
                          onAutoBumpChanged: (seconds) =>
                              viewModel.setKdsAutoBump(station.id, seconds),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Test Print Logs',
                    child: Column(
                      children: viewModel.printLogs.map((log) {
                        return _PrintLogRow(log: log);
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

  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Color _integrationColor(
  AppColorsExtension colors,
  VendorIntegrationStatus status,
) {
  return switch (status) {
    VendorIntegrationStatus.disconnected => colors.textSecondary,
    VendorIntegrationStatus.connecting => colors.warning,
    VendorIntegrationStatus.connected => colors.success,
    VendorIntegrationStatus.error => colors.error,
  };
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

class _PrinterCard extends StatelessWidget {
  final VendorPrinterDevice printer;
  final VoidCallback onConnectToggle;
  final VoidCallback onTestPrint;

  const _PrinterCard({
    required this.printer,
    required this.onConnectToggle,
    required this.onTestPrint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = _integrationColor(colors, printer.status);

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
                  printer.name,
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
                  printer.status.label,
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
            '${printer.locationLabel} • ${printer.paperLabel}',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Last test: ${printer.lastTestLabel}',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              TextButton.icon(
                onPressed: onConnectToggle,
                icon: const Icon(Icons.sync_rounded),
                label: Text(
                  'Cycle Status',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onTestPrint,
                icon: const Icon(Icons.print_outlined),
                label: Text(
                  'Test Print',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.vendorPrimaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KdsCard extends StatelessWidget {
  final VendorKdsStation station;
  final VoidCallback onStatusCycle;
  final ValueChanged<int> onAutoBumpChanged;

  const _KdsCard({
    required this.station,
    required this.onStatusCycle,
    required this.onAutoBumpChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = _integrationColor(colors, station.status);

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
                  station.name,
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
                  station.status.label,
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
            station.screenLabel,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Auto bump after ${station.autoBumpSeconds}s',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          Slider(
            value: station.autoBumpSeconds.toDouble(),
            min: 30,
            max: 300,
            divisions: 9,
            activeColor: colors.vendorPrimaryBlue,
            label: '${station.autoBumpSeconds}s',
            onChanged: (value) => onAutoBumpChanged(value.round()),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onStatusCycle,
              icon: const Icon(Icons.sync_rounded),
              label: Text(
                'Cycle Status',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrintLogRow extends StatelessWidget {
  final VendorPrintLog log;

  const _PrintLogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = log.success ? colors.success : colors.error;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(
            log.success ? Icons.check_circle_outline : Icons.error_outline,
            color: color,
            size: 18.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  log.timestampLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            log.success ? 'Success' : 'Failed',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
