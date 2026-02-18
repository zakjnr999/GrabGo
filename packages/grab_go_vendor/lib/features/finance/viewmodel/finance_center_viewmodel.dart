import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/finance/model/vendor_finance_models.dart';

class FinanceCenterViewModel extends ChangeNotifier {
  final Map<VendorFinanceRange, VendorSettlementSummary> summaries =
      mockSettlementSummaries();
  final List<VendorPayoutRecord> _payoutHistory = mockPayoutHistory();
  final List<VendorStatementRecord> statements = mockStatements();
  final List<VendorExportJob> _exportJobs = mockExportJobs();

  VendorFinanceRange _selectedRange = VendorFinanceRange.today;
  bool _autoPayoutEnabled = true;
  bool _emailAdviceEnabled = true;

  VendorFinanceRange get selectedRange => _selectedRange;
  VendorSettlementSummary get summary => summaries[_selectedRange]!;
  bool get autoPayoutEnabled => _autoPayoutEnabled;
  bool get emailAdviceEnabled => _emailAdviceEnabled;
  List<VendorPayoutRecord> get payoutHistory =>
      List.unmodifiable(_payoutHistory);
  List<VendorExportJob> get exportJobs => List.unmodifiable(_exportJobs);

  int get pendingPayoutCount => _payoutHistory
      .where((record) => record.status == VendorPayoutStatus.pending)
      .length;

  void setRange(VendorFinanceRange range) {
    if (_selectedRange == range) {
      return;
    }
    _selectedRange = range;
    notifyListeners();
  }

  void setAutoPayoutEnabled(bool enabled) {
    if (_autoPayoutEnabled == enabled) {
      return;
    }
    _autoPayoutEnabled = enabled;
    notifyListeners();
  }

  void setEmailAdviceEnabled(bool enabled) {
    if (_emailAdviceEnabled == enabled) {
      return;
    }
    _emailAdviceEnabled = enabled;
    notifyListeners();
  }

  void retryPayout(String payoutId) {
    final index = _payoutHistory.indexWhere((record) => record.id == payoutId);
    if (index < 0) {
      return;
    }
    _payoutHistory[index] = _payoutHistory[index].copyWith(
      status: VendorPayoutStatus.pending,
    );
    notifyListeners();
  }

  void markPendingAsPaid(String payoutId) {
    final index = _payoutHistory.indexWhere((record) => record.id == payoutId);
    if (index < 0) {
      return;
    }
    final current = _payoutHistory[index];
    if (current.status != VendorPayoutStatus.pending) {
      return;
    }
    _payoutHistory[index] = current.copyWith(status: VendorPayoutStatus.paid);
    notifyListeners();
  }

  void createExportJob(String title) {
    _exportJobs.insert(
      0,
      VendorExportJob(
        id: 'ex_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        createdLabel: 'Now',
        status: VendorExportStatus.queued,
      ),
    );
    notifyListeners();
  }

  void advanceExportStatus(String exportId) {
    final index = _exportJobs.indexWhere((job) => job.id == exportId);
    if (index < 0) {
      return;
    }
    final current = _exportJobs[index];
    final nextStatus = switch (current.status) {
      VendorExportStatus.queued => VendorExportStatus.running,
      VendorExportStatus.running => VendorExportStatus.completed,
      VendorExportStatus.completed => VendorExportStatus.completed,
      VendorExportStatus.failed => VendorExportStatus.queued,
    };
    _exportJobs[index] = current.copyWith(status: nextStatus);
    notifyListeners();
  }
}
