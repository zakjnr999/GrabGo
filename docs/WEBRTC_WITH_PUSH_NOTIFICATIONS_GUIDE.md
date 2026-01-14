# WebRTC Calling with Push Notifications Integration

## Overview
This guide explains how to integrate WebRTC calling with your existing Firebase Cloud Messaging (FCM) push notification system to handle incoming calls when users are not actively in the app.

---

## The Challenge

**WebRTC requires both parties to be connected to the signaling server** to establish a call. However, users may not always have the app open or be connected to the Socket.IO server. This creates a problem:

1. Customer initiates call → sends WebRTC offer via Socket.IO
2. Rider is not in the app → doesn't receive the offer
3. Call fails ❌

---

## The Solution

Use **Firebase Cloud Messaging (FCM)** to wake up the app and notify the user of an incoming call, then establish the WebRTC connection.

### Call Flow with Push Notifications

```
┌─────────────────────────────────────────────────────────────┐
│  Customer initiates call                                     │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Backend checks if rider is online (Socket.IO)              │
└─────────────────────────────────────────────────────────────┘
                          │
                ┌─────────┴──────────┐
                │                    │
         YES (Online)          NO (Offline)
                │                    │
                ▼                    ▼
    ┌──────────────────┐   ┌──────────────────────┐
    │ Send via Socket  │   │ Send FCM Push        │
    │ (WebRTC offer)   │   │ (Call notification)  │
    └──────────────────┘   └──────────────────────┘
                │                    │
                │                    ▼
                │          ┌──────────────────────┐
                │          │ Rider's phone wakes  │
                │          │ Shows incoming call  │
                │          └──────────────────────┘
                │                    │
                │                    ▼
                │          ┌──────────────────────┐
                │          │ Rider taps "Answer"  │
                │          │ App opens/resumes    │
                │          └──────────────────────┘
                │                    │
                └────────────────────┘
                          │
                          ▼
          ┌────────────────────────────────┐
          │ WebRTC connection established  │
          │ Call begins                    │
          └────────────────────────────────┘
```

---

## Implementation

### ✅ What You Already Have

1. **Firebase Cloud Messaging** - Fully configured
2. **FCM Service** - Backend service for sending push notifications
3. **Push Notification Service** - Flutter service for receiving notifications
4. **Socket.IO** - Real-time communication
5. **Background message handler** - Handles notifications when app is closed

### 🔧 What Needs to be Added

1. **Call notification type** in FCM service
2. **Call state persistence** for handling app resume
3. **Full-screen incoming call UI** (Android/iOS native)
4. **Call timeout mechanism**

---

## Backend Implementation

### 1. Update WebRTC Signaling Service

**File**: `/backend/services/webrtcSignalingService.js` (UPDATE)

```javascript
const { sendCallNotification } = require('./fcm_service');

class WebRTCSignalingService {
  constructor(io) {
    this.io = io;
    this.activeCalls = new Map();
    this.userSockets = new Map();
    this.setupSignaling();
  }

  // ... existing code ...

  async handleCallInitiation(socket, data) {
    const { calleeId, callerId, orderId, offer, callType } = data;
    
    console.log(`WebRTC: Call initiated from ${callerId} to ${calleeId}`);

    const callId = `call_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    // Store call info
    this.activeCalls.set(callId, {
      callId,
      callerId,
      calleeId,
      orderId,
      callType,
      status: 'ringing',
      startedAt: new Date(),
      offer, // Store offer for later retrieval
    });

    // Get callee socket
    const calleeSocketId = this.userSockets.get(calleeId);
    
    if (!calleeSocketId) {
      // User is OFFLINE - send push notification
      console.log(`WebRTC: User ${calleeId} is offline, sending push notification`);
      
      try {
        // Get caller info for notification
        const User = require('../models/User');
        const caller = await User.findById(callerId).select('username profilePicture');
        
        // Send push notification
        await sendCallNotification(
          calleeId,
          caller.username || 'Someone',
          callId,
          callType,
          orderId,
          caller.profilePicture
        );

        // Notify caller that we're trying to reach the callee
        socket.emit('webrtc:call-ringing', { 
          callId,
          viaNotification: true 
        });

        // Set timeout for call (30 seconds)
        setTimeout(() => {
          const call = this.activeCalls.get(callId);
          if (call && call.status === 'ringing') {
            // Call was not answered
            this.handleCallTimeout(callId);
          }
        }, 30000);

      } catch (error) {
        console.error('Error sending call notification:', error);
        socket.emit('webrtc:error', {
          error: 'Failed to reach user',
          callId,
        });
        this.activeCalls.delete(callId);
      }
      return;
    }

    // User is ONLINE - send via Socket.IO (existing logic)
    this.io.to(calleeSocketId).emit('webrtc:incoming-call', {
      callId,
      callerId,
      orderId,
      offer,
      callType,
    });

    socket.emit('webrtc:call-ringing', { callId });
  }

  handleCallTimeout(callId) {
    const call = this.activeCalls.get(callId);
    if (!call) return;

    console.log(`WebRTC: Call ${callId} timed out (no answer)`);

    // Notify caller
    const callerSocketId = this.userSockets.get(call.callerId);
    if (callerSocketId) {
      this.io.to(callerSocketId).emit('webrtc:call-timeout', { callId });
    }

    this.activeCalls.delete(callId);
  }

  // New method: Retrieve call details when user comes online
  async getCallDetails(callId) {
    return this.activeCalls.get(callId);
  }

  // ... rest of existing code ...
}

