import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/integrations/model/vendor_integrations_models.dart';

class IntegrationsCenterViewModel extends ChangeNotifier {
  final List<VendorPrinterDevice> _printers = mockPrinters();
  final List<VendorKdsStation> _kdsStations = mockKdsStations();
  final List<VendorPrintLog> _printLogs = mockPrintLogs();

  bool _autoPrintKitchen = true;
  bool _autoPrintCustomerCopy = false;

  bool get autoPrintKitchen => _autoPrintKitchen;
  bool get autoPrintCustomerCopy => _autoPrintCustomerCopy;
  List<VendorPrinterDevice> get printers => List.unmodifiable(_printers);
  List<VendorKdsStation> get kdsStations => List.unmodifiable(_kdsStations);
  List<VendorPrintLog> get printLogs => List.unmodifiable(_printLogs);

  void setAutoPrintKitchen(bool enabled) {
    if (_autoPrintKitchen == enabled) {
      return;
    }
    _autoPrintKitchen = enabled;
    notifyListeners();
  }

  void setAutoPrintCustomerCopy(bool enabled) {
    if (_autoPrintCustomerCopy == enabled) {
      return;
    }
    _autoPrintCustomerCopy = enabled;
    notifyListeners();
  }

  void cyclePrinterStatus(String printerId) {
    final index = _printers.indexWhere((printer) => printer.id == printerId);
    if (index < 0) {
      return;
    }
    final current = _printers[index];
    final nextStatus = switch (current.status) {
      VendorIntegrationStatus.disconnected =>
        VendorIntegrationStatus.connecting,
      VendorIntegrationStatus.connecting => VendorIntegrationStatus.connected,
      VendorIntegrationStatus.connected => VendorIntegrationStatus.error,
      VendorIntegrationStatus.error => VendorIntegrationStatus.disconnected,
    };
    _printers[index] = current.copyWith(status: nextStatus);
    notifyListeners();
  }

  void runPrinterTest(String printerId) {
    final index = _printers.indexWhere((printer) => printer.id == printerId);
    if (index < 0) {
      return;
    }
    final printer = _printers[index];
    final success = printer.status == VendorIntegrationStatus.connected;
    _printers[index] = printer.copyWith(lastTestLabel: 'Now');
    _printLogs.insert(
      0,
      VendorPrintLog(
        id: 'log_${DateTime.now().millisecondsSinceEpoch}',
        title: '${printer.name} test print',
        timestampLabel: 'Now',
        success: success,
      ),
    );
    notifyListeners();
  }

  void setKdsAutoBump(String stationId, int seconds) {
    final index = _kdsStations.indexWhere((station) => station.id == stationId);
    if (index < 0) {
      return;
    }
    _kdsStations[index] = _kdsStations[index].copyWith(
      autoBumpSeconds: seconds.clamp(30, 300),
    );
    notifyListeners();
  }

  void cycleKdsStatus(String stationId) {
    final index = _kdsStations.indexWhere((station) => station.id == stationId);
    if (index < 0) {
      return;
    }
    final current = _kdsStations[index];
    final nextStatus = switch (current.status) {
      VendorIntegrationStatus.disconnected =>
        VendorIntegrationStatus.connecting,
      VendorIntegrationStatus.connecting => VendorIntegrationStatus.connected,
      VendorIntegrationStatus.connected => VendorIntegrationStatus.error,
      VendorIntegrationStatus.error => VendorIntegrationStatus.disconnected,
    };
    _kdsStations[index] = current.copyWith(status: nextStatus);
    notifyListeners();
  }
}
