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
import 'package:grab_go_customer/features/home/model/food_category.dart';
import 'package:grab_go_customer/features/groceries/model/grocery_item.dart';
import 'package:grab_go_customer/features/pharmacy/model/pharmacy_item.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_customer/shared/services/paystack_service.dart' as paystack;
import 'package:pay_with_paystack/pay_with_paystack.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:shimmer/shimmer.dart';

class Checkout extends StatefulWidget {
  const Checkout({super.key});

  @override
  State<Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<Checkout> {
  String _selectedAddress = "";
  String _selectedAddressDetails = "";
  String? _selectedAddressId;
  double? _selectedLatitude;
  double? _selectedLongitude;
  List<AddressModel> _savedAddresses = [];
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

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
    _loadUserPhone();
  }

  @override
  void dispose() {
    _restaurantInstructionController.dispose();
    _deliveryInstructionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPhone() async {
    try {
      final user = await UserService().getCurrentUser();
      final formatted = _formatPhone(user?.phone);
      if (!mounted) return;
      setState(() {
        _userPhone = formatted;
      });
    } catch (e) {
      debugPrint('❌ Checkout: Failed to load user phone: $e');
    }
  }

  String? _formatPhone(int? phone) {
    if (phone == null) return null;
    final digits = phone.toString();
    if (digits.startsWith('0') && digits.length == 10) {
      return '+233${digits.substring(1)}';
    }
    if (digits.length == 9) {
      return '+233$digits';
    }
    if (digits.startsWith('233') && digits.length >= 12) {
      return '+$digits';
    }
    return digits;
  }

  Future<void> _loadSavedAddresses() async {
    if (_isLoadingAddresses) return;

    setState(() {
      _isLoadingAddresses = true;
    });

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

      AddressModel? defaultAddress;
      if (_selectedAddressId == null && addresses.isNotEmpty) {
        defaultAddress = addresses.firstWhere((address) => address.isDefault, orElse: () => addresses.first);
      }

      if (!mounted) return;

      setState(() {
        _savedAddresses = addresses;
        _isLoadingAddresses = false;

        if (defaultAddress != null) {
          _selectedAddressId = _addressSelectionKey(defaultAddress);
          _selectedAddress = defaultAddress.formattedAddress;
          _selectedAddressDetails = defaultAddress.formattedAddress;
          _selectedLatitude = defaultAddress.latitude;
          _selectedLongitude = defaultAddress.longitude;
        }
      });

      if (defaultAddress != null) {
        _updateDeliveryLocation(defaultAddress.latitude, defaultAddress.longitude);
      }
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
      statusBarColor: colors.backgroundSecondary,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: colors.backgroundSecondary,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: Consumer<CartProvider>(
          builder: (context, provider, child) {
            final double subtotal = provider.subtotal;
            final double deliveryFee = provider.deliveryFee;
            final double serviceFee = provider.serviceFee;
            final double rainFee = provider.rainFee;
            final double creditsApplied = provider.creditsApplied;
            final double total = provider.total + _tipAmount;
            final bool isPricingLoading = provider.isPricingLoading;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: padding.top, left: 20.w, right: 20.w, bottom: 16.h),
                  child: Row(
                    children: [
                      Container(
                        height: 44.h,
                        width: 44.w,
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
                          fontSize: 24.sp,
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
                        SizedBox(height: 10.h),
                        if (_isLoadingAddresses) ...[
                          _buildAddressShimmerTile(colors, isDark),
                          _buildAddressShimmerTile(colors, isDark),
                        ],
                        if (!_isLoadingAddresses && _savedAddresses.isNotEmpty)
                          ..._savedAddresses.map(
                            (address) => _buildAddressTile(
                              id: _addressSelectionKey(address),
                              title: _addressTitle(address),
                              phone: _userPhone,
                              address: address.formattedAddress,
                              latitude: address.latitude,
                              longitude: address.longitude,
                              context: context,
                            ),
                          ),
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

                        SizedBox(height: 8.h),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                          child: Text(
                            "Special Instructions",
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

                        // Tip amount chips
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
                              if (rainFee > 0) ...[
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
                              if (_tipAmount > 0) ...[
                                SizedBox(height: 6.h),
                                _buildPriceRow(context, "Tip", _tipAmount, colors, false, false),
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
                            ),
                            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
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
                            color: _isProcessingPayment ? colors.textSecondary : colors.accentOrange,
                            borderRadius: BorderRadius.circular(12.r),
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
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.sp),
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

  void _onProceedToPayment(BuildContext context, CartProvider provider, AppColorsExtension colors) {
    if (_isProcessingPayment) return;

    if (provider.isPricingLoading) {
      AppToastMessage.show(context: context, message: "Calculating fees, please wait...");
      return;
    }

    if (provider.cartItems.isEmpty) {
      AppToastMessage.show(context: context, message: "Your cart is empty.");
      return;
    }

    if (_selectedLatitude != null && _selectedLongitude != null) {
      provider.updateDeliveryLocation(latitude: _selectedLatitude, longitude: _selectedLongitude);
    }

    if (_selectedAddress.isEmpty) {
      AppToastMessage.show(context: context, message: "Please select a delivery address.");
      return;
    }

    _showPaymentConfirmationSheet(context, provider, colors);
  }

  void _showPaymentConfirmationSheet(BuildContext context, CartProvider provider, AppColorsExtension colors) {
    final parentContext = context;
    final addressText = _selectedAddressDetails.isNotEmpty ? _selectedAddressDetails : _selectedAddress;
    final double subtotal = provider.subtotal;
    final double deliveryFee = provider.deliveryFee;
    final double serviceFee = provider.serviceFee;
    final double rainFee = provider.rainFee;
    final double creditsApplied = provider.creditsApplied;
    final double total = provider.total + _tipAmount;

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
              _buildSummaryBlock("Delivery Address", addressText, colors),
              SizedBox(height: 10.h),
              _buildSummaryBlock("Payment Method", "Paystack (Card)", colors),
              SizedBox(height: 14.h),
              _buildSummaryRow("Subtotal", subtotal, colors),
              SizedBox(height: 6.h),
              _buildSummaryRow("Delivery Fee", deliveryFee, colors),
              SizedBox(height: 6.h),
              _buildSummaryRow("Service Fee", serviceFee, colors),
              if (rainFee > 0) ...[SizedBox(height: 6.h), _buildSummaryRow("Rain Fee", rainFee, colors)],
              if (creditsApplied > 0) ...[
                SizedBox(height: 6.h),
                _buildSummaryRow("Credits Applied", -creditsApplied, colors),
              ],
              if (_tipAmount > 0) ...[SizedBox(height: 6.h), _buildSummaryRow("Tip", _tipAmount, colors)],
              SizedBox(height: 10.h),
              Divider(color: colors.backgroundSecondary, height: 1),
              SizedBox(height: 10.h),
              _buildSummaryRow("Total", total, colors, isEmphasis: true),
              SizedBox(height: 16.h),
              GestureDetector(
                onTap: _isProcessingPayment
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _handlePaystackPayment(parentContext, provider);
                      },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  decoration: BoxDecoration(color: colors.accentOrange, borderRadius: BorderRadius.circular(12.r)),
                  child: Center(
                    child: Text(
                      "Pay Now (GHS ${total.toStringAsFixed(2)})",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.sp),
                    ),
                  ),
                ),
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
      decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(12.r)),
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

    final double subtotal = provider.subtotal;
    final double deliveryFee = provider.deliveryFee;
    final double total = provider.total + _tipAmount;

    try {
      final orderId = await _createOrder(context, subtotal, deliveryFee, total);
      if (orderId == null) {
        throw Exception('Failed to create order');
      }

      final user = await UserService().getCurrentUser();
      final email = user?.email ?? 'customer@grabgo.com';

      final paystackHelper = PayWithPayStack();
      final reference = paystackHelper.generateUuidV4();
      final authUrl = await _generatePaystackUrl(amount: total, email: email, reference: reference);

      setState(() {
        _isProcessingPayment = false;
      });

      final result = await paystack.PaystackService.instance.launchPayment(
        context: context,
        authorizationUrl: authUrl,
        reference: reference,
      );

      if (result.success) {
        _handlePaymentSuccess(context);
      } else {
        _handlePaymentFailure(context);
      }
    } catch (e) {
      setState(() {
        _isProcessingPayment = false;
      });
      _showErrorDialog(context, 'Payment failed: ${e.toString()}');
    }
  }

  Future<String> _generatePaystackUrl({
    required double amount,
    required String email,
    required String reference,
  }) async {
    final amountInKobo = (amount * 100).toInt();
    final publicKey = AppConfig.paystackPublicKey;
    return 'https://checkout.paystack.com/$publicKey?amount=$amountInKobo&email=$email&reference=$reference&currency=${AppConfig.currency}';
  }

  Future<String?> _createOrder(BuildContext context, double subtotal, double deliveryFee, double total) async {
    final cart = context.read<CartProvider>();
    final orderService = OrderServiceWrapper();

    try {
      final orderId = await orderService.createOrder(
        cartItems: cart.cartItems,
        deliveryAddress: _selectedAddress,
        deliveryLatitude: _selectedLatitude,
        deliveryLongitude: _selectedLongitude,
        paymentMethod: "card",
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        total: total,
        notes: _getConcatenatedNotes(),
      );

      return orderId;
    } catch (e) {
      debugPrint("Order creation error: $e");
      throw Exception("Failed to create order: ${e.toString()}");
    }
  }

  void _handlePaymentSuccess(BuildContext context) {
    final cart = context.read<CartProvider>();
    final cartSubtotal = cart.subtotal;
    final deliveryFeeAmount = cart.deliveryFee;
    final serviceFeeAmount = cart.serviceFee;
    final rainFeeAmount = cart.rainFee;
    final taxAmount = cart.tax;
    final double totalAmount = cart.total + _tipAmount;

    cart.clearCart();

    context.go(
      '/paymentComplete',
      extra: {
        'method': 'Paystack',
        'total': totalAmount,
        'subTotal': cartSubtotal,
        'deliveryFee': deliveryFeeAmount,
        'serviceFee': serviceFeeAmount,
        'rainFee': rainFeeAmount,
        'tax': taxAmount,
        'tip': _tipAmount,
        'orderNumber': _generateOrderNumber(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _handlePaymentFailure(BuildContext context) {
    _showErrorDialog(context, "Payment failed. Please try again.");
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

    if (_selectedDeliveryInstructions.isNotEmpty || _deliveryInstructionController.text.isNotEmpty) {
      notesParts.add(
        "Delivery: ${[..._selectedDeliveryInstructions, if (_deliveryInstructionController.text.isNotEmpty) _deliveryInstructionController.text].join(', ')}",
      );
    }

    return notesParts.join(" | ");
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Error'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  Widget _buildAddressShimmerTile(AppColorsExtension colors, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withValues(alpha: 0.5), width: 1),
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

  String _formatEstimatedDelivery(Map<CartItem, int> cartItems, {int? minMinutes, int? maxMinutes}) {
    if (minMinutes != null && maxMinutes != null && minMinutes > 0 && maxMinutes > 0) {
      if (minMinutes == maxMinutes) {
        const padding = 5;
        minMinutes = math.max(5, minMinutes - padding);
        maxMinutes = maxMinutes + padding;
      }
      return "Est. Delivery: $minMinutes-$maxMinutes mins";
    }

    if (cartItems.isEmpty) {
      return "Est. Delivery: --";
    }

    final times = cartItems.keys
        .map(_deliveryMinutesForItem)
        .where((minutes) => minutes != null && minutes > 0)
        .cast<int>()
        .toList();

    if (times.isEmpty) {
      return "Est. Delivery: --";
    }

    var minTime = times.reduce((a, b) => a < b ? a : b);
    var maxTime = times.reduce((a, b) => a > b ? a : b);

    if (minTime == maxTime) {
      const padding = 5;
      minTime = math.max(5, minTime - padding);
      maxTime = maxTime + padding;
    }
    return "Est. Delivery: $minTime-$maxTime mins";
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

enum _FeeInfoType { delivery, service, rain }

class _FeeInfoDetail {
  final String title;
  final String body;

  const _FeeInfoDetail({required this.title, required this.body});
}