module.exports = WebRTCSignalingService;
```

### 2. Add Call Notification to FCM Service

**File**: `/backend/services/fcm_service.js` (UPDATE)

Add this function to the exports:

```javascript
/**
 * Send incoming call notification
 * @param {string} recipientId - User ID to receive call
 * @param {string} callerName - Name of the caller
 * @param {string} callId - Call ID for answering
 * @param {string} callType - 'audio' or 'video'
 * @param {string} orderId - Order ID
 * @param {string} callerAvatar - Caller's profile picture URL
 */
const sendCallNotification = async (
  recipientId,
  callerName,
  callId,
  callType = 'audio',
  orderId = null,
  callerAvatar = null
) => {
  const callIcon = callType === 'video' ? '📹' : '📞';
  
  return sendToUser(
    recipientId,
    {
      title: `${callIcon} Incoming ${callType} call`,
      body: `${callerName} is calling you...`,
      ...(callerAvatar && { imageUrl: callerAvatar }),
    },
    {
      type: 'incoming_call',
      callId,
      callType,
      callerId: recipientId, // Will be populated from call data
      callerName,
      callerAvatar: callerAvatar || '',
      orderId: orderId || '',
      // High priority for call notifications
      priority: 'high',
      // Time-sensitive
      ttl: '30', // 30 seconds TTL
    }
  );
};

// Add to module.exports
module.exports = {
  // ... existing exports ...
  sendCallNotification,
};
```

### 3. Create Call Retrieval Endpoint

**File**: `/backend/routes/calls.js` (UPDATE or CREATE)

```javascript
const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/auth');

