import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/service/exclusive_vendor_service.dart';
import 'package:grab_go_customer/features/vendors/widgets/vendor_horizontal_section.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class ExclusiveVendorsPreviewSection extends StatefulWidget {
  final VoidCallback? onSeeAll;

  const ExclusiveVendorsPreviewSection({super.key, this.onSeeAll});

  @override
  State<ExclusiveVendorsPreviewSection> createState() =>
      _ExclusiveVendorsPreviewSectionState();
}

class _ExclusiveVendorsPreviewSectionState
    extends State<ExclusiveVendorsPreviewSection> {
  final ExclusiveVendorService _service = ExclusiveVendorService();

  List<VendorModel> _vendors = const [];
  bool _isLoading = false;
  bool _hasLoadedOnce = false;
  double? _lastLat;
  double? _lastLng;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final locationProvider = Provider.of<NativeLocationProvider>(context);
    final latitude = locationProvider.latitude;
    final longitude = locationProvider.longitude;
    final locationChanged = latitude != _lastLat || longitude != _lastLng;

    if (!_hasLoadedOnce || locationChanged) {
      _lastLat = latitude;
      _lastLng = longitude;
      _loadExclusiveVendors(latitude: latitude, longitude: longitude);
    }
  }

  Future<void> _loadExclusiveVendors({
    double? latitude,
    double? longitude,
  }) async {
    if (_isLoading) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final vendors = await _service.fetchExclusiveVendors(
        latitude: latitude,
        longitude: longitude,
      );
      if (!mounted) return;
      setState(() {
        _vendors = vendors.take(10).toList(growable: false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vendors = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _vendors.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_vendors.isEmpty) {
      return const SizedBox.shrink();
    }

    return VendorHorizontalSection(
      title: 'GrabGo Exclusives',
      icon: Assets.icons.sparkles,
      vendors: _vendors,
      isLoading: false,
      accentColor: context.appColors.accentOrange,
      highlightExclusiveBadge: true,
      onSeeAll: widget.onSeeAll,
      onItemTap: (vendor) => context.push('/vendorDetails', extra: vendor),
    );
  }
}
