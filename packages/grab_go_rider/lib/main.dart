import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:grab_go_rider/features/chat/view/chat_detail_page.dart';
import 'package:grab_go_rider/features/orders/view/call_screen.dart';
import 'package:grab_go_rider/features/orders/service/order_reservation_service.dart';
import 'package:grab_go_rider/features/orders/view/available_orders.dart';
import 'package:grab_go_rider/features/orders/view/order_confirmation_page.dart';
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
Map<String, dynamic>? _pendingNotificationTapData;
Timer? _pendingNotificationRetryTimer;
int _pendingNotificationRetryCount = 0;
const int _maxPendingNotificationRetries = 40;
bool _isProcessingPendingNotification = false;

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
  final normalizedData = Map<String, dynamic>.from(data);
  final type = normalizedData['type'];
  final chatId = normalizedData['chatId'];
  final orderId = normalizedData['orderId'];
  debugPrint(
    '📲 Notification tapped: type=$type, chatId=$chatId, orderId=$orderId',
  );

  _pendingNotificationTapData = normalizedData;
  _pendingNotificationRetryCount = 0;
  _schedulePendingNotificationProcessing();
}

void _schedulePendingNotificationProcessing({
  Duration delay = const Duration(milliseconds: 500),
}) {
  _pendingNotificationRetryTimer?.cancel();
  _pendingNotificationRetryTimer = Timer(
    delay,
    _tryProcessPendingNotificationTap,
  );
}

void _tryProcessPendingNotificationTap() {
  final data = _pendingNotificationTapData;
  if (data == null || _isProcessingPendingNotification) return;

  final navigator = navigatorKey.currentState;
  final currentPath = appRouter.routerDelegate.currentConfiguration.uri.path;
  final routeReady = currentPath.isNotEmpty && currentPath != '/';

  if (navigator == null || !routeReady) {
    _pendingNotificationRetryCount++;
    if (_pendingNotificationRetryCount <= _maxPendingNotificationRetries) {
      _schedulePendingNotificationProcessing(
        delay: const Duration(milliseconds: 700),
      );
      return;
    }

    if (navigator == null) {
      debugPrint(
        '⚠️ Dropping pending notification tap: navigator unavailable after retries',
      );
      _pendingNotificationTapData = null;
      return;
    }
  }

  _pendingNotificationTapData = null;
  _isProcessingPendingNotification = true;
  _processNotificationTapData(data, navigator);
  _isProcessingPendingNotification = false;
}

void _processNotificationTapData(
  Map<String, dynamic> data,
  NavigatorState navigator,
) {
  final type = data['type'];
  final chatId = data['chatId'];
  final orderId = data['orderId'];

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
  } else if (type == 'order_reserved') {
    unawaited(_handleReservedOrderTap(navigator, data));
  } else if ((type == 'order_update' || type == 'rider_assignment') &&
      orderId != null) {
    // Navigate to order details - you can customize this route
    debugPrint('Navigate to order: $orderId');
    // TODO: Add order detail navigation when route is available
  }
}

void _showGlobalSnackBar(NavigatorState navigator, String message) {
  final messenger = ScaffoldMessenger.maybeOf(navigator.context);
  messenger?.showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
  );
}

Future<void> _handleReservedOrderTap(
  NavigatorState navigator,
  Map<String, dynamic> data,
) async {
  try {
    final tappedOrderId = data['orderId']?.toString();
    debugPrint('📦 Handling order_reserved tap for order: $tappedOrderId');

    final reservationService = OrderReservationService();

    // Hydrate reservation state when opened from push/background.
    final reservation = await reservationService.fetchActiveReservation();
    if (reservation == null || reservation.isExpired) {
      _showGlobalSnackBar(
        navigator,
        'This order request is no longer available.',
      );
      navigator.push(
        MaterialPageRoute(builder: (context) => const AvailableOrders()),
      );
      return;
    }

    // Accept reservation on tap so rider lands directly in pickup flow.
    final accepted = await reservationService.acceptReservation();
    if (!accepted) {
      final failureMessage =
          reservationService.error ??
          'Could not accept this order. It may have expired.';
      _showGlobalSnackBar(navigator, failureMessage);
      navigator.push(
        MaterialPageRoute(builder: (context) => const AvailableOrders()),
      );
      return;
    }

    final order = reservation.order;
    navigator.push(
      MaterialPageRoute(
        builder: (context) => OrderConfirmationPage(
          orderId: reservation.orderId,
          orderNumber: reservation.orderNumber,
          orderStatus: 'ready',
          orderInstructions: '',
          customerName: order.customerName,
          customerAddress: order.deliveryAddress,
          customerPhone: '',
          customerPhoto: null,
          restaurantName: order.storeName,
          restaurantAddress: order.pickupAddress,
          restaurantLogo: order.storeLogo,
          orderTotal: 'GHS ${order.totalAmount.toStringAsFixed(2)}',
          orderItems: [
            '${order.itemCount} item${order.itemCount == 1 ? '' : 's'}',
          ],
          specialInstructions: null,
          riderEarnings: reservation.estimatedEarnings,
          pickupLatitude: order.pickupLat,
          pickupLongitude: order.pickupLon,
          destinationLatitude: order.deliveryLat,
          destinationLongitude: order.deliveryLon,
        ),
      ),
    );
  } catch (e) {
    debugPrint('❌ Error handling reserved-order notification tap: $e');
    _showGlobalSnackBar(navigator, 'Failed to open order from notification.');
    navigator.push(
      MaterialPageRoute(builder: (context) => const AvailableOrders()),
    );
  }
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
      _schedulePendingNotificationProcessing(
        delay: const Duration(milliseconds: 300),
      );
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
