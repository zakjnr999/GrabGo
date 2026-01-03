import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:grab_go_customer/shared/viewmodels/location_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class LocationPickerPage extends StatefulWidget {
  final bool isFromRegistration;

  const LocationPickerPage({super.key, this.isFromRegistration = false});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isLoadingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoadingCurrentLocation = true;
    });

    try {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      await locationProvider.fetchAddress();

      if (mounted) {
        if (widget.isFromRegistration) {
          context.go("/accountCreated");
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get current location: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCurrentLocation = false;
        });
      }
    }
  }

  void _onPlaceSelected(Prediction prediction) async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    await locationProvider.updateLocation(
      latitude: 0.0, // TODO: Get from place details
      longitude: 0.0, // TODO: Get from place details
      address: prediction.description ?? '',
    );

    if (mounted) {
      if (widget.isFromRegistration) {
        context.go("/accountCreated");
      } else {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 72,
        leading: SizedBox(
          height: KWidgetSize.buttonHeightSmall.h,
          width: KWidgetSize.buttonHeightSmall.w,
          child: Material(
            color: colors.backgroundPrimary,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () {
                context.pop();
              },
              customBorder: const CircleBorder(),
              splashColor: colors.iconSecondary.withAlpha(50),
              child: Padding(
                padding: EdgeInsets.all(KSpacing.md12.r),
                child: SvgPicture.asset(
                  Assets.icons.navArrowLeft,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
      body: AnnotatedRegion(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar Section
            Container(
              color: colors.backgroundPrimary,
              padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location',
                    style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                  ),
                  SizedBox(height: 14.h),
                  // Google Places Autocomplete Search
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(KBorderSize.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          spreadRadius: 1,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: GooglePlaceAutoCompleteTextField(
                      textEditingController: _searchController,
                      googleAPIKey: AppConfig.googlePlacesApiKey,
                      inputDecoration: InputDecoration(
                        hintText: 'Search for area, street name...',
                        hintStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w400, color: colors.textTertiary),
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(12.r),
                          child: SvgPicture.asset(
                            Assets.icons.search,
                            package: 'grab_go_shared',
                            height: KIconSize.md,
                            width: KIconSize.md,
                            colorFilter: ColorFilter.mode(colors.textTertiary, BlendMode.srcIn),
                          ),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: colors.textSecondary, size: 20.sp),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: colors.backgroundPrimary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KBorderSize.border),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KBorderSize.border),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(KBorderSize.border),
                          borderSide: BorderSide(color: colors.accentOrange, width: 1),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                      ),
                      debounceTime: 400,
                      countries: const ["gh"], // Restrict to Ghana
                      isLatLngRequired: true,
                      getPlaceDetailWithLatLng: (Prediction prediction) {
                        _onPlaceSelected(prediction);
                      },
                      itemClick: (Prediction prediction) {
                        _searchController.text = prediction.description ?? "";
                        _searchController.selection = TextSelection.fromPosition(
                          TextPosition(offset: prediction.description?.length ?? 0),
                        );
                      },
                      seperatedBuilder: Divider(color: colors.inputBorder.withValues(alpha: 0.2), height: 1),
                      containerHorizontalPadding: 0,
                      boxDecoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(KBorderSize.border),
                        border: Border.all(color: Colors.transparent, width: 0),
                      ),
                      itemBuilder: (context, index, Prediction prediction) {
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8.r),
                                decoration: BoxDecoration(
                                  color: colors.accentOrange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: SvgPicture.asset(
                                  Assets.icons.mapPin,
                                  package: 'grab_go_shared',
                                  width: 16.w,
                                  height: 16.h,
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      prediction.structuredFormatting?.mainText ?? prediction.description ?? '',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (prediction.structuredFormatting?.secondaryText != null) ...[
                                      SizedBox(height: 2.h),
                                      Text(
                                        prediction.structuredFormatting!.secondaryText!,
                                        style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
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
                      isCrossBtnShown: false,
                      focusNode: _searchFocusNode,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Text(
                      'Find delivery options near you.',
                      style: TextStyle(fontSize: 12.sp, color: colors.textTertiary, fontWeight: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ),

            // Content Section
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Location Button
                    _buildCurrentLocationButton(colors),

                    SizedBox(height: 24.h),

                    // Recent Addresses Section
                    _buildRecentAddresses(colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationButton(AppColorsExtension colors) {
    return GestureDetector(
      onTap: _isLoadingCurrentLocation ? null : _useCurrentLocation,
      child: Container(
        padding: EdgeInsets.all(18.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(10), spreadRadius: 1, blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.accentOrange.withValues(alpha: 0.3),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isLoadingCurrentLocation
                  ? SizedBox(
                      width: 24.w,
                      height: 24.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.backgroundPrimary),
                      ),
                    )
                  : SvgPicture.asset(
                      Assets.icons.mapPin,
                      package: 'grab_go_shared',
                      width: 24.w,
                      height: 24.h,
                      colorFilter: ColorFilter.mode(colors.backgroundPrimary, BlendMode.srcIn),
                    ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use Current Location',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Get your precise location automatically',
                    style: TextStyle(fontSize: 13.sp, color: colors.textSecondary, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
              child: SvgPicture.asset(
                Assets.icons.navArrowRight,
                package: 'grab_go_shared',
                width: 18.w,
                height: 18.h,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAddresses(AppColorsExtension colors) {
    // TODO: Load from cache/storage
    final recentAddresses = <Map<String, String>>[];

    if (recentAddresses.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Addresses',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
        ),
        SizedBox(height: 12.h),
        ...recentAddresses.map((address) {
          return Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: SvgPicture.asset(
                    Assets.icons.mapPin,
                    package: 'grab_go_shared',
                    width: 16.w,
                    height: 16.h,
                    colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        address['title'] ?? '',
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        address['address'] ?? '',
                        style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
