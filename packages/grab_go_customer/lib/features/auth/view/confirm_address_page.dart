import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:grab_go_customer/shared/models/address_model.dart';
import 'package:grab_go_customer/shared/services/location_service.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class ConfirmAddressPage extends StatefulWidget {
  const ConfirmAddressPage({super.key});

  @override
  State<ConfirmAddressPage> createState() => _ConfirmAddressPageState();
}

class _ConfirmAddressPageState extends State<ConfirmAddressPage> {
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  LatLng _currentMapPosition = const LatLng(5.6037, -0.1870); // Default to Accra
  String _currentAddress = "Loading address...";
  bool _isReverseGeocoding = false;
  AddressLabel _selectedLabel = AddressLabel.home;
  BuildingType _selectedBuildingType = BuildingType.apartment;

  Timer? _debounceTimer;
  bool _isMoving = false;
  int _geocodingRequestId = 0;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _unitController.dispose();
    _floorController.dispose();
    _instructionsController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    final locationProvider = Provider.of<NativeLocationProvider>(context, listen: false);
    if (locationProvider.hasLocation) {
      setState(() {
        _currentMapPosition = LatLng(locationProvider.latitude!, locationProvider.longitude!);
        _currentAddress = locationProvider.address;
      });
    } else {
      _useCurrentLocation(isManual: false);
    }
  }

  Future<void> _useCurrentLocation({required bool isManual}) async {
    setState(() => _isReverseGeocoding = true);
    try {
      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final latLng = LatLng(position.latitude, position.longitude);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        _updatePosition(latLng);
      } else {
        if (mounted) {
          setState(() => _isReverseGeocoding = false);
          if (isManual) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to get your current location. Please check your permissions.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReverseGeocoding = false);
        if (isManual) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _currentMapPosition = position.target;
      _isMoving = true;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _isMoving = false);
        _reverseGeocode(_currentMapPosition);
      }
    });
  }

  Future<void> _reverseGeocode(LatLng position) async {
    final requestId = ++_geocodingRequestId;
    setState(() => _isReverseGeocoding = true);

    try {
      final address = await LocationService.getAddressFromCoordinates(position.latitude, position.longitude);

      if (mounted && requestId == _geocodingRequestId) {
        setState(() {
          _currentAddress = address;
          _isReverseGeocoding = false;
        });
      }
    } catch (e) {
      if (mounted && requestId == _geocodingRequestId) {
        setState(() {
          _currentAddress = "Unknown location";
          _isReverseGeocoding = false;
        });
      }
    }
  }

  void _updatePosition(LatLng latLng) {
    setState(() {
      _currentMapPosition = latLng;
    });
    _reverseGeocode(latLng);
  }

  void _onPlaceSelected(Prediction prediction) {
    final lat = prediction.lat != null ? double.tryParse(prediction.lat!) : null;
    final lng = prediction.lng != null ? double.tryParse(prediction.lng!) : null;

    if (lat != null && lng != null) {
      // Invalidate any pending or future reverse geocoding for the camera movement we're about to trigger
      _geocodingRequestId++;
      _debounceTimer?.cancel();

      final latLng = LatLng(lat, lng);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
      setState(() {
        _currentMapPosition = latLng;
        _currentAddress = prediction.description ?? "";
        _isReverseGeocoding = false; // Just in case it was loading
      });
    }
  }

  Future<void> _confirmAddress() async {
    final addressModel = AddressModel(
      latitude: _currentMapPosition.latitude,
      longitude: _currentMapPosition.longitude,
      formattedAddress: _currentAddress,
      label: _selectedLabel,
      buildingType: _selectedBuildingType,
      unitNumber: _unitController.text,
      floor: _floorController.text,
      instructions: _instructionsController.text,
      isComplete: true,
      isDefault: true,
    );

    final locationProvider = Provider.of<NativeLocationProvider>(context, listen: false);
    await locationProvider.setConfirmedAddress(addressModel);

    if (mounted) {
      context.go("/homepage");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            // Map
            GoogleMap(
              initialCameraPosition: CameraPosition(target: _currentMapPosition, zoom: 16),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              style: GrabGoMapStyles.forBrightness(Theme.of(context).brightness),
              onCameraMove: _onCameraMove,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),

            // Central Pin (PickupMap style is simpler, just a pin)
            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isReverseGeocoding && !_isMoving)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius20.r),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black.withAlpha(50) : Colors.black.withAlpha(20),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: 16.w,
                          height: 16.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(colors.accentOrange),
                          ),
                        ),
                      ),
                    SizedBox(height: 8.h),
                    SvgPicture.asset(
                      Assets.icons.mapPin,
                      package: 'grab_go_shared',
                      height: 48.h,
                      colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ),

            // Refined Search Bar and Back Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 10.h,
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      children: [
                        _buildRefinedBackButton(colors, isDark),
                        SizedBox(width: 12.w),
                        Expanded(child: _buildRefinedSearchBar(colors, isDark)),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Map Control Buttons (from PickupMap)
                  Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: _buildMapControlButton(
                      icon: Assets.icons.position,
                      onTap: () => _useCurrentLocation(isManual: true),
                      colors: colors,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Sheet
            Align(alignment: Alignment.bottomCenter, child: _buildAddressDetailsSheet(colors)),
          ],
        ),
      ),
    );
  }

  Widget _buildRefinedBackButton(AppColorsExtension colors, bool isDark) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.pop(),
          customBorder: const CircleBorder(),
          child: Icon(Icons.arrow_back, color: colors.textPrimary, size: 22.r),
        ),
      ),
    );
  }

  Widget _buildRefinedSearchBar(AppColorsExtension colors, bool isDark) {
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.border.r),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GooglePlaceAutoCompleteTextField(
        textEditingController: _searchController,
        googleAPIKey: AppConfig.googlePlacesApiKey,
        inputDecoration: InputDecoration(
          hintText: "Search location...",
          hintStyle: TextStyle(color: colors.textSecondary, fontSize: 15.sp, fontWeight: FontWeight.w500),
          prefixIcon: Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: SvgPicture.asset(
              Assets.icons.search,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
          ),
          prefixIconConstraints: BoxConstraints(minWidth: 20.w, minHeight: 20.w),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 11.h),
        ),
        debounceTime: 400,
        countries: const ["gh"],
        isLatLngRequired: true,
        getPlaceDetailWithLatLng: (Prediction prediction) => _onPlaceSelected(prediction),
        itemClick: (Prediction prediction) {
          _searchController.text = prediction.description ?? "";
        },
        itemBuilder: (context, index, Prediction prediction) {
          return ListTile(
            title: Text(
              prediction.description ?? "",
              style: TextStyle(fontSize: 14.sp, color: colors.textPrimary),
            ),
            leading: Icon(Icons.location_on, color: colors.accentOrange, size: 20.r),
          );
        },
      ),
    );
  }

  Widget _buildMapControlButton({
    required String icon,
    required VoidCallback onTap,
    required AppColorsExtension colors,
    required bool isDark,
  }) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              width: 22.w,
              height: 22.w,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressDetailsSheet(AppColorsExtension colors) {
    return Container(
      height: 480.h,
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.lg.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KBorderSize.border.r)),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 20, spreadRadius: 5, offset: const Offset(0, -5)),
        ],
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withAlpha(50),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: KSpacing.lg.h),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(KSpacing.sm.r),
                  decoration: BoxDecoration(color: colors.accentOrange.withAlpha(20), shape: BoxShape.circle),
                  child: Icon(Icons.location_on, color: colors.accentOrange, size: 24.r),
                ),
                SizedBox(width: KSpacing.md.w),
                Expanded(
                  child: Text(
                    _currentAddress,
                    style: TextStyle(
                      fontSize: KTextSize.large.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: KSpacing.lg.h),

            // Label Selection
            Text(
              "Save as",
              style: TextStyle(fontSize: KTextSize.medium.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            SizedBox(height: KSpacing.sm.h),
            Wrap(
              spacing: KSpacing.md.w,
              children: AddressLabel.values.map((label) {
                final isSelected = _selectedLabel == label;
                return ChoiceChip(
                  label: Text(label.name.capitalize()),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedLabel = label);
                  },
                  selectedColor: colors.accentViolet.withAlpha(40),
                  labelStyle: TextStyle(
                    color: isSelected ? colors.accentViolet : colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: KTextSize.small.sp,
                  ),
                  backgroundColor: colors.backgroundSecondary,
                  side: BorderSide(color: isSelected ? colors.accentViolet : Colors.transparent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius20.r)),
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                );
              }).toList(),
            ),
            SizedBox(height: KSpacing.lg.h),

            // Building Type Selection
            Text(
              "Building Type",
              style: TextStyle(fontSize: KTextSize.medium.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            SizedBox(height: KSpacing.sm.h),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: BuildingType.values.map((type) {
                  final isSelected = _selectedBuildingType == type;
                  return Padding(
                    padding: EdgeInsets.only(right: KSpacing.sm.w),
                    child: ChoiceChip(
                      label: Text(type.name.capitalize()),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedBuildingType = type);
                      },
                      selectedColor: colors.accentOrange.withAlpha(40),
                      labelStyle: TextStyle(
                        color: isSelected ? colors.accentOrange : colors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: KTextSize.small.sp,
                      ),
                      backgroundColor: colors.backgroundSecondary,
                      side: BorderSide(color: isSelected ? colors.accentOrange : Colors.transparent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius20.r)),
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: KSpacing.lg.h),

            Text(
              "Further Details",
              style: TextStyle(fontSize: KTextSize.medium.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
            ),
            SizedBox(height: KSpacing.md.h),
            Row(
              children: [
                Expanded(
                  child: AppTextInput(
                    controller: _unitController,
                    hintText: "Apt/Suite/Unit",
                    borderRadius: KBorderSize.borderMedium,
                  ),
                ),
                SizedBox(width: KSpacing.md.w),
                Expanded(
                  child: AppTextInput(
                    controller: _floorController,
                    hintText: "Floor (Optional)",
                    borderRadius: KBorderSize.borderMedium,
                  ),
                ),
              ],
            ),
            SizedBox(height: KSpacing.md.h),
            AppTextInput(
              controller: _instructionsController,
              hintText: "Delivery instructions",
              borderRadius: KBorderSize.borderMedium,
            ),
            SizedBox(height: KSpacing.xl.h),
            AppButton(
              onPressed: _confirmAddress,
              buttonText: "Confirm Location",
              backgroundColor: colors.accentViolet,
              width: double.infinity,
              height: KWidgetSize.buttonHeight.h,
              borderRadius: KBorderSize.borderMedium,
              textStyle: TextStyle(color: Colors.white, fontSize: KTextSize.large.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + KSpacing.md.h),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
