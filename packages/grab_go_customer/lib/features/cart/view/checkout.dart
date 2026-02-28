import 'dart:convert';
import 'dart:math' as math;
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_customer/shared/widgets/food_customization_chips.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/shared/models/address_model.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/grabmart/model/grabmart_item.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_customer/shared/services/paystack_service.dart' as paystack;
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';

class Checkout extends StatefulWidget {
  const Checkout({super.key});

  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> with TickerProviderStateMixin {
  static const Duration _addressCacheMaxAge = Duration(minutes: 30);
  static const int _collapsedAddressCount = 3;
  static const int _scheduleSlotCount = 6;
  static const int _defaultScheduleLeadMinutes = 45;
  static const int _defaultScheduleSlotMinutes = 30;
  static const int _defaultScheduleHorizonDays = 7;
  String _selectedAddress = "";
  String _selectedAddressDetails = "";
  String? _selectedAddressId;
  double? _selectedLatitude;
  double? _selectedLongitude;
  List<AddressModel> _savedAddresses = [];
  bool _showAllAddresses = false;
  bool _isScheduleEnabled = false;
  int _selectedScheduleIndex = 0;
  List<_ScheduleSlot> _scheduleSlots = [];
  String? _lastScheduleAvailabilitySignature;
  bool _isScheduleSyncQueued = false;
  bool _isGiftOrder = false;
  _CheckoutPaymentMethod _selectedPaymentMethod = _CheckoutPaymentMethod.card;
  CodEligibilityResult? _codEligibility;
  bool _isCheckingCodEligibility = false;
  bool _didHydrateGiftDraft = false;
  bool _isHydratingGiftDraft = false;
  bool _isLoadingAddresses = false;
  String? _userPhone;
  bool _isProcessingPayment = false;
  static const List<String> _orderNotePresetOptions = <String>[
    'Pack sauces separately',
    'No cutlery',
    'Extra napkins',
    'Seal package well',
  ];
  final Map<String, Set<String>> _selectedOrderNotePresetsByGroup = {};
  final Set<String> _expandedOrderNoteGroups = <String>{};
  final Map<String, TextEditingController> _orderNoteControllersByGroup = {};
  final List<String> _selectedDeliveryInstructions = [];
  bool _showCustomDeliveryInstruction = false;
  bool _showCustomTip = false;
  double _tipAmount = 0.0;

  final TextEditingController _deliveryInstructionController = TextEditingController();
  final TextEditingController _pickupContactNameController = TextEditingController();
  final TextEditingController _pickupContactPhoneController = TextEditingController();
  final TextEditingController _giftRecipientNameController = TextEditingController();
  final TextEditingController _giftRecipientPhoneController = TextEditingController();
  final TextEditingController _giftNoteController = TextEditingController();
  final TextEditingController _giftAddressDetailsController = TextEditingController();
  bool _pickupNoShowAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
    _loadUserPhone();
    _scheduleSlots = _generateScheduleSlots();
    _giftRecipientNameController.addListener(_syncGiftDraftToProvider);
    _giftRecipientPhoneController.addListener(_syncGiftDraftToProvider);
    _giftNoteController.addListener(_syncGiftDraftToProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCodEligibility();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didHydrateGiftDraft) return;
    _hydrateGiftDraftFromProvider();
    _didHydrateGiftDraft = true;
  }

