import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:geolocator/geolocator.dart';
import 'package:grab_go_customer/shared/models/address_model.dart';
import 'package:grab_go_customer/shared/services/location_service.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class ConfirmAddressPage extends StatefulWidget {
  final bool returnToPrevious;
  final bool selectionOnly;
  const ConfirmAddressPage({
    super.key,
    this.returnToPrevious = false,
    this.selectionOnly = false,
  });

  @override
  State<ConfirmAddressPage> createState() => _ConfirmAddressPageState();
}

class _ConfirmAddressPageState extends State<ConfirmAddressPage> {
  GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _customLabelController = TextEditingController();
  final FocusNode _customLabelFocusNode = FocusNode();
  final FocusNode _customInstructionFocusNode = FocusNode();
  String? _selectedDeliveryInstruction;
  bool _showCustomDeliveryInstruction = false;

  LatLng _currentMapPosition = const LatLng(5.6037, -0.1870);
  String _currentAddress = "Loading address...";
  bool _isReverseGeocoding = false;
  bool _isSyncing = false;
  AddressLabel _selectedLabel = AddressLabel.home;
  BuildingType _selectedBuildingType = BuildingType.apartment;

  Timer? _debounceTimer;
  bool _isMoving = false;
  int _geocodingRequestId = 0;
  bool _hasMovedMap = false;
  bool _pendingReveal = false;
  LatLng? _lastGeocodedPosition;
  final Map<String, String> _addressCache = {};

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _searchController.addListener(_onSearchTextChanged);
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _collapseSheet();
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _sheetController.dispose();
    _searchController.removeListener(_onSearchTextChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    _unitController.dispose();
    _floorController.dispose();
    _instructionsController.dispose();
    _customLabelController.dispose();
    _customLabelFocusNode.dispose();
    _customInstructionFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    final locationProvider = Provider.of<NativeLocationProvider>(
      context,
      listen: false,
    );
    if (locationProvider.hasLocation) {
      setState(() {
        _currentMapPosition = LatLng(
          locationProvider.latitude!,
          locationProvider.longitude!,
        );
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
        _revealSheet();
      } else {
        if (mounted) {
          setState(() => _isReverseGeocoding = false);
          if (isManual) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unable to get your current location. Please check your permissions.',
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReverseGeocoding = false);
        if (isManual) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _currentMapPosition = position.target;
      _isMoving = true;
      _hasMovedMap = true;
    });
  }

  void _onCameraIdle() {
    if (mounted) {
      setState(() => _isMoving = false);
    }
    _reverseGeocodeIfNeeded(_currentMapPosition);
    if (_hasMovedMap) {
      _revealSheet();
    }
  }

  Future<void> _reverseGeocodeIfNeeded(LatLng position) async {
    if (_lastGeocodedPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastGeocodedPosition!.latitude,
        _lastGeocodedPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance < 20) {
        return;
      }
    }
    await _reverseGeocode(position);
  }

  String _cacheKey(LatLng position) {
    return "${position.latitude.toStringAsFixed(5)}_${position.longitude.toStringAsFixed(5)}";
  }