// Get call details (for when user comes online after receiving notification)
router.get('/:callId', protect, async (req, res) => {
  try {
    const { callId } = req.params;
    const userId = req.user._id.toString();

    // Get WebRTC signaling service instance
    const webrtcSignaling = req.app.get('webrtcSignaling');
    const call = await webrtcSignaling.getCallDetails(callId);

    if (!call) {
      return res.status(404).json({ error: 'Call not found or expired' });
    }

    // Verify user is the callee
    if (call.calleeId !== userId) {
      return res.status(403).json({ error: 'Unauthorized' });
    }

    // Return call details
    res.json({
      callId: call.callId,
      callerId: call.callerId,
      orderId: call.orderId,
      callType: call.callType,
      offer: call.offer,
      status: call.status,
    });
  } catch (error) {
    console.error('Error retrieving call details:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
```

Add to `server.js`:
```javascript
const callRoutes = require('./routes/calls');
app.use('/api/calls', callRoutes);

// Make webrtcSignaling accessible to routes
app.set('webrtcSignaling', webrtcSignaling);
```

---

## Flutter Implementation

### 1. Update Push Notification Service

**File**: `/packages/grab_go_shared/lib/shared/services/push_notification_service.dart` (UPDATE)

Add a new notification channel for calls:

```dart
/// Android notification channel for incoming calls
static const AndroidNotificationChannel _callChannel = AndroidNotificationChannel(
  'incoming_calls',
  'Incoming Calls',
  description: 'Notifications for incoming voice and video calls',
  importance: Importance.max, // Maximum importance for calls
  playSound: true,
  enableVibration: true,
  enableLights: true,
  ledColor: Colors.green,
);
```

Update `_initializeLocalNotifications()`:

```dart
// Incoming calls channel (highest priority)
await androidPlugin?.createNotificationChannel(_callChannel);
```

Update `_getNotificationChannel()`:

```dart
String _getNotificationChannel(String? type) {
  const channelMap = {
    'incoming_call': 'incoming_calls', // Add this
    'chat_message': 'chat_messages',
    // ... rest of existing mappings
  };
  return channelMap[type] ?? 'default';
}
```

### 2. Handle Incoming Call Notifications

Update `_handleForegroundMessage()` to handle call notifications specially:

```dart
Future<void> _handleForegroundMessage(RemoteMessage message) async {
  debugPrint('Foreground message: ${message.messageId}');

  final notification = message.notification;
  final data = message.data;

  // Special handling for incoming calls
  if (data['type'] == 'incoming_call') {
    debugPrint('📞 Incoming call notification received');
    // Don't show as regular notification - let the app handle it
    _onNotificationTap?.call(data);
    return;
  }

  // ... rest of existing code for other notification types
}
```

### 3. Create Call Notification Handler

**File**: `/packages/grab_go_customer/lib/shared/services/call_notification_handler.dart` (NEW)

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/webrtc_service.dart';
import '../../features/call/view/call_screen.dart';

class CallNotificationHandler {
  static final CallNotificationHandler _instance = CallNotificationHandler._();
  factory CallNotificationHandler() => _instance;
  CallNotificationHandler._();

  BuildContext? _context;

  void initialize(BuildContext context) {
    _context = context;
  }

  /// Handle incoming call notification
  Future<void> handleIncomingCall(Map<String, dynamic> data) async {
    if (_context == null || !_context!.mounted) {
      debugPrint('❌ Context not available for incoming call');
      return;
    }

    final callId = data['callId'];
    final callType = data['callType'];
    final callerName = data['callerName'];
    final callerAvatar = data['callerAvatar'];
    final orderId = data['orderId'];

    debugPrint('📞 Handling incoming call: $callId from $callerName');

    // Fetch call details from backend
    final callDetails = await _fetchCallDetails(callId);
    if (callDetails == null) {
      debugPrint('❌ Call not found or expired');
      return;
    }

    // Navigate to call screen
    Navigator.of(_context!).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          recipientName: callerName ?? 'Unknown',
          recipientAvatar: callerAvatar,
          isIncoming: true,
          callId: callId,
          offer: callDetails['offer'],
        ),
        fullscreenDialog: true,
      ),
    );
  }

  /// Fetch call details from backend
  Future<Map<String, dynamic>?> _fetchCallDetails(String callId) async {
    try {
      // Use your existing API service
      final dio = Dio();
      final token = await SecureStorageService.getToken();
      
      final response = await dio.get(
        '${AppConfig.apiUrl}/calls/$callId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return response.data;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error fetching call details: $e');
      return null;
    }
  }
}
```

### 4. Update Main App to Handle Call Notifications

**File**: `/packages/grab_go_customer/lib/main.dart` (UPDATE)

```dart
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNotificationHandlers();
  }

  void _setupNotificationHandlers() {
    // Setup push notification tap handler
    PushNotificationService().setOnNotificationTap((data) {
      debugPrint('📲 Notification tapped: ${data['type']}');
      
      // Handle incoming call notifications
      if (data['type'] == 'incoming_call') {
        CallNotificationHandler().handleIncomingCall(data);
        return;
      }

      // Handle other notification types
      _handleOtherNotifications(data);
    });
  }

  void _handleOtherNotifications(Map<String, dynamic> data) {
    // Your existing notification handling logic
    final type = data['type'];
    
    switch (type) {
      case 'chat_message':
        // Navigate to chat
        break;
      case 'order_update':
        // Navigate to order
        break;
      // ... other cases
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) {
            // Initialize call notification handler with context
            WidgetsBinding.instance.addPostFrameCallback((_) {
              CallNotificationHandler().initialize(context);
            });

            return MaterialApp.router(
              // ... existing code
            );
          },
        );
      },
    );
  }
}
```

### 5. Update WebRTC Service to Handle Timeouts

**File**: `/packages/grab_go_customer/lib/shared/services/webrtc_service.dart` (UPDATE)

Add timeout handling:

```dart
void _setupSocketListeners() {
  _socket?.on('webrtc:incoming-call', _handleIncomingCall);
  _socket?.on('webrtc:call-ringing', _handleCallRinging);
  _socket?.on('webrtc:call-answered', _handleCallAnswered);
  _socket?.on('webrtc:ice-candidate', _handleIceCandidate);
  _socket?.on('webrtc:call-ended', _handleCallEnded);
  _socket?.on('webrtc:call-rejected', _handleCallRejected);
  _socket?.on('webrtc:call-timeout', _handleCallTimeout); // Add this
  _socket?.on('webrtc:error', _handleError);
}

void _handleCallTimeout(dynamic data) {
  debugPrint('WebRTC: Call timed out (no answer)');
  _callState = CallState.timeout; // Add this state
  notifyListeners();
  _cleanup();
}
```

---

## Android-Specific: Full-Screen Incoming Call

For a better user experience on Android, you can show a full-screen incoming call notification.

### Update Android Manifest

**File**: `android/app/src/main/AndroidManifest.xml`

```xml
<manifest>
    <!-- Add these permissions -->
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    
    <application>
        <!-- Add activity for full-screen call -->
        <activity
            android:name=".IncomingCallActivity"
            android:excludeFromRecents="true"
            android:exported="false"
            android:launchMode="singleInstance"
            android:showWhenLocked="true"
            android:turnScreenOn="true" />
    </application>
</manifest>
```

### Create Full-Screen Call Notification (Optional)

This requires native Android code. For simplicity, you can use the `flutter_callkit_incoming` package:

```yaml
dependencies:
  flutter_callkit_incoming: ^2.0.0
```

Then update your notification handling to show a native call UI.

---

## iOS-Specific: CallKit Integration

For iOS, you should use CallKit for a native calling experience.

### Add CallKit Package

```yaml
dependencies:
  flutter_callkit_incoming: ^2.0.0
```

### Update iOS Info.plist

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
    <string>voip</string>
</array>
```

---

## Testing

### Test Scenarios

1. **Both users online**
   - ✅ Call should connect via Socket.IO immediately
   
2. **Callee app in background**
   - ✅ Push notification should wake app
   - ✅ Call screen should appear
   - ✅ User can answer
   
3. **Callee app completely closed**
   - ✅ Push notification should appear
   - ✅ Tapping notification opens app to call screen
   - ✅ User can answer
   
4. **Callee doesn't answer (30 seconds)**
   - ✅ Call should timeout
   - ✅ Caller should see "No answer" message
   
5. **Callee rejects call**
   - ✅ Caller should see "Call rejected"

---

## Production Checklist

- [ ] FCM credentials configured
- [ ] Call notifications have highest priority
- [ ] Call timeout set (30 seconds recommended)
- [ ] Full-screen call UI implemented (Android)
- [ ] CallKit integrated (iOS)
- [ ] Call history/logs saved
- [ ] Missed call notifications sent
- [ ] Battery optimization handled
- [ ] Network reconnection handled
- [ ] Call quality monitoring

---

## Summary

### ✅ Your Current Setup Already Supports This!

You have:
1. ✅ Firebase Cloud Messaging configured
2. ✅ Background message handler
3. ✅ Notification tap handling
4. ✅ Socket.IO for real-time communication

### 🔧 What You Need to Add:

1. **Backend** (30 minutes):
   - Check if user is online before sending call
   - Send FCM notification if offline
   - Store call details for retrieval
   - Handle call timeout

2. **Flutter** (1 hour):
   - Handle `incoming_call` notification type
   - Fetch call details when app resumes
   - Show call screen from notification
   - Handle call timeout state

### Total Implementation Time: ~2 hours

---

## Advantages of This Approach

✅ **Works when app is closed** - FCM wakes the app  
✅ **Works when app is in background** - Notification appears  
✅ **No missed calls** - Users always get notified  
✅ **Uses existing infrastructure** - No new services needed  
✅ **Battery efficient** - Only wakes app for actual calls  
✅ **Reliable** - FCM has 99.9% delivery rate  

---

## Alternative: VoIP Push Notifications (iOS)

For iOS, you can use VoIP push notifications for even better reliability:

- Wakes app instantly (no delay)
- Shows native CallKit UI
- Better battery efficiency
- Required for production iOS apps with calling

This requires Apple Push Notification service (APNs) VoIP certificates.

---

## Next Steps

1. ✅ Implement backend changes (check online status, send FCM)
2. ✅ Add call notification handling in Flutter
3. ✅ Test with app in background
4. ✅ Test with app completely closed
5. ✅ Add CallKit for iOS (production)
6. ✅ Add full-screen call UI for Android (production)

Your existing notification infrastructure is perfect for this! You just need to add the call-specific logic. 🚀