  @override
  void dispose() {
    _giftRecipientNameController.removeListener(_syncGiftDraftToProvider);
    _giftRecipientPhoneController.removeListener(_syncGiftDraftToProvider);
    _giftNoteController.removeListener(_syncGiftDraftToProvider);
    for (final controller in _orderNoteControllersByGroup.values) {
      controller.dispose();
    }
    _deliveryInstructionController.dispose();
    _pickupContactNameController.dispose();
    _pickupContactPhoneController.dispose();
    _giftRecipientNameController.dispose();
    _giftRecipientPhoneController.dispose();
    _giftNoteController.dispose();
    _giftAddressDetailsController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPhone() async {
    try {
      final user = await UserService().getCurrentUser();
      final formatted = _formatPhone(user?.phone);
      if (!mounted) return;
      setState(() {
        _userPhone = formatted;
        if (_pickupContactPhoneController.text.isEmpty && formatted != null) {
          _pickupContactPhoneController.text = _pickupPhoneLocalFromAny(formatted);
        }
      });
    } catch (e) {
      debugPrint('Checkout: Failed to load user phone: $e');
    }
  }

  String? _formatPhone(String? phone) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('0') && digits.length == 10) {
      return '+233${digits.substring(1)}';
    }
    if (digits.length == 9) {
      return '+233$digits';
    }
    if (digits.startsWith('233') && digits.length >= 12) {
      return '+$digits';
    }
    return phone;
  }

  String? _normalizeGhanaPhone(String? phone) {
    if (phone == null) return null;
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    if (digits.startsWith('233') && digits.length == 12) {
      digits = digits.substring(3);
    }
    if (digits.startsWith('0') && digits.length == 10) {
      digits = digits.substring(1);
    }

    if (digits.length != 9) return null;
    return '+233$digits';
  }

  String _pickupPhoneLocalFromAny(String? phone) {
    final normalized = _normalizeGhanaPhone(phone);
    if (normalized == null) return '';
    return normalized.substring(4);
  }

  String _pickupPhoneDisplay() {
    final raw = _pickupContactPhoneController.text.trim();
    if (raw.isEmpty) return '';
    final normalized = _normalizeGhanaPhone(_pickupContactPhoneController.text);
    return normalized ?? '+233$raw';
  }

  void _hydrateGiftDraftFromProvider() {
    final provider = context.read<CartProvider>();
    _isHydratingGiftDraft = true;
    _isGiftOrder = provider.fulfillmentMode == 'pickup' ? false : provider.isGiftOrderDraftEnabled;
    _giftRecipientNameController.text = provider.giftRecipientNameDraft;
    _giftRecipientPhoneController.text = provider.giftRecipientPhoneDraft;
    _giftNoteController.text = provider.giftNoteDraft;
    _isHydratingGiftDraft = false;
  }

  void _syncGiftDraftToProvider() {
    if (!mounted || _isHydratingGiftDraft) return;
    final provider = context.read<CartProvider>();
    final isPickupMode = provider.fulfillmentMode == 'pickup';
    provider.setGiftOrderDraft(
      enabled: isPickupMode ? false : _isGiftOrder,
      recipientName: _giftRecipientNameController.text,
      recipientPhone: _giftRecipientPhoneController.text,
      giftNote: _giftNoteController.text,
      notify: false,
    );
  }

  void _setGiftOrderEnabled(bool enabled) {
    final provider = context.read<CartProvider>();
    final isPickupMode = provider.fulfillmentMode == 'pickup';
    final nextValue = isPickupMode ? false : enabled;
    if (_isGiftOrder == nextValue) return;

    setState(() {
      _isGiftOrder = nextValue;
    });

    provider.setGiftOrderDraft(
      enabled: nextValue,
      recipientName: _giftRecipientNameController.text,
      recipientPhone: _giftRecipientPhoneController.text,
      giftNote: _giftNoteController.text,
    );
  }

  String _addressCacheKey(String userId) => 'user_addresses_$userId';

  Future<_CachedAddresses?> _readCachedAddresses() async {
    try {
      final userId = UserService().getUserId();
      if (userId == null || userId.isEmpty) return null;
      final cachedJson = CacheService.getData(_addressCacheKey(userId));
      if (cachedJson == null || cachedJson.isEmpty) return null;

      final decoded = jsonDecode(cachedJson);
      if (decoded is! Map<String, dynamic>) return null;
      final cachedAtRaw = decoded['cachedAt'];
      final itemsRaw = decoded['items'];
      if (cachedAtRaw is! String || itemsRaw is! List) return null;

      final cachedAt = DateTime.tryParse(cachedAtRaw);
      if (cachedAt == null) return null;
      final isStale = DateTime.now().difference(cachedAt) > _addressCacheMaxAge;

      final addresses = <AddressModel>[];
      for (final entry in itemsRaw) {
        if (entry is Map<String, dynamic>) {
          addresses.add(AddressModel.fromJson(entry));
        } else if (entry is Map) {
          addresses.add(AddressModel.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
      return _CachedAddresses(addresses: addresses, isStale: isStale);
    } catch (e) {
      debugPrint('❌ Checkout: Failed to read cached addresses: $e');
      return null;
    }
  }

  Future<void> _saveAddressesToCache(List<AddressModel> addresses) async {
    try {
      final userId = UserService().getUserId();
      if (userId == null || userId.isEmpty) return;
      final payload = {
        'cachedAt': DateTime.now().toIso8601String(),
        'items': addresses.map((address) => address.toJson()).toList(),
      };
      await CacheService.saveData(_addressCacheKey(userId), jsonEncode(payload));
    } catch (e) {
      debugPrint('❌ Checkout: Failed to cache addresses: $e');
    }
  }

  AddressModel? _findSelectedAddress(List<AddressModel> addresses) {
    if (_selectedAddressId == null) return null;
    for (final address in addresses) {
      if (_addressSelectionKey(address) == _selectedAddressId) {
        return address;
      }
    }
    return null;
  }

  void _applyAddresses(List<AddressModel> addresses) {
    AddressModel? selectedAddress = _findSelectedAddress(addresses);
    selectedAddress ??= addresses.isNotEmpty
        ? addresses.firstWhere((address) => address.isDefault, orElse: () => addresses.first)
        : null;
    final String? selectedKey = selectedAddress != null ? _addressSelectionKey(selectedAddress) : null;
    final int selectedIndex = selectedKey == null
        ? -1
        : addresses.indexWhere((address) => _addressSelectionKey(address) == selectedKey);
    final bool shouldExpandForSelection = selectedIndex >= _collapsedAddressCount;

    if (!mounted) return;
    setState(() {
      _savedAddresses = addresses;
      _isLoadingAddresses = false;
      if (addresses.length <= _collapsedAddressCount) {
        _showAllAddresses = false;
      } else if (shouldExpandForSelection) {
        _showAllAddresses = true;
      }

      if (selectedAddress != null) {
        _selectedAddressId = _addressSelectionKey(selectedAddress);
        _selectedAddress = selectedAddress.formattedAddress;
        _selectedAddressDetails = selectedAddress.formattedAddress;
        _selectedLatitude = selectedAddress.latitude;
        _selectedLongitude = selectedAddress.longitude;
      }
    });

    if (selectedAddress != null) {
      _updateDeliveryLocation(selectedAddress.latitude, selectedAddress.longitude);
    }
  }

  Future<void> _loadSavedAddresses() async {
    if (_isLoadingAddresses) return;

    setState(() {
      _isLoadingAddresses = true;
    });

    final cached = await _readCachedAddresses();
    if (cached != null) {
      _applyAddresses(cached.addresses);
      if (!cached.isStale) {
        return;
      }
    }

    try {
      final response = await addressApiService.getUserAddresses();
      if (!response.isSuccessful || response.body == null) {
        if (mounted) {
          setState(() {
            _isLoadingAddresses = false;
          });
        }
        return;
      }

      final body = response.body!;
      final data = body['data'];
      final List<AddressModel> addresses = [];

      if (data is List) {
        for (final entry in data) {
          if (entry is Map<String, dynamic>) {
            addresses.add(AddressModel.fromJson(entry));
          } else if (entry is Map) {
            addresses.add(AddressModel.fromJson(Map<String, dynamic>.from(entry)));
          }
        }
      }

      _applyAddresses(addresses);
      await _saveAddressesToCache(addresses);
    } catch (e) {
      debugPrint('❌ Checkout: Failed to load saved addresses: $e');
      if (mounted) {
        setState(() {
          _isLoadingAddresses = false;
        });
      }
    }
  }

  void _updateDeliveryLocation(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return;
    final cartProvider = context.read<CartProvider>();
    cartProvider.updateDeliveryLocation(latitude: latitude, longitude: longitude);
  }

  Future<void> _openAddressPickerFromCheckout() async {
    final changed = await context.push("/confirm-address?returnTo=previous");
    if (!mounted) return;

    if (changed == true) {
      final confirmedAddress = context.read<NativeLocationProvider>().confirmedAddress;
      if (confirmedAddress != null) {
        setState(() {
          _selectedAddressId = _addressSelectionKey(confirmedAddress);
          _selectedAddress = confirmedAddress.formattedAddress;
          _selectedAddressDetails = confirmedAddress.formattedAddress;
          _selectedLatitude = confirmedAddress.latitude;
          _selectedLongitude = confirmedAddress.longitude;
        });
        _updateDeliveryLocation(confirmedAddress.latitude, confirmedAddress.longitude);
      }
    }

    await _loadSavedAddresses();
  }

  String _addressSelectionKey(AddressModel address) {
    return address.id ?? '${address.label.name}_${address.formattedAddress}_${address.latitude}_${address.longitude}';
  }

  String _addressTitle(AddressModel address) {
    if (address.customLabel != null && address.customLabel!.trim().isNotEmpty) {
      return address.customLabel!;
    }
    if (address.label == AddressLabel.work) return "Office";
    if (address.label == AddressLabel.other) return "Other";
    return "Home";
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationProvider = context.watch<NativeLocationProvider>();
    final cartProvider = context.read<CartProvider>();
    final confirmedAddress = locationProvider.confirmedAddress;

    final bool hasInitialCoords = _selectedLatitude != null && _selectedLongitude != null;
    final double? fallbackLat = confirmedAddress?.latitude ?? locationProvider.latitude;
    final double? fallbackLng = confirmedAddress?.longitude ?? locationProvider.longitude;
    if (!hasInitialCoords && fallbackLat != null && fallbackLng != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedLatitude = fallbackLat;
          _selectedLongitude = fallbackLng;
        });
        cartProvider.updateDeliveryLocation(latitude: fallbackLat, longitude: fallbackLng);
      });
    }
    if (!_isLoadingAddresses && _savedAddresses.isEmpty && confirmedAddress != null && _selectedAddressId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedAddressId = _addressSelectionKey(confirmedAddress);
          _selectedAddress = confirmedAddress.formattedAddress;
          _selectedAddressDetails = confirmedAddress.formattedAddress;
          _selectedLatitude = confirmedAddress.latitude;
          _selectedLongitude = confirmedAddress.longitude;
        });
        _updateDeliveryLocation(confirmedAddress.latitude, confirmedAddress.longitude);
      });
    }

    final systemUiOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: colors.backgroundPrimary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundPrimary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Consumer<CartProvider>(
            builder: (context, provider, child) {
              final bool isPickupTab = context.watch<NavigationProvider>().selectedIndex == 1;
              if (isPickupTab && provider.fulfillmentMode != 'pickup') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  context.read<CartProvider>().setFulfillmentMode('pickup');
                });
              }
              _syncScheduleSlotsForProvider(provider);
              final double subtotal = provider.subtotal;
              final double deliveryFee = provider.deliveryFee;
              final double serviceFee = provider.serviceFee;
              final double rainFee = provider.rainFee;
              final bool isPickupMode = provider.fulfillmentMode == 'pickup' || isPickupTab;
              final bool isMixedCheckout = _isMixedCartCheckout(provider, isPickupMode: isPickupMode);
              _syncMixedCheckoutState(provider, isPickupMode: isPickupMode);
              final double creditsApplied = _effectiveCreditsAppliedForCheckout(provider, isPickupMode: isPickupMode);
              final double effectiveTip = isPickupMode ? 0.0 : _tipAmount;
              final double total = _checkoutGrandTotal(provider, isPickupMode: isPickupMode);
              final bool isCashOnDelivery = !isMixedCheckout && _isCashOnDeliverySelected(isPickupMode: isPickupMode);
              final double payableNowAmount = isCashOnDelivery
                  ? _codUpfrontAmountForCheckout(provider, isPickupMode: isPickupMode)
                  : total;
              final bool isPricingLoading = provider.isPricingLoading;
              final bool hasMoreAddresses = _savedAddresses.length > _collapsedAddressCount;
              final int hiddenAddressCount = math.max(0, _savedAddresses.length - _collapsedAddressCount);
              final List<AddressModel> addressesToShow = _showAllAddresses
                  ? _savedAddresses
                  : _savedAddresses.take(_collapsedAddressCount).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: padding.top + 10, left: 20.w, right: 20.w, bottom: 16.h),
                    child: Row(
                      children: [
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
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
                                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Text(
                          "Checkout",
                          style: TextStyle(
                            fontFamily: "Lato",
                            package: 'grab_go_shared',
                            color: colors.textPrimary,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: colors.backgroundSecondary, height: 1.h, thickness: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isPickupMode) ...[
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                              child: Text(
                                _isGiftOrder ? "Recipient Delivery Address" : "Delivery Address",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _buildPickOnMapTile(context),
                            if (_isLoadingAddresses) ...[
                              _buildAddressShimmerTile(colors, isDark),
                              _buildAddressShimmerTile(colors, isDark),
                            ],
                            if (!_isLoadingAddresses && _savedAddresses.isNotEmpty)
                              AnimatedSize(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeInOut,
                                alignment: Alignment.topCenter,
                                clipBehavior: Clip.hardEdge,
                                child: Column(
                                  children: List.generate(addressesToShow.length, (index) {
                                    final address = addressesToShow[index];
                                    final bool showDivider = index < addressesToShow.length - 1;

                                    return Column(
                                      children: [
                                        _buildAddressTile(
                                          id: _addressSelectionKey(address),
                                          title: _addressTitle(address),
                                          phone: _userPhone,
                                          address: address.formattedAddress,
                                          latitude: address.latitude,
                                          longitude: address.longitude,
                                          context: context,
                                        ),
                                        if (showDivider)
                                          Padding(
                                            padding: EdgeInsets.only(left: 56.w, right: 20.w),
                                            child: Divider(
                                              height: 8.h,
                                              thickness: 0.8,
                                              color: colors.inputBorder.withValues(alpha: 0.35),
                                            ),
                                          ),
                                      ],
                                    );
                                  }),
                                ),
                              ),
                            if (!_isLoadingAddresses && _savedAddresses.isNotEmpty && hasMoreAddresses)
                              _buildAddressListToggle(colors, hiddenAddressCount),
                            if (!_isLoadingAddresses && _savedAddresses.isEmpty && confirmedAddress != null)
                              _buildAddressTile(
                                id: _addressSelectionKey(confirmedAddress),
                                title: _addressTitle(confirmedAddress),
                                phone: _userPhone,
                                address: confirmedAddress.formattedAddress,
                                latitude: confirmedAddress.latitude,
                                longitude: confirmedAddress.longitude,
                                context: context,
                              ),
                            if (!_isLoadingAddresses && _savedAddresses.isEmpty && confirmedAddress == null)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                                child: Text(
                                  "No saved addresses yet.",
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            if (!_isLoadingAddresses && _savedAddresses.isEmpty) _buildCurrentLocationTile(context),
                            SizedBox(height: 12.h),
                            if (!isMixedCheckout) ...[
                              _buildScheduleSection(colors, provider),
                              SizedBox(height: 8.h),
                              _buildGiftOrderSection(colors),
                            ] else ...[
                              _buildMixedCheckoutInfoBanner(colors),
                            ],
                            SizedBox(height: 8.h),
                          ] else ...[
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                              child: Text(
                                "Pickup Contact",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: AppTextInput(
                                controller: _pickupContactNameController,
                                hintText: "Contact name",
                                fillColor: colors.backgroundPrimary,
                                borderColor: colors.inputBorder,
                                keyboardType: TextInputType.name,
                                borderRadius: 12.r,
                                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: AppTextInput(
                                controller: _pickupContactPhoneController,
                                hintText: "501234567",
                                fillColor: colors.backgroundPrimary,
                                borderColor: colors.inputBorder,
                                keyboardType: TextInputType.phone,
                                prefixIcon: _buildGhanaPhonePrefix(context),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                borderRadius: 12.r,
                                contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _pickupNoShowAccepted,
                                    onChanged: (value) {
                                      setState(() {
                                        _pickupNoShowAccepted = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 10.h),
                                      child: Text(
                                        "I understand that if I do not pick up within 30 minutes after ready, the order will be cancelled and no refund will be issued.",
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8.h),
                          ],

                          _buildOrderNotesSection(provider: provider, colors: colors, isMixedCheckout: isMixedCheckout),

                          if (!isPickupMode) ...[
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                              child: Text(
                                "Delivery Instructions",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                children: [
                                  _buildDeliveryInstructionChip("Leave at door", colors),
                                  _buildDeliveryInstructionChip("Ring doorbell", colors),
                                  _buildDeliveryInstructionChip("Text on arrival", colors),
                                  _buildDeliveryInstructionChip("Call on arrival", colors),
                                  _buildCustomDeliveryInstructionChip(colors),
                                ],
                              ),
                            ),
                            _buildAnimatedInstructionPanel(
                              isVisible: _showCustomDeliveryInstruction,
                              child: Padding(
                                padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 12.h),
                                child: Container(
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: colors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: TextField(
                                    controller: _deliveryInstructionController,
                                    maxLines: 2,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "Enter custom delivery instructions",
                                      hintStyle: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 16.h),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                              child: Text(
                                "Support Your Rider (Optional)",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                children: [
                                  _buildTipChip(0.0, "No tip", colors),
                                  _buildTipChip(2.0, "GHS 2", colors),
                                  _buildTipChip(5.0, "GHS 5", colors),
                                  _buildTipChip(10.0, "GHS 10", colors),
                                  _buildCustomTipChip(colors),
                                ],
                              ),
                            ),
                            _buildAnimatedInstructionPanel(
                              isVisible: _showCustomTip,
                              child: Padding(
                                padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 12.h),
                                child: Container(
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: colors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      final amount = double.tryParse(value);
                                      if (amount != null && amount >= 0) {
                                        setState(() {
                                          _tipAmount = amount;
                                        });
                                      }
                                    },
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: "Enter custom tip amount (GHS)",
                                      prefixText: "GHS ",
                                      prefixStyle: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      hintStyle: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          SizedBox(height: 16.h),
                          _buildPaymentMethodSection(colors, provider, isPickupMode: isPickupMode),
                          SizedBox(height: 16.h),

                          SizedBox(
                            width: double.infinity,
                            child: UmbrellaHeader(
                              backgroundColor: colors.backgroundSecondary,
                              curveDepth: 10,
                              numberOfCurves: 24,
                              curvesOnTop: true,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
                                child: Text(
                                  "Order Summary",
                                  style: TextStyle(
                                    fontFamily: "Lato",
                                    package: 'grab_go_shared',
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                                  child: Column(
                                    children: [
                                      _buildCheckoutLineItemsCard(provider, colors),
                                      SizedBox(height: 10.h),
                                      if (isMixedCheckout) ...[
                                        _buildGroupedVendorBreakdown(provider, colors),
                                        SizedBox(height: 10.h),
                                      ],
                                      _buildPriceRow(context, "Subtotal", subtotal, colors, false, false),
                                      if (!isPickupMode) ...[
                                        SizedBox(height: 6.h),
                                        _buildPriceRow(
                                          context,
                                          "Delivery Fee",
                                          deliveryFee,
                                          colors,
                                          false,
                                          true,
                                          infoType: _FeeInfoType.delivery,
                                          isLoading: isPricingLoading,
                                        ),
                                      ],
                                      SizedBox(height: 6.h),
                                      _buildPriceRow(
                                        context,
                                        "Service Fee",
                                        serviceFee,
                                        colors,
                                        false,
                                        true,
                                        infoType: _FeeInfoType.service,
                                        isLoading: isPricingLoading,
                                      ),
                                      if (!isPickupMode && rainFee > 0) ...[
                                        SizedBox(height: 6.h),
                                        _buildPriceRow(
                                          context,
                                          "Rain Fee",
                                          rainFee,
                                          colors,
                                          false,
                                          true,
                                          infoType: _FeeInfoType.rain,
                                        ),
                                      ],
                                      if (creditsApplied > 0) ...[
                                        SizedBox(height: 6.h),
                                        _buildPriceRow(
                                          context,
                                          "Credits Applied",
                                          -creditsApplied,
                                          colors,
                                          false,
                                          false,
                                        ),
                                      ],
                                      if (!isPickupMode && effectiveTip > 0) ...[
                                        SizedBox(height: 6.h),
                                        _buildPriceRow(context, "Tip", effectiveTip, colors, false, false),
                                      ],
                                      SizedBox(height: 6.h),
                                      _buildTotalRow(
                                        context,
                                        total,
                                        creditsApplied,
                                        colors,
                                        isLoading: isPricingLoading,
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                                  child: Text(
                                    _formatEstimatedDelivery(
                                      provider.cartItems,
                                      providerCount: provider.providerCount,
                                      minMinutes: provider.estimatedDeliveryMin,
                                      maxMinutes: provider.estimatedDeliveryMax,
                                      completionMinMinutes: provider.estimatedDeliveryCompletionMin,
                                      completionMaxMinutes: provider.estimatedDeliveryCompletionMax,
                                      isPickupMode: isPickupMode,
                                    ),
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 16.h, bottom: padding.bottom + 16.h),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      border: Border(top: BorderSide(color: colors.backgroundSecondary, width: 1)),
                    ),

                    child: GestureDetector(
                      onTap: _isProcessingPayment ? null : () => _onProceedToPayment(context, provider, colors),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor: Colors.white.withValues(alpha: 0.2),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 16.h),
                            decoration: BoxDecoration(
                              color: _isProcessingPayment
                                  ? colors.accentOrange.withValues(alpha: 0.5)
                                  : colors.accentOrange,
                              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _isProcessingPayment ? "Confirming..." : "Confirm order",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.sp),
                                  ),
                                  if (!_isProcessingPayment)
                                    Text(
                                      payableNowAmount > 0 ? " (GHS ${payableNowAmount.toStringAsFixed(2)})" : "",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15.sp,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildPriceRow(
    BuildContext context,
    String label,
    double amount,
    AppColorsExtension colors,
    bool isTotal,
    bool info, {
    _FeeInfoType? infoType,
    bool isLoading = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 13.sp,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        info
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: infoType == null ? null : () => _showFeeInfoSheet(context, colors, infoType),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: EdgeInsets.all(8.0.r),
                    child: SvgPicture.asset(
                      Assets.icons.infoCircle,
                      package: "grab_go_shared",
                      height: 10.h,
                      width: 10.w,
                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
        const Spacer(),
        isLoading
            ? Text(
                "...",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
                ),
              )
            : Text(
                "GHS ${amount.toStringAsFixed(2)}",
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
      ],
    );
  }

  Widget _buildTotalRow(
    BuildContext context,
    double total,
    double creditsApplied,
    AppColorsExtension colors, {
    bool isLoading = false,
  }) {
    if (isLoading) {
      return Row(
        children: [
          Text(
            "Total Amount",
            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            "...",
            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    final double? originalTotal = creditsApplied > 0 ? total + creditsApplied : null;

    return Row(
      children: [
        Text(
          "Total Amount",
          style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        if (originalTotal != null)
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "GHS ${originalTotal.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                TextSpan(
                  text: " / ",
                  style: TextStyle(color: colors.textSecondary, fontSize: 16.sp, fontWeight: FontWeight.w400),
                ),
                TextSpan(
                  text: "GHS ${total.toStringAsFixed(2)}",
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          Text(
            "GHS ${total.toStringAsFixed(2)}",
            style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  void _showFeeInfoSheet(BuildContext context, AppColorsExtension colors, _FeeInfoType type) {
    final title = type == _FeeInfoType.delivery
        ? "Delivery Fee"
        : type == _FeeInfoType.service
        ? "Service Fee"
        : "Rain Fee";
    final description = type == _FeeInfoType.delivery
        ? "This helps cover the cost of getting your order from the vendor to your door."
        : type == _FeeInfoType.service
        ? "This supports platform operations and keeps the service running smoothly."
        : "This is applied when it's raining to support safe and reliable deliveries.";

    final details = type == _FeeInfoType.delivery
        ? const [
            _FeeInfoDetail(
              title: "Distance-based",
              body: "Calculated using the distance from the vendor to your delivery address.",
            ),
            _FeeInfoDetail(
              title: "Fair limits",
              body: "A minimum and maximum are applied to keep pricing predictable.",
            ),
            _FeeInfoDetail(title: "Courier coverage", body: "Helps cover rider time, fuel, and delivery handling."),
          ]
        : type == _FeeInfoType.service
        ? const [
            _FeeInfoDetail(
              title: "Platform support",
              body: "Keeps the app running, including customer support and order processing.",
            ),
            _FeeInfoDetail(
              title: "Order value based",
              body: "Scales with your subtotal so larger orders contribute slightly more.",
            ),
            _FeeInfoDetail(
              title: "Lower delivery fees",
              body: "Helps reduce delivery charges by spreading costs across orders.",
            ),
          ]
        : const [
            _FeeInfoDetail(
              title: "Weather-based",
              body: "Applied only when active rain is detected for your delivery area.",
            ),
            _FeeInfoDetail(
              title: "Rider safety",
              body: "Helps cover extra time and protective handling in wet conditions.",
            ),
            _FeeInfoDetail(title: "Transparent pricing", body: "The fee is fixed and visible before checkout."),
          ];

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: colors.divider, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                title,
                style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8.h),
              Text(
                description,
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 12.h),
              ...details.map((detail) => _buildInfoDetail(detail, colors)),
              SizedBox(height: 6.h),
              Text(
                "Fees can vary by location, vendor, and promotions.",
                style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoDetail(_FeeInfoDetail detail, AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            margin: EdgeInsets.only(top: 6.h),
            decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.title,
                  style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 2.h),
                Text(
                  detail.body,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isMixedCartCheckout(CartProvider provider, {required bool isPickupMode}) {
    return !isPickupMode && provider.providerCount > 1;
  }

  void _syncMixedCheckoutState(CartProvider provider, {required bool isPickupMode}) {
    final isMixedCheckout = _isMixedCartCheckout(provider, isPickupMode: isPickupMode);
    if (!isMixedCheckout) return;

    final bool shouldResetPaymentMethod = _selectedPaymentMethod != _CheckoutPaymentMethod.card;
    final bool shouldDisableSchedule = _isScheduleEnabled;
    final bool shouldDisableGift = _isGiftOrder;

    if (!shouldResetPaymentMethod && !shouldDisableSchedule && !shouldDisableGift) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedPaymentMethod = _CheckoutPaymentMethod.card;
        _isScheduleEnabled = false;
        _selectedScheduleIndex = 0;
        if (shouldDisableGift) {
          _isGiftOrder = false;
        }
      });
      if (shouldDisableGift) {
        provider.setGiftOrderDraft(
          enabled: false,
          recipientName: _giftRecipientNameController.text,
          recipientPhone: _giftRecipientPhoneController.text,
          giftNote: _giftNoteController.text,
        );
      }
    });
  }

  bool _isCashOnDeliverySelected({required bool isPickupMode}) {
    return !isPickupMode && _selectedPaymentMethod == _CheckoutPaymentMethod.cash;
  }

  String _selectedPaymentMethodApiValue({required bool isPickupMode}) {
    return _isCashOnDeliverySelected(isPickupMode: isPickupMode) ? "cash" : "card";
  }

  String _selectedPaymentMethodLabel({required bool isPickupMode}) {
    return _isCashOnDeliverySelected(isPickupMode: isPickupMode) ? "Cash on Delivery" : "Paystack";
  }

  double _effectiveCreditsAppliedForCheckout(CartProvider provider, {required bool isPickupMode}) {
    if (_isCashOnDeliverySelected(isPickupMode: isPickupMode)) {
      return 0.0;
    }
    return provider.creditsApplied;
  }

  double _checkoutGrandTotal(CartProvider provider, {required bool isPickupMode}) {
    final double tipAmount = isPickupMode ? 0.0 : _tipAmount;
    final double baseTotal = provider.total + tipAmount;
    if (_isCashOnDeliverySelected(isPickupMode: isPickupMode)) {
      return baseTotal + provider.creditsApplied;
    }
    return baseTotal;
  }

  double _codUpfrontAmountForCheckout(CartProvider provider, {required bool isPickupMode}) {
    if (isPickupMode) {
      return _checkoutGrandTotal(provider, isPickupMode: isPickupMode);
    }
    return provider.deliveryFee + provider.rainFee;
  }

  double _codRemainingAmountForCheckout(CartProvider provider, {required bool isPickupMode}) {
    if (!_isCashOnDeliverySelected(isPickupMode: isPickupMode)) {
      return 0.0;
    }
    final orderTotal = _checkoutGrandTotal(provider, isPickupMode: isPickupMode);
    final upfrontAmount = _codUpfrontAmountForCheckout(provider, isPickupMode: isPickupMode);
    return math.max(0, orderTotal - upfrontAmount);
  }

  Future<CodEligibilityResult?> _refreshCodEligibility() async {
    if (!mounted || _isCheckingCodEligibility) return null;
    setState(() {
      _isCheckingCodEligibility = true;
    });

    final result = await OrderServiceWrapper().getCodEligibility();
    if (!mounted) return null;

    setState(() {
      _isCheckingCodEligibility = false;
      _codEligibility = result;
      if (!result.eligible && _selectedPaymentMethod == _CheckoutPaymentMethod.cash) {
        _selectedPaymentMethod = _CheckoutPaymentMethod.card;
      }
    });
    return result;
  }

  _CodEligibilitySheetContent _buildCodEligibilitySheetContent(CodEligibilityResult eligibility) {
    switch (eligibility.code) {
      case 'COD_TRUST_THRESHOLD_NOT_MET':
        final delivered = eligibility.deliveredPrepaidOrders ?? 0;
        final minimum = eligibility.minPrepaidDeliveredOrders ?? delivered;
        final remaining = math.max(0, minimum - delivered);
        final progress = minimum > 0 ? '$delivered / $minimum prepaid delivered orders completed' : null;
        return _CodEligibilitySheetContent(
          title: 'Unlock Cash on Delivery',
          message: remaining > 0
              ? 'You need $remaining more prepaid delivered ${remaining == 1 ? 'order' : 'orders'} before Cash on Delivery is unlocked.'
              : 'Complete more prepaid delivered orders to unlock Cash on Delivery.',
          steps: const [
            'Use Pay Online for your next orders.',
            'Ensure those orders are marked delivered.',
            'Avoid cancellations and no-shows while building trust.',
          ],
          progress: progress,
        );
      case 'COD_PHONE_REQUIRED':
        return const _CodEligibilitySheetContent(
          title: 'Add Phone Number',
          message: 'Cash on delivery requires a phone number on your account.',
          steps: ['Open Profile settings.', 'Add your phone number.', 'Verify the number with OTP.'],
        );
      case 'COD_PHONE_NOT_VERIFIED':
        return const _CodEligibilitySheetContent(
          title: 'Verify Your Phone',
          message: 'Your phone number must be verified before Cash on Delivery can be used.',
          steps: ['Open Profile settings.', 'Tap phone verification.', 'Complete OTP verification.'],
        );
      case 'COD_ACTIVE_ORDER_EXISTS':
        return const _CodEligibilitySheetContent(
          title: 'Complete Current Cash on Delivery Order',
          message: 'You already have an active cash-on-delivery order.',
          steps: [
            'Wait for the current Cash on Delivery order to be completed.',
            'Then return to checkout and select Cash on Delivery again.',
          ],
        );
      case 'COD_DISABLED_NO_SHOW':
        return const _CodEligibilitySheetContent(
          title: 'Cash on Delivery Temporarily Disabled',
          message: 'Cash on Delivery is disabled on your account due to previous no-show activity.',
          steps: [
            'Use Pay Online for upcoming orders.',
            'Complete orders successfully to restore trust.',
            'Contact support if this was applied in error.',
          ],
        );
      case 'COD_DISABLED':
        return _CodEligibilitySheetContent(
          title: 'Cash on Delivery Unavailable',
          message: eligibility.message,
          steps: const ['Use Pay Online for now and try COD again later.'],
        );
      default:
        return _CodEligibilitySheetContent(
          title: 'Cash on Delivery Not Available',
          message: eligibility.message,
          steps: const ['Use Pay Online to continue checkout.'],
        );
    }
  }

  void _showCodEligibilityBottomSheet(CodEligibilityResult eligibility) {
    final colors = context.appColors;
    final content = _buildCodEligibilitySheetContent(eligibility);

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          ),
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(color: colors.divider, borderRadius: BorderRadius.circular(999)),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                content.title,
                style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 8.h),
              Text(
                content.message,
                style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w500),
              ),
              if (content.progress != null) ...[
                SizedBox(height: 10.h),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(KBorderSize.borderSmall),
                  ),
                  child: Text(
                    content.progress!,
                    style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              SizedBox(height: 12.h),
              ...content.steps.map(
                (step) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 6.h),
                        child: Container(
                          width: 5.w,
                          height: 5.h,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.textSecondary),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCodSelectionTap({required bool isPickupMode}) async {
    if (isPickupMode) return;

    if (_isCheckingCodEligibility && _codEligibility == null) {
      return;
    }

    final eligibility = _codEligibility ?? await _refreshCodEligibility();
    if (!mounted) return;

    if (eligibility == null) {
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: "We couldn't check COD eligibility right now. Please try again.",
        maxLines: 3,
      );
      return;
    }

    if (eligibility.eligible) {
      setState(() {
        _selectedPaymentMethod = _CheckoutPaymentMethod.cash;
      });
      return;
    }

    _showCodEligibilityBottomSheet(eligibility);
  }

  Future<void> _onProceedToPayment(BuildContext context, CartProvider provider, AppColorsExtension colors) async {
    if (_isProcessingPayment) return;

    final bool isPickupTab = context.read<NavigationProvider>().selectedIndex == 1;
    if (isPickupTab && provider.fulfillmentMode != 'pickup') {
      await provider.setFulfillmentMode('pickup');
      if (!mounted) return;
    }

    final bool isPickupMode = provider.fulfillmentMode == 'pickup';
    final bool isMixedCheckout = _isMixedCartCheckout(provider, isPickupMode: isPickupMode);
    if (isMixedCheckout) {
      if (_selectedPaymentMethod != _CheckoutPaymentMethod.card || _isGiftOrder || _isScheduleEnabled) {
        setState(() {
          _selectedPaymentMethod = _CheckoutPaymentMethod.card;
          _isGiftOrder = false;
          _isScheduleEnabled = false;
          _selectedScheduleIndex = 0;
        });
      }
      provider.setGiftOrderDraft(
        enabled: false,
        recipientName: _giftRecipientNameController.text,
        recipientPhone: _giftRecipientPhoneController.text,
        giftNote: _giftNoteController.text,
        notify: false,
      );
    }
    final bool wantsCashOnDelivery = _isCashOnDeliverySelected(isPickupMode: isPickupMode);
    if (!isPickupMode && !isMixedCheckout && wantsCashOnDelivery) {
      final eligibility = _codEligibility ?? await _refreshCodEligibility();
      if (!mounted) return;
      if (eligibility?.eligible != true) {
        if (eligibility != null) {
          _showCodEligibilityBottomSheet(eligibility);
        } else {
          AppToastMessage.show(
            context: context,
            backgroundColor: colors.error,
            message: "We couldn't verify COD eligibility right now. Please try again.",
            maxLines: 3,
          );
        }
        return;
      }
    }

    if (provider.isPricingLoading) {
      AppToastMessage.show(
        context: context,
        backgroundColor: colors.error,
        message: "Calculating fees, please wait...",
      );
      return;
    }

    if (provider.cartItems.isEmpty) {
      AppToastMessage.show(context: context, backgroundColor: colors.error, message: "Your cart is empty.");
      return;
    }

    final bool hasValidScheduleSelection = _ensureScheduleSelectionAvailable(provider);
    if (!hasValidScheduleSelection) {
      AppToastMessage.show(
        context: context,
        message: _getNoScheduleSlotsMessage(provider.scheduleAvailability),
        backgroundColor: colors.error,
        maxLines: 3,
      );
      return;
    }

    final preSyncIssue = _getPrePaymentBlockingIssue(
      provider,
      allowClosedVendor: _shouldAllowClosedVendorPreCheck(provider),
    );
    if (preSyncIssue != null) {
      AppToastMessage.show(context: context, message: preSyncIssue, backgroundColor: colors.error, maxLines: 3);
      return;
    }

    setState(() {
      _isProcessingPayment = true;
    });

    bool syncSucceeded = true;
    try {
      syncSucceeded = await provider.syncFromBackend();
    } catch (e) {
      debugPrint('Checkout: pre-payment cart sync failed: $e');
      syncSucceeded = false;
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }

    if (!mounted) return;
    if (!syncSucceeded) {
      AppToastMessage.show(
        context: context,
        backgroundColor: colors.error,
        message: "Couldn't verify latest availability. Please refresh and try again.",
        maxLines: 3,
      );
      return;
    }

    if (provider.cartItems.isEmpty) {
      AppToastMessage.show(
        context: context,
        backgroundColor: colors.error,
        message: "Some items in your cart are no longer available.",
        maxLines: 2,
      );
      return;
    }

    if (!_ensureScheduleSelectionAvailable(provider)) {
      AppToastMessage.show(
        context: context,
        message: _getNoScheduleSlotsMessage(provider.scheduleAvailability),
        backgroundColor: colors.error,
        maxLines: 3,
      );
      return;
    }

    final postSyncIssue = _getPrePaymentBlockingIssue(
      provider,
      allowClosedVendor: _shouldAllowClosedVendorPreCheck(provider),
    );
    if (postSyncIssue != null) {
      AppToastMessage.show(context: context, message: postSyncIssue, backgroundColor: colors.error, maxLines: 3);
      return;
    }

    if (_selectedLatitude != null && _selectedLongitude != null) {
      provider.updateDeliveryLocation(latitude: _selectedLatitude, longitude: _selectedLongitude);
    }

    if (provider.fulfillmentMode == 'pickup') {
      final normalizedPickupPhone = _normalizeGhanaPhone(_pickupContactPhoneController.text);
      if (_pickupContactNameController.text.trim().isEmpty || _pickupContactPhoneController.text.trim().isEmpty) {
        AppToastMessage.show(
          context: context,
          backgroundColor: colors.error,
          message: "Please provide pickup contact details.",
          maxLines: 2,
        );
        return;
      }
      if (normalizedPickupPhone == null) {
        AppToastMessage.show(
          context: context,
          backgroundColor: colors.error,
          message: "Please enter a valid Ghana phone number.",
          maxLines: 2,
        );
        return;
      }
      if (!_pickupNoShowAccepted) {
        AppToastMessage.show(
          context: context,
          backgroundColor: colors.error,
          message: "Please accept the no-show policy to continue.",
          maxLines: 2,
        );
        return;
      }
    } else if (_selectedAddress.isEmpty) {
      AppToastMessage.show(
        context: context,
        backgroundColor: colors.error,
        message: "Please select a delivery address.",
      );
      return;
    }

    if (provider.fulfillmentMode != 'pickup' && _isGiftOrder) {
      if (_giftRecipientNameController.text.trim().isEmpty) {
        AppToastMessage.show(
          context: context,
          backgroundColor: colors.error,
          maxLines: 2,
          message: "Recipient name is required for gift orders.",
        );
        return;
      }
      if (_giftRecipientPhoneController.text.trim().isNotEmpty &&
          _normalizeGhanaPhone(_giftRecipientPhoneController.text) == null) {
        AppToastMessage.show(
          context: context,
          backgroundColor: colors.error,
          message: "Please enter a valid Ghana recipient phone number.",
          maxLines: 2,
        );
        return;
      }
      if (_giftAddressDetailsController.text.trim().isEmpty) {
        AppToastMessage.show(
          context: context,
          backgroundColor: colors.error,
          message: "Add recipient landmark/house details for gift delivery.",
          maxLines: 2,
        );
        return;
      }
    }

    _showPaymentConfirmationSheet(context, provider, colors);
  }

  String? _getPrePaymentBlockingIssue(CartProvider provider, {bool allowClosedVendor = false}) {
    if (provider.cartItems.isEmpty) return "Your cart is empty.";

    final scheduleAvailability = provider.scheduleAvailability;
    final vendorIsAcceptingOrders = _parseBool(scheduleAvailability?['isAcceptingOrders'], defaultValue: true);
    if (!vendorIsAcceptingOrders) {
      return "This vendor is currently unavailable for new orders.";
    }

    final vendorIsOpenNow = _parseBool(scheduleAvailability?['isOpen'], defaultValue: true);
    final vendorIsAcceptingScheduledOrders = _parseBool(
      scheduleAvailability?['isAcceptingScheduledOrders'],
      defaultValue: true,
    );
    if (allowClosedVendor && !vendorIsAcceptingScheduledOrders) {
      return "This vendor is not accepting scheduled orders right now.";
    }
    if (!allowClosedVendor && !vendorIsOpenNow) {
      return "This vendor is currently closed. Choose a scheduled slot or try again later.";
    }

    final unavailableItems = <CartItem>[];
    final outOfStockItems = <CartItem>[];
    final closedVendorItems = <FoodItem>[];

    for (final entry in provider.cartItems.entries) {
      final item = entry.key;
      final quantity = entry.value;

      if (!item.isAvailable) {
        unavailableItems.add(item);
      }

      if (item is FoodItem && !item.isRestaurantOpen) {
        closedVendorItems.add(item);
      }

      if (item is GroceryItem && (item.stock <= 0 || quantity > item.stock)) {
        outOfStockItems.add(item);
      } else if (item is PharmacyItem && (item.stock <= 0 || quantity > item.stock)) {
        outOfStockItems.add(item);
      } else if (item is GrabMartItem && (item.stock <= 0 || quantity > item.stock)) {
        outOfStockItems.add(item);
      }
    }

    if (!allowClosedVendor && closedVendorItems.isNotEmpty) {
      return "This vendor is currently closed. Please remove those items and try again.";
    }

    if (unavailableItems.isNotEmpty) {
      final names = unavailableItems.take(2).map((item) => item.name).join(", ");
      final suffix = unavailableItems.length > 2 ? " and more" : "";
      return "Some items are unavailable: $names$suffix. Please update your cart.";
    }

    if (outOfStockItems.isNotEmpty) {
      final names = outOfStockItems.take(2).map((item) => item.name).join(", ");
      final suffix = outOfStockItems.length > 2 ? " and more" : "";
      return "Insufficient stock for: $names$suffix. Please update your cart quantities.";
    }

    return null;
  }

  void _showPaymentConfirmationSheet(BuildContext context, CartProvider provider, AppColorsExtension colors) {
    final parentContext = context;
    final addressText = _selectedAddressDetails.isNotEmpty ? _selectedAddressDetails : _selectedAddress;
    final isPickupMode = provider.fulfillmentMode == 'pickup';
    final isMixedCheckout = _isMixedCartCheckout(provider, isPickupMode: isPickupMode);
    final double subtotal = provider.subtotal;
    final double deliveryFee = isPickupMode ? 0 : provider.deliveryFee;
    final double serviceFee = provider.serviceFee;
    final double rainFee = isPickupMode ? 0 : provider.rainFee;
    final double creditsApplied = _effectiveCreditsAppliedForCheckout(provider, isPickupMode: isPickupMode);
    final double effectiveTip = isPickupMode ? 0.0 : _tipAmount;
    final double total = _checkoutGrandTotal(provider, isPickupMode: isPickupMode);
    final bool isCashOnDelivery = !isMixedCheckout && _isCashOnDeliverySelected(isPickupMode: isPickupMode);
    final double codUpfrontAmount = _codUpfrontAmountForCheckout(provider, isPickupMode: isPickupMode);
    final double codRemainingAmount = _codRemainingAmountForCheckout(provider, isPickupMode: isPickupMode);

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    decoration: BoxDecoration(color: colors.divider, borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  "Confirm Payment",
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 12.h),
                _buildSummaryBlock(
                  isPickupMode ? "Pickup Contact" : (_isGiftOrder ? "Recipient Address" : "Delivery Address"),
                  isPickupMode ? "${_pickupContactNameController.text.trim()} • ${_pickupPhoneDisplay()}" : addressText,
                  colors,
                ),
                if (!isPickupMode) ...[
                  SizedBox(height: 10.h),
                  _buildSummaryBlock("Delivery Time", _buildDeliveryTimeSummaryText(), colors),
                ],
                if (!isPickupMode && _isGiftOrder) ...[
                  SizedBox(height: 10.h),
                  _buildSummaryBlock("Gift Delivery", _buildGiftSummaryText(), colors),
                ],
                SizedBox(height: 10.h),
                _buildSummaryBlock(
                  "Payment Method",
                  isCashOnDelivery
                      ? "Cash on Delivery\nReview your payment breakdown below."
                      : "Paystack (Card, Mobile Money & Bank Transfer)",
                  colors,
                ),
                SizedBox(height: 10.h),
                _buildCheckoutLineItemsCard(provider, colors, compact: true),
                if (isMixedCheckout) ...[
                  SizedBox(height: 10.h),
                  _buildGroupedVendorBreakdown(provider, colors, compact: true),
                ],
                SizedBox(height: 14.h),
                _buildSummaryRow("Subtotal", subtotal, colors),
                if (!isPickupMode) ...[SizedBox(height: 6.h), _buildSummaryRow("Delivery Fee", deliveryFee, colors)],
                SizedBox(height: 6.h),
                _buildSummaryRow("Service Fee", serviceFee, colors),
                if (!isPickupMode && rainFee > 0) ...[
                  SizedBox(height: 6.h),
                  _buildSummaryRow("Rain Fee", rainFee, colors),
                ],
                if (creditsApplied > 0) ...[
                  SizedBox(height: 6.h),
                  _buildSummaryRow("Credits Applied", -creditsApplied, colors),
                ],
                if (!isPickupMode && effectiveTip > 0) ...[
                  SizedBox(height: 6.h),
                  _buildSummaryRow("Tip", effectiveTip, colors),
                ],
                if (isCashOnDelivery) ...[
                  SizedBox(height: 10.h),
                  Divider(color: colors.backgroundSecondary, height: 1),
                  SizedBox(height: 10.h),
                  _buildSummaryRow("Pay Online", codUpfrontAmount, colors),
                  SizedBox(height: 6.h),
                  _buildSummaryRow("Cash at Delivery", codRemainingAmount, colors),
                ],
                SizedBox(height: 10.h),
                Divider(color: colors.backgroundSecondary, height: 1),
                SizedBox(height: 10.h),
                _buildSummaryRow(isCashOnDelivery ? "Order Total" : "Total", total, colors, isEmphasis: true),
                SizedBox(height: 16.h),
                AppButton(
                  width: double.infinity,
                  onPressed: () {
                    if (_isProcessingPayment) return;
                    Navigator.of(sheetContext).pop();
                    _handlePaystackPayment(parentContext, provider);
                  },
                  buttonText: isCashOnDelivery
                      ? "Pay Online (GHS ${codUpfrontAmount.toStringAsFixed(2)})"
                      : "Pay Now (GHS ${total.toStringAsFixed(2)})",
                  textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
                  textColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  borderRadius: KBorderSize.borderMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryBlock(String title, String value, AppColorsExtension colors) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, AppColorsExtension colors, {bool isEmphasis = false}) {
    final displayAmount = "GHS ${amount.toStringAsFixed(2)}";
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 12.sp,
            fontWeight: isEmphasis ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          displayAmount,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 12.sp,
            fontWeight: isEmphasis ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  List<MapEntry<CartItem, int>> _sortedCheckoutEntries(Map<CartItem, int> cartItems) {
    final entries = cartItems.entries.toList(growable: false);
    entries.sort((a, b) {
      final providerCompare = a.key.providerName.toLowerCase().compareTo(b.key.providerName.toLowerCase());
      if (providerCompare != 0) return providerCompare;
      return a.key.name.toLowerCase().compareTo(b.key.name.toLowerCase());
    });
    return entries;
  }

  Widget _buildCheckoutLineItemsCard(CartProvider provider, AppColorsExtension colors, {bool compact = false}) {
    if (provider.cartItems.isEmpty) return const SizedBox.shrink();
    final entries = _sortedCheckoutEntries(provider.cartItems);
    final showProviderName = provider.providerCount > 1;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10.r : 12.r),
      decoration: BoxDecoration(
        color: compact ? colors.backgroundSecondary : colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Order Items",
            style: TextStyle(color: colors.textPrimary, fontSize: compact ? 11.sp : 12.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: compact ? 8.h : 10.h),
          for (int index = 0; index < entries.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entries[index].key.name} x${entries[index].value}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: compact ? 11.sp : 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (showProviderName) ...[
                        SizedBox(height: 2.h),
                        Text(
                          entries[index].key.providerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: compact ? 9.sp : 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (entries[index].key is FoodItem) ...[
                        SizedBox(height: 6.h),
                        FoodCustomizationChips(
                          item: entries[index].key as FoodItem,
                          colors: colors,
                          compact: true,
                          maxPreferenceLabels: compact ? 2 : 3,
                          maxNoteLength: compact ? 24 : 32,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Text(
                  'GHS ${(entries[index].key.price * entries[index].value).toStringAsFixed(2)}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: compact ? 11.sp : 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (index < entries.length - 1) ...[
              SizedBox(height: compact ? 8.h : 10.h),
              DottedLine(
                dashLength: 6,
                dashGapLength: 4,
                lineThickness: 1,
                dashColor: colors.textSecondary.withAlpha(50),
              ),
              SizedBox(height: compact ? 8.h : 10.h),
            ],
          ],
        ],
      ),
    );
  }

  List<_CheckoutVendorGroup> _collectCheckoutVendorGroups(CartProvider provider, Map<CartItem, int> cartItems) {
    final grouped = <String, _CheckoutVendorGroupMutable>{};

    for (final entry in cartItems.entries) {
      final item = entry.key;
      final quantity = entry.value;
      final providerId = item.providerId.trim();
      final providerName = item.providerName.trim().isNotEmpty ? item.providerName.trim() : 'Vendor';
      final key = provider.buildVendorGroupKey(
        itemType: item.itemType,
        providerId: providerId,
        providerName: providerName,
      );
      final subtotal = item.price * quantity;
      final etaLabel = provider.etaLabelForVendorGroupKey(key);

      grouped.putIfAbsent(
        key,
        () => _CheckoutVendorGroupMutable(
          groupKey: key,
          providerName: providerName,
          itemCount: 0,
          subtotal: 0,
          etaLabel: etaLabel,
        ),
      );
      grouped[key]!.itemCount += quantity;
      grouped[key]!.subtotal += subtotal;
      grouped[key]!.etaLabel ??= etaLabel;
    }

    return grouped.values
        .map(
          (value) => _CheckoutVendorGroup(
            groupKey: value.groupKey,
            providerName: value.providerName,
            itemCount: value.itemCount,
            subtotal: value.subtotal,
            etaLabel: value.etaLabel,
          ),
        )
        .toList(growable: false);
  }

  Widget _buildGroupedVendorBreakdown(CartProvider provider, AppColorsExtension colors, {bool compact = false}) {
    final groups = _collectCheckoutVendorGroups(provider, provider.cartItems);
    if (groups.isEmpty) return const SizedBox.shrink();

    final content = Column(
      children: [
        for (int index = 0; index < groups.length; index++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groups[index].providerName,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: compact ? 11.sp : 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (groups[index].etaLabel != null) ...[
                      SizedBox(height: compact ? 2.h : 3.h),
                      Text(
                        'ETA ${groups[index].etaLabel}',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: compact ? 9.sp : 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Padding(
                padding: EdgeInsets.only(top: groups[index].etaLabel == null ? 0 : 1.h),
                child: Text(
                  '${groups[index].itemCount} ${groups[index].itemCount == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: compact ? 10.sp : 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Padding(
                padding: EdgeInsets.only(top: groups[index].etaLabel == null ? 0 : 1.h),
                child: Text(
                  'GHS ${groups[index].subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: compact ? 11.sp : 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (index < groups.length - 1) SizedBox(height: compact ? 6.h : 8.h),
        ],
      ],
    );

    if (compact) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.35), width: 0.8),
        ),
        child: content,
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Vendor Breakdown",
            style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8.h),
          content,
        ],
      ),
    );
  }

  Future<void> _handlePaystackPayment(BuildContext context, CartProvider provider) async {
    if (_isProcessingPayment) return;

    setState(() {
      _isProcessingPayment = true;
    });

    bool syncSucceeded = true;
    try {
      syncSucceeded = await provider.syncFromBackend();
    } catch (e) {
      debugPrint('Checkout: payment-time cart sync failed: $e');
      syncSucceeded = false;
    }

    if (!mounted) return;
    if (!syncSucceeded) {
      setState(() {
        _isProcessingPayment = false;
      });
      AppToastMessage.show(
        context: context,
        backgroundColor: context.appColors.error,
        message: "Couldn't verify latest availability. Please refresh and try again.",
        maxLines: 3,
      );
      return;
    }

    if (provider.cartItems.isEmpty) {
      setState(() {
        _isProcessingPayment = false;
      });
      AppToastMessage.show(context: context, message: "Some items in your cart are no longer available.");
      return;
    }

    if (!_ensureScheduleSelectionAvailable(provider)) {
      setState(() {
        _isProcessingPayment = false;
      });
      AppToastMessage.show(
        context: context,
        message: _getNoScheduleSlotsMessage(provider.scheduleAvailability),
        backgroundColor: context.appColors.error,
        maxLines: 3,
      );
      return;
    }

    final prePaymentIssue = _getPrePaymentBlockingIssue(
      provider,
      allowClosedVendor: _shouldAllowClosedVendorPreCheck(provider),
    );
    if (prePaymentIssue != null) {
      setState(() {
        _isProcessingPayment = false;
      });
      AppToastMessage.show(
        context: context,
        message: prePaymentIssue,
        backgroundColor: context.appColors.error,
        maxLines: 3,
      );
      return;
    }

    final double subtotal = provider.subtotal;
    final bool isPickupMode = provider.fulfillmentMode == 'pickup';
    final double deliveryFee = isPickupMode ? 0.0 : provider.deliveryFee;
    final bool isMixedCheckout = _isMixedCartCheckout(provider, isPickupMode: isPickupMode);
    final bool isCashOnDelivery = !isMixedCheckout && _isCashOnDeliverySelected(isPickupMode: isPickupMode);
    final double orderGrandTotal = _checkoutGrandTotal(provider, isPickupMode: isPickupMode);
    CreateOrderResult? createdOrder;
    CreateCheckoutSessionResult? createdSession;
    String? orderId;
    String? sessionId;
    bool paymentSucceeded = false;
    Map<String, dynamic>? paymentData;
    final orderService = OrderServiceWrapper();

    try {
      double expectedOnlineAmount;
      double? expectedCodRemainingAmount;

      if (isMixedCheckout) {
        createdSession = await _createCheckoutSession(context);
        sessionId = createdSession?.sessionId;
        if (sessionId == null) {
          throw Exception('Failed to create checkout session');
        }

        expectedOnlineAmount = orderGrandTotal;
        expectedCodRemainingAmount = null;

        paymentData = _buildPaymentCompletePayload(
          orderId: null,
          checkoutSessionId: sessionId,
          isGroupedOrder: true,
          orderNumber: createdSession?.groupOrderNumber,
          giftDeliveryCode: null,
          paymentMethod: 'card',
          paymentMethodLabel: 'Paystack',
          orderGrandTotal: orderGrandTotal,
          paidOnlineAmount: expectedOnlineAmount,
          codRemainingCashAmount: null,
        );
      } else {
        createdOrder = await _createOrder(context, subtotal, deliveryFee, orderGrandTotal);
        orderId = createdOrder?.orderId;
        if (orderId == null) {
          throw Exception('Failed to create order');
        }

        expectedOnlineAmount = isCashOnDelivery
            ? math.max(
                0,
                createdOrder?.codUpfrontAmount ?? _codUpfrontAmountForCheckout(provider, isPickupMode: isPickupMode),
              )
            : orderGrandTotal;
        expectedCodRemainingAmount = isCashOnDelivery
            ? (createdOrder?.codRemainingCashOnDelivery ?? math.max(0, orderGrandTotal - expectedOnlineAmount))
            : null;

        paymentData = _buildPaymentCompletePayload(
          orderId: orderId,
          checkoutSessionId: null,
          isGroupedOrder: false,
          orderNumber: createdOrder?.orderNumber,
          giftDeliveryCode: createdOrder?.giftDeliveryCode,
          paymentMethod: _selectedPaymentMethodApiValue(isPickupMode: isPickupMode),
          paymentMethodLabel: _selectedPaymentMethodLabel(isPickupMode: isPickupMode),
          orderGrandTotal: orderGrandTotal,
          paidOnlineAmount: expectedOnlineAmount,
          codRemainingCashAmount: expectedCodRemainingAmount,
        );
      }

      if (expectedOnlineAmount <= 0) {
        setState(() {
          _isProcessingPayment = false;
        });
        final confirmationResult = sessionId != null
            ? await _confirmCheckoutSessionPayment(sessionId: sessionId, reference: 'credits-only')
            : await _confirmOrderPayment(orderId: orderId!, reference: 'credits-only');
        paymentData = _mergePaymentResultIntoPayload(
          paymentData,
          confirmationResult: confirmationResult,
          isCashOnDelivery: isCashOnDelivery,
        );

        if (confirmationResult.success) {
          _handlePaymentSuccess(context, paymentData: paymentData);
        } else {
          _showErrorDialog(context, 'Payment confirmation failed. Please try again.');
        }
        return;
      }

      final init = sessionId != null
          ? await orderService.initializeCheckoutSessionPaystackPayment(sessionId: sessionId)
          : await orderService.initializePaystackPayment(orderId: orderId!);
      final authUrl = init.authorizationUrl;
      final reference = init.reference;

      final paidOnlineAmount = init.paymentAmount ?? expectedOnlineAmount;
      final codRemainingCashAmount =
          init.codRemainingCashAmount ??
          (isCashOnDelivery ? (expectedCodRemainingAmount ?? math.max(0, orderGrandTotal - paidOnlineAmount)) : null);
      paymentData = {
        ...paymentData,
        'paymentScope': init.paymentScope,
        'total': paidOnlineAmount,
        'orderGrandTotal': orderGrandTotal,
        'codRemainingCashAmount': codRemainingCashAmount,
      };

      setState(() {
        _isProcessingPayment = false;
      });

      final result = await paystack.PaystackService.instance.launchPayment(
        context: context,
        authorizationUrl: authUrl,
        reference: reference,
      );

      paymentSucceeded = result.status == paystack.PaystackPaymentStatus.success;
      if (result.status == paystack.PaystackPaymentStatus.success ||
          result.status == paystack.PaystackPaymentStatus.unknown) {
        if (!mounted) return;
        context.go(
          '/paymentConfirming',
          extra: {
            'orderId': orderId,
            'sessionId': sessionId,
            'reference': result.reference ?? reference,
            'paymentData': paymentData,
          },
        );
        return;
      }

      if (sessionId != null) {
        await _releaseCheckoutSessionCreditHold(sessionId: sessionId);
      } else if (orderId != null) {
        await _releaseOrderCreditHold(orderId: orderId);
      }
      _handlePaymentFailure(context, paymentData: paymentData);
    } catch (e) {
      if (!paymentSucceeded) {
        if (sessionId != null) {
          await _releaseCheckoutSessionCreditHold(sessionId: sessionId);
        } else if (orderId != null) {
          await _releaseOrderCreditHold(orderId: orderId);
        }
      }
      setState(() {
        _isProcessingPayment = false;
      });
      if ((orderId != null || sessionId != null) && paymentData != null) {
        _handlePaymentFailure(context, paymentData: paymentData);
      } else {
        final toastMessage = _getOrderCreationFailureToastMessage(e);
        if (toastMessage != null) {
          AppToastMessage.show(
            context: context,
            backgroundColor: context.appColors.error,
            message: toastMessage,
            maxLines: 3,
          );
          return;
        }
        _showErrorDialog(context, 'Payment failed: ${e.toString()}');
      }
    }
  }

  String? _getOrderCreationFailureToastMessage(Object error) {
    final rawError = error.toString().toLowerCase();

    if (rawError.contains('scheduled_order_vendor_disabled') || rawError.contains('not accepting scheduled orders')) {
      return "This vendor is not accepting scheduled orders right now.";
    }

    if (rawError.contains('cod_disabled')) {
      return "Cash on delivery is currently unavailable.";
    }
    if (rawError.contains('cod_trust_threshold_not_met')) {
      return "Complete more prepaid orders to unlock cash on delivery.";
    }
    if (rawError.contains('cod_phone_not_verified') || rawError.contains('cod_phone_required')) {
      return "Please verify your phone number to use cash on delivery.";
    }
    if (rawError.contains('cod_active_order_exists')) {
      return "Complete your active cash-on-delivery order before placing a new one.";
    }
    if (rawError.contains('cod_disabled_no_show')) {
      return "Cash on delivery is disabled for this account due to prior no-shows.";
    }
    if (rawError.contains('cod_max_order_total_exceeded')) {
      return "This order total exceeds the current cash-on-delivery limit.";
    }
    if (rawError.contains('cod_upfront_amount_invalid')) {
      return "This order cannot be placed as cash on delivery.";
    }
    if (rawError.contains('cod_delivery_only')) {
      return "Cash on delivery is available for delivery orders only.";
    }
    if (rawError.contains('mixed_checkout_disabled') ||
        rawError.contains('mixed cart is currently unavailable') ||
        rawError.contains('mixed checkout is currently unavailable')) {
      return "Multi-vendor checkout is not available right now.";
    }
    if (rawError.contains('mixed_checkout_card_only')) {
      return "Multi-vendor checkout supports card payment only.";
    }
    if (rawError.contains('mixed_checkout_gift_not_supported')) {
      return "Gift delivery is not available for multi-vendor checkout yet.";
    }
    if (rawError.contains('mixed_checkout_scheduled_not_supported')) {
      return "Scheduled delivery is not available for multi-vendor checkout yet.";
    }
    if (rawError.contains('mixed_checkout_min_groups_not_met')) {
      return "Add items from at least two vendors to use multi-vendor checkout.";
    }

    final isVendorUnavailable =
        rawError.contains('store/restaurant not found or inactive') ||
        rawError.contains('store/restaurant') && rawError.contains('inactive') ||
        rawError.contains('vendor') && rawError.contains('closed') ||
        rawError.contains('restaurant') && rawError.contains('closed') ||
        rawError.contains('store is currently closed') ||
        rawError.contains('store is currently unavailable for new orders') ||
        rawError.contains('not accepting orders');
    if (isVendorUnavailable) {
      return "This vendor is currently closed or unavailable. Please choose another vendor.";
    }

    final isItemUnavailable =
        rawError.contains('no longer available') ||
        rawError.contains('currently unavailable') ||
        rawError.contains('item') && rawError.contains('not found') ||
        rawError.contains('unable to reserve inventory') ||
        rawError.contains('stock changes') ||
        rawError.contains('out of stock') ||
        rawError.contains('insufficient stock') ||
        rawError.contains('not enough stock');
    if (isItemUnavailable) {
      return "Some items in your cart are unavailable. Please review your cart and try again.";
    }

    return null;
  }

  Future<CreateOrderResult?> _createOrder(
    BuildContext context,
    double subtotal,
    double deliveryFee,
    double total,
  ) async {
    final cart = context.read<CartProvider>();
    final orderService = OrderServiceWrapper();
    final isPickupMode = cart.fulfillmentMode == 'pickup';
    final isMixedCheckout = _isMixedCartCheckout(cart, isPickupMode: isPickupMode);
    final selectedPaymentMethod = _selectedPaymentMethodApiValue(isPickupMode: isPickupMode);
    final shouldCreateGiftOrder = !isPickupMode && _isGiftOrder;
    final selectedScheduleSlot = !isPickupMode ? _selectedScheduleSlot() : null;
    final deliveryTimeType = selectedScheduleSlot != null ? 'scheduled' : 'asap';
    final scheduledForAtIso = selectedScheduleSlot?.startAt.toUtc().toIso8601String();
    final giftRecipientName = shouldCreateGiftOrder ? _giftRecipientNameController.text.trim() : null;
    final giftRecipientPhone = shouldCreateGiftOrder ? _normalizeGhanaPhone(_giftRecipientPhoneController.text) : null;
    final giftNote = shouldCreateGiftOrder ? _giftNoteController.text.trim() : null;

    try {
      final createOrderResult = await orderService.createOrder(
        cartItems: cart.cartItems,
        fulfillmentMode: cart.fulfillmentMode,
        deliveryTimeType: deliveryTimeType,
        scheduledForAt: scheduledForAtIso,
        deliveryAddress: isPickupMode ? null : _selectedAddress,
        deliveryLatitude: isPickupMode ? null : _selectedLatitude,
        deliveryLongitude: isPickupMode ? null : _selectedLongitude,
        pickupContactName: isPickupMode ? _pickupContactNameController.text.trim() : null,
        pickupContactPhone: isPickupMode ? _normalizeGhanaPhone(_pickupContactPhoneController.text) : null,
        acceptNoShowPolicy: isPickupMode ? _pickupNoShowAccepted : null,
        noShowPolicyVersion: isPickupMode ? "v1" : null,
        paymentMethod: selectedPaymentMethod,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        useCredits: selectedPaymentMethod == "cash" ? false : cart.useCredits,
        notes: _getConcatenatedNotes(provider: cart, isPickupMode: isPickupMode, isMixedCheckout: isMixedCheckout),
        isGiftOrder: shouldCreateGiftOrder,
        giftRecipientName: shouldCreateGiftOrder ? giftRecipientName : null,
        giftRecipientPhone: shouldCreateGiftOrder ? giftRecipientPhone : null,
        giftNote: shouldCreateGiftOrder && giftNote != null && giftNote.isNotEmpty ? giftNote : null,
      );

      return createOrderResult;
    } catch (e) {
      debugPrint("Order creation error: $e");
      throw Exception("Failed to create order: ${e.toString()}");
    }
  }

  Future<CreateCheckoutSessionResult?> _createCheckoutSession(BuildContext context) async {
    final cart = context.read<CartProvider>();
    final orderService = OrderServiceWrapper();
    final isPickupMode = cart.fulfillmentMode == 'pickup';
    final isMixedCheckout = _isMixedCartCheckout(cart, isPickupMode: isPickupMode);
    if (isPickupMode) {
      throw Exception('Mixed checkout supports delivery orders only');
    }

    final deliveryAddress = orderService.resolveDeliveryAddress(
      _selectedAddress,
      latitude: _selectedLatitude,
      longitude: _selectedLongitude,
    );

    try {
      final sessionResult = await orderService.createCheckoutSession(
        fulfillmentMode: cart.fulfillmentMode,
        paymentMethod: 'card',
        deliveryAddress: deliveryAddress,
        useCredits: cart.useCredits,
        notes: _getConcatenatedNotes(provider: cart, isPickupMode: isPickupMode, isMixedCheckout: isMixedCheckout),
      );
      return sessionResult;
    } catch (e) {
      debugPrint("Checkout session creation error: $e");
      throw Exception("Failed to create checkout session: ${e.toString()}");
    }
  }

  Future<ConfirmPaymentResult> _confirmOrderPayment({required String orderId, required String reference}) async {
    final orderService = OrderServiceWrapper();
    return orderService.confirmPayment(orderId: orderId, reference: reference);
  }

  Future<ConfirmPaymentResult> _confirmCheckoutSessionPayment({
    required String sessionId,
    required String reference,
  }) async {
    final orderService = OrderServiceWrapper();
    return await orderService.confirmCheckoutSessionPayment(sessionId: sessionId, reference: reference);
  }

  Future<void> _releaseOrderCreditHold({required String orderId}) async {
    try {
      final orderService = OrderServiceWrapper();
      await orderService.releaseCreditHold(orderId: orderId);
    } catch (e) {
      debugPrint('⚠️ Failed to release credit hold: $e');
    }
  }

  Future<void> _releaseCheckoutSessionCreditHold({required String sessionId}) async {
    try {
      final orderService = OrderServiceWrapper();
      await orderService.releaseCheckoutSessionCreditHold(sessionId: sessionId);
    } catch (e) {
      debugPrint('⚠️ Failed to release checkout-session credit hold: $e');
    }
  }

  Map<String, dynamic> _buildPaymentCompletePayload({
    required String? orderId,
    required String? checkoutSessionId,
    required bool isGroupedOrder,
    required String paymentMethod,
    required String paymentMethodLabel,
    required double orderGrandTotal,
    String? orderNumber,
    String? giftDeliveryCode,
    double? paidOnlineAmount,
    double? codRemainingCashAmount,
    String? paymentScope,
  }) {
    final cart = context.read<CartProvider>();
    final isPickupMode = cart.fulfillmentMode == 'pickup';
    final cartSubtotal = cart.subtotal;
    final deliveryFeeAmount = isPickupMode ? 0.0 : cart.deliveryFee;
    final serviceFeeAmount = cart.serviceFee;
    final rainFeeAmount = isPickupMode ? 0.0 : cart.rainFee;
    final taxAmount = cart.tax;
    final double effectiveTip = isPickupMode ? 0.0 : _tipAmount;
    final bool isGiftOrder = !isPickupMode && _isGiftOrder;
    final String? normalizedGiftPhone = isGiftOrder ? _normalizeGhanaPhone(_giftRecipientPhoneController.text) : null;
    final onlinePaidAmount = paidOnlineAmount ?? orderGrandTotal;

    return {
      'orderId': orderId,
      'checkoutSessionId': checkoutSessionId,
      'isGroupedOrder': isGroupedOrder,
      'fulfillmentMode': cart.fulfillmentMode,
      'method': paymentMethodLabel,
      'paymentMethod': paymentMethod,
      'paymentScope': paymentScope,
      'total': onlinePaidAmount,
      'orderGrandTotal': orderGrandTotal,
      'codRemainingCashAmount': codRemainingCashAmount,
      'subTotal': cartSubtotal,
      'deliveryFee': deliveryFeeAmount,
      'serviceFee': serviceFeeAmount,
      'rainFee': rainFeeAmount,
      'tax': taxAmount,
      'tip': effectiveTip,
      'orderNumber': orderNumber ?? _generateOrderNumber(),
      'timestamp': DateTime.now().toIso8601String(),
      'isGiftOrder': isGiftOrder,
      'giftRecipientName': isGiftOrder ? _giftRecipientNameController.text.trim() : null,
      'giftRecipientPhone': normalizedGiftPhone,
      'giftDeliveryCode': isGiftOrder ? giftDeliveryCode : null,
    };
  }

  Map<String, dynamic> _mergePaymentResultIntoPayload(
    Map<String, dynamic> payload, {
    required ConfirmPaymentResult confirmationResult,
    required bool isCashOnDelivery,
  }) {
    final merged = <String, dynamic>{...payload};
    final previousTotal = _asDouble(merged['total']) ?? 0.0;
    final orderGrandTotal = _asDouble(merged['orderGrandTotal']) ?? previousTotal;
    final confirmedExternalAmount = confirmationResult.externalPaymentAmount ?? previousTotal;
    final confirmedCodRemaining =
        confirmationResult.codRemainingCashAmount ??
        (isCashOnDelivery ? math.max(0, orderGrandTotal - confirmedExternalAmount) : null);

    merged['paymentScope'] = confirmationResult.paymentScope ?? merged['paymentScope'];
    merged['total'] = confirmedExternalAmount;
    merged['orderGrandTotal'] = orderGrandTotal;
    merged['codRemainingCashAmount'] = confirmedCodRemaining;
    return merged;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _handlePaymentSuccess(BuildContext context, {required Map<String, dynamic> paymentData}) {
    context.go('/paymentComplete', extra: paymentData);
  }

  void _handlePaymentFailure(BuildContext context, {Map<String, dynamic>? paymentData}) {
    if (paymentData == null) {
      _showErrorDialog(context, "Payment failed. Please try again.");
      return;
    }

    context.go('/paymentFailed', extra: paymentData);
  }

  String _generateOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    return 'ORD${timestamp.substring(timestamp.length - 8)}';
  }

  String _getConcatenatedNotes({
    required CartProvider provider,
    required bool isPickupMode,
    required bool isMixedCheckout,
  }) {
    final notesParts = <String>[];
    final vendorGroups = _collectCheckoutVendorGroups(provider, provider.cartItems);
    final vendorOrderNotes = <String>[];

    for (final group in vendorGroups) {
      final groupNote = _combinedOrderNoteForGroup(group.groupKey).trim();
      if (groupNote.isEmpty) continue;
      if (isMixedCheckout || vendorGroups.length > 1) {
        vendorOrderNotes.add('${group.providerName}: $groupNote');
      } else {
        vendorOrderNotes.add(groupNote);
      }
    }

    if (vendorOrderNotes.isNotEmpty) {
      if (isMixedCheckout || vendorGroups.length > 1) {
        notesParts.add('Order notes: ${vendorOrderNotes.join(' | ')}');
      } else {
        notesParts.add('Order note: ${vendorOrderNotes.first}');
      }
    }

    if (!isPickupMode && (_selectedDeliveryInstructions.isNotEmpty || _deliveryInstructionController.text.isNotEmpty)) {
      notesParts.add(
        "Delivery: ${[..._selectedDeliveryInstructions, if (_deliveryInstructionController.text.isNotEmpty) _deliveryInstructionController.text].join(', ')}",
      );
    }

    if (!isPickupMode && _isGiftOrder && _giftAddressDetailsController.text.trim().isNotEmpty) {
      notesParts.add("Gift drop-off details: ${_giftAddressDetailsController.text.trim()}");
    }

    return notesParts.join(" | ");
  }

  void _showErrorDialog(BuildContext context, String message) {
    AppDialog.show(
      context: context,
      title: 'Payment Error',
      message: message,
      type: AppDialogType.error,
      primaryButtonText: 'OK',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
  }

  Widget _buildAddressShimmerTile(AppColorsExtension colors, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 0.w, vertical: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 6.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
      ),
      child: Row(
        children: [
          _buildShimmerBox(width: 24.w, height: 24.h, colors: colors, isDark: isDark, shape: BoxShape.circle),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBox(width: 70.w, height: 14.h, colors: colors, isDark: isDark, borderRadius: 6.r),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    _buildShimmerBox(width: 12.w, height: 12.h, colors: colors, isDark: isDark, borderRadius: 3.r),
                    SizedBox(width: 6.w),
                    _buildShimmerBox(width: 120.w, height: 10.h, colors: colors, isDark: isDark, borderRadius: 4.r),
                  ],
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    _buildShimmerBox(width: 12.w, height: 12.h, colors: colors, isDark: isDark, borderRadius: 3.r),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: _buildShimmerBox(
                        width: double.infinity,
                        height: 10.h,
                        colors: colors,
                        isDark: isDark,
                        borderRadius: 4.r,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          _buildShimmerBox(width: 32.w, height: 32.h, colors: colors, isDark: isDark, shape: BoxShape.circle),
        ],
      ),
    );
  }

  Widget _buildPickOnMapTile(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: GestureDetector(
        onTap: _openAddressPickerFromCheckout,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.1)),
          child: Row(
            children: [
              SvgPicture.asset(
                Assets.icons.mapPin,
                package: 'grab_go_shared',
                height: 18.h,
                width: 18.w,
                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  _isGiftOrder ? "Pick recipient address on map" : "Pick delivery address on map",
                  style: TextStyle(color: colors.accentOrange, fontSize: 13.sp, fontWeight: FontWeight.w700),
                ),
              ),
              SvgPicture.asset(
                Assets.icons.navArrowRight,
                package: 'grab_go_shared',
                height: 16.h,
                width: 16.w,
                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressListToggle(AppColorsExtension colors, int hiddenCount) {
    final String label = _showAllAddresses ? "Show less" : "Show $hiddenCount more";
    final String icon = _showAllAddresses ? Assets.icons.navArrowUp : Assets.icons.navArrowDown;

    return Padding(
      padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 2.h, bottom: 6.h),
      child: Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _showAllAddresses = !_showAllAddresses;
              });
            },
            borderRadius: BorderRadius.circular(20.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: colors.accentOrange, fontSize: 12.sp, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 4.w),
                  SvgPicture.asset(
                    icon,
                    package: 'grab_go_shared',
                    height: 14.h,
                    width: 14.w,
                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleSection(AppColorsExtension colors, CartProvider provider) {
    final noSlotsMessage = _getNoScheduleSlotsMessage(provider.scheduleAvailability);
    final bool isDeliveryMode = provider.fulfillmentMode != 'pickup';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Text(
            "Delivery Time",
            style: TextStyle(
              fontFamily: "Lato",
              package: 'grab_go_shared',
              color: colors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Wrap(
            spacing: 10.w,
            children: [
              _buildScheduleToggleChip(
                label: "ASAP",
                isSelected: !_isScheduleEnabled,
                onTap: () {
                  setState(() {
                    _isScheduleEnabled = false;
                  });
                },
                colors: colors,
              ),
              _buildScheduleToggleChip(
                label: "Schedule",
                isSelected: _isScheduleEnabled,
                onTap: () {
                  setState(() {
                    _isScheduleEnabled = true;
                    _scheduleSlots = _generateScheduleSlots(provider.scheduleAvailability);
                    if (_selectedScheduleIndex >= _scheduleSlots.length) {
                      _selectedScheduleIndex = 0;
                    }
                  });
                },
                colors: colors,
              ),
            ],
          ),
        ),
        if (isDeliveryMode && !_isScheduleEnabled)
          Padding(
            padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 10.h),
            child: Text(
              "Choose ASAP or schedule for a later delivery window.",
              style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
            ),
          ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: _isScheduleEnabled
              ? Padding(
                  padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 12.h),
                  child: Column(
                    children: _scheduleSlots.isEmpty
                        ? [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.h),
                              child: Text(
                                noSlotsMessage,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ]
                        : List.generate(
                            _scheduleSlots.length,
                            (index) => _buildScheduleSlotTile(_scheduleSlots[index], index, colors),
                          ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMixedCheckoutInfoBanner(AppColorsExtension colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Text(
          "Multi-vendor checkout: Gift delivery and scheduled delivery are unavailable for this order.",
          style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildGiftOrderSection(AppColorsExtension colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Text(
            "Gift Delivery",
            style: TextStyle(
              fontFamily: "Lato",
              package: 'grab_go_shared',
              color: colors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: colors.accentOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    Assets.icons.gift,
                    package: 'grab_go_shared',
                    height: 20.h,
                    width: 20.w,
                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Send as a gift",
                      style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      "Recipient will need a delivery code.",
                      style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              CustomSwitch(value: _isGiftOrder, onChanged: _setGiftOrderEnabled, activeColor: colors.accentOrange),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: _isGiftOrder
              ? Padding(
                  padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 10.h),
                  child: Column(
                    children: [
                      AppTextInput(
                        controller: _giftRecipientNameController,
                        hintText: "Recipient name",
                        keyboardType: TextInputType.name,
                        fillColor: colors.backgroundPrimary,
                        borderColor: colors.inputBorder,
                        borderRadius: 12.r,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                      ),
                      SizedBox(height: 10.h),
                      AppTextInput(
                        controller: _giftRecipientPhoneController,
                        hintText: "Recipient phone (optional)",
                        fillColor: colors.backgroundPrimary,
                        borderColor: colors.inputBorder,
                        keyboardType: TextInputType.phone,
                        prefixIcon: _buildGhanaPhonePrefix(context),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        borderRadius: 12.r,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                      ),
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: colors.inputBorder, width: 0.5),
                        ),
                        child: TextField(
                          controller: _giftNoteController,
                          maxLines: 3,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: "Gift note (optional)",
                            hintStyle: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: colors.inputBorder, width: 0.5),
                        ),
                        child: TextField(
                          controller: _giftAddressDetailsController,
                          maxLines: 2,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: "Recipient landmark / house details (required)",
                            hintStyle: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      if (_selectedAddressDetails.isNotEmpty || _selectedAddress.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Recipient address: ${_selectedAddressDetails.isNotEmpty ? _selectedAddressDetails : _selectedAddress}",
                            style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                          ),
                        ),
                        SizedBox(height: 6.h),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Delivery code is sent to you, and to recipient if phone is provided. Add precise drop-off details.",
                          style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSection(AppColorsExtension colors, CartProvider provider, {required bool isPickupMode}) {
    final bool isMixedCheckout = _isMixedCartCheckout(provider, isPickupMode: isPickupMode);
    final bool isCashOnDelivery = !isMixedCheckout && _isCashOnDeliverySelected(isPickupMode: isPickupMode);
    final double totalAmount = _checkoutGrandTotal(provider, isPickupMode: isPickupMode);
    final double codUpfrontAmount = _codUpfrontAmountForCheckout(provider, isPickupMode: isPickupMode);
    final double codRemainingAmount = _codRemainingAmountForCheckout(provider, isPickupMode: isPickupMode);
    final codEligibility = _codEligibility;
    final bool codEligibilityKnown = codEligibility != null;
    final bool codEligible = codEligibility?.eligible == true;
    final String codSubtitle;
    if (isPickupMode) {
      codSubtitle = "Available only for delivery orders";
    } else if (isMixedCheckout) {
      codSubtitle = "Not available for multi-vendor checkout";
    } else if (_isCheckingCodEligibility && !codEligibilityKnown) {
      codSubtitle = "Checking eligibility...";
    } else if (!codEligible && codEligibilityKnown) {
      codSubtitle = codEligibility.code == 'COD_DISABLED'
          ? "Temporarily unavailable right now"
          : "Not eligible yet. Tap to view requirements.";
    } else {
      codSubtitle = "Pay part now and the rest on delivery";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Text(
            "Payment Method",
            style: TextStyle(
              fontFamily: "Lato",
              package: 'grab_go_shared',
              color: colors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Column(
            children: [
              _buildPaymentMethodTile(
                title: "Pay Online",
                subtitle: "Card, mobile money, or bank transfer",
                isSelected: _selectedPaymentMethod == _CheckoutPaymentMethod.card || isPickupMode,
                colors: colors,
                onTap: () {
                  if (_selectedPaymentMethod == _CheckoutPaymentMethod.card) {
                    return;
                  }
                  setState(() {
                    _selectedPaymentMethod = _CheckoutPaymentMethod.card;
                  });
                },
              ),
              Divider(height: 8.h, thickness: 0.8, color: colors.inputBorder.withValues(alpha: 0.35)),

              _buildPaymentMethodTile(
                title: "Cash on Delivery",
                subtitle: codSubtitle,
                isSelected: !isPickupMode && _selectedPaymentMethod == _CheckoutPaymentMethod.cash,
                colors: colors,
                isDisabled: isPickupMode || isMixedCheckout,
                onTap: () {
                  _handleCodSelectionTap(isPickupMode: isPickupMode);
                },
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          clipBehavior: Clip.hardEdge,
          child: isCashOnDelivery
              ? Padding(
                  padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 10.h),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                      border: Border.all(color: colors.inputBorder.withValues(alpha: 0.35), width: 0.8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "COD Breakdown",
                          style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Text(
                              "Pay Online",
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "GHS ${codUpfrontAmount.toStringAsFixed(2)}",
                              style: TextStyle(color: colors.textPrimary, fontSize: 11.sp, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Text(
                              "Pay at Delivery",
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              "GHS ${codRemainingAmount.toStringAsFixed(2)}",
                              style: TextStyle(color: colors.textPrimary, fontSize: 11.sp, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          "Order total: GHS ${totalAmount.toStringAsFixed(2)}",
                          style: TextStyle(color: colors.textSecondary, fontSize: 10.sp, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required AppColorsExtension colors,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    final Color titleColor = isDisabled ? colors.textSecondary : colors.textPrimary;
    final Color subtitleColor = colors.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: titleColor, fontSize: 13.sp, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(color: subtitleColor, fontSize: 11.sp, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                height: 24.h,
                width: 24.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? colors.accentOrange.withValues(alpha: 0.1) : Colors.transparent,
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          height: 10.h,
                          width: 10.w,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildGiftSummaryText() {
    final recipientName = _giftRecipientNameController.text.trim();
    final normalizedRecipientPhone = _normalizeGhanaPhone(_giftRecipientPhoneController.text);
    final giftNote = _giftNoteController.text.trim();
    final giftAddressDetails = _giftAddressDetailsController.text.trim();

    final lines = <String>[
      "Recipient: $recipientName",
      if (normalizedRecipientPhone != null) "Phone: $normalizedRecipientPhone",
      if (giftAddressDetails.isNotEmpty) "Landmark: $giftAddressDetails",
      if (giftNote.isNotEmpty) "Note: $giftNote",
    ];
    return lines.join('\n');
  }

  String _buildDeliveryTimeSummaryText() {
    final selectedSlot = _selectedScheduleSlot();
    if (selectedSlot == null) return "ASAP";
    return '${selectedSlot.dayLabel}, ${selectedSlot.timeRange}';
  }

  Widget _buildScheduleToggleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColorsExtension colors,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleSlotTile(_ScheduleSlot slot, int index, AppColorsExtension colors) {
    final bool isSelected = _selectedScheduleIndex == index;

    final bool showDivider = index < _scheduleSlots.length - 1;

    return Column(
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedScheduleIndex = index;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(12.r)),
            child: Row(
              children: [
                Container(
                  height: 20.h,
                  width: 20.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? colors.accentOrange.withValues(alpha: 0.15) : Colors.transparent,
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            height: 8.h,
                            width: 8.w,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                          ),
                        )
                      : null,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.dayLabel,
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        slot.timeRange,
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: 32.w),
            child: Divider(height: 12.h, thickness: 0.8, color: colors.inputBorder.withValues(alpha: 0.4)),
          ),
      ],
    );
  }

  void _syncScheduleSlotsForProvider(CartProvider provider) {
    final signature = _scheduleAvailabilitySignature(provider);
    if (signature == _lastScheduleAvailabilitySignature) {
      return;
    }
    _lastScheduleAvailabilitySignature = signature;
    if (_isScheduleSyncQueued) return;

    _isScheduleSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isScheduleSyncQueued = false;
      if (!mounted) return;

      final nextSlots = _generateScheduleSlots(provider.scheduleAvailability);
      final nextIndex = nextSlots.isEmpty ? 0 : math.min(_selectedScheduleIndex, nextSlots.length - 1);
      if (_areScheduleSlotsEqual(_scheduleSlots, nextSlots) && nextIndex == _selectedScheduleIndex) {
        return;
      }
      setState(() {
        _scheduleSlots = nextSlots;
        _selectedScheduleIndex = nextIndex;
      });
    });
  }

  String _scheduleAvailabilitySignature(CartProvider provider) {
    final availability = provider.scheduleAvailability;
    if (availability == null) {
      return '${provider.fulfillmentMode}|none';
    }
    try {
      return '${provider.fulfillmentMode}|${jsonEncode(availability)}';
    } catch (_) {
      return '${provider.fulfillmentMode}|${availability.toString()}';
    }
  }

  bool _areScheduleSlotsEqual(List<_ScheduleSlot> a, List<_ScheduleSlot> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].startAt != b[i].startAt || a[i].endAt != b[i].endAt) {
        return false;
      }
    }
    return true;
  }

  List<_ScheduleSlot> _generateScheduleSlots([Map<String, dynamic>? scheduleAvailability]) {
    final minLeadMinutes = _parsePositiveInt(
      scheduleAvailability?['minLeadMinutes'],
      _defaultScheduleLeadMinutes,
      min: 1,
      max: 24 * 60,
    );
    final slotMinutes = _parsePositiveInt(
      scheduleAvailability?['slotMinutes'],
      _defaultScheduleSlotMinutes,
      min: 5,
      max: 4 * 60,
    );
    final maxHorizonDays = _parsePositiveInt(
      scheduleAvailability?['maxHorizonDays'],
      _defaultScheduleHorizonDays,
      min: 1,
      max: 30,
    );
    final bool isOpenNow = _parseBool(scheduleAvailability?['isOpen'], defaultValue: true);
    final bool isAcceptingOrders = _parseBool(scheduleAvailability?['isAcceptingOrders'], defaultValue: true);
    final bool isAcceptingScheduledOrders = _parseBool(
      scheduleAvailability?['isAcceptingScheduledOrders'],
      defaultValue: true,
    );
    final bool is24Hours = _parseBool(scheduleAvailability?['is24Hours'], defaultValue: false);
    final openingHours = _parseOpeningHours(scheduleAvailability?['openingHours']);

    if (!isAcceptingOrders || !isAcceptingScheduledOrders) {
      return [];
    }
    if (!is24Hours && openingHours.isEmpty && !isOpenNow) return [];

    final now = DateTime.now();
    final leadTime = now.add(Duration(minutes: minLeadMinutes));
    final slotDuration = Duration(minutes: slotMinutes);
    DateTime cursor = _roundUpToSlot(leadTime, slotDuration);
    final horizonEnd = now.add(Duration(days: maxHorizonDays));
    final slots = <_ScheduleSlot>[];

    final int maxIterations = ((maxHorizonDays * 24 * 60) ~/ slotMinutes) + 8;
    int iterations = 0;
    while (slots.length < _scheduleSlotCount && cursor.isBefore(horizonEnd) && iterations < maxIterations) {
      iterations += 1;
      final slotEnd = cursor.add(slotDuration);
      final bool shouldInclude =
          is24Hours ||
          openingHours.isEmpty ||
          (_isWithinOpeningHours(openingHours, cursor) &&
              _isWithinOpeningHours(openingHours, slotEnd.subtract(const Duration(minutes: 1))));
      if (shouldInclude) {
        slots.add(
          _ScheduleSlot(
            startAt: cursor,
            endAt: slotEnd,
            dayLabel: _formatDayLabel(cursor),
            timeRange: '${_formatTime(cursor)} - ${_formatTime(slotEnd)}',
          ),
        );
      }
      cursor = cursor.add(slotDuration);
    }

    return slots;
  }

  int _parsePositiveInt(dynamic value, int fallback, {required int min, required int max}) {
    final parsed = value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
    if (parsed == null) return fallback;
    if (parsed < min || parsed > max) return fallback;
    return parsed;
  }

  bool _parseBool(dynamic value, {required bool defaultValue}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (['true', '1', 'yes', 'y', 'on'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n', 'off'].contains(normalized)) return false;
    }
    return defaultValue;
  }

  List<_OpeningHourEntry> _parseOpeningHours(dynamic raw) {
    if (raw is! List) return const <_OpeningHourEntry>[];
    final parsed = <_OpeningHourEntry>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final dayOfWeek = entry['dayOfWeek'] is num ? (entry['dayOfWeek'] as num).toInt() : null;
      final openTime = entry['openTime']?.toString();
      final closeTime = entry['closeTime']?.toString();
      if (dayOfWeek == null || dayOfWeek < 0 || dayOfWeek > 6) continue;
      if (openTime == null || closeTime == null) continue;
      parsed.add(
        _OpeningHourEntry(
          dayOfWeek: dayOfWeek,
          openTime: openTime,
          closeTime: closeTime,
          isClosed: _parseBool(entry['isClosed'], defaultValue: false),
        ),
      );
    }
    return parsed;
  }

  int? _timeToMinutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(value.trim());
    if (match == null) return null;
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  bool _isWithinOpeningHours(List<_OpeningHourEntry> openingHours, DateTime time) {
    if (openingHours.isEmpty) return true;

    final dayOfWeek = time.weekday % 7;
    final minuteOfDay = time.hour * 60 + time.minute;
    _OpeningHourEntry? byDay(int day) {
      for (final entry in openingHours) {
        if (entry.dayOfWeek == day) return entry;
      }
      return null;
    }

    final today = byDay(dayOfWeek);
    if (today != null && !today.isClosed) {
      final openMinute = _timeToMinutes(today.openTime);
      final closeMinute = _timeToMinutes(today.closeTime);
      if (openMinute != null && closeMinute != null) {
        if (_isMinuteInsideWindow(minuteOfDay, openMinute, closeMinute)) {
          return true;
        }
      }
    }

    final previousDay = (dayOfWeek + 6) % 7;
    final previous = byDay(previousDay);
    if (previous == null || previous.isClosed) return false;
    final prevOpen = _timeToMinutes(previous.openTime);
    final prevClose = _timeToMinutes(previous.closeTime);
    if (prevOpen == null || prevClose == null) return false;
    if (prevClose >= prevOpen) return false;
    return minuteOfDay < prevClose;
  }

  bool _isMinuteInsideWindow(int minuteOfDay, int openMinute, int closeMinute) {
    if (openMinute == closeMinute) return true;
    if (closeMinute > openMinute) {
      return minuteOfDay >= openMinute && minuteOfDay < closeMinute;
    }
    return minuteOfDay >= openMinute || minuteOfDay < closeMinute;
  }

  String _getNoScheduleSlotsMessage(Map<String, dynamic>? scheduleAvailability) {
    final bool isAcceptingOrders = _parseBool(scheduleAvailability?['isAcceptingOrders'], defaultValue: true);
    if (!isAcceptingOrders) {
      return "This vendor is currently unavailable for new orders.";
    }

    final bool isAcceptingScheduledOrders = _parseBool(
      scheduleAvailability?['isAcceptingScheduledOrders'],
      defaultValue: true,
    );
    if (!isAcceptingScheduledOrders) {
      return "This vendor is not accepting scheduled orders right now.";
    }

    final bool isOpenNow = _parseBool(scheduleAvailability?['isOpen'], defaultValue: true);
    final bool is24Hours = _parseBool(scheduleAvailability?['is24Hours'], defaultValue: false);
    final openingHours = _parseOpeningHours(scheduleAvailability?['openingHours']);
    if (!is24Hours && openingHours.isEmpty && !isOpenNow) {
      return "No scheduled slots available right now. Try again later.";
    }

    return "No delivery slots available in the selected scheduling window.";
  }

  bool _shouldAllowClosedVendorPreCheck(CartProvider provider) {
    if (_isMixedCartCheckout(provider, isPickupMode: provider.fulfillmentMode == 'pickup')) {
      return false;
    }
    if (provider.fulfillmentMode == 'pickup') return false;
    if (!_isScheduleEnabled) return false;
    return _selectedScheduleSlot() != null;
  }

  bool _ensureScheduleSelectionAvailable(CartProvider provider) {
    final isPickupMode = provider.fulfillmentMode == 'pickup';
    if (_isMixedCartCheckout(provider, isPickupMode: isPickupMode)) {
      return true;
    }
    if (provider.fulfillmentMode == 'pickup' || !_isScheduleEnabled) {
      return true;
    }

    final nextSlots = _generateScheduleSlots(provider.scheduleAvailability);
    final nextIndex = nextSlots.isEmpty ? 0 : math.min(_selectedScheduleIndex, nextSlots.length - 1);
    if (!_areScheduleSlotsEqual(_scheduleSlots, nextSlots) || nextIndex != _selectedScheduleIndex) {
      setState(() {
        _scheduleSlots = nextSlots;
        _selectedScheduleIndex = nextIndex;
      });
    }

    return nextSlots.isNotEmpty;
  }

  _ScheduleSlot? _selectedScheduleSlot() {
    if (!_isScheduleEnabled || _scheduleSlots.isEmpty) return null;
    final index = math.min(_selectedScheduleIndex, _scheduleSlots.length - 1);
    if (index < 0) return null;
    return _scheduleSlots[index];
  }

  DateTime _roundUpToSlot(DateTime time, Duration slot) {
    final slotMinutes = slot.inMinutes;
    final totalMinutes = time.hour * 60 + time.minute;
    final remainder = totalMinutes % slotMinutes;
    final delta = remainder == 0 ? 0 : slotMinutes - remainder;
    final rounded = time.add(Duration(minutes: delta));
    return DateTime(rounded.year, rounded.month, rounded.day, rounded.hour, rounded.minute);
  }

  String _formatDayLabel(DateTime time) {
    final now = DateTime.now();
    if (_isSameDay(time, now)) return "Today";
    if (_isSameDay(time, now.add(const Duration(days: 1)))) return "Tomorrow";

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = weekdays[time.weekday - 1];
    final monthName = months[time.month - 1];
    return '$dayName, $monthName ${time.day}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    required AppColorsExtension colors,
    required bool isDark,
    double? borderRadius,
    BoxShape shape = BoxShape.rectangle,
  }) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: shape,
          borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius ?? 8.r) : null,
        ),
      ),
    );
  }

  Widget _buildAnimatedInstructionPanel({required bool isVisible, required Widget child}) {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: child,
      crossFadeState: isVisible ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 260),
      firstCurve: Curves.easeInOutCubic,
      secondCurve: Curves.easeInOutCubic,
      sizeCurve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
    );
  }

  Set<String> _orderNoteSelectionsForGroup(String groupKey) {
    return _selectedOrderNotePresetsByGroup.putIfAbsent(groupKey, () => <String>{});
  }

  TextEditingController _orderNoteControllerForGroup(String groupKey) {
    return _orderNoteControllersByGroup.putIfAbsent(groupKey, TextEditingController.new);
  }

  String _combinedOrderNoteForGroup(String groupKey) {
    final selected = _orderNoteSelectionsForGroup(groupKey);
    final custom = _orderNoteControllerForGroup(groupKey).text.trim();
    final segments = <String>[...selected, if (custom.isNotEmpty) custom];
    return segments.join(', ');
  }

  Widget _buildOrderNotesSection({
    required CartProvider provider,
    required AppColorsExtension colors,
    required bool isMixedCheckout,
  }) {
    final groups = _collectCheckoutVendorGroups(provider, provider.cartItems);
    if (groups.isEmpty) return const SizedBox.shrink();

    final bool showGroupLabels = isMixedCheckout || groups.length > 1;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Order Note (Optional)",
            style: TextStyle(
              fontFamily: "Lato",
              package: 'grab_go_shared',
              color: colors.textPrimary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            "Use item customization for food preferences. Add notes here for packaging, substitutions, or handover details.",
            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500, height: 1.35),
          ),
          SizedBox(height: 12.h),
          for (int index = 0; index < groups.length; index++) ...[
            _buildOrderNoteEditorCard(group: groups[index], colors: colors, showGroupLabel: showGroupLabels),
            if (index < groups.length - 1) SizedBox(height: 10.h),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderNoteEditorCard({
    required _CheckoutVendorGroup group,
    required AppColorsExtension colors,
    required bool showGroupLabel,
  }) {
    final groupKey = group.groupKey;
    final isCustomExpanded = _expandedOrderNoteGroups.contains(groupKey);
    final controller = _orderNoteControllerForGroup(groupKey);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.inputBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showGroupLabel) ...[
            Text(
              group.providerName,
              style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
          ],
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final option in _orderNotePresetOptions)
                _buildOrderNotePresetChip(groupKey: groupKey, label: option, colors: colors),
              _buildCustomOrderNoteChip(groupKey: groupKey, colors: colors),
            ],
          ),
          _buildAnimatedInstructionPanel(
            isVisible: isCustomExpanded,
            child: Padding(
              padding: EdgeInsets.only(top: 10.h),
              child: Container(
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(10.r)),
                child: TextField(
                  controller: controller,
                  maxLines: 3,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: "Add order-level note (e.g., pack separately, call if unavailable)",
                    hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w500),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderNotePresetChip({
    required String groupKey,
    required String label,
    required AppColorsExtension colors,
  }) {
    final bool isSelected = _orderNoteSelectionsForGroup(groupKey).contains(label);

    return GestureDetector(
      onTap: () {
        setState(() {
          final selections = _orderNoteSelectionsForGroup(groupKey);
          if (isSelected) {
            selections.remove(label);
          } else {
            selections.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomOrderNoteChip({required String groupKey, required AppColorsExtension colors}) {
    final bool isExpanded = _expandedOrderNoteGroups.contains(groupKey);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedOrderNoteGroups.remove(groupKey);
          } else {
            _expandedOrderNoteGroups.add(groupKey);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isExpanded ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Custom",
              style: TextStyle(
                color: isExpanded ? Colors.white : colors.textPrimary,
                fontSize: 13.sp,
                fontWeight: isExpanded ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              child: SvgPicture.asset(
                Assets.icons.navArrowDown,
                package: 'grab_go_shared',
                height: 16.h,
                width: 16.w,
                colorFilter: ColorFilter.mode(isExpanded ? Colors.white : colors.textPrimary, BlendMode.srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInstructionChip(String label, AppColorsExtension colors) {
    final bool isSelected = _selectedDeliveryInstructions.contains(label);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDeliveryInstructions.remove(label);
          } else {
            _selectedDeliveryInstructions.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomDeliveryInstructionChip(AppColorsExtension colors) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomDeliveryInstruction = !_showCustomDeliveryInstruction;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _showCustomDeliveryInstruction ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Custom",
              style: TextStyle(
                color: _showCustomDeliveryInstruction ? Colors.white : colors.textPrimary,
                fontSize: 13.sp,
                fontWeight: _showCustomDeliveryInstruction ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            AnimatedRotation(
              turns: _showCustomDeliveryInstruction ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              child: SvgPicture.asset(
                Assets.icons.navArrowDown,
                package: 'grab_go_shared',
                height: 16.h,
                width: 16.w,
                colorFilter: ColorFilter.mode(
                  _showCustomDeliveryInstruction ? Colors.white : colors.textPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipChip(double amount, String label, AppColorsExtension colors) {
    final bool isSelected = _tipAmount == amount;

    return GestureDetector(
      onTap: () {
        setState(() {
          _tipAmount = amount;
          _showCustomTip = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.textPrimary,
            fontSize: 13.sp,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomTipChip(AppColorsExtension colors) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomTip = !_showCustomTip;
          if (!_showCustomTip) {
            _tipAmount = 0.0;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _showCustomTip ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Custom",
              style: TextStyle(
                color: _showCustomTip ? Colors.white : colors.textPrimary,
                fontSize: 13.sp,
                fontWeight: _showCustomTip ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            AnimatedRotation(
              turns: _showCustomTip ? 0.5 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              child: SvgPicture.asset(
                Assets.icons.navArrowDown,
                package: 'grab_go_shared',
                height: 16.h,
                width: 16.w,
                colorFilter: ColorFilter.mode(_showCustomTip ? Colors.white : colors.textPrimary, BlendMode.srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGhanaPhonePrefix(BuildContext context) {
    final colors = context.appColors;
    return SizedBox(
      width: 92.w,
      child: Container(
        padding: EdgeInsets.only(left: 12.w, right: 8.w),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 4.w),
            Text(
              "+233",
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            SizedBox(width: 8.w),
            Container(width: 1.2, height: 22.h, color: colors.inputBorder),
            SizedBox(width: 8.w),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressTile({
    required String id,
    required String title,
    String? phone,
    required String address,
    double? latitude,
    double? longitude,
    required BuildContext context,
  }) {
    final colors = context.appColors;
    final bool isSelected = _selectedAddressId == id;
    final cartProvider = context.read<CartProvider>();

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddressId = id;
          _selectedAddress = address;
          _selectedAddressDetails = address;
          _selectedLatitude = latitude;
          _selectedLongitude = longitude;
        });
        if (latitude != null && longitude != null) {
          cartProvider.updateDeliveryLocation(latitude: latitude, longitude: longitude);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.symmetric(horizontal: 0.w, vertical: 6.h),
        padding: EdgeInsets.symmetric(horizontal: 16.r, vertical: 6.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        ),
        child: Row(
          children: [
            Container(
              height: 24.h,
              width: 24.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colors.accentOrange.withValues(alpha: 0.1) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        height: 10.h,
                        width: 10.w,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.accentOrange.withValues(alpha: 0.15) : colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? colors.accentOrange : colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  if (phone != null && phone.trim().isNotEmpty) ...[
                    Row(
                      children: [
                        SvgPicture.asset(
                          Assets.icons.phone,
                          package: 'grab_go_shared',
                          height: 12.h,
                          width: 12.w,
                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          phone,
                          style: TextStyle(fontSize: 12.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                  ],
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.mapPin,
                        package: 'grab_go_shared',
                        height: 12.h,
                        width: 12.w,
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          address,
                          style: TextStyle(fontSize: 12.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openAddressPickerFromCheckout,
                customBorder: const CircleBorder(),
                child: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
                  child: SvgPicture.asset(
                    Assets.icons.edit,
                    package: 'grab_go_shared',
                    height: 16.h,
                    width: 16.w,
                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationTile(BuildContext context) {
    final colors = context.appColors;
    final bool isSelected = _selectedAddressId == "current_location";
    final locationProvider = context.read<NativeLocationProvider>();
    final cartProvider = context.read<CartProvider>();
    final double? latitude = locationProvider.latitude;
    final double? longitude = locationProvider.longitude;

    return GestureDetector(
      onTap: () {
        final addressText = locationProvider.address.isNotEmpty ? locationProvider.address : "Current Location";
        setState(() {
          _selectedAddressId = "current_location";
          _selectedAddress = addressText;
          _selectedAddressDetails = addressText;
          _selectedLatitude = latitude;
          _selectedLongitude = longitude;
        });
        if (latitude != null && longitude != null) {
          cartProvider.updateDeliveryLocation(latitude: latitude, longitude: longitude);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          border: Border.all(color: colors.inputBorder.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          children: [
            Container(
              height: 50.h,
              width: 50.w,
              decoration: BoxDecoration(
                color: colors.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.mapPin,
                  package: 'grab_go_shared',
                  height: 28.h,
                  width: 28.w,
                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                ),
              ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.accentOrange.withValues(alpha: 0.15) : colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          "Use Current Location",
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? colors.accentOrange : colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    "Tap to use your current GPS location",
                    style: TextStyle(fontSize: 12.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              height: 24.h,
              width: 24.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? colors.accentOrange.withValues(alpha: 0.1) : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        height: 10.h,
                        width: 10.w,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _formatEstimatedDelivery(
    Map<CartItem, int> cartItems, {
    int providerCount = 1,
    int? minMinutes,
    int? maxMinutes,
    int? completionMinMinutes,
    int? completionMaxMinutes,
    bool isPickupMode = false,
  }) {
    final prefix = isPickupMode ? "Est. Pickup" : "Est. Delivery";
    String formatWindow(int start, int end) {
      if (start == end) {
        const padding = 5;
        start = math.max(5, start - padding);
        end = end + padding;
      }
      return "$start-$end mins";
    }

    if (!isPickupMode &&
        providerCount > 1 &&
        completionMinMinutes != null &&
        completionMaxMinutes != null &&
        completionMinMinutes > 0 &&
        completionMaxMinutes > 0) {
      final completionWindow = formatWindow(completionMinMinutes, completionMaxMinutes);
      return "All deliveries by: $completionWindow";
    }

    if (minMinutes != null && maxMinutes != null && minMinutes > 0 && maxMinutes > 0) {
      return "$prefix: ${formatWindow(minMinutes, maxMinutes)}";
    }

    if (cartItems.isEmpty) {
      return "$prefix: --";
    }

    final times = cartItems.keys
        .map(_deliveryMinutesForItem)
        .where((minutes) => minutes != null && minutes > 0)
        .cast<int>()
        .toList();

    if (times.isEmpty) {
      return "$prefix: --";
    }

    var minTime = times.reduce((a, b) => a < b ? a : b);
    var maxTime = times.reduce((a, b) => a > b ? a : b);

    if (minTime == maxTime) {
      const padding = 5;
      minTime = math.max(5, minTime - padding);
      maxTime = maxTime + padding;
    }
    return "$prefix: $minTime-$maxTime mins";
  }

  int? _deliveryMinutesForItem(CartItem item) {
    if (item is FoodItem) {
      return item.deliveryTimeMinutes;
    }
    if (item is GroceryItem) {
      return 45;
    }
    if (item is PharmacyItem) {
      return 30;
    }
    return 30;
  }
}

class _ScheduleSlot {
  final DateTime startAt;
  final DateTime endAt;
  final String dayLabel;
  final String timeRange;

  const _ScheduleSlot({required this.startAt, required this.endAt, required this.dayLabel, required this.timeRange});
}

class _OpeningHourEntry {
  final int dayOfWeek;
  final String openTime;
  final String closeTime;
  final bool isClosed;

  const _OpeningHourEntry({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
  });
}

class _CachedAddresses {
  final List<AddressModel> addresses;
  final bool isStale;

  const _CachedAddresses({required this.addresses, required this.isStale});
}

class _CodEligibilitySheetContent {
  final String title;
  final String message;
  final List<String> steps;
  final String? progress;

  const _CodEligibilitySheetContent({required this.title, required this.message, required this.steps, this.progress});
}

class _CheckoutVendorGroup {
  final String groupKey;
  final String providerName;
  final int itemCount;
  final double subtotal;
  final String? etaLabel;

  const _CheckoutVendorGroup({
    required this.groupKey,
    required this.providerName,
    required this.itemCount,
    required this.subtotal,
    this.etaLabel,
  });
}

class _CheckoutVendorGroupMutable {
  final String groupKey;
  final String providerName;
  int itemCount;
  double subtotal;
  String? etaLabel;

  _CheckoutVendorGroupMutable({
    required this.groupKey,
    required this.providerName,
    required this.itemCount,
    required this.subtotal,
    this.etaLabel,
  });
}

enum _FeeInfoType { delivery, service, rain }

enum _CheckoutPaymentMethod { card, cash }

class _FeeInfoDetail {
  final String title;
  final String body;

  const _FeeInfoDetail({required this.title, required this.body});
}
