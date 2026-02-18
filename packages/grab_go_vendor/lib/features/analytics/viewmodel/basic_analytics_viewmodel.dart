import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/analytics/model/vendor_analytics_models.dart';

class BasicAnalyticsViewModel extends ChangeNotifier {
  final Map<VendorAnalyticsRange, VendorAnalyticsSnapshot> _snapshots =
      mockAnalyticsByRange();

  VendorAnalyticsRange _selectedRange = VendorAnalyticsRange.today;

  VendorAnalyticsRange get selectedRange => _selectedRange;
  VendorAnalyticsSnapshot get currentSnapshot => _snapshots[_selectedRange]!;

  void setRange(VendorAnalyticsRange range) {
    if (_selectedRange == range) return;
    _selectedRange = range;
    notifyListeners();
  }

  String rangeLabel(VendorAnalyticsRange range) {
    return switch (range) {
      VendorAnalyticsRange.today => 'Today',
      VendorAnalyticsRange.sevenDays => '7 Days',
      VendorAnalyticsRange.thirtyDays => '30 Days',
    };
  }

  String revenueLabel(double value) => 'GHS ${value.toStringAsFixed(2)}';
}
