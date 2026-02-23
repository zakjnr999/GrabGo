import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/home/view/catalog_tab.dart';
import 'package:grab_go_vendor/features/home/view/home_tab.dart';
import 'package:grab_go_vendor/features/home/view/more_tab.dart';
import 'package:grab_go_vendor/features/home/view/orders_tab.dart';
import 'package:grab_go_vendor/features/store_operations/viewmodel/store_operations_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/bottom_nav_provider.dart';
import 'package:provider/provider.dart';

class VendorBottomNavigator extends StatelessWidget {
  const VendorBottomNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VendorBottomNavProvider()),
        ChangeNotifierProvider(create: (_) => VendorStoreOperationsViewModel()),
      ],
      child: const _VendorBottomNavigatorView(),
    );
  }
}

class _VendorBottomNavigatorView extends StatefulWidget {
  const _VendorBottomNavigatorView();

  @override
  State<_VendorBottomNavigatorView> createState() =>
      _VendorBottomNavigatorViewState();
}

class _VendorBottomNavigatorViewState extends State<_VendorBottomNavigatorView>
    with SingleTickerProviderStateMixin {
  static final List<Widget> _screens = <Widget>[
    const HomeTab(),
    const OrdersTab(),
    const CatalogTab(),
    const MoreTab(),
  ];

  late final AnimationController _tabSwitchController;
  VendorBottomNavProvider? _navProvider;

  int _activeIndex = 0;
  int? _previousIndex;
  int _slideDirection = 1;
  int _animationEpoch = 0;

  bool get _isAnimating =>
      _previousIndex != null && _tabSwitchController.isAnimating;

  @override
  void initState() {
    super.initState();
    _tabSwitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<VendorBottomNavProvider>();
    if (_navProvider == provider) return;

    _navProvider?.removeListener(_handleTabIndexChanged);
    _navProvider = provider;
    _activeIndex = provider.selectedIndex;
    _navProvider!.addListener(_handleTabIndexChanged);
  }

  void _handleTabIndexChanged() {
    final provider = _navProvider;
    if (!mounted || provider == null) return;

    final nextIndex = provider.selectedIndex;
    if (nextIndex == _activeIndex) return;

    final previous = _activeIndex;
    _tabSwitchController.stop();

    setState(() {
      _previousIndex = previous;
      _activeIndex = nextIndex;
      _slideDirection = nextIndex > previous ? 1 : -1;
    });

    final epoch = ++_animationEpoch;
    _tabSwitchController.forward(from: 0).whenComplete(() {
      if (!mounted || epoch != _animationEpoch) return;
      setState(() {
        _previousIndex = null;
      });
    });
  }

  @override
  void dispose() {
    _navProvider?.removeListener(_handleTabIndexChanged);
    _tabSwitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = context.select<VendorBottomNavProvider, int>(
      (value) => value.selectedIndex,
    );
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: _buildAnimatedBody(selectedIndex),
      ),
      bottomNavigationBar: Container(
        height: size.height * 0.16,
        decoration: BoxDecoration(
          color: colors.backgroundTertiary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderRadius20),
            topRight: Radius.circular(KBorderSize.borderRadius20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              spreadRadius: 1,
              blurRadius: 20,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          child: Row(
            children: [
              Expanded(
                child: _NavButton(
                  icon: Assets.icons.home,
                  label: 'Home',
                  index: 0,
                  selectedIndex: selectedIndex,
                ),
              ),
              Expanded(
                child: _NavButton(
                  icon: Assets.icons.boxIso,
                  label: 'Orders',
                  index: 1,
                  selectedIndex: selectedIndex,
                ),
              ),
              Expanded(
                child: _NavButton(
                  icon: Assets.icons.viewGrid,
                  label: 'Catalog',
                  index: 2,
                  selectedIndex: selectedIndex,
                ),
              ),
              Expanded(
                child: _NavButton(
                  icon: Assets.icons.squareMenu,
                  label: 'More',
                  index: 3,
                  selectedIndex: selectedIndex,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBody(int selectedIndex) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return AnimatedBuilder(
          animation: _tabSwitchController,
          builder: (context, _) {
            final previousIndex = _previousIndex;
            final progress = _tabSwitchController.value;
            final animating = _isAnimating && previousIndex != null;

            return Stack(
              fit: StackFit.expand,
              children: List.generate(_screens.length, (index) {
                if (!animating) {
                  final isVisible = index == selectedIndex;
                  return Offstage(
                    offstage: !isVisible,
                    child: TickerMode(
                      enabled: isVisible,
                      child: _screens[index],
                    ),
                  );
                }

                final isCurrent = index == selectedIndex;
                final isPrevious = index == previousIndex;
                if (!isCurrent && !isPrevious) {
                  return Offstage(
                    offstage: true,
                    child: TickerMode(enabled: false, child: _screens[index]),
                  );
                }

                final offsetX = isCurrent
                    ? _slideDirection * (1 - progress) * width
                    : -_slideDirection * progress * width;

                return Transform.translate(
                  offset: Offset(offsetX, 0),
                  child: TickerMode(enabled: true, child: _screens[index]),
                );
              }),
            );
          },
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  final String icon;
  final String label;
  final int index;
  final int selectedIndex;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selected = selectedIndex == index;

    return GestureDetector(
      onTap: () => context.read<VendorBottomNavProvider>().setIndex(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.all(selected ? 6.0 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? colors.vendorPrimaryBlue : Colors.transparent,
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOutCubic,
              scale: selected ? 1.0 : 0.95,
              child: TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                tween: ColorTween(
                  begin: selected ? Colors.white : colors.textPrimary,
                  end: selected ? Colors.white : colors.textPrimary,
                ),
                builder: (context, color, child) {
                  return SvgPicture.asset(
                    icon,
                    package: 'grab_go_shared',
                    height: KIconSize.lg,
                    width: KIconSize.lg,
                    colorFilter: ColorFilter.mode(
                      color ?? colors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            style: TextStyle(
              fontFamily: 'Lato',
              package: 'grab_go_shared',
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? colors.vendorPrimaryBlue : colors.textPrimary,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
