import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_rider/shared/service/storage_service.dart';
import 'package:grab_go_rider/shared/service/auth_guard.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    await UserService().initialize();
    await SocketService().initialize();

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final router = GoRouter.of(context);
    final currentLocation = router.routerDelegate.currentConfiguration.uri.path;

    if (currentLocation != '/' && currentLocation != '') {
      return;
    }

    final isFirst = await StorageService.isFirstLaunch();

    if (isFirst) {
      context.go("/onboarding");
    } else {
      await AuthGuard.checkAuthAndRedirect(context);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: FadeTransition(
          opacity: _fade,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: colors.accentGreen,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 2.w),
                      child: Text(
                        'Grab',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 64.sp,
                          height: 1.0,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Container(
                      color: Colors.white,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 2.w),
                          child: Text(
                            'GO',
                            style: TextStyle(
                              color: colors.accentGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 64.sp,
                              height: 1.0,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    SvgPicture.asset(
                      Assets.icons.deliveryGuyIcon,
                      package: 'grab_go_shared',
                      width: 64.w,
                      height: 64.w,
                      colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
