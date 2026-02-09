import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/features/auth/service/phone_auth_service.dart';
import 'package:grab_go_customer/shared/viewmodels/theme_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/features/order/viewmodel/order_provider.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_discovery_provider.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/features/grabmart/viewmodel/grabmart_provider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';

class Account extends StatefulWidget {
  const Account({super.key});

  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> with SingleTickerProviderStateMixin {
  User? _user;
  bool _isLoading = true;
  bool _isEmailHidden = true;
  late AnimationController _animationController;

  final CreditService _creditService = CreditService();
  CreditBalance? _creditBalance;
  bool _isLoadingCredits = true;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _animationController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _loadUserData();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollOffsetNotifier.value = _scrollController.offset;
  }

  Future<void> _loadUserData() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      _loadCreditBalance();

      var user = await UserService().getCurrentUser();

      if (user == null) {
        final userId = UserService().currentUser?.id ?? PhoneAuthService().userId;
        if (userId != null && userId.isNotEmpty) {
          user = await UserService().getUserById(userId);
          if (user != null) {
            await UserService().setCurrentUser(user);
          }
        }
      }

      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCreditBalance() async {
    try {
      final balance = await _creditService.getBalance();
      if (mounted) {
        setState(() {
          _creditBalance = balance;
          _isLoadingCredits = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCredits = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await AppDialog.show(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout? You will need to sign in again to access your account.',
      type: AppDialogType.logout,
      primaryButtonText: 'Logout',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (shouldLogout == true) {
      await _clearSessionState();
      await UserService().logout();

      if (mounted) {
        context.go('/login');
      }
    }
  }

  bool _ensureEmailVerified() {
    final hasUser = _user != null;
    final isVerified = _user?.isEmailVerified == true;
    if (!hasUser || isVerified) return true;
    context.push("/emailVerification");
    return false;
  }

  String _maskEmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split('@');
    if (parts.length != 2) {
      if (trimmed.length <= 2) return '...';
      return '${trimmed.substring(0, 2)}...';
    }

    final name = parts[0];
    final domain = parts[1];

    final maskedName = name.length <= 2 ? '${name.substring(0, 1)}...' : '${name.substring(0, 2)}...';
    final domainParts = domain.split('.');
    final domainName = domainParts.first;
    final domainExt = domainParts.length > 1 ? domainParts.sublist(1).join('.') : '';
    final maskedDomain = domainName.isEmpty ? '...' : '${domainName.substring(0, domainName.length >= 2 ? 2 : 1)}...';

    return '$maskedName@$maskedDomain${domainExt.isNotEmpty ? '.$domainExt' : ''}';
  }

  Future<void> _clearSessionState() async {
    try {
      context.read<OrderProvider>().clearOrders();
    } catch (_) {}

    try {
      await context.read<CartProvider>().clearCart();
    } catch (_) {}

    try {
      await context.read<FavoritesProvider>().clearFavorites();
    } catch (_) {}

    try {
      context.read<FoodDiscoveryProvider>().clearUserHistory();
    } catch (_) {}

    try {
      context.read<GroceryProvider>().clearAll();
    } catch (_) {}

    try {
      context.read<PharmacyProvider>().clearData();
    } catch (_) {}

    try {
      context.read<GrabMartProvider>().clearData();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = context.appColors;
        final Size size = MediaQuery.sizeOf(context);

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: colors.accentOrange,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: colors.backgroundPrimary,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: colors.backgroundPrimary,
            body: SafeArea(
              top: false,
              child: ClipRect(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(top: size.height * 0.22),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 0.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.w),
                                child: Row(
                                  children: [
                                    ClipOval(
                                      child: GestureDetector(
                                        child: CachedNetworkImage(
                                          height: size.width * 0.15,
                                          width: size.width * 0.15,
                                          fit: BoxFit.cover,
                                          imageUrl: ImageOptimizer.getPreviewUrl(
                                            _user?.profilePicture ?? "",
                                            width: 200,
                                          ),
                                          memCacheWidth: 200,
                                          maxHeightDiskCache: 200,
                                          placeholder: (context, url) => Container(
                                            height: size.width * 0.15,
                                            width: size.width * 0.15,
                                            padding: EdgeInsets.all(12.r),
                                            child: SvgPicture.asset(
                                              Assets.icons.user,
                                              package: "grab_go_shared",
                                              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            height: size.width * 0.15,
                                            width: size.width * 0.15,
                                            padding: EdgeInsets.all(12.r),
                                            child: SvgPicture.asset(
                                              Assets.icons.user,
                                              package: "grab_go_shared",
                                              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16.w),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _isLoading ? "..." : (_user?.username ?? "Guest User"),
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          SizedBox(height: 4.h),
                                          Row(
                                            children: [
                                              Text(
                                                _isLoading
                                                    ? "..."
                                                    : (_user == null
                                                          ? "Please log in to continue"
                                                          : (_user?.email == null || _user!.email!.isEmpty)
                                                          ? "No email added"
                                                          : (_isEmailHidden
                                                                ? _maskEmail(_user!.email!)
                                                                : _user!.email!)),
                                                style: TextStyle(
                                                  color: colors.textPrimary.withValues(alpha: 0.9),
                                                  fontSize: 13.sp,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                              SizedBox(width: 10.w),
                                              if (!_isLoading &&
                                                  _user != null &&
                                                  _user?.email != null &&
                                                  _user!.email!.isNotEmpty) ...[
                                                SizedBox(width: 6.w),
                                                GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _isEmailHidden = !_isEmailHidden;
                                                    });
                                                  },
                                                  child: SvgPicture.asset(
                                                    _isEmailHidden ? Assets.icons.eyeClosed : Assets.icons.eye,
                                                    package: 'grab_go_shared',
                                                    height: 18.h,
                                                    width: 18.w,
                                                    colorFilter: ColorFilter.mode(
                                                      colors.textPrimary.withValues(alpha: 0.9),
                                                      BlendMode.srcIn,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            if (_user != null &&
                                ((_user?.email == null || _user!.email!.isEmpty) || _user?.isEmailVerified == false))
                              GestureDetector(
                                onTap: () => context.push("/emailVerification"),
                                child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: 20.w),
                                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                                  decoration: BoxDecoration(
                                    color: colors.accentOrange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                                  ),
                                  child: Row(
                                    children: [
                                      SvgPicture.asset(
                                        Assets.icons.infoCircle,
                                        package: 'grab_go_shared',
                                        height: 18.h,
                                        width: 18.w,
                                        colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          (_user?.email == null || _user!.email!.isEmpty)
                                              ? "Add your email for receipts and recovery."
                                              : "Verify your email for receipts and account recovery.",
                                          style: TextStyle(
                                            color: colors.accentOrange,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            SizedBox(height: 24.h),
                            _buildCreditBalanceCard(colors),
                            SizedBox(height: 24.h),

                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                              color: colors.backgroundSecondary,
                              child: Text(
                                "General",
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),

                            Column(
                              children: [
                                itemTile("Pickup Location", Assets.icons.sendDiagonal, context, () {
                                  context.push("/mapTracking");
                                }),
                                _favoritesTile(context),

                                itemTile("Refer & Earn", Assets.icons.gift, context, () {
                                  context.push("/referral");
                                }),
                                itemTile("Change Password", Assets.icons.lock, context, () {
                                  if (_ensureEmailVerified()) {
                                    context.push("/orderTracking");
                                  }
                                }),
                              ],
                            ),
                            SizedBox(height: 24.h),

                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                              color: colors.backgroundSecondary,
                              child: Text(
                                "Other Information",
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),

                            Column(
                              children: [
                                itemTile("Settings", Assets.icons.settings, context, () {
                                  context.push("/settings");
                                }),
                                itemTile("Vender Registration", Assets.icons.store, context, () {
                                  if (_ensureEmailVerified()) {
                                    context.push("/restaurantRegistration");
                                  }
                                }),
                                itemTile("Notifications", Assets.icons.bell, context, () {
                                  context.push("/notification");
                                }),
                                itemTile("Help & Support", Assets.icons.headsetHelp, context, () {
                                  //Do nothing for now
                                }),
                                itemTile("About App", Assets.icons.infoCircle, context, () {
                                  //Do nothing for now
                                }),
                                itemTile("Logout", Assets.icons.logOut, context, () {
                                  _handleLogout();
                                }),
                              ],
                            ),
                            SizedBox(height: 24.h),
                          ],
                        ),
                      ),
                    ),

                    Positioned(top: 0, left: 0, right: 0, child: _buildCollapsibleUmbrellaHeader(colors, size)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsibleUmbrellaHeader(AppColorsExtension colors, Size size) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);

        final expandedHeight = size.height * 0.20;

        final currentHeight = expandedHeight - ((expandedHeight - _collapsedHeight) * collapseProgress);

        final contentOpacity = (1.0 - collapseProgress).clamp(0.0, 1.0);

        return SizedBox(
          height: currentHeight,
          child: UmbrellaHeaderWithShadow(
            curveDepth: 25.h,
            numberOfCurves: 10,
            height: currentHeight,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: contentOpacity,
              child: _buildAccountHeader(colors),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountHeader(AppColorsExtension colors) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return SizedBox.expand(
      child: Padding(
        padding: EdgeInsets.only(left: 20.w, right: 20.w, top: statusBarHeight + 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Account",
              style: TextStyle(
                fontFamily: "Lato",
                package: 'grab_go_shared',
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              "Manage your profile, orders, and settings",
              style: TextStyle(
                fontFamily: "Lato",
                package: 'grab_go_shared',
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget itemTile(String title, String icon, BuildContext context, VoidCallback onTap) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: colors.backgroundSecondary,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
          child: Row(
            children: [
              SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                height: 18.h,
                width: 18.w,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              SvgPicture.asset(
                Assets.icons.navArrowRight,
                package: 'grab_go_shared',
                height: 20.h,
                width: 20.w,
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditBalanceCard(AppColorsExtension colors) {
    return GestureDetector(
      onTap: () {
        if (_ensureEmailVerified()) {
          context.push("/credits");
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: colors.accentOrange,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
              ),
              child: SvgPicture.asset(
                Assets.icons.wallet,
                package: 'grab_go_shared',
                height: 28.h,
                width: 28.w,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "GrabGo Credits",
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),

                  Text(
                    _isLoading ? "..." : _creditBalance?.formatted ?? "₵0.00",
                    style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "View",
                        style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 12.sp),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  "Tap to see history",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10.sp),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _favoritesTile(BuildContext context) {
    final colors = context.appColors;

    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push("/favorites");
            },
            splashColor: colors.backgroundSecondary,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SvgPicture.asset(
                        Assets.icons.heart,
                        package: 'grab_go_shared',
                        height: 18.h,
                        width: 18.w,
                        colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Text(
                          "Favorites",
                          style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      SvgPicture.asset(
                        Assets.icons.navArrowRight,
                        package: 'grab_go_shared',
                        height: 20.h,
                        width: 20.w,
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                    ],
                  ),
                  if (favoritesProvider.hasFavorites) ...[
                    SizedBox(height: 14.h),
                    SizedBox(
                      height: 60.h,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: favoritesProvider.favoriteItems.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final item = favoritesProvider.favoriteItems.toList()[index];
                          return Container(
                            margin: EdgeInsets.only(right: 8.w),
                            width: 60.w,
                            height: 60.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius12),
                              color: colors.inputBorder.withValues(alpha: 0.5),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(KBorderSize.borderRadius12)),
                              child: CachedNetworkImage(
                                imageUrl: ImageOptimizer.getPreviewUrl(item.image, width: 100),
                                fit: BoxFit.cover,
                                memCacheWidth: 100,
                                maxHeightDiskCache: 100,
                                placeholder: (context, url) {
                                  return Container(
                                    color: colors.backgroundSecondary,
                                    child: Center(
                                      child: SvgPicture.asset(
                                        Assets.icons.utensilsCrossed,
                                        package: 'grab_go_shared',
                                        height: 24.h,
                                        width: 24.w,
                                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                      ),
                                    ),
                                  );
                                },
                                errorWidget: (context, url, error) {
                                  return Container(
                                    color: colors.backgroundSecondary,
                                    child: Center(
                                      child: SvgPicture.asset(
                                        Assets.icons.utensilsCrossed,
                                        package: 'grab_go_shared',
                                        height: 24.h,
                                        width: 24.w,
                                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
