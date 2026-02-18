import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/services/secure_storage_service.dart';
import 'package:grab_go_vendor/features/onboarding/viewmodel/onboarding_setup_viewmodel.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/shared/utils/routes.dart';
import 'package:grab_go_vendor/shared/viewmodel/theme_provider.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SecureStorageService.initialize();
  await CacheService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => VendorPreviewSessionViewModel()),
        ChangeNotifierProxyProvider<
          VendorPreviewSessionViewModel,
          VendorStoreContextViewModel
        >(
          create: (_) => VendorStoreContextViewModel(),
          update: (_, previewSession, storeContextViewModel) {
            final viewModel =
                storeContextViewModel ?? VendorStoreContextViewModel();
            viewModel.setAllowedServices(previewSession.allowedServices);
            return viewModel;
          },
        ),
        ChangeNotifierProvider(create: (_) => OnboardingSetupViewModel()),
      ],
      child: const GrabGoVendorApp(),
    ),
  );
}

class GrabGoVendorApp extends StatelessWidget {
  const GrabGoVendorApp({super.key});

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
              title: 'GrabGo Vendor',
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
