import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:grab_go_rider/features/chat/view/chat_detail_page.dart';
import 'package:grab_go_rider/features/orders/view/call_screen.dart';
import 'package:grab_go_rider/features/orders/service/rider_foreground_service.dart';
import 'package:grab_go_rider/features/orders/viewmodel/rider_tracking_provider.dart';
import 'package:grab_go_rider/shared/viewmodel/bottom_nav_provider.dart';
import 'package:grab_go_rider/shared/viewmodel/theme_provider.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';
import 'package:grab_go_rider/shared/utils/routes.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/services/secure_storage_service.dart';
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

  // Initialize secure storage first (for encrypted token/credential storage)
  await SecureStorageService.initialize();

  // Then initialize cache service
  await CacheService.initialize();
  await _initializeBackgroundServices();

  // Initialize foreground service for rider tracking
  await RiderForegroundService().initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => BottomNavProvider()),
        ChangeNotifierProvider(create: (context) => RiderTrackingProvider()),
        ChangeNotifierProvider(create: (context) => WebRTCService()),
      ],
      child: GrabGoRiderApp(),
    ),
  );
}

Future<void> _initializeBackgroundServices() async {
  try {
    await GoogleSignInService().initialize();
    await UserService().initialize();
    await SocketService().initialize();

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

  debugPrint(
    '📲 Notification tapped: type=$type, chatId=$chatId, orderId=$orderId',
  );

  // Delay navigation slightly to ensure app is ready
  Future.delayed(const Duration(milliseconds: 500), () {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('⚠️ Navigator state not available');
      return;
    }

    if (type == 'chat_message' && chatId != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chatId: chatId,
            senderName: data['senderName'] ?? 'Chat',
          ),
        ),
      );
    } else if (type == 'incoming_call') {
      final callId = data['callId']?.toString() ?? '';
      if (callId.isEmpty) {
        return;
      }

      // Restore call details; UI presentation is handled by the root WebRTC listener.
      unawaited(WebRTCService().hydrateIncomingCallFromCallId(callId));
    } else if ((type == 'order_update' || type == 'rider_assignment') &&
        orderId != null) {
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

class GrabGoRiderApp extends StatefulWidget {
  const GrabGoRiderApp({super.key});

  @override
  State<GrabGoRiderApp> createState() => _GrabGoRiderAppState();
}

class _GrabGoRiderAppState extends State<GrabGoRiderApp>
    with WidgetsBindingObserver {
  WebRTCService? _webrtcService;
  void Function(SocketConnectionState)? _socketConnectionListener;
  bool _isIncomingCallScreenOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Clear badge when app starts
    PushNotificationService().clearBadge();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupWebRTCBindings();
      _initializeWebRTC();
    });
  }

  void _setupWebRTCBindings() {
    _webrtcService = context.read<WebRTCService>();
    _webrtcService!.addListener(_handleWebRTCStateChanged);

    _socketConnectionListener = (state) {
      if (state == SocketConnectionState.connected && mounted) {
        _initializeWebRTC();
      }
    };

    SocketService().addConnectionListener(_socketConnectionListener!);
  }

  void _handleWebRTCStateChanged() {
    final service = _webrtcService;
    if (service == null || !mounted) return;

    if (!service.hasPendingIncomingCall || _isIncomingCallScreenOpen) {
      return;
    }

    final otherUserId = service.otherUserId;
    if (otherUserId == null || otherUserId.isEmpty) {
      return;
    }

    _isIncomingCallScreenOpen = true;
    final navContext = navigatorKey.currentContext ?? context;
    Navigator.of(navContext)
        .push(
          MaterialPageRoute(
            builder: (context) => RiderCallScreen(
              otherUserId: otherUserId,
              otherUserName: 'Incoming call',
              orderId: service.orderId,
              isIncoming: true,
            ),
            fullscreenDialog: true,
          ),
        )
        .whenComplete(() {
          _isIncomingCallScreenOpen = false;
        });
  }

  Future<void> _initializeWebRTC() async {
    try {
      final socketService = SocketService();
      final webrtcService = _webrtcService ?? context.read<WebRTCService>();
      final user = UserService().currentUser;

      if (socketService.isConnected &&
          socketService.socket != null &&
          user != null &&
          user.id != null) {
        await webrtcService.initialize(socketService.socket!, user.id!);
      }
    } catch (error) {
      debugPrint('Error initializing rider WebRTC: $error');
    }
  }

  @override
  void dispose() {
    if (_socketConnectionListener != null) {
      SocketService().removeConnectionListener(_socketConnectionListener!);
    }
    _webrtcService?.removeListener(_handleWebRTCStateChanged);
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
