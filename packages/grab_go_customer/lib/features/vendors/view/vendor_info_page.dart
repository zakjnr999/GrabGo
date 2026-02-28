import 'package:chopper/chopper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:url_launcher/url_launcher.dart';

class VendorInfoPage extends StatefulWidget {
  const VendorInfoPage({super.key, required this.vendor});

  final VendorModel vendor;

  @override
  State<VendorInfoPage> createState() => _VendorInfoPageState();
}

class _VendorInfoPageState extends State<VendorInfoPage> {
  late VendorModel _vendor;

  @override
  void initState() {
    super.initState();
    _vendor = widget.vendor;
    _fetchVendorDetails();
  }

  Future<void> _fetchVendorDetails() async {
    try {
      final currentVendor = _vendor;
      late Response<Map<String, dynamic>> response;

      switch (currentVendor.vendorTypeEnum) {
        case VendorType.food:
          response = await vendorService.getRestaurantById(currentVendor.id);
          break;
        case VendorType.grocery:
          response = await vendorService.getGroceryStoreById(currentVendor.id);
          break;
        case VendorType.pharmacy:
          response = await vendorService.getPharmacyStoreById(currentVendor.id);
          break;
        case VendorType.grabmart:
          response = await vendorService.getGrabMartStoreById(currentVendor.id);
          break;
      }

      final body = response.body;
      if (response.isSuccessful &&
          body != null &&
          body['data'] is Map<String, dynamic>) {
        final detailJson = Map<String, dynamic>.from(
          body['data'] as Map<String, dynamic>,
        );
        final detail = currentVendor.mergeDetailSnapshot(detailJson);

        if (!mounted) return;
        setState(() {
          _vendor = detail;
        });
      }
    } catch (error) {
      debugPrint('VendorInfoPage: failed to load vendor details: $error');
    }
  }

