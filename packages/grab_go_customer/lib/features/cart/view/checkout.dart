import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/cart/model/cart_item_interface.dart';
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
  bool _isGiftOrder = false;
  bool _isLoadingAddresses = false;
  String? _userPhone;
  bool _isProcessingPayment = false;
  final List<String> _selectedInstructions = [];
  bool _showCustomInstruction = false;
  final List<String> _selectedDeliveryInstructions = [];
  bool _showCustomDeliveryInstruction = false;
  bool _showCustomTip = false;
  double _tipAmount = 0.0;

  final TextEditingController _restaurantInstructionController = TextEditingController();
  final TextEditingController _deliveryInstructionController = TextEditingController();
  final TextEditingController _pickupContactNameController = TextEditingController();
  final TextEditingController _pickupContactPhoneController = TextEditingController();
  final TextEditingController _giftRecipientNameController = TextEditingController();
  final TextEditingController _giftRecipientPhoneController = TextEditingController();
  final TextEditingController _giftNoteController = TextEditingController();
  bool _pickupNoShowAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
    _loadUserPhone();
    _scheduleSlots = _generateScheduleSlots();
  }

  @override
  void dispose() {
    _restaurantInstructionController.dispose();
    _deliveryInstructionController.dispose();
    _pickupContactNameController.dispose();
    _pickupContactPhoneController.dispose();
    _giftRecipientNameController.dispose();
    _giftRecipientPhoneController.dispose();
    _giftNoteController.dispose();
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
              final double subtotal = provider.subtotal;
              final double deliveryFee = provider.deliveryFee;
              final double serviceFee = provider.serviceFee;
              final double rainFee = provider.rainFee;
              final double creditsApplied = provider.creditsApplied;
              final bool isPickupMode = provider.fulfillmentMode == 'pickup' || isPickupTab;
              final double effectiveTip = isPickupMode ? 0.0 : _tipAmount;
              final double total = provider.total + effectiveTip;
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
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
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
                                "Delivery Address",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
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
                            _buildScheduleSection(colors),
                            SizedBox(height: 8.h),
                            _buildGiftOrderSection(colors),
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
                              child: Container(
                                padding: EdgeInsets.all(12.r),
                                decoration: BoxDecoration(
                                  color: colors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
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
                            ),
                            SizedBox(height: 8.h),
                          ],

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                            child: Text(
                              "Vendor Instructions",
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
                                _buildInstructionChip("No onions", colors),
                                _buildInstructionChip("Extra sauce", colors),
                                _buildInstructionChip("Less spicy", colors),
                                _buildInstructionChip("No ice", colors),
                                _buildInstructionChip("Cutlery included", colors),
                                _buildInstructionChip("Extra napkins", colors),
                                _buildCustomInstructionChip(colors),
                              ],
                            ),
                          ),

                          if (_showCustomInstruction) ...[
                            SizedBox(height: 12.h),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              child: Container(
                                padding: EdgeInsets.all(16.r),
                                decoration: BoxDecoration(
                                  color: colors.backgroundPrimary,
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(color: colors.inputBorder, width: 0.5),
                                ),
                                child: TextField(
                                  controller: _restaurantInstructionController,
                                  maxLines: 3,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Add notes for the restaurant (e.g., no onions, extra sauce)",
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
                          ],

                          if (!isPickupMode) ...[
                            SizedBox(height: 16.h),
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
                            if (_showCustomDeliveryInstruction) ...[
                              SizedBox(height: 12.h),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Container(
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: colors.backgroundPrimary,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(color: colors.inputBorder, width: 0.5),
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
                            ],
                            SizedBox(height: 16.h),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                              child: Text(
                                "Tip Delivery Driver",
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
                            if (_showCustomTip) ...[
                              SizedBox(height: 12.h),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Container(
                                  padding: EdgeInsets.all(16.r),
                                  decoration: BoxDecoration(
                                    color: colors.backgroundPrimary,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(color: colors.inputBorder, width: 0.5),
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
                            ],
                          ],
                          SizedBox(height: 16.h),

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
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

                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Column(
                              children: [
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
                                  _buildPriceRow(context, "Credits Applied", -creditsApplied, colors, false, false),
                                ],
                                if (!isPickupMode && effectiveTip > 0) ...[
                                  SizedBox(height: 6.h),
                                  _buildPriceRow(context, "Tip", effectiveTip, colors, false, false),
                                ],
                                SizedBox(height: 6.h),
                                _buildTotalRow(context, total, creditsApplied, colors, isLoading: isPricingLoading),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                            child: Text(
                              _formatEstimatedDelivery(
                                provider.cartItems,
                                minMinutes: provider.estimatedDeliveryMin,
                                maxMinutes: provider.estimatedDeliveryMax,
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
                                    _isProcessingPayment ? "Processing..." : "Proceed to Payment",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.sp),
                                  ),
                                  if (!_isProcessingPayment)
                                    Text(
                                      total > 0 ? " (GHS ${total.toStringAsFixed(2)})" : "",
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
            style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            "...",
            style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
        ],
      );
    }

    final double? originalTotal = creditsApplied > 0 ? total + creditsApplied : null;

    return Row(
      children: [
        Text(
          "Total Amount",
          style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w600),
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
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                TextSpan(
                  text: " / ",
                  style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w400),
                ),
                TextSpan(
                  text: "GHS ${total.toStringAsFixed(2)}",
                  style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else
          Text(
            "GHS ${total.toStringAsFixed(2)}",
            style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w600),
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

  Future<void> _onProceedToPayment(BuildContext context, CartProvider provider, AppColorsExtension colors) async {
    if (_isProcessingPayment) return;

    final bool isPickupTab = context.read<NavigationProvider>().selectedIndex == 1;
    if (isPickupTab && provider.fulfillmentMode != 'pickup') {
      await provider.setFulfillmentMode('pickup');
      if (!mounted) return;
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

    final preSyncIssue = _getPrePaymentBlockingIssue(provider);
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

    final postSyncIssue = _getPrePaymentBlockingIssue(provider);
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
    }

    _showPaymentConfirmationSheet(context, provider, colors);
  }

  String? _getPrePaymentBlockingIssue(CartProvider provider) {
    if (provider.cartItems.isEmpty) return "Your cart is empty.";

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

    if (closedVendorItems.isNotEmpty) {
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
    final double subtotal = provider.subtotal;
    final double deliveryFee = isPickupMode ? 0 : provider.deliveryFee;
    final double serviceFee = provider.serviceFee;
    final double rainFee = isPickupMode ? 0 : provider.rainFee;
    final double creditsApplied = provider.creditsApplied;
    final double effectiveTip = isPickupMode ? 0.0 : _tipAmount;
    final double total = provider.total + effectiveTip;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
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
                "Confirm Payment",
                style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 12.h),
              _buildSummaryBlock(
                isPickupMode ? "Pickup Contact" : "Delivery Address",
                isPickupMode ? "${_pickupContactNameController.text.trim()} • ${_pickupPhoneDisplay()}" : addressText,
                colors,
              ),
              if (!isPickupMode && _isGiftOrder) ...[
                SizedBox(height: 10.h),
                _buildSummaryBlock("Gift Delivery", _buildGiftSummaryText(), colors),
              ],
              SizedBox(height: 10.h),
              _buildSummaryBlock("Payment Method", "Paystack (Card, Mobile Money & Bank Transfer)", colors),
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
              SizedBox(height: 10.h),
              Divider(color: colors.backgroundSecondary, height: 1),
              SizedBox(height: 10.h),
              _buildSummaryRow("Total", total, colors, isEmphasis: true),
              SizedBox(height: 16.h),
              AppButton(
                width: double.infinity,
                onPressed: () {
                  if (_isProcessingPayment) return;
                  Navigator.of(sheetContext).pop();
                  _handlePaystackPayment(parentContext, provider);
                },
                buttonText: "Pay Now (GHS ${total.toStringAsFixed(2)})",
                textStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800),
                textColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                borderRadius: KBorderSize.borderMedium,
              ),
            ],
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

    final prePaymentIssue = _getPrePaymentBlockingIssue(provider);
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
    final double total = provider.total + (isPickupMode ? 0.0 : _tipAmount);
    CreateOrderResult? createdOrder;
    String? orderId;
    bool paymentSucceeded = false;
    Map<String, dynamic>? paymentData;

    try {
      createdOrder = await _createOrder(context, subtotal, deliveryFee, total);
      orderId = createdOrder?.orderId;
      if (orderId == null) {
        throw Exception('Failed to create order');
      }

      paymentData = _buildPaymentCompletePayload(
        orderId: orderId,
        orderNumber: createdOrder?.orderNumber,
        giftDeliveryCode: createdOrder?.giftDeliveryCode,
      );

      if (total <= 0) {
        setState(() {
          _isProcessingPayment = false;
        });
        final confirmed = await _confirmOrderPayment(orderId: orderId, reference: 'credits-only');
        if (confirmed) {
          _handlePaymentSuccess(context, paymentData: paymentData);
        } else {
          _showErrorDialog(context, 'Payment confirmation failed. Please try again.');
        }
        return;
      }

      final init = await OrderServiceWrapper().initializePaystackPayment(orderId: orderId);
      final authUrl = init['authorizationUrl']!;
      final reference = init['reference']!;

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
          extra: {'orderId': orderId, 'reference': result.reference ?? reference, 'paymentData': paymentData},
        );
        return;
      }

      await _releaseOrderCreditHold(orderId: orderId);
      _handlePaymentFailure(context, paymentData: paymentData);
    } catch (e) {
      if (orderId != null && !paymentSucceeded) {
        await _releaseOrderCreditHold(orderId: orderId);
      }
      setState(() {
        _isProcessingPayment = false;
      });
      if (orderId != null && paymentData != null) {
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
    final shouldCreateGiftOrder = !isPickupMode && _isGiftOrder;
    final giftRecipientName = shouldCreateGiftOrder ? _giftRecipientNameController.text.trim() : null;
    final giftRecipientPhone = shouldCreateGiftOrder ? _normalizeGhanaPhone(_giftRecipientPhoneController.text) : null;
    final giftNote = shouldCreateGiftOrder ? _giftNoteController.text.trim() : null;

    try {
      final createOrderResult = await orderService.createOrder(
        cartItems: cart.cartItems,
        fulfillmentMode: cart.fulfillmentMode,
        deliveryAddress: isPickupMode ? null : _selectedAddress,
        deliveryLatitude: isPickupMode ? null : _selectedLatitude,
        deliveryLongitude: isPickupMode ? null : _selectedLongitude,
        pickupContactName: isPickupMode ? _pickupContactNameController.text.trim() : null,
        pickupContactPhone: isPickupMode ? _normalizeGhanaPhone(_pickupContactPhoneController.text) : null,
        acceptNoShowPolicy: isPickupMode ? _pickupNoShowAccepted : null,
        noShowPolicyVersion: isPickupMode ? "v1" : null,
        paymentMethod: "card",
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        useCredits: cart.useCredits,
        notes: _getConcatenatedNotes(),
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

  Future<bool> _confirmOrderPayment({required String orderId, required String reference}) async {
    final orderService = OrderServiceWrapper();
    return await orderService.confirmPayment(orderId: orderId, reference: reference);
  }

  Future<void> _releaseOrderCreditHold({required String orderId}) async {
    try {
      final orderService = OrderServiceWrapper();
      await orderService.releaseCreditHold(orderId: orderId);
    } catch (e) {
      debugPrint('⚠️ Failed to release credit hold: $e');
    }
  }

  Map<String, dynamic> _buildPaymentCompletePayload({
    required String orderId,
    String? orderNumber,
    String? giftDeliveryCode,
  }) {
    final cart = context.read<CartProvider>();
    final isPickupMode = cart.fulfillmentMode == 'pickup';
    final cartSubtotal = cart.subtotal;
    final deliveryFeeAmount = isPickupMode ? 0.0 : cart.deliveryFee;
    final serviceFeeAmount = cart.serviceFee;
    final rainFeeAmount = isPickupMode ? 0.0 : cart.rainFee;
    final taxAmount = cart.tax;
    final double effectiveTip = isPickupMode ? 0.0 : _tipAmount;
    final double totalAmount = cart.total + effectiveTip;
    final bool isGiftOrder = !isPickupMode && _isGiftOrder;
    final String? normalizedGiftPhone = isGiftOrder ? _normalizeGhanaPhone(_giftRecipientPhoneController.text) : null;

    return {
      'orderId': orderId,
      'fulfillmentMode': cart.fulfillmentMode,
      'method': 'Paystack',
      'total': totalAmount,
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

  String _getConcatenatedNotes() {
    List<String> notesParts = [];

    if (_selectedInstructions.isNotEmpty || _restaurantInstructionController.text.isNotEmpty) {
      notesParts.add(
        "Restaurant: ${[..._selectedInstructions, if (_restaurantInstructionController.text.isNotEmpty) _restaurantInstructionController.text].join(', ')}",
      );
    }

    final isPickupMode = context.read<CartProvider>().fulfillmentMode == 'pickup';
    if (!isPickupMode && (_selectedDeliveryInstructions.isNotEmpty || _deliveryInstructionController.text.isNotEmpty)) {
      notesParts.add(
        "Delivery: ${[..._selectedDeliveryInstructions, if (_deliveryInstructionController.text.isNotEmpty) _deliveryInstructionController.text].join(', ')}",
      );
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
      padding: EdgeInsets.all(16.r),
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

  Widget _buildScheduleSection(AppColorsExtension colors) {
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
                    _scheduleSlots = _generateScheduleSlots();
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
                                "No delivery slots available right now.",
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
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            ),
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
                        "This order is a gift",
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
                CustomSwitch(
                  value: _isGiftOrder,
                  onChanged: (value) {
                    setState(() {
                      _isGiftOrder = value;
                    });
                  },
                  activeColor: colors.accentOrange,
                ),
              ],
            ),
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
                        borderRadius: 12.r,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
                      ),
                      SizedBox(height: 10.h),
                      AppTextInput(
                        controller: _giftRecipientPhoneController,
                        hintText: "Recipient phone (optional)",
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
                      SizedBox(height: 8.h),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Delivery code is sent to you, and to recipient if phone is provided.",
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

  String _buildGiftSummaryText() {
    final recipientName = _giftRecipientNameController.text.trim();
    final normalizedRecipientPhone = _normalizeGhanaPhone(_giftRecipientPhoneController.text);
    final giftNote = _giftNoteController.text.trim();

    final lines = <String>[
      "Recipient: $recipientName",
      if (normalizedRecipientPhone != null) "Phone: $normalizedRecipientPhone",
      if (giftNote.isNotEmpty) "Note: $giftNote",
    ];
    return lines.join('\n');
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

  List<_ScheduleSlot> _generateScheduleSlots() {
    final now = DateTime.now();
    final leadTime = now.add(const Duration(minutes: 45));
    DateTime start = _roundUpToSlot(leadTime, const Duration(minutes: 30));
    final slots = <_ScheduleSlot>[];

    for (int i = 0; i < _scheduleSlotCount; i++) {
      final slotStart = start.add(Duration(minutes: i * 30));
      final slotEnd = slotStart.add(const Duration(minutes: 30));
      slots.add(
        _ScheduleSlot(
          dayLabel: _formatDayLabel(slotStart),
          timeRange: '${_formatTime(slotStart)} - ${_formatTime(slotEnd)}',
        ),
      );
    }

    return slots;
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

  Widget _buildInstructionChip(String label, AppColorsExtension colors) {
    final bool isSelected = _selectedInstructions.contains(label);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedInstructions.remove(label);
          } else {
            _selectedInstructions.add(label);
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

  Widget _buildCustomInstructionChip(AppColorsExtension colors) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showCustomInstruction = !_showCustomInstruction;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: _showCustomInstruction ? colors.accentOrange : colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Custom",
              style: TextStyle(
                color: _showCustomInstruction ? Colors.white : colors.textPrimary,
                fontSize: 13.sp,
                fontWeight: _showCustomInstruction ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            SizedBox(width: 4.w),
            SvgPicture.asset(
              _showCustomInstruction ? Assets.icons.navArrowUp : Assets.icons.navArrowDown,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(
                _showCustomInstruction ? Colors.white : colors.textPrimary,
                BlendMode.srcIn,
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
            SvgPicture.asset(
              _showCustomDeliveryInstruction ? Assets.icons.navArrowUp : Assets.icons.navArrowDown,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(
                _showCustomDeliveryInstruction ? Colors.white : colors.textPrimary,
                BlendMode.srcIn,
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
            SvgPicture.asset(
              _showCustomTip ? Assets.icons.navArrowUp : Assets.icons.navArrowDown,
              package: 'grab_go_shared',
              height: 16.h,
              width: 16.w,
              colorFilter: ColorFilter.mode(_showCustomTip ? Colors.white : colors.textPrimary, BlendMode.srcIn),
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
        padding: EdgeInsets.all(16.r),
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
                onTap: () async {
                  await context.push("/confirm-address");
                  if (!mounted) return;
                  _loadSavedAddresses();
                },
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
    int? minMinutes,
    int? maxMinutes,
    bool isPickupMode = false,
  }) {
    final prefix = isPickupMode ? "Est. Pickup" : "Est. Delivery";
    if (minMinutes != null && maxMinutes != null && minMinutes > 0 && maxMinutes > 0) {
      if (minMinutes == maxMinutes) {
        const padding = 5;
        minMinutes = math.max(5, minMinutes - padding);
        maxMinutes = maxMinutes + padding;
      }
      return "$prefix: $minMinutes-$maxMinutes mins";
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
  final String dayLabel;
  final String timeRange;

  const _ScheduleSlot({required this.dayLabel, required this.timeRange});
}

class _CachedAddresses {
  final List<AddressModel> addresses;
  final bool isStale;

  const _CachedAddresses({required this.addresses, required this.isStale});
}

enum _FeeInfoType { delivery, service, rain }

class _FeeInfoDetail {
  final String title;
  final String body;

  const _FeeInfoDetail({required this.title, required this.body});
}
