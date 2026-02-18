import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/store_context/model/vendor_store_context_models.dart';

class VendorStoreContextViewModel extends ChangeNotifier {
  VendorStoreContextViewModel() {
    _branches = mockVendorStoreBranches();
    _selectedBranchId = _branches.first.id;
    _allowedServices = VendorServiceType.values.toSet();
    searchController.addListener(_onSearchChanged);
  }

  final TextEditingController searchController = TextEditingController();

  late final List<VendorStoreBranch> _branches;
  late String _selectedBranchId;
  late Set<VendorServiceType> _allowedServices;
  VendorServiceType? _serviceScope;
  String _query = '';

  List<VendorStoreBranch> get branches {
    return _branches.where(_supportsAllowedServices).toList();
  }

  Set<VendorServiceType> get allowedServices =>
      Set.unmodifiable(_allowedServices);
  VendorServiceType? get serviceScope => _serviceScope;

  VendorStoreBranch get selectedBranch {
    final branches = this.branches;
    if (branches.isEmpty) return _branches.first;
    return branches.firstWhere(
      (branch) => branch.id == _selectedBranchId,
      orElse: () => branches.first,
    );
  }

  List<VendorServiceType> get availableServicesForSelectedBranch {
    final services = selectedBranch.serviceTypes
        .where(_allowedServices.contains)
        .toList();
    return List.unmodifiable(services);
  }

  List<VendorStoreBranch> get filteredBranches {
    final query = _query.toLowerCase();
    final branchList = branches;
    if (query.isEmpty) return List.unmodifiable(branchList);
    return branchList.where((branch) {
      return branch.name.toLowerCase().contains(query) ||
          branch.address.toLowerCase().contains(query);
    }).toList();
  }

  void setBranch(String branchId) {
    if (_selectedBranchId == branchId) return;
    final exists = branches.any((branch) => branch.id == branchId);
    if (!exists) return;
    _selectedBranchId = branchId;

    if (_serviceScope != null &&
        !availableServicesForSelectedBranch.contains(_serviceScope)) {
      _serviceScope = null;
    }

    _applyScopeDefaultIfNeeded();
    notifyListeners();
  }

  void setServiceScope(VendorServiceType? type) {
    if (_serviceScope == type) return;
    if (type != null && !availableServicesForSelectedBranch.contains(type)) {
      return;
    }
    _serviceScope = type;
    notifyListeners();
  }

  void setAllowedServices(Set<VendorServiceType> services) {
    final nextAllowed = services.isEmpty
        ? VendorServiceType.values.toSet()
        : services.toSet();
    if (setEquals(_allowedServices, nextAllowed)) return;

    _allowedServices = nextAllowed;

    final availableBranches = branches;
    if (availableBranches.isNotEmpty &&
        !availableBranches.any((branch) => branch.id == _selectedBranchId)) {
      _selectedBranchId = availableBranches.first.id;
    }

    if (_serviceScope != null &&
        !_allowedServices.contains(_serviceScope) &&
        !availableServicesForSelectedBranch.contains(_serviceScope)) {
      _serviceScope = null;
    }

    _applyScopeDefaultIfNeeded();
    notifyListeners();
  }

  String serviceScopeLabel() {
    final value = _serviceScope;
    if (value == null) return 'All Services';
    return switch (value) {
      VendorServiceType.food => 'Food',
      VendorServiceType.grocery => 'Grocery',
      VendorServiceType.pharmacy => 'Pharmacy',
      VendorServiceType.grabMart => 'GrabMart',
    };
  }

  void _onSearchChanged() {
    final nextValue = searchController.text.trim();
    if (_query == nextValue) return;
    _query = nextValue;
    notifyListeners();
  }

  bool _supportsAllowedServices(VendorStoreBranch branch) {
    return branch.serviceTypes.any(_allowedServices.contains);
  }

  void _applyScopeDefaultIfNeeded() {
    final available = availableServicesForSelectedBranch;
    if (available.isEmpty) {
      _serviceScope = null;
      return;
    }
    if (_allowedServices.length == 1) {
      final singleService = _allowedServices.first;
      if (available.contains(singleService)) {
        _serviceScope = singleService;
        return;
      }
    }
    if (_serviceScope != null && !available.contains(_serviceScope)) {
      _serviceScope = null;
    }
  }

  @override
  void dispose() {
    searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }
}