  String _formatOpeningTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '--';
    final parsed = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
    if (parsed == null) return raw.trim();
    final hour24 = int.tryParse(parsed.group(1)!);
    final minute = parsed.group(2)!;
    if (hour24 == null || hour24 < 0 || hour24 > 23) return raw.trim();
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minute $suffix';
  }

  DaySchedule? _todaySchedule(OpeningHours? openingHours) {
    if (openingHours == null) return null;
    switch (DateTime.now().weekday) {
      case DateTime.monday:
        return openingHours.monday;
      case DateTime.tuesday:
        return openingHours.tuesday;
      case DateTime.wednesday:
        return openingHours.wednesday;
      case DateTime.thursday:
        return openingHours.thursday;
      case DateTime.friday:
        return openingHours.friday;
      case DateTime.saturday:
        return openingHours.saturday;
      case DateTime.sunday:
        return openingHours.sunday;
      default:
        return null;
    }
  }

  String _availabilityText() {
    if (_vendor.isTemporarilyUnavailableButOpen) {
      return 'Not accepting orders';
    }
    if (_vendor.is24Hours == true && _vendor.isAvailableForOrders)
      return 'Open 24 hours';
    final today = _todaySchedule(_vendor.openingHours);
    if (today == null) {
      return _vendor.isAvailableForOrders ? 'Open now' : 'Closed for now';
    }
    if (today.isClosed) return 'Closed today';
    return _vendor.isAvailableForOrders
        ? 'Closes at ${_formatOpeningTime(today.close)}'
        : 'Opens at ${_formatOpeningTime(today.open)}';
  }

  String? _lastSeenText() {
    final lastSeenAt = _vendor.lastOnlineAt;
    if (lastSeenAt == null) return null;
    final difference = DateTime.now().difference(lastSeenAt.toLocal());
    if (difference.isNegative) return null;
    if (difference.inMinutes < 1) return 'Seen just now';
    if (difference.inMinutes < 60) return 'Seen ${difference.inMinutes}m ago';
    if (difference.inHours < 24) return 'Seen ${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Seen yesterday';
    if (difference.inDays < 7) return 'Seen ${difference.inDays}d ago';
    return 'Seen recently';
  }

  Uri? _websiteUri() {
    final raw = _vendor.websiteUrl?.trim();
    if (raw == null || raw.isEmpty) return null;
    final normalized = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    return Uri.tryParse(normalized);
  }

  Uri? _externalUri(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final normalized =
        value.startsWith('http://') || value.startsWith('https://')
        ? value
        : 'https://$value';
    return Uri.tryParse(normalized);
  }

  String? _normalizedWhatsAppNumber() {
    final raw = (_vendor.whatsappNumber ?? _vendor.phone).trim();
    if (raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('+')) return digits.substring(1);
    if (digits.startsWith('0')) return '233${digits.substring(1)}';
    return digits;
  }

  Future<void> _launchVendorUri(Uri uri, {required String errorMessage}) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !mounted) return;
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: errorMessage,
      );
    } catch (_) {
      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: errorMessage,
      );
    }
  }

  bool get _hasOverviewSection {
    return (_vendor.description ?? '').trim().isNotEmpty ||
        _vendor.address.isNotEmpty ||
        !_vendor.isAcceptingOrders ||
        _lastSeenText() != null ||
        _vendor.distanceText.isNotEmpty;
  }

  bool get _hasContactSection {
    return _vendor.phone.trim().isNotEmpty ||
        ((_vendor.whatsappNumber ?? '').trim().isNotEmpty) ||
        (_vendor.paymentMethods?.isNotEmpty ?? false);
  }

  bool get _hasOnlineSection {
    return _websiteUri() != null ||
        _externalUri(_vendor.instagramUrl) != null ||
        _externalUri(_vendor.facebookUrl) != null ||
        _externalUri(_vendor.twitterUrl) != null;
  }

  bool get _hasCapabilitiesSection {
    return (_vendor.features?.isNotEmpty ?? false) ||
        (_vendor.services?.isNotEmpty ?? false) ||
        (_vendor.productTypes?.isNotEmpty ?? false) ||
        _vendor.vendorCategories.isNotEmpty ||
        (_vendor.tags?.isNotEmpty ?? false) ||
        (_vendor.foodType ?? '').trim().isNotEmpty;
  }

  bool get _hasOperationalSection {
    return (_vendor.isVerified ?? false) ||
        (_vendor.featured ?? false) ||
        _vendor.isExclusive ||
        (_vendor.averagePreparationTime != null &&
            _vendor.averagePreparationTime! > 0) ||
        (_vendor.deliveryRadius != null && _vendor.deliveryRadius! > 0) ||
        (_vendor.is24Hours ?? false) ||
        (_vendor.hasParking ?? false) ||
        (_vendor.emergencyService ?? false) ||
        (_vendor.prescriptionRequired ?? false);
  }

  bool get _hasPharmacySection {
    return (_vendor.pharmacistName ?? '').trim().isNotEmpty ||
        (_vendor.licenseNumber ?? '').trim().isNotEmpty ||
        (_vendor.insuranceAccepted?.isNotEmpty ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final accentColor = Color(_vendor.vendorTypeEnum.color);
    final expandedHeight = UmbrellaHeaderMetrics.expandedHeightFor(
      size,
      extra: 12.h,
    );
    final contentPadding = UmbrellaHeaderMetrics.contentPaddingFor(
      size,
      extra: 12.h,
    );
    final statusBarStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        body: Stack(
          children: [
            SizedBox(
              height: expandedHeight,
              child: UmbrellaHeaderWithShadow(
                curveDepth: 20.h,
                numberOfCurves: 10,
                height: expandedHeight,
                backgroundColor: accentColor,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20.w,
                    padding.top + 10.h,
                    20.w,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.pop(),
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: EdgeInsets.all(10.r),
                              child: SvgPicture.asset(
                                Assets.icons.navArrowLeft,
                                package: 'grab_go_shared',
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Store info',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              _vendor.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            RefreshIndicator(
              color: accentColor,
              onRefresh: _fetchVendorDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16.w, contentPadding, 16.w, 24.h),
                child: Column(
                  children: [
                    if (_hasOverviewSection) ...[
                      _buildSectionCard(
                        colors: colors,
                        title: 'Overview',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWrapPills(colors, [
                              _buildMetaPill(
                                colors: colors,
                                label: _availabilityText(),
                                backgroundColor: _vendor.isOpen
                                    ? colors.accentGreen.withValues(alpha: 0.12)
                                    : colors.error.withValues(alpha: 0.10),
                                textColor: _vendor.isOpen
                                    ? colors.accentGreen
                                    : colors.error,
                              ),
                              if (_vendor.distanceText.isNotEmpty)
                                _buildMetaPill(
                                  colors: colors,
                                  label: _vendor.distanceText,
                                ),
                              if (_lastSeenText() != null)
                                _buildMetaPill(
                                  colors: colors,
                                  label: _lastSeenText()!,
                                ),
                            ]),
                            if (_vendor.address.isNotEmpty) ...[
                              SizedBox(height: 10.h),
                              Text(
                                _vendor.address,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if ((_vendor.description ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              SizedBox(height: 10.h),
                              Text(
                                _vendor.description!.trim(),
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),
                    ],
                    if (_hasOperationalSection) ...[
                      _buildSectionCard(
                        colors: colors,
                        title: 'Operations',
                        child: _buildWrapPills(colors, [
                          if (_vendor.isVerified == true)
                            _buildMetaPill(
                              colors: colors,
                              label: 'Verified',
                              backgroundColor: colors.accentGreen.withValues(
                                alpha: 0.12,
                              ),
                              textColor: colors.accentGreen,
                            ),
                          if (_vendor.featured == true)
                            _buildMetaPill(
                              colors: colors,
                              label: 'Featured',
                              backgroundColor: colors.accentOrange.withValues(
                                alpha: 0.12,
                              ),
                              textColor: colors.accentOrange,
                            ),
                          if (_vendor.isExclusive)
                            _buildMetaPill(
                              colors: colors,
                              label: 'GrabGo Exclusive',
                              backgroundColor: colors.accentOrange.withValues(
                                alpha: 0.12,
                              ),
                              textColor: colors.accentOrange,
                            ),
                          if (_vendor.averagePreparationTime != null &&
                              _vendor.averagePreparationTime! > 0)
                            _buildMetaPill(
                              colors: colors,
                              label:
                                  'Prep ${_vendor.averagePreparationTime} mins',
                            ),
                          if (_vendor.deliveryRadius != null &&
                              _vendor.deliveryRadius! > 0)
                            _buildMetaPill(
                              colors: colors,
                              label:
                                  '${_vendor.deliveryRadius!.toStringAsFixed(0)}km radius',
                            ),
                          if (_vendor.is24Hours == true)
                            _buildMetaPill(colors: colors, label: '24/7'),
                          if (_vendor.hasParking == true)
                            _buildMetaPill(colors: colors, label: 'Parking'),
                          if (_vendor.emergencyService == true)
                            _buildMetaPill(
                              colors: colors,
                              label: 'Emergency service',
                            ),
                          if (_vendor.prescriptionRequired == true)
                            _buildMetaPill(
                              colors: colors,
                              label: 'Prescription required',
                            ),
                        ]),
                      ),
                      SizedBox(height: 14.h),
                    ],
                    if (_vendor.openingHours != null) ...[
                      _buildSectionCard(
                        colors: colors,
                        title: 'Opening hours',
                        child: _buildOpeningHoursList(colors),
                      ),
                      SizedBox(height: 14.h),
                    ],
                    if (_hasContactSection) ...[
                      _buildSectionCard(
                        colors: colors,
                        title: 'Contact & payment',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_vendor.phone.trim().isNotEmpty)
                              _buildInfoRow(colors, 'Phone', _vendor.phone),
                            if ((_vendor.whatsappNumber ?? '')
                                .trim()
                                .isNotEmpty)
                              _buildInfoRow(
                                colors,
                                'WhatsApp',
                                _vendor.whatsappNumber!.trim(),
                              ),
                            if (_vendor.paymentMethods?.isNotEmpty ??
                                false) ...[
                              SizedBox(height: 10.h),
                              Text(
                                'Payment methods',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              _buildWrapPills(
                                colors,
                                _vendor.paymentMethods!
                                    .where((entry) => entry.trim().isNotEmpty)
                                    .map(
                                      (entry) => _buildMetaPill(
                                        colors: colors,
                                        label: entry,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),
                    ],
                    if (_hasOnlineSection) ...[
                      _buildSectionCard(
                        colors: colors,
                        title: 'Online',
                        child: Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: [
                            if (_vendor.phone.trim().isNotEmpty)
                              _buildActionPill(
                                colors: colors,
                                icon: Icons.call_rounded,
                                label: 'Call',
                                onTap: () => _launchVendorUri(
                                  Uri(
                                    scheme: 'tel',
                                    path: _vendor.phone.trim(),
                                  ),
                                  errorMessage:
                                      'Unable to open the phone app right now.',
                                ),
                              ),
                            if (_normalizedWhatsAppNumber() != null)
                              _buildActionPill(
                                colors: colors,
                                icon: Icons.chat_bubble_rounded,
                                label: 'WhatsApp',
                                onTap: () => _launchVendorUri(
                                  Uri.parse(
                                    'https://wa.me/${_normalizedWhatsAppNumber()!}',
                                  ),
                                  errorMessage:
                                      'Unable to open WhatsApp right now.',
                                ),
                              ),
                            if (_websiteUri() != null)
                              _buildActionPill(
                                colors: colors,
                                icon: Icons.language_rounded,
                                label: 'Website',
                                onTap: () => _launchVendorUri(
                                  _websiteUri()!,
                                  errorMessage:
                                      'Unable to open the website right now.',
                                ),
                              ),
                            if (_externalUri(_vendor.instagramUrl) != null)
                              _buildActionPill(
                                colors: colors,
                                icon: Icons.camera_alt_rounded,
                                label: 'Instagram',
                                onTap: () => _launchVendorUri(
                                  _externalUri(_vendor.instagramUrl)!,
                                  errorMessage:
                                      'Unable to open Instagram right now.',
                                ),
                              ),
                            if (_externalUri(_vendor.facebookUrl) != null)
                              _buildActionPill(
                                colors: colors,
                                icon: Icons.facebook_rounded,
                                label: 'Facebook',
                                onTap: () => _launchVendorUri(
                                  _externalUri(_vendor.facebookUrl)!,
                                  errorMessage:
                                      'Unable to open Facebook right now.',
                                ),
                              ),
                            if (_externalUri(_vendor.twitterUrl) != null)
                              _buildActionPill(
                                colors: colors,
                                icon: Icons.alternate_email_rounded,
                                label: 'X',
                                onTap: () => _launchVendorUri(
                                  _externalUri(_vendor.twitterUrl)!,
                                  errorMessage: 'Unable to open X right now.',
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),
                    ],
                    if (_hasCapabilitiesSection) ...[
                      _buildSectionCard(
                        colors: colors,
                        title: 'What this store offers',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((_vendor.foodType ?? '').trim().isNotEmpty) ...[
                              _buildInfoRow(
                                colors,
                                'Type',
                                _vendor.foodType!.trim(),
                              ),
                              SizedBox(height: 8.h),
                            ],
                            if (_vendor.vendorCategories.isNotEmpty) ...[
                              Text(
                                'Categories',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              _buildWrapPills(
                                colors,
                                _vendor.vendorCategories
                                    .map(
                                      (entry) => _buildMetaPill(
                                        colors: colors,
                                        label: entry,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (_vendor.tags?.isNotEmpty ?? false) ...[
                              SizedBox(height: 12.h),
                              Text(
                                'Tags',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              _buildWrapPills(
                                colors,
                                _vendor.tags!
                                    .where((entry) => entry.trim().isNotEmpty)
                                    .map(
                                      (entry) => _buildMetaPill(
                                        colors: colors,
                                        label: entry,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (_vendor.services?.isNotEmpty ?? false) ...[
                              SizedBox(height: 12.h),
                              Text(
                                'Services',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              _buildWrapPills(
                                colors,
                                _vendor.services!
                                    .where((entry) => entry.trim().isNotEmpty)
                                    .map(
                                      (entry) => _buildMetaPill(
                                        colors: colors,
                                        label: entry,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (_vendor.productTypes?.isNotEmpty ?? false) ...[
                              SizedBox(height: 12.h),
                              Text(
                                'Product types',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              _buildWrapPills(
                                colors,
                                _vendor.productTypes!
                                    .where((entry) => entry.trim().isNotEmpty)
                                    .map(
                                      (entry) => _buildMetaPill(
                                        colors: colors,
                                        label: entry,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (_vendor.features?.isNotEmpty ?? false) ...[
                              SizedBox(height: 12.h),
                              Text(
                                'Store features',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              _buildWrapPills(
                                colors,
                                _vendor.features!
                                    .where((entry) => entry.trim().isNotEmpty)
                                    .map(
                                      (entry) => _buildMetaPill(
                                        colors: colors,
                                        label: entry,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 14.h),
                    ],
                    if (_hasPharmacySection)
                      _buildSectionCard(
                        colors: colors,
                        title: 'Pharmacy info',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if ((_vendor.pharmacistName ?? '')
                                .trim()
                                .isNotEmpty)
                              _buildInfoRow(
                                colors,
                                'Pharmacist',
                                _vendor.pharmacistName!.trim(),
                              ),
                            if ((_vendor.licenseNumber ?? '').trim().isNotEmpty)
                              _buildInfoRow(
                                colors,
                                'License',
                                _vendor.licenseNumber!.trim(),
                              ),
                            if (_vendor.insuranceAccepted?.isNotEmpty ??
                                false) ...[
                              SizedBox(height: 8.h),
                              Text(
                                'Insurance accepted',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              _buildWrapPills(
                                colors,
                                _vendor.insuranceAccepted!
                                    .where((entry) => entry.trim().isNotEmpty)
                                    .map(
                                      (entry) => _buildMetaPill(
                                        colors: colors,
                                        label: entry,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required AppColorsExtension colors,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }

  Widget _buildWrapPills(AppColorsExtension colors, List<Widget> children) {
    final filtered = children.whereType<Widget>().toList(growable: false);
    if (filtered.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8.w, runSpacing: 8.h, children: filtered);
  }

  Widget _buildMetaPill({
    required AppColorsExtension colors,
    required String label,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? colors.textPrimary,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildOpeningHoursList(AppColorsExtension colors) {
    final openingHours = _vendor.openingHours;
    if (openingHours == null) return const SizedBox.shrink();

    final dayEntries = <(String, DaySchedule?)>[
      ('Mon', openingHours.monday),
      ('Tue', openingHours.tuesday),
      ('Wed', openingHours.wednesday),
      ('Thu', openingHours.thursday),
      ('Fri', openingHours.friday),
      ('Sat', openingHours.saturday),
      ('Sun', openingHours.sunday),
    ];
    final todayIndex = DateTime.now().weekday - 1;

    return Column(
      children: [
        for (int index = 0; index < dayEntries.length; index++) ...[
          _buildOpeningHourRow(
            colors: colors,
            dayLabel: dayEntries[index].$1,
            schedule: dayEntries[index].$2,
            isToday: index == todayIndex,
          ),
          if (index < dayEntries.length - 1) SizedBox(height: 6.h),
        ],
      ],
    );
  }

  Widget _buildOpeningHourRow({
    required AppColorsExtension colors,
    required String dayLabel,
    required DaySchedule? schedule,
    required bool isToday,
  }) {
    final isClosed = schedule == null || schedule.isClosed;
    final value = isClosed
        ? 'Closed'
        : '${_formatOpeningTime(schedule.open)} - ${_formatOpeningTime(schedule.close)}';
    return Row(
      children: [
        SizedBox(
          width: 42.w,
          child: Text(
            dayLabel,
            style: TextStyle(
              color: isToday ? colors.accentOrange : colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isToday ? colors.textPrimary : colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(AppColorsExtension colors, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82.w,
            child: Text(
              label,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required AppColorsExtension colors,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999.r),
        child: Ink(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15.sp, color: colors.accentOrange),
              SizedBox(width: 6.w),
              Text(
                label,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
