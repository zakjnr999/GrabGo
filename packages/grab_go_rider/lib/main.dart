import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_rider/shared/viewmodel/bottom_nav_provider.dart';
import 'package:grab_go_rider/shared/viewmodel/theme_provider.dart';
import 'package:grab_go_rider/shared/service/cache_service.dart';
import 'package:grab_go_rider/shared/utils/routes.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Validate environment configuration
  try {
    AppConfig.validateConfiguration();
    if (AppConfig.enableLogging) {
      debugPrint('✅ Rider: Environment configuration validated');
    }
  } catch (e) {
    debugPrint('❌ Rider Configuration Error: $e');
    rethrow;
  }

  await CacheService.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => BottomNavProvider()),
      ],
      child: GrabGoRiderApp(),
    ),
  );
}

class GrabGoRiderApp extends StatefulWidget {
  const GrabGoRiderApp({super.key});

  @override
  State<GrabGoRiderApp> createState() => _GrabGoRiderAppState();
}

class _GrabGoRiderAppState extends State<GrabGoRiderApp> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return ScreenUtilInit(
          designSize: const Size(375, 812),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (context, child) {
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,
              routerConfig: appRouter,
            );
          },
        );
      },
    );
  }
}
