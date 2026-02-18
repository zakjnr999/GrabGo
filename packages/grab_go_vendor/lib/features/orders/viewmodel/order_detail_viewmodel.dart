import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';

class OrderDetailViewModel extends ChangeNotifier {
  OrderDetailViewModel({required VendorOrderSummary order})
    : _order = order,
      _currentStatus = order.status,
      _auditEntries = List<VendorOrderAuditEntry>.from(order.auditEntries),
      _issueEntries = List<VendorIssueEntry>.from(order.issueEntries);

  final VendorOrderSummary _order;
  final TextEditingController pickupCodeController = TextEditingController();
  final TextEditingController issueNoteController = TextEditingController();
  final TextEditingController prescriptionDecisionNoteController =
      TextEditingController();
  final TextEditingController substitutionNoteController =
      TextEditingController();

  VendorOrderStatus _currentStatus;
  final List<VendorOrderAuditEntry> _auditEntries;
  final List<VendorIssueEntry> _issueEntries;
  String? _pickupCodeError;
  String? _selectedIssueType;

  VendorOrderSummary get order => _order;
  VendorOrderStatus get currentStatus => _currentStatus;
  List<VendorOrderAuditEntry> get auditEntries => _auditEntries;
  List<VendorIssueEntry> get issueEntries => _issueEntries;
  String? get pickupCodeError => _pickupCodeError;
  String? get selectedIssueType => _selectedIssueType;

  void clearPickupCodeError() {
    if (_pickupCodeError == null) return;
    _pickupCodeError = null;
    notifyListeners();
  }

  void selectIssueType(String type) {
    if (_selectedIssueType == type) return;
    _selectedIssueType = type;
    notifyListeners();
  }

  String? reasonActionUnavailable(VendorOrderActionType action) {
    final allowedActions = _allowedActionsForStatus(_currentStatus);
    if (allowedActions.contains(action)) return null;

    return switch (action) {
      VendorOrderActionType.accept =>
        'Order can only be accepted while status is New.',
      VendorOrderActionType.reject => 'Rejected orders cannot be changed.',
      VendorOrderActionType.markPreparing =>
        'Accept order first before moving to Preparing.',
      VendorOrderActionType.markReady => 'Mark Preparing before marking Ready.',
      VendorOrderActionType.handover => 'Order must be Ready before handover.',
    };
  }

  bool applyAction(VendorOrderActionType action) {
    if (reasonActionUnavailable(action) != null) return false;

    _currentStatus = switch (action) {
      VendorOrderActionType.accept => VendorOrderStatus.accepted,
      VendorOrderActionType.reject => VendorOrderStatus.cancelled,
      VendorOrderActionType.markPreparing => VendorOrderStatus.preparing,
      VendorOrderActionType.markReady => VendorOrderStatus.ready,
      VendorOrderActionType.handover => VendorOrderStatus.handover,
    };

    _auditEntries.insert(
      0,
      VendorOrderAuditEntry(
        action: action.label,
        actor: 'You',
        timeLabel: 'Now',
        details: 'Action performed from vendor app.',
      ),
    );
    notifyListeners();
    return true;
  }

  bool validatePickupCode() {
    _pickupCodeError = null;
    final code = pickupCodeController.text.trim();
    if (code.length != 6) {
      _pickupCodeError = 'Enter the 6-digit pickup code';
      notifyListeners();
      return false;
    }
    return true;
  }

  bool submitIssue() {
    if (_selectedIssueType == null) return false;
    final details = issueNoteController.text.trim().isEmpty
        ? 'Issue reported from order detail.'
        : issueNoteController.text.trim();

    _issueEntries.insert(
      0,
      VendorIssueEntry(
        title: _selectedIssueType!,
        status: 'Open',
        timeLabel: 'Now',
        details: details,
      ),
    );
    _auditEntries.insert(
      0,
      VendorOrderAuditEntry(
        action: 'Issue reported',
        actor: 'You',
        timeLabel: 'Now',
        details: '$details (${_selectedIssueType!})',
      ),
    );
    issueNoteController.clear();
    _selectedIssueType = null;
    notifyListeners();
    return true;
  }

  void addAuditEntry({required String action, required String details}) {
    _auditEntries.insert(
      0,
      VendorOrderAuditEntry(
        action: action,
        actor: 'You',
        timeLabel: 'Now',
        details: details,
      ),
    );
    notifyListeners();
  }

  List<VendorOrderActionType> _allowedActionsForStatus(
    VendorOrderStatus status,
  ) {
    return switch (status) {
      VendorOrderStatus.newOrder => [
        VendorOrderActionType.accept,
        VendorOrderActionType.reject,
      ],
      VendorOrderStatus.accepted => [
        VendorOrderActionType.markPreparing,
        VendorOrderActionType.reject,
      ],
      VendorOrderStatus.preparing => [
        VendorOrderActionType.markReady,
        VendorOrderActionType.reject,
      ],
      VendorOrderStatus.ready => [VendorOrderActionType.handover],
      VendorOrderStatus.handover => const [],
      VendorOrderStatus.cancelled => const [],
    };
  }

  @override
  void dispose() {
    pickupCodeController.dispose();
    issueNoteController.dispose();
    prescriptionDecisionNoteController.dispose();
    substitutionNoteController.dispose();
    super.dispose();
  }
}
