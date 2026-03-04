import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:chopper/chopper.dart';
import 'package:grab_go_shared/core/auth/user_model.dart';
import 'package:grab_go_shared/core/auth/rider_model.dart';
import 'package:grab_go_rider/core/api/api_client.dart' show riderService;

class HomeSliverAppbar extends StatefulWidget {
  const HomeSliverAppbar({super.key});

  @override
  State<HomeSliverAppbar> createState() => _HomeSliverAppbarState();
}

class _HomeSliverAppbarState extends State<HomeSliverAppbar> {
  User? _user;
  Rider? _rider;
  double _balance = 0.0;
  bool _isLoading = true;
  bool _isWalletLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadCachedVehicleType();
    _loadRiderData();
    _loadWalletData();
  }

  Future<void> _loadUserData() async {
    final userData = CacheService.getUserData();
    if (userData != null) {
      setState(() {
        _user = User.fromJson(userData);
      });
    }
  }

  Future<void> _loadCachedVehicleType() async {
    final cachedVehicleType = CacheService.getVehicleType();
    if (cachedVehicleType != null && mounted) {
      setState(() {
        _rider = Rider(vehicleType: cachedVehicleType);
      });
    }
  }

  Future<void> _loadRiderData() async {
    try {
      final token = await CacheService.getAuthToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('❌ No auth token found, cannot fetch rider data');
        }
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final uri = Uri.parse(
        '${riderService.client.baseUrl}/riders/verification',
      );
      final request = Request(
        'GET',
        uri,
        riderService.client.baseUrl,
        headers: {'Authorization': 'Bearer $token'},
      );
      final response = await riderService.client
          .send<RiderResponse, RiderResponse>(request);

      if (response.isSuccessful && response.body != null) {
        if (response.body!.data != null) {
          if (mounted) {
            setState(() {
              _rider = response.body!.data;
              _isLoading = false;
            });
            if (_rider?.vehicleType != null) {
              await CacheService.saveVehicleType(_rider!.vehicleType!);
            }
          }
        }
      } else if (response.statusCode == 404) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadWalletData() async {
    try {
      final token = await CacheService.getAuthToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _isWalletLoading = false;
          });
        }
        return;
      }

      final uri = Uri.parse('${riderService.client.baseUrl}/riders/wallet');
      final request = Request(
        'GET',
        uri,
        riderService.client.baseUrl,
        headers: {'Authorization': 'Bearer $token'},
      );
      final response = await riderService.client
          .send<Map<String, dynamic>, Map<String, dynamic>>(request);

      if (response.isSuccessful && response.body != null) {
        final data = response.body!['data'] as Map<String, dynamic>?;
        if (data != null && mounted) {
          setState(() {
            _balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
            _isWalletLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isWalletLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWalletLoading = false;
        });
      }
    }
  }

  String _getGreetingText() {
    final username = _user?.username ?? '';
    if (username.isEmpty) {
      final vehicleType = _rider?.vehicleType ?? CacheService.getVehicleType();
      return vehicleType?.toLowerCase() == "car" ? "Driver!" : "Rider!";
    }

    final firstName = username.split(' ').first.trim();

    final vehicleType = _rider?.vehicleType ?? CacheService.getVehicleType();
    return vehicleType?.toLowerCase() == "car"
        ? "Driver $firstName"
        : "Rider $firstName";
  }

  Widget _getVehicleImage({
    required String? vehicleType,
    required double expandRatio,
    required double reverseRatio,
    required Size size,
  }) {
    final height =
        size.height * 0.48 * expandRatio + size.height * 0.35 * reverseRatio;
    final width =
        size.width * 0.48 * expandRatio + size.width * 0.35 * reverseRatio;

    final cachedVehicleType = CacheService.getVehicleType();
    final effectiveVehicleType = vehicleType ?? cachedVehicleType;
    final normalizedType = effectiveVehicleType?.toLowerCase().trim();

    if (normalizedType == null && _isLoading) {
      return SizedBox(height: height, width: width);
    }

    if (normalizedType == 'scooter') {
      return Assets.images.deliveryGuyScooter.image(
        package: "grab_go_shared",
        height: height,
        width: width,
        fit: BoxFit.contain,
      );
    } else if (normalizedType == 'car') {
      return Assets.images.deliveryGuyCar.image(
        package: "grab_go_shared",
        height: height,
        width: width,
        fit: BoxFit.contain,
      );
    } else if (normalizedType == 'bicycle') {
      return Assets.images.deliveryGuyBicycle.image(
        package: "grab_go_shared",
        height: height,
        width: width,
        fit: BoxFit.contain,
      );
    } else if (normalizedType == 'motorcycle') {
      return Assets.images.deliveryGuyMotorcycle.image(
        package: "grab_go_shared",
        height: height,
        width: width,
        fit: BoxFit.contain,
      );
    } else {
      return Assets.images.deliveryGuyMotorcycle.image(
        package: "grab_go_shared",
        height: height,
        width: width,
        fit: BoxFit.contain,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);

    return SliverAppBar(
      expandedHeight: size.height * 0.40,
      backgroundColor: colors.accentGreen,
      surfaceTintColor: colors.accentGreen.withValues(alpha: 0.2),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
      elevation: 0,
      pinned: true,
      stretch: false,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final double expandRatio =
              ((constraints.maxHeight - kToolbarHeight) /
                      (size.height * 0.40 - kToolbarHeight))
                  .clamp(0.0, 1.0);
          final double reverseRatio = 1.0 - expandRatio;

          return FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.accentGreen,
                        colors.accentGreen.withValues(alpha: 0.85),
                        colors.accentGreen.withValues(alpha: 0.75),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),

                Positioned(
                  top: -50 * reverseRatio,
                  right: -30 * reverseRatio,
                  child: Container(
                    width: 200.w * (1 - reverseRatio * 0.5),
                    height: 200.w * (1 - reverseRatio * 0.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08 * expandRatio),
                    ),
                  ),
                ),
                Positioned(
                  top: 80.h * expandRatio,
                  right: -60.w * reverseRatio,
                  child: Container(
                    width: 150.w * (1 - reverseRatio * 0.6),
                    height: 150.w * (1 - reverseRatio * 0.6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06 * expandRatio),
                    ),
                  ),
                ),

                SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 20.w,
                            right: 16.w,
                            top: 40.h,
                            bottom: 20.h,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedOpacity(
                                opacity: expandRatio,
                                duration: const Duration(milliseconds: 200),
                                child: GestureDetector(
                                  onTap: () => context.push("/verifyEmail"),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        KBorderSize.borderRadius50,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6.w,
                                          height: 6.w,
                                          decoration: BoxDecoration(
                                            color: colors.accentGreen,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          "Level 4",
                                          style: TextStyle(
                                            color: colors.accentGreen,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h * expandRatio + 4.h),

                              AnimatedOpacity(
                                opacity: expandRatio,
                                duration: const Duration(milliseconds: 200),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Welcome back,",
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      _getGreetingText(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize:
                                            28.sp * expandRatio +
                                            18.sp * reverseRatio,
                                        height: 1.2,
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 26.h * expandRatio + 12.h),

                              AnimatedOpacity(
                                opacity: expandRatio,
                                duration: const Duration(milliseconds: 200),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "YOUR EARNINGS",
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "GHC",
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.9,
                                            ),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 18.sp,
                                            height: 1,
                                          ),
                                        ),
                                        SizedBox(width: 4.w),
                                        Flexible(
                                          child: Text(
                                            _isWalletLoading
                                                ? "..."
                                                : _balance.toStringAsFixed(2),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize:
                                                  32.sp * expandRatio +
                                                  24.sp * reverseRatio,
                                              height: 1,
                                              letterSpacing: -1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      Expanded(
                        flex: 2,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width:
                                    size.width * 0.42 * expandRatio +
                                    size.width * 0.30 * reverseRatio,
                                height:
                                    size.width * 0.42 * expandRatio +
                                    size.width * 0.30 * reverseRatio,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withValues(
                                        alpha: 0.15 * expandRatio,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            Positioned(
                              bottom: -10.h * reverseRatio,
                              right: -10.w * reverseRatio,
                              child: Transform.scale(
                                scale: expandRatio * 0.2 + 0.8,
                                child: _getVehicleImage(
                                  vehicleType: _rider?.vehicleType,
                                  expandRatio: expandRatio,
                                  reverseRatio: reverseRatio,
                                  size: size,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),

      bottom: PreferredSize(
        preferredSize: Size.fromHeight(20.h),
        child: Container(
          height: 20.h,
          decoration: BoxDecoration(
            color: colors.backgroundSecondary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(KBorderSize.borderRadius20),
              topRight: Radius.circular(KBorderSize.borderRadius20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
        ),
      ),

      leadingWidth: 56.w,
      leading: Center(
        child: Padding(
          padding: EdgeInsets.only(left: 14.w),
          child: IconButton(
            icon: SvgPicture.asset(
              Assets.icons.menu,
              package: 'grab_go_shared',
              width: 24.w,
              height: 24.w,
              colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      actions: [
        Center(
          child: Padding(
            padding: EdgeInsets.only(right: 14.w),
            child: Badge(
              offset: Offset(-6.w, 6.h),
              label: const Text(
                '99+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              backgroundColor: colors.error,
              child: IconButton(
                icon: SvgPicture.asset(
                  Assets.icons.bell,
                  package: 'grab_go_shared',
                  width: 24.w,
                  height: 24.w,
                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                onPressed: () => context.push(
                  "/delivery-tracking",
                  extra: {
                    'testTrigger': true,
                    'orderId': 'DEMO-RIDER-TRACK-001',
                    'customerName': 'Demo Customer',
                    'customerAddress': '7 Ayawaso, Accra',
                    'customerPhone': '+233 000 000 000',
                    'restaurantName': 'Demo Restaurant',
                    'restaurantAddress': 'Kanda, Accra',
                    'orderTotal': 'GHS 51.40',
                    'orderItems': const ['1x Jollof Rice with Chicken'],
                    'customerId': 'demo-customer',
                    'riderId': 'demo-rider',
                    'pickupLatitude': 5.60372,
                    'pickupLongitude': -0.18700,
                    'destinationLatitude': 5.57458,
                    'destinationLongitude': -0.21516,
                    'phase': 'pickup',
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
