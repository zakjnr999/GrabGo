import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/parcel/viewmodel/parcel_provider.dart';
import 'package:grab_go_customer/features/parcel/widgets/order_actions.dart';
import 'package:grab_go_customer/features/parcel/widgets/order_card.dart';
import 'package:grab_go_customer/features/parcel/widgets/order_detail_sheet.dart';
import 'package:grab_go_customer/shared/models/address_model.dart';
import 'package:grab_go_customer/shared/services/auth_guard.dart';
import 'package:grab_go_customer/shared/services/paystack_service.dart'
    as paystack;
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class ParcelDeliveryPage extends StatefulWidget {
  const ParcelDeliveryPage({super.key});

  @override
  State<ParcelDeliveryPage> createState() => _ParcelDeliveryPageState();
}

class _ParcelDeliveryPageState extends State<ParcelDeliveryPage> {
  bool _redirectingToLogin = false;
  bool _defaultsApplied = false;
  bool _isQuoteReadyForOrder = false;
  Map<String, String?> _fieldErrors = {};

  final _pickupAddressController = TextEditingController();
  final _pickupCityController = TextEditingController(text: 'Accra');
  final _pickupLatController = TextEditingController();
  final _pickupLngController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();

  final _dropoffAddressController = TextEditingController();
  final _dropoffCityController = TextEditingController(text: 'Accra');
  final _dropoffLatController = TextEditingController();
  final _dropoffLngController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();

  final _declaredValueController = TextEditingController(text: '120');
  final _weightController = TextEditingController(text: '2');

  String _sizeTier = 'medium';
  String _paymentMethod = 'paystack';
  bool _acceptTerms = true;
  bool _acceptProhibited = true;

