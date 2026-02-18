enum VendorFinanceRange { today, sevenDays, thirtyDays }

enum VendorPayoutStatus { pending, paid, failed }

enum VendorExportStatus { queued, running, completed, failed }

class VendorSettlementSummary {
  final String label;
  final double gross;
  final double fees;
  final double adjustments;
  final double net;

  const VendorSettlementSummary({
    required this.label,
    required this.gross,
    required this.fees,
    required this.adjustments,
    required this.net,
  });
}

class VendorPayoutRecord {
  final String id;
  final String dateLabel;
  final String reference;
  final double amount;
  final VendorPayoutStatus status;

  const VendorPayoutRecord({
    required this.id,
    required this.dateLabel,
    required this.reference,
    required this.amount,
    required this.status,
  });

  VendorPayoutRecord copyWith({VendorPayoutStatus? status}) {
    return VendorPayoutRecord(
      id: id,
      dateLabel: dateLabel,
      reference: reference,
      amount: amount,
      status: status ?? this.status,
    );
  }
}

class VendorStatementRecord {
  final String id;
  final String periodLabel;
  final String generatedLabel;
  final String format;
  final String sizeLabel;

  const VendorStatementRecord({
    required this.id,
    required this.periodLabel,
    required this.generatedLabel,
    required this.format,
    required this.sizeLabel,
  });
}

class VendorExportJob {
  final String id;
  final String title;
  final String createdLabel;
  final VendorExportStatus status;

  const VendorExportJob({
    required this.id,
    required this.title,
    required this.createdLabel,
    required this.status,
  });

  VendorExportJob copyWith({VendorExportStatus? status}) {
    return VendorExportJob(
      id: id,
      title: title,
      createdLabel: createdLabel,
      status: status ?? this.status,
    );
  }
}

extension VendorFinanceRangeX on VendorFinanceRange {
  String get label {
    return switch (this) {
      VendorFinanceRange.today => 'Today',
      VendorFinanceRange.sevenDays => '7 Days',
      VendorFinanceRange.thirtyDays => '30 Days',
    };
  }
}

extension VendorPayoutStatusX on VendorPayoutStatus {
  String get label {
    return switch (this) {
      VendorPayoutStatus.pending => 'Pending',
      VendorPayoutStatus.paid => 'Paid',
      VendorPayoutStatus.failed => 'Failed',
    };
  }
}

extension VendorExportStatusX on VendorExportStatus {
  String get label {
    return switch (this) {
      VendorExportStatus.queued => 'Queued',
      VendorExportStatus.running => 'Running',
      VendorExportStatus.completed => 'Completed',
      VendorExportStatus.failed => 'Failed',
    };
  }
}

Map<VendorFinanceRange, VendorSettlementSummary> mockSettlementSummaries() {
  return const {
    VendorFinanceRange.today: VendorSettlementSummary(
      label: 'Today',
      gross: 3220.50,
      fees: 382.70,
      adjustments: -40.00,
      net: 2797.80,
    ),
    VendorFinanceRange.sevenDays: VendorSettlementSummary(
      label: 'Last 7 Days',
      gross: 21780.00,
      fees: 2526.40,
      adjustments: -112.30,
      net: 19141.30,
    ),
    VendorFinanceRange.thirtyDays: VendorSettlementSummary(
      label: 'Last 30 Days',
      gross: 93420.10,
      fees: 10685.55,
      adjustments: -482.40,
      net: 82252.15,
    ),
  };
}

List<VendorPayoutRecord> mockPayoutHistory() {
  return const [
    VendorPayoutRecord(
      id: 'po_001',
      dateLabel: 'Feb 18, 2026',
      reference: 'PAYOUT-84211',
      amount: 2740.30,
      status: VendorPayoutStatus.pending,
    ),
    VendorPayoutRecord(
      id: 'po_002',
      dateLabel: 'Feb 17, 2026',
      reference: 'PAYOUT-84205',
      amount: 3104.12,
      status: VendorPayoutStatus.paid,
    ),
    VendorPayoutRecord(
      id: 'po_003',
      dateLabel: 'Feb 16, 2026',
      reference: 'PAYOUT-84198',
      amount: 2951.77,
      status: VendorPayoutStatus.failed,
    ),
  ];
}

List<VendorStatementRecord> mockStatements() {
  return const [
    VendorStatementRecord(
      id: 'st_001',
      periodLabel: 'Feb 1 - Feb 7',
      generatedLabel: 'Generated Feb 8',
      format: 'PDF',
      sizeLabel: '420 KB',
    ),
    VendorStatementRecord(
      id: 'st_002',
      periodLabel: 'Jan 25 - Jan 31',
      generatedLabel: 'Generated Feb 1',
      format: 'CSV',
      sizeLabel: '180 KB',
    ),
    VendorStatementRecord(
      id: 'st_003',
      periodLabel: 'Jan 18 - Jan 24',
      generatedLabel: 'Generated Jan 25',
      format: 'PDF',
      sizeLabel: '395 KB',
    ),
  ];
}

List<VendorExportJob> mockExportJobs() {
  return const [
    VendorExportJob(
      id: 'ex_001',
      title: 'Settlement Summary CSV',
      createdLabel: 'Today 12:20 PM',
      status: VendorExportStatus.running,
    ),
    VendorExportJob(
      id: 'ex_002',
      title: 'Payout Reconciliation PDF',
      createdLabel: 'Yesterday 9:10 AM',
      status: VendorExportStatus.completed,
    ),
  ];
}