  Future<void> _reverseGeocode(LatLng position) async {
    final requestId = ++_geocodingRequestId;
    setState(() => _isReverseGeocoding = true);

    try {
      final cacheKey = _cacheKey(position);
      final cached = _addressCache[cacheKey];
      final address =
          cached ??
          await LocationService.getAddressFromCoordinates(
            position.latitude,
            position.longitude,
          );

      if (mounted && requestId == _geocodingRequestId) {
        _addressCache[cacheKey] = address;
        _lastGeocodedPosition = position;
        final changed = _currentAddress != address;
        setState(() {
          _currentAddress = address;
          _isReverseGeocoding = false;
        });
        if (changed) {
          HapticFeedback.selectionClick();
        }
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
    _reverseGeocodeIfNeeded(latLng);
  }

  void _revealSheet() {
    if (_sheetController.isAttached) {
      if (_sheetController.size < 0.24) {
        _sheetController.animateTo(
          0.48,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    } else if (!_pendingReveal) {
      _pendingReveal = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingReveal = false;
        if (mounted) {
          _revealSheet();
        }
      });
    }
  }

  void _onSearchTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _collapseSheet() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.18,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _showBuildingTypePicker(
    AppColorsExtension colors,
    bool isDark,
  ) async {
    final selected = await showModalBottomSheet<BuildingType>(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KBorderSize.border.r),
        ),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    "Select Building Type",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: KSpacing.md.h),
                ...BuildingType.values.map((type) {
                  final isSelected = _selectedBuildingType == type;
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
                    title: Text(
                      type.name.capitalize(),
                      style: TextStyle(
                        fontSize: isSelected ? 16.sp : 14.sp,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),

                    onTap: () => Navigator.of(context).pop(type),
                  );
                }),
                SizedBox(height: KSpacing.md.h),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() => _selectedBuildingType = selected);
    }
  }

  Future<void> _showDeliveryInstructionsPicker(
    AppColorsExtension colors,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KBorderSize.border.r),
        ),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    "Delivery Instructions",
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(height: KSpacing.md.h),
                ...[
                  "Leave at door",
                  "Ring doorbell",
                  "Text on arrival",
                  "Call on arrival",
                ].map((label) {
                  final isSelected = _selectedDeliveryInstruction == label;
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),

                    onTap: () {
                      setState(() {
                        _selectedDeliveryInstruction = label;
                        _showCustomDeliveryInstruction = false;
                      });
                      Navigator.of(context).pop();
                    },
                  );
                }),
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
                  title: Text(
                    "Custom",
                    style: TextStyle(
                      fontSize: _showCustomDeliveryInstruction ? 16.sp : 14.sp,
                      fontWeight: _showCustomDeliveryInstruction
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),

                  onTap: () {
                    setState(() {
                      _showCustomDeliveryInstruction = true;
                      _selectedDeliveryInstruction = null;
                    });
                    Navigator.of(context).pop();
                  },
                ),
                SizedBox(height: KSpacing.md.h),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onPlaceSelected(Prediction prediction) {
    final lat = prediction.lat != null
        ? double.tryParse(prediction.lat!)
        : null;
    final lng = prediction.lng != null
        ? double.tryParse(prediction.lng!)
        : null;

    if (lat != null && lng != null) {
      _geocodingRequestId++;
      _debounceTimer?.cancel();

      final latLng = LatLng(lat, lng);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
      setState(() {
        _currentMapPosition = latLng;
        _currentAddress = prediction.description ?? "";
        _isReverseGeocoding = false;
      });
    }
  }

  Future<void> _confirmAddress() async {
    if (_selectedLabel == AddressLabel.other &&
        _customLabelController.text.trim().isEmpty) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: "Please enter a custom label",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    final addressModel = AddressModel(
      latitude: _currentMapPosition.latitude,
      longitude: _currentMapPosition.longitude,
      formattedAddress: _currentAddress,
      label: _selectedLabel,
      customLabel: _selectedLabel == AddressLabel.other
          ? _customLabelController.text.trim()
          : null,
      buildingType: _selectedBuildingType,
      unitNumber: _unitController.text,
      floor: _floorController.text,
      instructions: _buildDeliveryInstructions(),
      isComplete: true,
      isDefault: true,
    );

    if (widget.selectionOnly) {
      if (mounted) {
        context.pop(addressModel);
      }
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final locationProvider = Provider.of<NativeLocationProvider>(
        context,
        listen: false,
      );
      debugPrint(
        '📍 ConfirmAddressPage: Confirming address: ${addressModel.formattedAddress}',
      );
      await locationProvider.setConfirmedAddress(addressModel);

      if (mounted) {
        if (widget.returnToPrevious) {
          context.pop(true);
        } else {
          context.go("/homepage");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        AppToastMessage.show(
          context: context,
          message: "Failed to save address. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    }
  }

  String _buildDeliveryInstructions() {
    if (_selectedDeliveryInstruction != null &&
        _selectedDeliveryInstruction!.isNotEmpty) {
      return _selectedDeliveryInstruction!;
    }
    if (_showCustomDeliveryInstruction &&
        _instructionsController.text.trim().isNotEmpty) {
      return _instructionsController.text.trim();
    }
    return "";
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
            Positioned.fill(
              child: _ConfirmAddressMap(
                initialPosition: _currentMapPosition,
                mapStyle: GrabGoMapStyles.forBrightness(
                  Theme.of(context).brightness,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onCameraMove: _onCameraMove,
                onCameraIdle: _onCameraIdle,
              ),
            ),

            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_hasMovedMap)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(
                            KBorderSize.borderRadius20.r,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(10),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Text(
                          "Drag map to refine location",
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    if (!_hasMovedMap) SizedBox(height: 8.h),
                    if (_isReverseGeocoding && !_isMoving)
                      Container(
                        padding: EdgeInsets.all(4.r),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(
                            KBorderSize.borderRadius20.r,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(10),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: 16.w,
                          height: 16.h,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              colors.accentOrange,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: 8.h),
                    SvgPicture.asset(
                      Assets.icons.mapPinSimpleFill,
                      package: 'grab_go_shared',
                      height: 48.h,
                      colorFilter: ColorFilter.mode(
                        colors.accentOrange,
                        BlendMode.srcIn,
                      ),
                    ),
                  ],
                ),
              ),
            ),

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

            Positioned.fill(child: _buildAddressDetailsSheet(colors, isDark)),
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
            color: Colors.black.withAlpha(10),
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
          child: Padding(
            padding: EdgeInsets.all(KSpacing.md12.r),
            child: SvgPicture.asset(
              Assets.icons.navArrowLeft,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(
                colors.iconPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
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
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: GooglePlaceAutoCompleteTextField(
        textEditingController: _searchController,
        googleAPIKey: AppConfig.googlePlacesApiKey,
        focusNode: _searchFocusNode,
        isCrossBtnShown: false,
        inputDecoration: InputDecoration(
          hintText: "Search location...",
          hintStyle: TextStyle(
            color: colors.textSecondary,
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(right: 12.w),
            child: SvgPicture.asset(
              Assets.icons.search,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(
                colors.textPrimary,
                BlendMode.srcIn,
              ),
            ),
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? Builder(
                  builder: (iconContext) {
                    return IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _searchFocusNode.unfocus();
                        try {
                          final state = iconContext
                              .findAncestorStateOfType<State>();
                          (state as dynamic).clearData();
                        } catch (_) {}
                        setState(() {});
                      },
                      icon: Padding(
                        padding: EdgeInsets.only(left: 12.w),
                        child: SvgPicture.asset(
                          Assets.icons.xmark,
                          package: 'grab_go_shared',
                          width: 20.w,
                          height: 20.w,
                          colorFilter: ColorFilter.mode(
                            colors.textSecondary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    );
                  },
                )
              : null,
          suffixIconConstraints: BoxConstraints(
            minWidth: 20.w,
            minHeight: 20.w,
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: 20.w,
            minHeight: 20.w,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 11.h),
        ),
        debounceTime: 400,
        countries: const ["gh"],
        isLatLngRequired: true,
        getPlaceDetailWithLatLng: (Prediction prediction) =>
            _onPlaceSelected(prediction),
        itemClick: (Prediction prediction) {
          _searchController.text = prediction.description ?? "";
        },
        itemBuilder: (context, index, Prediction prediction) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),

            child: Row(
              children: [
                SvgPicture.asset(
                  Assets.icons.mapPin,
                  package: 'grab_go_shared',
                  width: 16.w,
                  height: 16.h,
                  colorFilter: ColorFilter.mode(
                    colors.accentOrange,
                    BlendMode.srcIn,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prediction.structuredFormatting?.mainText ??
                            prediction.description ??
                            '',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (prediction.structuredFormatting?.secondaryText !=
                          null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          prediction.structuredFormatting!.secondaryText!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        boxDecoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: Colors.transparent, width: 0),
          borderRadius: BorderRadius.circular(KBorderSize.border.r),
        ),
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
            color: Colors.black.withAlpha(10),
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
              colorFilter: ColorFilter.mode(
                colors.textPrimary,
                BlendMode.srcIn,
              ),
              width: 22.w,
              height: 22.w,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddressDetailsSheet(AppColorsExtension colors, bool isDark) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.22,
      minChildSize: 0.18,
      maxChildSize: 0.78,
      expand: true,
      snap: true,
      snapSizes: const [0.18, 0.48, 0.78],
      builder: (context, scrollController) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(KBorderSize.border.r),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 10,
                spreadRadius: 5,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
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
                      SizedBox(height: 20.h),
                      Text(
                        _currentAddress,
                        style: TextStyle(
                          fontSize: KTextSize.large.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 30.h),

                      Text(
                        "Address Label",
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: KSpacing.sm.h),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: AddressLabel.values.map((label) {
                          final isSelected = _selectedLabel == label;
                          final String icon = switch (label) {
                            AddressLabel.home => Assets.icons.home,
                            AddressLabel.work => Assets.icons.briefcaseBusiness,
                            AddressLabel.other => Assets.icons.mapPin,
                          };
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedLabel = label;
                              });
                              if (label == AddressLabel.other) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    _customLabelFocusNode.requestFocus();
                                  }
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.accentOrange
                                    : colors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(20.r),
                              ),

                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 8.h,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    icon,
                                    package: 'grab_go_shared',
                                    width: 16.r,
                                    height: 16.r,
                                    colorFilter: isSelected
                                        ? const ColorFilter.mode(
                                            Colors.white,
                                            BlendMode.srcIn,
                                          )
                                        : ColorFilter.mode(
                                            colors.textSecondary,
                                            BlendMode.srcIn,
                                          ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    label.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : colors.textSecondary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _selectedLabel == AddressLabel.other
                            ? Padding(
                                key: const ValueKey("custom_label_input"),
                                padding: EdgeInsets.only(top: KSpacing.md.h),
                                child: AppTextInput(
                                  controller: _customLabelController,
                                  focusNode: _customLabelFocusNode,
                                  hintText:
                                      "Custom label (e.g., Parents' House)",
                                  fillColor: colors.backgroundSecondary,
                                  borderRadius: KBorderSize.borderMedium,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      SizedBox(height: 20.h),

                      Text(
                        "Building Type",
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: KSpacing.sm.h),
                      GestureDetector(
                        onTap: () => _showBuildingTypePicker(colors, isDark),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(
                              KBorderSize.borderMedium,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedBuildingType.name.capitalize(),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ),
                              SvgPicture.asset(
                                Assets.icons.navArrowDown,
                                package: 'grab_go_shared',
                                width: 18.w,
                                height: 18.h,
                                colorFilter: ColorFilter.mode(
                                  colors.textSecondary,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: KSpacing.lg.h),

                      Text(
                        "Further Details",
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: KSpacing.md.h),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextInput(
                              controller: _unitController,
                              hintText: "Apt/Suite/Unit",
                              fillColor: colors.backgroundSecondary,
                              borderRadius: KBorderSize.borderMedium,
                            ),
                          ),
                          SizedBox(width: KSpacing.md.w),
                          Expanded(
                            child: AppTextInput(
                              controller: _floorController,
                              hintText: "Floor (Optional)",
                              fillColor: colors.backgroundSecondary,
                              borderRadius: KBorderSize.borderMedium,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: KSpacing.lg.h),

                      Text(
                        "Delivery Instructions",
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: KSpacing.md.h),
                      GestureDetector(
                        onTap: () => _showDeliveryInstructionsPicker(colors),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 12.h,
                          ),
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(
                              KBorderSize.borderMedium,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _buildDeliveryInstructions().isEmpty
                                      ? "Add delivery instructions"
                                      : _buildDeliveryInstructions(),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500,
                                    color: _buildDeliveryInstructions().isEmpty
                                        ? colors.textSecondary
                                        : colors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SvgPicture.asset(
                                Assets.icons.navArrowDown,
                                package: 'grab_go_shared',
                                width: 18.w,
                                height: 18.h,
                                colorFilter: ColorFilter.mode(
                                  colors.textSecondary,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: _showCustomDeliveryInstruction
                            ? Padding(
                                key: const ValueKey(
                                  "custom_delivery_instruction_inline",
                                ),
                                padding: EdgeInsets.only(top: KSpacing.md.h),
                                child: AppTextInput(
                                  controller: _instructionsController,
                                  focusNode: _customInstructionFocusNode,
                                  hintText:
                                      "Enter custom delivery instructions",
                                  fillColor: colors.backgroundSecondary,
                                  borderRadius: KBorderSize.borderMedium,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      SizedBox(height: KSpacing.lg.h),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.only(top: 12.h),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colors.backgroundSecondary,
                      width: 1,
                    ),
                  ),
                ),
                child: AppButton(
                  onPressed: _confirmAddress,
                  buttonText: "Confirm Location",
                  isLoading: _isSyncing,
                  backgroundColor: colors.accentOrange,
                  width: double.infinity,
                  height: KWidgetSize.buttonHeight.h,
                  borderRadius: KBorderSize.borderMedium,
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + KSpacing.md.h,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConfirmAddressMap extends StatefulWidget {
  final LatLng initialPosition;
  final String? mapStyle;
  final ValueChanged<GoogleMapController> onMapCreated;
  final ValueChanged<CameraPosition> onCameraMove;
  final VoidCallback onCameraIdle;

  const _ConfirmAddressMap({
    required this.initialPosition,
    required this.mapStyle,
    required this.onMapCreated,
    required this.onCameraMove,
    required this.onCameraIdle,
  });

  @override
  State<_ConfirmAddressMap> createState() => _ConfirmAddressMapState();
}

class _ConfirmAddressMapState extends State<_ConfirmAddressMap> {
  Timer? _moveDebounce;
  CameraPosition? _lastCameraPosition;

  @override
  void dispose() {
    _moveDebounce?.cancel();
    super.dispose();
  }

  void _onCameraMoveDebounced(CameraPosition position) {
    _lastCameraPosition = position;
    _moveDebounce?.cancel();
    _moveDebounce = Timer(const Duration(milliseconds: 120), () {
      final last = _lastCameraPosition;
      if (last != null) {
        widget.onCameraMove(last);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialPosition,
          zoom: 16,
        ),
        onMapCreated: widget.onMapCreated,
        style: widget.mapStyle,
        onCameraMove: _onCameraMoveDebounced,
        onCameraIdle: widget.onCameraIdle,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        compassEnabled: false,
        mapToolbarEnabled: false,
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
