import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_banner_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_category_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_deals_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_discovery_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/settings_provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/services/secure_storage_service.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/order/viewmodel/order_provider.dart';
import 'package:grab_go_customer/features/restaurant/viewmodel/restaurant_provider.dart';
import 'package:grab_go_customer/features/status/viewmodel/status_provider.dart';
import 'package:grab_go_customer/shared/services/image_cache_service.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/shared/utils/routes.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/theme_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/service_provider.dart';
import 'package:grab_go_customer/features/groceries/viewmodel/grocery_provider.dart';
import 'package:grab_go_customer/features/pharmacy/viewmodel/pharmacy_provider.dart';
import 'package:grab_go_customer/features/grabmart/viewmodel/grabmart_provider.dart';
import 'package:grab_go_customer/features/vendors/viewmodel/vendor_provider.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:provider/provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  AppConfig.validateConfiguration();

  await SecureStorageService.initialize();

  await CacheService.initialize();
  await ImageCacheService.initialize();
  await _initializeBackgroundServices();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => NativeLocationProvider()),
        ChangeNotifierProxyProvider<NativeLocationProvider, CartProvider>(
          create: (context) => CartProvider(),
          update: (context, locationProvider, cartProvider) {
            final provider = cartProvider ?? CartProvider();
            final confirmed = locationProvider.confirmedAddress;
            provider.updateDeliveryLocation(
              latitude: confirmed?.latitude ?? locationProvider.latitude,
              longitude: confirmed?.longitude ?? locationProvider.longitude,
            );
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (context) => FoodCategoryProvider()),
        ChangeNotifierProvider(create: (context) => FoodBannerProvider()),
        ChangeNotifierProvider(create: (context) => FoodDealsProvider()),
        ChangeNotifierProvider(create: (context) => FoodDiscoveryProvider()),
        ChangeNotifierProxyProvider4<
          FoodCategoryProvider,
          FoodBannerProvider,
          FoodDealsProvider,
          FoodDiscoveryProvider,
          FoodProvider
        >(
          create: (context) => FoodProvider(
            categoryProvider: Provider.of<FoodCategoryProvider>(context, listen: false),
            bannerProvider: Provider.of<FoodBannerProvider>(context, listen: false),
            dealsProvider: Provider.of<FoodDealsProvider>(context, listen: false),
            discoveryProvider: Provider.of<FoodDiscoveryProvider>(context, listen: false),
          ),
          update: (context, cat, ban, deal, disc, food) => food!,
        ),
        ChangeNotifierProvider(create: (context) => RestaurantProvider()),
        ChangeNotifierProvider(create: (context) => OrderProvider()),
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => FavoritesProvider()),
        ChangeNotifierProvider(create: (context) => StatusProvider()..init()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
        ChangeNotifierProvider(create: (context) => ServiceProvider()),
        ChangeNotifierProvider(create: (context) => GroceryProvider()),
        ChangeNotifierProvider(create: (context) => PharmacyProvider()),
        ChangeNotifierProvider(create: (context) => GrabMartProvider()),
        ChangeNotifierProvider(create: (context) => VendorProvider(vendorService)),
        ChangeNotifierProvider(create: (context) => WebRTCService()),
      ],
      child: const GrabGoCustomerApp(),
    ),
  );
}

Future<void> _initializeBackgroundServices() async {
  try {
    await GoogleSignInService().initialize();
    await UserService().initialize();
    await SocketService().initialize();
  } catch (e) {
    debugPrint('Error initializing background services: $e');
  }
}

class GrabGoCustomerApp extends StatefulWidget {
  const GrabGoCustomerApp({super.key});

  @override
  State<GrabGoCustomerApp> createState() => _MyAppState();
}

class _MyAppState extends State<GrabGoCustomerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize WebRTC service after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWebRTC();
    });
  }

  Future<void> _initializeWebRTC() async {
    try {
      debugPrint('🔧 Attempting to initialize WebRTC...');
      final socketService = SocketService();
      final webrtcService = context.read<WebRTCService>();
      final user = UserService().currentUser;

      debugPrint('   Socket connected: ${socketService.isConnected}');
      debugPrint('   Socket exists: ${socketService.socket != null}');
      debugPrint('   User exists: ${user != null}');
      debugPrint('   User ID: ${user?.id}');

      if (socketService.isConnected && socketService.socket != null && user != null) {
        await webrtcService.initialize(socketService.socket!, user.id!);
        debugPrint('✅ WebRTC service initialized');
      } else {
        debugPrint('⚠️ Cannot initialize WebRTC: Socket not connected or user not logged in');
        debugPrint('   Will retry in 2 seconds...');

        // Retry after a delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _initializeWebRTC();
        });
      }
    } catch (e) {
      debugPrint('Error initializing WebRTC: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (PushNotificationService().isInitialized) {
        PushNotificationService().clearBadge();
      }
    }
  }

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
              key: navigatorKey,
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
