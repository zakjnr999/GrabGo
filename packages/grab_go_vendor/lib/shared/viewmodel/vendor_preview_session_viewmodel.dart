import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';

enum VendorPreviewType { restaurant, grocery, pharmacy, grabMart, multiService }

class VendorPreviewProfile {
  final VendorPreviewType type;
  final String title;
  final String subtitle;
  final Set<VendorServiceType> allowedServices;

  const VendorPreviewProfile({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.allowedServices,
  });
}

class VendorPreviewSessionViewModel extends ChangeNotifier {
  VendorPreviewSessionViewModel()
    : _activeProfile = _profiles.firstWhere(
        (profile) => profile.type == VendorPreviewType.multiService,
      );

  static final List<VendorPreviewProfile> _profiles = [
    const VendorPreviewProfile(
      type: VendorPreviewType.restaurant,
      title: 'Restaurant Vendor',
      subtitle: 'Food-only storefront and operations',
      allowedServices: {VendorServiceType.food},
    ),
    const VendorPreviewProfile(
      type: VendorPreviewType.grocery,
      title: 'Grocery Vendor',
      subtitle: 'Grocery-only storefront and inventory',
      allowedServices: {VendorServiceType.grocery},
    ),
    const VendorPreviewProfile(
      type: VendorPreviewType.pharmacy,
      title: 'Pharmacy Vendor',
      subtitle: 'Pharmacy-only catalog and compliance workflows',
      allowedServices: {VendorServiceType.pharmacy},
    ),
    const VendorPreviewProfile(
      type: VendorPreviewType.grabMart,
      title: 'GrabMart Vendor',
      subtitle: 'GrabMart-only product and order flow',
      allowedServices: {VendorServiceType.grabMart},
    ),
    const VendorPreviewProfile(
      type: VendorPreviewType.multiService,
      title: 'Multi-Service Vendor',
      subtitle: 'Access to all supported services',
      allowedServices: {
        VendorServiceType.food,
        VendorServiceType.grocery,
        VendorServiceType.pharmacy,
        VendorServiceType.grabMart,
      },
    ),
  ];

  VendorPreviewProfile _activeProfile;

  List<VendorPreviewProfile> get profiles => List.unmodifiable(_profiles);
  VendorPreviewProfile get activeProfile => _activeProfile;
  Set<VendorServiceType> get allowedServices =>
      Set.unmodifiable(_activeProfile.allowedServices);
  bool get isSingleService => _activeProfile.allowedServices.length == 1;
  String get allowedServicesLabel =>
      servicesLabel(_activeProfile.allowedServices);

  bool isServiceAllowed(VendorServiceType serviceType) {
    return _activeProfile.allowedServices.contains(serviceType);
  }

  void setActiveProfile(VendorPreviewType type) {
    final next = _profiles.cast<VendorPreviewProfile?>().firstWhere(
      (profile) => profile?.type == type,
      orElse: () => null,
    );
    if (next == null || next.type == _activeProfile.type) return;
    _activeProfile = next;
    notifyListeners();
  }

  OrderServiceType mapToOrderService(VendorServiceType serviceType) {
    return switch (serviceType) {
      VendorServiceType.food => OrderServiceType.food,
      VendorServiceType.grocery => OrderServiceType.grocery,
      VendorServiceType.pharmacy => OrderServiceType.pharmacy,
      VendorServiceType.grabMart => OrderServiceType.grabmart,
    };
  }

  VendorServiceType mapToVendorService(OrderServiceType serviceType) {
    return switch (serviceType) {
      OrderServiceType.food => VendorServiceType.food,
      OrderServiceType.grocery => VendorServiceType.grocery,
      OrderServiceType.pharmacy => VendorServiceType.pharmacy,
      OrderServiceType.grabmart => VendorServiceType.grabMart,
    };
  }

  Set<OrderServiceType> get allowedOrderServices {
    return _activeProfile.allowedServices.map(mapToOrderService).toSet();
  }

  String servicesLabel(Iterable<VendorServiceType> services) {
    final ordered = services.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    return ordered.map(_vendorServiceLabel).join(', ');
  }

  String _vendorServiceLabel(VendorServiceType serviceType) {
    return switch (serviceType) {
      VendorServiceType.food => 'Food',
      VendorServiceType.grocery => 'Grocery',
      VendorServiceType.pharmacy => 'Pharmacy',
      VendorServiceType.grabMart => 'GrabMart',
    };
  }
}
