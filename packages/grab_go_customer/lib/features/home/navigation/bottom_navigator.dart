import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/Pickup/view/pickup_map.dart';
import 'package:grab_go_customer/features/browse/view/browse_page.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/view/home_page.dart';
import 'package:grab_go_customer/features/profile/view/account.dart';
import 'package:grab_go_customer/features/order/view/orders.dart';
import 'package:grab_go_customer/shared/services/connectivity_service.dart';
import 'package:grab_go_customer/shared/widgets/no_internet_screen.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class BottomNavigator extends StatefulWidget {
  const BottomNavigator({super.key});

  @override
  State<BottomNavigator> createState() => _BottomNavigatorState();
}

class _BottomNavigatorState extends State<BottomNavigator> {
  bool _hasNoInternet = false;
  int? _lastCheckedIndex;

  void _onItemSelected(int index) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final targetMode = index == 1 ? 'pickup' : 'delivery';
    cartProvider.setFulfillmentMode(targetMode);
    Provider.of<NavigationProvider>(context, listen: false).setIndex(index);
  }

  final List<Widget> _screens = [
    const HomePage(),
    const PickupMap(),
    const BrowsePage(),
    const Orders(),
    const Account(),
  ];

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final hasInternet = await ConnectivityService.hasInternetConnection();
    if (!mounted) return;
    setState(() {
      _hasNoInternet = !hasInternet;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final selectedIndex = navigationProvider.selectedIndex;
    final bool shouldShowNoInternet = _hasNoInternet && selectedIndex != 4;
    Size size = MediaQuery.sizeOf(context);

    debugPrint('📍 BottomNavigator: build - index: $selectedIndex, noInternet: $_hasNoInternet');

    if (_lastCheckedIndex != selectedIndex) {
      _lastCheckedIndex = selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkConnectivity();
      });
    }

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Theme.of(context).scaffoldBackgroundColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: Stack(
          children: [
            IndexedStack(index: selectedIndex, children: _screens),
            if (shouldShowNoInternet) Positioned.fill(child: NoInternetScreen(onRetry: _checkConnectivity)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.backgroundTertiary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.border),
            topRight: Radius.circular(KBorderSize.border),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(25), spreadRadius: 1, blurRadius: 20, offset: const Offset(0, -3)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCartBar(colors),
            SizedBox(
              height: size.height * 0.16,
              child: BottomAppBar(
                color: Colors.transparent,
                elevation: 0,
                child: Row(
                  children: [
                    Expanded(child: _buildNavItem(Assets.icons.home, "Home", 0, context)),
                    Expanded(child: _buildNavItem(Assets.icons.running, "Pickup", 1, context)),
                    Expanded(child: _buildNavItem(Assets.icons.search, "Browse", 2, context)),
                    Expanded(child: _buildNavItem(Assets.icons.squareMenu, "Orders", 3, context)),
                    Expanded(child: _buildNavItem(Assets.icons.user, "Account", 4, context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBar(AppColorsExtension colors) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        if (cartProvider.cartItems.isEmpty) return const SizedBox.shrink();

        final itemCount = cartProvider.totalQuantity;
        final totalAmount = cartProvider.total;

        return GestureDetector(
          onTap: () => context.push("/cart"),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(color: colors.accentOrange),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: SvgPicture.asset(
                    Assets.icons.cart,
                    height: 18.h,
                    width: 18.w,
                    package: 'grab_go_shared',
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "View cart",
                        style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        "$itemCount ${itemCount == 1 ? "item" : "items"} in cart",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${AppStrings.currencySymbol} ${totalAmount.toStringAsFixed(2)}",
                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(String icon, String label, int index, BuildContext context) {
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final bool selected = navigationProvider.selectedIndex == index;
    final colors = context.appColors;
    final int unread = navigationProvider.chatUnreadCount;

    Widget iconWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      padding: EdgeInsets.all(selected ? 6.0 : 0),
      decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? colors.accentOrange : Colors.transparent),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        scale: selected ? 1.0 : 0.95,
        child: SvgPicture.asset(
          icon,
          package: 'grab_go_shared',
          height: KIconSize.lg,
          width: KIconSize.lg,
          colorFilter: ColorFilter.mode(selected ? colors.backgroundPrimary : colors.textPrimary, BlendMode.srcIn),
        ),
      ),
    );

    if (index == 2 && unread > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.accentOrange,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.backgroundPrimary, width: 2),
              ),
              child: Text(
                unread > 9 ? '9+' : unread.toString(),
                style: TextStyle(
                  fontFamily: 'Lato',
                  package: 'grab_go_shared',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.backgroundPrimary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _onItemSelected(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            style: TextStyle(
              fontFamily: "Lato",
              package: 'grab_go_shared',
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: colors.textPrimary,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