  static const _pickupAddressKey = 'pickup_address';
  static const _pickupCityKey = 'pickup_city';
  static const _pickupLatKey = 'pickup_lat';
  static const _pickupLngKey = 'pickup_lng';
  static const _senderNameKey = 'sender_name';
  static const _senderPhoneKey = 'sender_phone';
  static const _dropoffAddressKey = 'dropoff_address';
  static const _dropoffCityKey = 'dropoff_city';
  static const _dropoffLatKey = 'dropoff_lat';
  static const _dropoffLngKey = 'dropoff_lng';
  static const _recipientNameKey = 'recipient_name';
  static const _recipientPhoneKey = 'recipient_phone';
  static const _declaredValueKey = 'declared_value';
  static const _weightKey = 'weight';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_ensureAuthenticated()) return;
      final provider = context.read<ParcelProvider>();
      provider.loadConfig();
      _applyDefaultsFromContext();
    });
  }

  bool _ensureAuthenticated() {
    if (UserService().isLoggedIn) {
      _redirectingToLogin = false;
      return true;
    }

    if (!_redirectingToLogin) {
      _redirectingToLogin = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(AuthGuard.loginRoute(returnTo: '/parcel'));
      });
    }
    return false;
  }

  @override
  void dispose() {
    _pickupAddressController.dispose();
    _pickupCityController.dispose();
    _pickupLatController.dispose();
    _pickupLngController.dispose();
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _dropoffAddressController.dispose();
    _dropoffCityController.dispose();
    _dropoffLatController.dispose();
    _dropoffLngController.dispose();
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _declaredValueController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _applyDefaultsFromContext() {
    if (_defaultsApplied) return;
    _defaultsApplied = true;

    final location = context.read<NativeLocationProvider>();
    final user = UserService().currentUser;

    final lat = location.latitude ?? 5.6037;
    final lng = location.longitude ?? -0.1870;
    final baseAddress = (location.address.isNotEmpty
        ? location.address
        : 'Current pickup location');

    _pickupAddressController.text = baseAddress;
    _pickupLatController.text = lat.toStringAsFixed(6);
    _pickupLngController.text = lng.toStringAsFixed(6);

    _dropoffAddressController.text = 'Recipient address';
    _dropoffLatController.text = (lat + 0.01).toStringAsFixed(6);
    _dropoffLngController.text = (lng + 0.01).toStringAsFixed(6);

    _senderNameController.text = user?.username ?? 'Sender';
    _senderPhoneController.text = user?.phone ?? '';
    _recipientNameController.text = 'Recipient';
  }

  double? _parseDouble(String text) => double.tryParse(text.trim());

  String? _required(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  bool _validateFormInputs() {
    final errors = <String, String?>{};

    void requireField(
      TextEditingController controller,
      String key,
      String label,
    ) {
      final error = _required(controller.text, label);
      if (error != null) {
        errors[key] = error;
      }
    }

    void requireNumber(
      TextEditingController controller,
      String key,
      String label, {
      double? min,
      double? max,
    }) {
      final value = _parseDouble(controller.text);
      if (value == null) {
        errors[key] = '$label must be a valid number';
        return;
      }
      if (min != null && value < min) {
        errors[key] = '$label must be at least $min';
      } else if (max != null && value > max) {
        errors[key] = '$label must be at most $max';
      }
    }

    requireField(_pickupAddressController, _pickupAddressKey, 'Pickup address');
    requireField(_pickupCityController, _pickupCityKey, 'Pickup city');
    requireNumber(
      _pickupLatController,
      _pickupLatKey,
      'Pickup latitude',
      min: -90,
      max: 90,
    );
    requireNumber(
      _pickupLngController,
      _pickupLngKey,
      'Pickup longitude',
      min: -180,
      max: 180,
    );
    requireField(_senderNameController, _senderNameKey, 'Sender name');
    requireField(_senderPhoneController, _senderPhoneKey, 'Sender phone');

    requireField(
      _dropoffAddressController,
      _dropoffAddressKey,
      'Dropoff address',
    );
    requireField(_dropoffCityController, _dropoffCityKey, 'Dropoff city');
    requireNumber(
      _dropoffLatController,
      _dropoffLatKey,
      'Dropoff latitude',
      min: -90,
      max: 90,
    );
    requireNumber(
      _dropoffLngController,
      _dropoffLngKey,
      'Dropoff longitude',
      min: -180,
      max: 180,
    );
    requireField(_recipientNameController, _recipientNameKey, 'Recipient name');
    requireField(
      _recipientPhoneController,
      _recipientPhoneKey,
      'Recipient phone',
    );

    requireNumber(
      _declaredValueController,
      _declaredValueKey,
      'Declared value',
      min: 0.01,
    );
    requireNumber(_weightController, _weightKey, 'Weight', min: 0.01);

    setState(() {
      _fieldErrors = errors;
    });
    return errors.isEmpty;
  }

  void _clearFieldError(String fieldKey) {
    if (!_fieldErrors.containsKey(fieldKey)) return;
    setState(() {
      _fieldErrors = Map<String, String?>.from(_fieldErrors)..remove(fieldKey);
    });
  }

  void _markQuoteStale() {
    if (!_isQuoteReadyForOrder) return;
    setState(() {
      _isQuoteReadyForOrder = false;
    });
  }

  ParcelQuoteRequest? _buildQuoteRequest() {
    final pickupLat = _parseDouble(_pickupLatController.text);
    final pickupLng = _parseDouble(_pickupLngController.text);
    final dropoffLat = _parseDouble(_dropoffLatController.text);
    final dropoffLng = _parseDouble(_dropoffLngController.text);
    final declaredValue = _parseDouble(_declaredValueController.text);
    final weight = _parseDouble(_weightController.text);

    if ([
      pickupLat,
      pickupLng,
      dropoffLat,
      dropoffLng,
      declaredValue,
      weight,
    ].contains(null)) {
      return null;
    }

    return ParcelQuoteRequest(
      pickup: ParcelStopInput(
        addressLine1: _pickupAddressController.text.trim(),
        city: _pickupCityController.text.trim(),
        latitude: pickupLat!,
        longitude: pickupLng!,
        contactName: _senderNameController.text.trim(),
        contactPhone: _senderPhoneController.text.trim(),
      ),
      dropoff: ParcelStopInput(
        addressLine1: _dropoffAddressController.text.trim(),
        city: _dropoffCityController.text.trim(),
        latitude: dropoffLat!,
        longitude: dropoffLng!,
        contactName: _recipientNameController.text.trim(),
        contactPhone: _recipientPhoneController.text.trim(),
      ),
      declaredValueGhs: declaredValue!,
      weightKg: weight!,
      sizeTier: _sizeTier,
      paymentMethod: _paymentMethod,
      prohibitedItemsAccepted: _acceptProhibited,
    );
  }

  Future<void> _getQuote() async {
    final provider = context.read<ParcelProvider>();
    if (provider.isQuoting) return;
    if (!_validateFormInputs()) return;
    final request = _buildQuoteRequest();
    if (request == null) {
      _showToast(
        'Please enter valid numeric values for coordinates, weight and declared value.',
      );
      return;
    }

    LoadingDialog.instance().show(
      context: context,
      text: 'Getting parcel quote...',
    );
    try {
      await provider.requestQuote(request);
    } finally {
      LoadingDialog.instance().hide();
    }
    if (!mounted) return;

    setState(() {
      _isQuoteReadyForOrder =
          provider.errorMessage == null && provider.latestQuote != null;
    });
  }

  Future<void> _createOrder(ParcelProvider provider) async {
    if (!_validateFormInputs()) return;
    if (!_acceptTerms) {
      _showToast('You must accept parcel terms before creating an order.');
      return;
    }
    if (!_acceptProhibited) {
      _showToast('You must accept prohibited-items confirmation.');
      return;
    }

    final baseRequest = _buildQuoteRequest();
    if (baseRequest == null) {
      _showToast(
        'Please enter valid numeric values for coordinates, weight and declared value.',
      );
      return;
    }

    final order = await provider.createOrder(
      ParcelCreateOrderRequest(
        pickup: baseRequest.pickup,
        dropoff: baseRequest.dropoff,
        declaredValueGhs: baseRequest.declaredValueGhs,
        weightKg: baseRequest.weightKg,
        sizeTier: baseRequest.sizeTier,
        paymentMethod: baseRequest.paymentMethod,
        scheduleType: baseRequest.scheduleType,
        prohibitedItemsAccepted: _acceptProhibited,
        packageCategory: baseRequest.packageCategory,
        packageDescription: baseRequest.packageDescription,
        containsHazardous: baseRequest.containsHazardous,
        containsLiquid: baseRequest.containsLiquid,
        isPerishable: baseRequest.isPerishable,
        isFragile: baseRequest.isFragile,
        lengthCm: baseRequest.lengthCm,
        widthCm: baseRequest.widthCm,
        heightCm: baseRequest.heightCm,
        notes: baseRequest.notes,
        acceptParcelTerms: _acceptTerms,
        termsVersion: provider.config?.termsVersion,
      ),
    );

    if (!mounted) return;
    if (order != null) {
      setState(() {
        _isQuoteReadyForOrder = false;
      });
      _showToast('Parcel order created: ${order.parcelNumber}');
    } else if (provider.errorMessage != null) {
      _showToast(provider.errorMessage!);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  bool _canRetryPayment(ParcelOrderSummary order) {
    const unpaidStatuses = {'pending', 'processing'};
    return unpaidStatuses.contains(order.paymentStatus.toLowerCase());
  }

  bool _canCancelOrder(ParcelOrderSummary order) {
    const cancellableStatuses = {
      'pending_payment',
      'payment_processing',
      'paid',
      'awaiting_dispatch',
    };
    return cancellableStatuses.contains(order.status.toLowerCase());
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'n/a';
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$month-$day $hour:$minute';
  }

  Future<void> _refreshOrders() async {
    await context.read<ParcelProvider>().loadOrders();
  }

  String _resolveCityFromAddress(AddressModel address, String fallback) {
    final modelCity = address.city?.trim();
    if (modelCity != null && modelCity.isNotEmpty) {
      return modelCity;
    }

    final parts = address.formattedAddress
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (parts.length >= 2) {
      return parts[parts.length - 2];
    }
    if (parts.isNotEmpty) {
      return parts.last;
    }
    return fallback;
  }

  Future<void> _pickStopOnMap({required bool isPickup}) async {
    final result = await context.push(
      '/confirm-address?returnTo=previous&mode=select',
    );
    if (!mounted || result == null) return;

    AddressModel? selectedAddress;
    if (result is AddressModel) {
      selectedAddress = result;
    } else if (result is Map<String, dynamic>) {
      selectedAddress = AddressModel.fromJson(result);
    } else if (result is Map) {
      selectedAddress = AddressModel.fromJson(
        Map<String, dynamic>.from(result),
      );
    } else if (result == true) {
      selectedAddress = context.read<NativeLocationProvider>().confirmedAddress;
    }

    if (selectedAddress == null) {
      _showToast('No address was selected.');
      return;
    }

    final city = _resolveCityFromAddress(
      selectedAddress,
      isPickup
          ? _pickupCityController.text.trim()
          : _dropoffCityController.text.trim(),
    );

    setState(() {
      if (isPickup) {
        _pickupAddressController.text = selectedAddress!.formattedAddress;
        _pickupCityController.text = city;
        _pickupLatController.text = selectedAddress.latitude.toStringAsFixed(6);
        _pickupLngController.text = selectedAddress.longitude.toStringAsFixed(
          6,
        );
      } else {
        _dropoffAddressController.text = selectedAddress!.formattedAddress;
        _dropoffCityController.text = city;
        _dropoffLatController.text = selectedAddress.latitude.toStringAsFixed(
          6,
        );
        _dropoffLngController.text = selectedAddress.longitude.toStringAsFixed(
          6,
        );
      }
      _isQuoteReadyForOrder = false;
    });
  }

  Future<void> _viewOrder(ParcelProvider provider, String parcelId) async {
    final detail = await provider.loadOrderDetail(parcelId);
    if (!mounted) return;
    if (detail == null) {
      _showToast(provider.errorMessage ?? 'Failed to load order details.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.86,
        child: OrderDetailSheet(detail: detail, formatDate: _formatDate),
      ),
    );
  }

  Future<void> _payForOrder(
    ParcelProvider provider,
    ParcelOrderSummary order,
  ) async {
    final init = await provider.initializePaystack(order.id);
    if (!mounted) return;
    if (init == null) {
      _showToast(provider.errorMessage ?? 'Failed to initialize payment.');
      return;
    }

    final result = await paystack.PaystackService.instance.launchPayment(
      context: context,
      authorizationUrl: init.authorizationUrl,
      reference: init.reference,
    );

    if (!mounted) return;
    if (result.status == paystack.PaystackPaymentStatus.cancelled) {
      _showToast('Payment was cancelled.');
      return;
    }

    if (result.status == paystack.PaystackPaymentStatus.failed) {
      _showToast('Payment did not complete successfully.');
      return;
    }

    final confirmation = await provider.confirmPayment(
      order.id,
      reference: result.reference ?? init.reference,
    );
    if (!mounted) return;
    if (confirmation == null) {
      _showToast(provider.errorMessage ?? 'Payment confirmation failed.');
      return;
    }

    _showToast(
      confirmation.alreadyPaid
          ? 'Payment was already confirmed for this parcel.'
          : 'Payment confirmed successfully.',
    );
  }

  Future<void> _cancelOrder(
    ParcelProvider provider,
    ParcelOrderSummary order,
  ) async {
    final cancelled = await provider.cancelOrder(order.id);
    if (!mounted) return;
    if (cancelled == null) {
      _showToast(provider.errorMessage ?? 'Failed to cancel parcel order.');
      return;
    }
    _showToast('Parcel ${cancelled.parcelNumber} cancelled.');
  }

  @override
  Widget build(BuildContext context) {
    if (!_ensureAuthenticated()) {
      return const SizedBox.shrink();
    }

    final colors = context.appColors;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.backgroundPrimary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Consumer<ParcelProvider>(
            builder: (context, provider, _) {
              final config = provider.config;
              final isPaymentBusy =
                  provider.isInitializingPayment ||
                  provider.isConfirmingPayment;
              final isAnyOrderActionBusy =
                  isPaymentBusy || provider.isCancellingOrder;
              final showCreateOrderCta = _isQuoteReadyForOrder;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: padding.top + 10,
                      left: 20.w,
                      right: 20.w,
                      bottom: 16.h,
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
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
                                  colorFilter: ColorFilter.mode(
                                    colors.textPrimary,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Text(
                          'Parcel Delivery',
                          style: TextStyle(
                            fontFamily: 'Lato',
                            package: 'grab_go_shared',
                            color: colors.textPrimary,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),

                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            shape: BoxShape.circle,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => context.push('/parcel/orders'),
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: EdgeInsets.all(10.r),
                                child: SvgPicture.asset(
                                  Assets.icons.squareMenu,
                                  package: 'grab_go_shared',
                                  colorFilter: ColorFilter.mode(
                                    colors.textPrimary,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    color: colors.backgroundSecondary,
                    height: 1.h,
                    thickness: 1,
                  ),
                  Expanded(
                    child: AppRefreshIndicator(
                      onRefresh: _refreshOrders,
                      iconPath: Assets.icons.boxIso,
                      bgColor: colors.accentOrange,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (provider.isLoadingConfig && config == null)
                              const Center(child: CircularProgressIndicator())
                            else if (config != null)
                              _PolicyCard(config: config),
                            SizedBox(height: 14.h),
                            if (provider.errorMessage != null) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(12.w),
                                decoration: BoxDecoration(
                                  color: colors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  provider.errorMessage!,
                                  style: TextStyle(
                                    color: colors.error,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h),
                            ],
                            _buildSectionCard(
                              title: 'Sender',
                              child: Column(
                                children: [
                                  _buildTextField(
                                    _pickupAddressController,
                                    'Pickup address',
                                    fieldKey: _pickupAddressKey,
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildMapPickTile(
                                    title: 'Pick pickup address on map',
                                    onTap: () => _pickStopOnMap(isPickup: true),
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildTextField(
                                    _pickupCityController,
                                    'Pickup city',
                                    fieldKey: _pickupCityKey,
                                  ),
                                  SizedBox(height: 8.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          _pickupLatController,
                                          'Pickup latitude',
                                          fieldKey: _pickupLatKey,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: _buildTextField(
                                          _pickupLngController,
                                          'Pickup longitude',
                                          fieldKey: _pickupLngKey,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildTextField(
                                    _senderNameController,
                                    'Sender name',
                                    fieldKey: _senderNameKey,
                                    keyboardType: TextInputType.name,
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildTextField(
                                    _senderPhoneController,
                                    'Sender phone',
                                    fieldKey: _senderPhoneKey,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Divider(
                              color: colors.backgroundSecondary,
                              height: 32.h,
                              thickness: 1,
                            ),
                            SizedBox(height: 10.h),
                            _buildSectionCard(
                              title: 'Recipient',
                              child: Column(
                                children: [
                                  _buildTextField(
                                    _dropoffAddressController,
                                    'Dropoff address',
                                    fieldKey: _dropoffAddressKey,
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildMapPickTile(
                                    title: 'Pick dropoff address on map',
                                    onTap: () =>
                                        _pickStopOnMap(isPickup: false),
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildTextField(
                                    _dropoffCityController,
                                    'Dropoff city',
                                    fieldKey: _dropoffCityKey,
                                  ),
                                  SizedBox(height: 8.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          _dropoffLatController,
                                          'Dropoff latitude',
                                          fieldKey: _dropoffLatKey,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: _buildTextField(
                                          _dropoffLngController,
                                          'Dropoff longitude',
                                          fieldKey: _dropoffLngKey,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildTextField(
                                    _recipientNameController,
                                    'Recipient name',
                                    fieldKey: _recipientNameKey,
                                    keyboardType: TextInputType.name,
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildTextField(
                                    _recipientPhoneController,
                                    'Recipient phone',
                                    fieldKey: _recipientPhoneKey,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Divider(
                              color: colors.backgroundSecondary,
                              height: 32.h,
                              thickness: 1,
                            ),
                            SizedBox(height: 10.h),
                            _buildSectionCard(
                              title: 'Parcel Details',
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          _declaredValueController,
                                          'Declared value (GHS)',
                                          fieldKey: _declaredValueKey,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: _buildTextField(
                                          _weightController,
                                          'Weight (kg)',
                                          fieldKey: _weightKey,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildChoiceSelector(
                                    title: 'Size tier',
                                    selected: _sizeTier,
                                    choices: const [
                                      ('small', 'Small'),
                                      ('medium', 'Medium'),
                                      ('large', 'Large'),
                                      ('xlarge', 'XLarge'),
                                    ],
                                    onSelected: (value) => setState(() {
                                      _sizeTier = value;
                                      _isQuoteReadyForOrder = false;
                                    }),
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildChoiceSelector(
                                    title: 'Payment method',
                                    selected: _paymentMethod,
                                    choices: const [
                                      ('paystack', 'Paystack'),
                                      ('card', 'Card'),
                                    ],
                                    onSelected: (value) => setState(() {
                                      _paymentMethod = value;
                                      _isQuoteReadyForOrder = false;
                                    }),
                                  ),
                                  SizedBox(height: 8.h),
                                  _buildConsentTile(
                                    value: _acceptProhibited,
                                    onChanged: (value) => setState(() {
                                      _acceptProhibited = value;
                                      _isQuoteReadyForOrder = false;
                                    }),
                                    title:
                                        'I confirm this parcel has no prohibited items',
                                  ),
                                  _buildConsentTile(
                                    value: _acceptTerms,
                                    onChanged: (value) =>
                                        setState(() => _acceptTerms = value),
                                    title:
                                        'I accept parcel terms and liability policy',
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 14.h),
                            if (provider.latestQuote != null)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: -20.w,
                                ),
                                child: _QuoteCard(quote: provider.latestQuote!),
                              ),
                            if (provider.latestOrder != null) ...[
                              SizedBox(height: 10.h),
                              OrderCard(
                                title: 'Latest Order',
                                order: provider.latestOrder!,
                                createdAtLabel: _formatDate(
                                  provider.latestOrder!.createdAt,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              OrderActions(
                                isBusy: isAnyOrderActionBusy,
                                canPay: _canRetryPayment(provider.latestOrder!),
                                canCancel: _canCancelOrder(
                                  provider.latestOrder!,
                                ),
                                onViewDetails: () => _viewOrder(
                                  provider,
                                  provider.latestOrder!.id,
                                ),
                                onPay: () => _payForOrder(
                                  provider,
                                  provider.latestOrder!,
                                ),
                                onCancel: () => _cancelOrder(
                                  provider,
                                  provider.latestOrder!,
                                ),
                              ),
                            ],
                            if (provider.isLoadingOrderDetail)
                              Padding(
                                padding: EdgeInsets.only(top: 8.h),
                                child: const LinearProgressIndicator(),
                              ),
                            if (isPaymentBusy)
                              Padding(
                                padding: EdgeInsets.only(top: 8.h),
                                child: Text(
                                  provider.isConfirmingPayment
                                      ? 'Confirming parcel payment...'
                                      : 'Preparing parcel payment...',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (provider.isCancellingOrder)
                              Padding(
                                padding: EdgeInsets.only(top: 8.h),
                                child: Text(
                                  'Cancelling parcel order...',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.only(
                      left: 20.w,
                      right: 20.w,
                      top: 16.h,
                      bottom: padding.bottom + 16.h,
                    ),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      border: Border(
                        top: BorderSide(
                          color: colors.backgroundSecondary,
                          width: 1,
                        ),
                      ),
                    ),
                    child: AppButton(
                      width: double.infinity,
                      onPressed: showCreateOrderCta
                          ? (provider.isCreatingOrder
                                ? () {}
                                : () => _createOrder(provider))
                          : _getQuote,
                      isLoading: showCreateOrderCta
                          ? provider.isCreatingOrder
                          : false,
                      buttonText: showCreateOrderCta
                          ? 'Create Order'
                          : 'Get Quote',
                      height: KWidgetSize.buttonHeight.h,
                      borderRadius: KBorderSize.borderMedium,
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                      backgroundColor: showCreateOrderCta
                          ? colors.accentOrange
                          : colors.accentOrange,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        SizedBox(height: 8.h),
        child,
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    final colors = context.appColors;
    return Text(
      title,
      style: TextStyle(
        fontFamily: "Lato",
        package: 'grab_go_shared',
        color: colors.textPrimary,
        fontSize: 16.sp,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildMapPickTile({
    required String title,
    required VoidCallback onTap,
  }) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: colors.accentOrange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Row(
          children: [
            SvgPicture.asset(
              Assets.icons.mapPin,
              package: 'grab_go_shared',
              height: 18.h,
              width: 18.w,
              colorFilter: ColorFilter.mode(
                colors.accentOrange,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: colors.accentOrange,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(
                colors.accentOrange,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    required String fieldKey,
    TextInputType? keyboardType,
  }) {
    return AppTextInput(
      controller: controller,
      label: label,
      hintText: label,
      keyboardType: keyboardType ?? TextInputType.text,
      fillColor: context.appColors.backgroundSecondary,
      borderRadius: KBorderSize.borderMedium,
      errorText: _fieldErrors[fieldKey],
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      hintStyle: TextStyle(
        color: context.appColors.textSecondary,
        fontSize: 13.sp,
      ),
      onChanged: (_) {
        _clearFieldError(fieldKey);
        _markQuoteStale();
      },
    );
  }

  Widget _buildChoiceSelector({
    required String title,
    required String selected,
    required List<(String value, String label)> choices,
    required ValueChanged<String> onSelected,
  }) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
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
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: choices.map((choice) {
              final isSelected = choice.$1 == selected;
              return GestureDetector(
                onTap: () => onSelected(choice.$1),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: isSelected ? 1 : 0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOutCubic,
                  builder: (context, progress, _) {
                    final backgroundColor = Color.lerp(
                      colors.backgroundSecondary,
                      colors.accentOrange,
                      progress,
                    );
                    final borderColor = Color.lerp(
                      colors.inputBorder.withValues(alpha: 0.45),
                      colors.accentOrange,
                      progress,
                    );
                    final textColor = Color.lerp(
                      colors.textPrimary,
                      Colors.white,
                      progress,
                    );

                    return Transform.scale(
                      scale: 0.985 + (0.015 * progress),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: borderColor!),
                        ),
                        child: Text(
                          choice.$2,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentTile({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
  }) {
    final colors = context.appColors;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
      ),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 6.w),
        value: value,
        activeColor: colors.accentOrange,
        checkColor: Colors.white,
        onChanged: (next) => onChanged(next ?? false),
        title: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final ParcelConfigModel config;

  const _PolicyCard({required this.config});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parcel Policy',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 15.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'Max declared value: GHS ${config.maxDeclaredValueGhs.toStringAsFixed(2)}',
          style: TextStyle(color: colors.textPrimary, fontSize: 13.sp),
        ),
        Text(
          'Liability cap: GHS ${config.liabilityCapGhs.toStringAsFixed(2)}',
          style: TextStyle(color: colors.textPrimary, fontSize: 13.sp),
        ),
        Text(
          'Terms version: ${config.termsVersion}',
          style: TextStyle(color: colors.textPrimary, fontSize: 13.sp),
        ),
        Text(
          'Payment methods: ${config.paymentMethods.apiAccepted.join(', ')}',
          style: TextStyle(color: colors.textPrimary, fontSize: 13.sp),
        ),
        SizedBox(height: 8.h),
        Text(
          config.liabilityDisclaimer,
          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final ParcelQuoteResponseModel quote;

  const _QuoteCard({required this.quote});

  String _formatMoney(String currency, double value) =>
      '$currency ${value.toStringAsFixed(2)}';

  Widget _buildSummaryRow(
    AppColorsExtension colors, {
    required String label,
    required String value,
    bool isEmphasis = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isEmphasis ? colors.textPrimary : colors.textSecondary,
            fontSize: isEmphasis ? 16.sp : 12.sp,
            fontWeight: isEmphasis ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: isEmphasis ? 16.sp : 12.sp,
            fontWeight: isEmphasis ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final summary = quote.quote;
    final breakdown = summary.breakdown;
    final deliveryFee =
        breakdown.baseFee +
        breakdown.distanceFee +
        breakdown.timeFee +
        breakdown.sizeFee +
        breakdown.weightFee;
    final currency = summary.currency;

    return ClipRRect(
      borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: UmbrellaHeader(
              backgroundColor: colors.backgroundSecondary,
              curveDepth: 10,
              numberOfCurves: 24,
              curvesOnTop: true,
              child: Padding(
                padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 12.h),
                child: Text(
                  'Quote Summary',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: colors.backgroundSecondary,
            padding: EdgeInsets.fromLTRB(14.w, 2.h, 14.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(
                      KBorderSize.borderMedium,
                    ),
                    border: Border.all(
                      color: colors.inputBorder.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Items',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Parcel Delivery x1',
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            _formatMoney(currency, summary.subtotal),
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                _buildSummaryRow(
                  colors,
                  label: 'Subtotal',
                  value: _formatMoney(currency, summary.subtotal),
                ),
                SizedBox(height: 6.h),
                _buildSummaryRow(
                  colors,
                  label: 'Delivery Fee',
                  value: _formatMoney(currency, deliveryFee),
                ),
                SizedBox(height: 6.h),
                _buildSummaryRow(
                  colors,
                  label: 'Service Fee',
                  value: _formatMoney(currency, summary.serviceFee),
                ),
                if (summary.rainFee > 0) ...[
                  SizedBox(height: 6.h),
                  _buildSummaryRow(
                    colors,
                    label: 'Rain Surcharge',
                    value: _formatMoney(currency, summary.rainFee),
                  ),
                ],
                SizedBox(height: 8.h),
                _buildSummaryRow(
                  colors,
                  label: 'Total Amount',
                  value: _formatMoney(currency, summary.total),
                  isEmphasis: true,
                ),
                SizedBox(height: 8.h),
                Text(
                  'Est. Delivery: ${summary.estimatedMinutes} min • ${summary.distanceKm.toStringAsFixed(2)} km',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
