import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/chat/view/chats_details.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/features/order/viewmodel/order_provider.dart';
import 'package:grab_go_customer/features/restaurant/viewmodel/restaurant_provider.dart';
import 'package:grab_go_customer/features/status/viewmodel/status_provider.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';
import 'package:grab_go_customer/shared/services/chat_socket_service.dart';
import 'package:grab_go_customer/shared/services/image_cache_service.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/shared/utils/routes.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/location_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/theme_provider.dart';
import 'package:provider/provider.dart';

/// Global navigator key for navigation from outside widget tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Background message handler - must be top-level
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Validate environment configuration before proceeding
  AppConfig.validateConfiguration();
  await CacheService.initialize();
  await ImageCacheService.initialize();
  await _initializeBackgroundServices();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => CartProvider()),
        ChangeNotifierProvider(create: (context) => LocationProvider()),
        ChangeNotifierProvider(create: (context) => FoodProvider()),
        ChangeNotifierProvider(create: (context) => RestaurantProvider()),
        ChangeNotifierProvider(create: (context) => OrderProvider()),
        ChangeNotifierProvider(create: (context) => NavigationProvider()),
        ChangeNotifierProvider(create: (context) => FavoritesProvider()),
        ChangeNotifierProvider(create: (context) => StatusProvider()..init()),
      ],
      child: const GrabGoCustomerApp(),
    ),
  );
}

Future<void> _initializeBackgroundServices() async {
  try {
    await GoogleSignInService().initialize();
    await UserService().initialize();
    await ChatSocketService().initialize();

    // Initialize push notifications
    await PushNotificationService().initialize(
      onNotificationTap: _handleNotificationTap,
      onTokenRefresh: _handleTokenRefresh,
    );

    // Register FCM token with backend if user is logged in
    await _registerFcmToken();
  } catch (e) {
    debugPrint('Error initializing background services: $e');
  }
}

/// Handle notification tap - navigate to appropriate screen
void _handleNotificationTap(Map<String, dynamic> data) {
  final type = data['type'];
  final chatId = data['chatId'];
  final orderId = data['orderId'];

  debugPrint('📲 Notification tapped: type=$type, chatId=$chatId, orderId=$orderId');

  // Delay navigation slightly to ensure app is ready
  Future.delayed(const Duration(milliseconds: 500), () {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('⚠️ Navigator context not available');
      return;
    }

    if (type == 'chat_message' && chatId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ChatDetail(chatId: chatId, senderName: data['senderName'] ?? 'Chat'),
        ),
      );
    } else if (type == 'order_update' && orderId != null) {
      // Navigate to order details - you can customize this route
      debugPrint('Navigate to order: $orderId');
      // TODO: Add order detail navigation when route is available
    }
  });
}

/// Handle FCM token refresh
Future<void> _handleTokenRefresh(String token) async {
  await _registerFcmToken();
}

/// Register FCM token with backend
Future<void> _registerFcmToken() async {
  try {
    final userService = UserService();
    if (!userService.isLoggedIn) return;

    final token = await PushNotificationService().getToken();
    if (token == null) return;

    await userService.registerFcmToken(token, platform: 'android');
    debugPrint('✅ FCM token registered with backend');
  } catch (e) {
    debugPrint('Failed to register FCM token: $e');
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
    // Clear badge when app starts
    PushNotificationService().clearBadge();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Clear badge when app comes to foreground
      PushNotificationService().clearBadge();
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
