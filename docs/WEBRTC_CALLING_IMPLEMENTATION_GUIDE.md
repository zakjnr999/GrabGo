# WebRTC In-App Calling Implementation Guide for GrabGo

## Overview

This guide provides a complete implementation of WebRTC-based voice and video calling in your GrabGo food delivery app, allowing customers and riders to communicate directly within the app without exposing phone numbers.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Technology Stack](#technology-stack)?
3. [Prerequisites](#prerequisites)
4. [Backend Implementation](#backend-implementation)
5. [Flutter Implementation](#flutter-implementation)
6. [Call Flow](#call-flow)
7. [UI Components](#ui-components)
8. [Testing](#testing)
9. [Production Considerations](#production-considerations)

---

## Architecture Overview

```
┌─────────────┐         WebSocket          ┌─────────────┐
│  Customer   │◄──────Signaling───────────►│   Rider     │
│   Flutter   │                             │   Flutter   │
└──────┬──────┘                             └──────┬──────┘
       │                                           │
       │         WebRTC P2P Connection            │
       └──────────────────────────────────────────┘
                  (Audio/Video)

       ┌──────────────────────────────────┐
       │   Node.js Signaling Server       │
       │   (Socket.IO + Express)          │
       └──────────────────────────────────┘
```

### Key Components

1. **Signaling Server**: Coordinates call setup (offer/answer/ICE candidates)
2. **STUN/TURN Servers**: Help establish P2P connections through NAT/firewalls
3. **Flutter WebRTC**: Handles media streams and peer connections
4. **Socket.IO**: Real-time signaling communication

---

## Technology Stack

### Backend

- **Node.js** + **Express** (existing)
- **Socket.IO** (you already have this!)
- **MongoDB** (for call logs)

### Frontend

- **flutter_webrtc**: ^0.11.0+
- **socket_io_client**: ^2.0.3+1 (you already have this!)
- **permission_handler**: ^11.3.1 (you already have this!)

### Infrastructure

- **STUN Server**: Free (Google STUN)
- **TURN Server**: Optional (for NAT traversal)

---

## Prerequisites

### 1. Install Flutter Package

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter_webrtc: ^0.11.7
  # You already have these:
  socket_io_client: ^2.0.3+1
  permission_handler: ^11.3.1
```

### 2. Platform Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<manifest>
    <!-- Add these permissions -->
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <uses-feature android:name="android.hardware.camera" android:required="false" />
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />

    <application>
        <!-- ... -->
    </application>
</manifest>
```

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>NSCameraUsageDescription</key>
<string>GrabGo needs camera access for video calls with riders</string>
<key>NSMicrophoneUsageDescription</key>
<string>GrabGo needs microphone access for voice calls with riders</string>
```

### 3. Backend Dependencies

```bash
cd backend
npm install socket.io@^4.7.5  # You already have this
```

---

## Backend Implementation

### 1. Create WebRTC Signaling Service

**File**: `/backend/services/webrtcSignalingService.js` (NEW)

```javascript
class WebRTCSignalingService {
  constructor(io) {
    this.io = io;
    this.activeCalls = new Map(); // callId -> { caller, callee, status }
    this.userSockets = new Map(); // userId -> socketId
    this.setupSignaling();
  }

  setupSignaling() {
    this.io.on("connection", (socket) => {
      console.log(`WebRTC: User connected: ${socket.id}`);

      // Register user
      socket.on("webrtc:register", (userId) => {
        this.userSockets.set(userId, socket.id);
        socket.userId = userId;
        console.log(
          `WebRTC: User ${userId} registered with socket ${socket.id}`
        );
      });

      // Initiate call
      socket.on("webrtc:call", async (data) => {
        await this.handleCallInitiation(socket, data);
      });

      // Answer call
      socket.on("webrtc:answer", async (data) => {
        await this.handleCallAnswer(socket, data);
      });

      // ICE candidate exchange
      socket.on("webrtc:ice-candidate", (data) => {
        this.handleIceCandidate(socket, data);
      });

      // End call
      socket.on("webrtc:end-call", (data) => {
        this.handleEndCall(socket, data);
      });

      // Reject call
      socket.on("webrtc:reject", (data) => {
        this.handleRejectCall(socket, data);
      });

      // Disconnect
      socket.on("disconnect", () => {
        this.handleDisconnect(socket);
      });
    });
  }

  async handleCallInitiation(socket, data) {
    const { calleeId, callerId, orderId, offer, callType } = data;

    console.log(`WebRTC: Call initiated from ${callerId} to ${calleeId}`);

    const callId = `call_${Date.now()}_${Math.random()
      .toString(36)
      .substr(2, 9)}`;

    // Store call info
    this.activeCalls.set(callId, {
      callId,
      callerId,
      calleeId,
      orderId,
      callType, // 'audio' or 'video'
      status: "ringing",
      startedAt: new Date(),
    });

    // Get callee socket
    const calleeSocketId = this.userSockets.get(calleeId);

    if (!calleeSocketId) {
      socket.emit("webrtc:error", {
        error: "User is offline",
        callId,
      });
      this.activeCalls.delete(callId);
      return;
    }

    // Send call offer to callee
    this.io.to(calleeSocketId).emit("webrtc:incoming-call", {
      callId,
      callerId,
      orderId,
      offer,
      callType,
    });

    // Notify caller that call is ringing
    socket.emit("webrtc:call-ringing", { callId });
  }

  async handleCallAnswer(socket, data) {
    const { callId, answer } = data;

    const call = this.activeCalls.get(callId);
    if (!call) {
      socket.emit("webrtc:error", { error: "Call not found" });
      return;
    }

    console.log(`WebRTC: Call ${callId} answered`);

    // Update call status
    call.status = "active";
    call.answeredAt = new Date();

    // Send answer to caller
    const callerSocketId = this.userSockets.get(call.callerId);
    if (callerSocketId) {
      this.io.to(callerSocketId).emit("webrtc:call-answered", {
        callId,
        answer,
      });
    }
  }

  handleIceCandidate(socket, data) {
    const { callId, candidate, targetUserId } = data;

    const targetSocketId = this.userSockets.get(targetUserId);
    if (targetSocketId) {
      this.io.to(targetSocketId).emit("webrtc:ice-candidate", {
        callId,
        candidate,
      });
    }
  }

  handleEndCall(socket, data) {
    const { callId } = data;

    const call = this.activeCalls.get(callId);
    if (!call) return;

    console.log(`WebRTC: Call ${callId} ended`);

    // Notify both parties
    const callerSocketId = this.userSockets.get(call.callerId);
    const calleeSocketId = this.userSockets.get(call.calleeId);

    if (callerSocketId) {
      this.io.to(callerSocketId).emit("webrtc:call-ended", { callId });
    }
    if (calleeSocketId) {
      this.io.to(calleeSocketId).emit("webrtc:call-ended", { callId });
    }

    // Calculate duration and save call log
    const duration = call.answeredAt
      ? Math.floor((Date.now() - call.answeredAt.getTime()) / 1000)
      : 0;

    this.saveCallLog(call, duration);
    this.activeCalls.delete(callId);
  }

  handleRejectCall(socket, data) {
    const { callId } = data;

    const call = this.activeCalls.get(callId);
    if (!call) return;

    console.log(`WebRTC: Call ${callId} rejected`);

    // Notify caller
    const callerSocketId = this.userSockets.get(call.callerId);
    if (callerSocketId) {
      this.io.to(callerSocketId).emit("webrtc:call-rejected", { callId });
    }

    this.activeCalls.delete(callId);
  }

  handleDisconnect(socket) {
    const userId = socket.userId;
    if (userId) {
      this.userSockets.delete(userId);
      console.log(`WebRTC: User ${userId} disconnected`);

      // End any active calls for this user
      for (const [callId, call] of this.activeCalls.entries()) {
        if (call.callerId === userId || call.calleeId === userId) {
          this.handleEndCall(socket, { callId });
        }
      }
    }
  }

  async saveCallLog(call, duration) {
    try {
      const CallLog = require("../models/CallLog");

      await CallLog.create({
        order: call.orderId,
        caller: call.callerId,
        recipient: call.calleeId,
        callType: "webrtc",
        status: duration > 0 ? "completed" : "missed",
        duration,
        startedAt: call.startedAt,
        endedAt: new Date(),
      });

      console.log(`WebRTC: Call log saved for ${call.callId}`);
    } catch (error) {
      console.error("Error saving call log:", error);
    }
  }

  getActiveCall(userId) {
    for (const call of this.activeCalls.values()) {
      if (call.callerId === userId || call.calleeId === userId) {
        return call;
      }
    }
    return null;
  }
}

module.exports = WebRTCSignalingService;
```

### 2. Update Server.js

**File**: `/backend/server.js` (UPDATE)

```javascript
// Add after existing Socket.IO setup
const WebRTCSignalingService = require("./services/webrtcSignalingService");

// Initialize WebRTC signaling
const webrtcSignaling = new WebRTCSignalingService(io);

console.log("✅ WebRTC signaling service initialized");
```

### 3. Create Call Log Model (if not exists)

**File**: `/backend/models/CallLog.js`

```javascript
const mongoose = require("mongoose");

const callLogSchema = new mongoose.Schema(
  {
    order: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Order",
      required: true,
    },
    caller: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    callType: {
      type: String,
      enum: ["direct", "masked", "webrtc"],
      default: "webrtc",
    },
    status: {
      type: String,
      enum: [
        "initiated",
        "ringing",
        "active",
        "completed",
        "missed",
        "rejected",
        "failed",
      ],
      default: "initiated",
    },
    duration: {
      type: Number, // in seconds
      default: 0,
    },
    isVideoCall: {
      type: Boolean,
      default: false,
    },
    startedAt: {
      type: Date,
      default: Date.now,
    },
    endedAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

callLogSchema.index({ order: 1 });
callLogSchema.index({ caller: 1 });
callLogSchema.index({ recipient: 1 });
callLogSchema.index({ createdAt: -1 });

module.exports = mongoose.model("CallLog", callLogSchema);
```

---

## Flutter Implementation

### 1. Create WebRTC Service

**File**: `/packages/grab_go_customer/lib/shared/services/webrtc_service.dart` (NEW)

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:permission_handler/permission_handler.dart';

enum CallState {
  idle,
  connecting,
  ringing,
  active,
  ended,
  rejected,
  error,
}

class WebRTCService extends ChangeNotifier {
  // WebRTC
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Socket
  IO.Socket? _socket;

  // State
  CallState _callState = CallState.idle;
  String? _currentCallId;
  String? _remoteUserId;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoEnabled = false;

  // Getters
  CallState get callState => _callState;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isVideoEnabled => _isVideoEnabled;
  String? get currentCallId => _currentCallId;

  // STUN/TURN servers configuration
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
     {'urls': 'stun:stun.l.google.com:19302'},
     {
    'urls': 'turn:34.136.2.17:3478',
    'username': 'testuser',
    'credential': 'testpass'
  }
    ],
  };

  final Map<String, dynamic> _mediaConstraints = {
    'audio': true,
    'video': false, // Set to true for video calls
  };

  /// Initialize WebRTC service with Socket.IO
  Future<void> initialize(IO.Socket socket, String userId) async {
    _socket = socket;
    _setupSocketListeners();

    // Register user for WebRTC signaling
    _socket?.emit('webrtc:register', userId);

    debugPrint('WebRTC Service initialized for user: $userId');
  }

  /// Setup Socket.IO listeners for WebRTC signaling
  void _setupSocketListeners() {
    _socket?.on('webrtc:incoming-call', _handleIncomingCall);
    _socket?.on('webrtc:call-ringing', _handleCallRinging);
    _socket?.on('webrtc:call-answered', _handleCallAnswered);
    _socket?.on('webrtc:ice-candidate', _handleIceCandidate);
    _socket?.on('webrtc:call-ended', _handleCallEnded);
    _socket?.on('webrtc:call-rejected', _handleCallRejected);
    _socket?.on('webrtc:error', _handleError);
  }

  /// Request necessary permissions
  Future<bool> requestPermissions({bool video = false}) async {
    final permissions = [Permission.microphone];
    if (video) permissions.add(Permission.camera);

    final statuses = await permissions.request();

    return statuses.values.every((status) => status.isGranted);
  }

  /// Initiate a call
  Future<void> initiateCall({
    required String calleeId,
    required String callerId,
    required String orderId,
    bool isVideo = false,
  }) async {
    try {
      _callState = CallState.connecting;
      _remoteUserId = calleeId;
      _isVideoEnabled = isVideo;
      notifyListeners();

      // Request permissions
      final hasPermission = await requestPermissions(video: isVideo);
      if (!hasPermission) {
        throw Exception('Microphone permission required');
      }

      // Create peer connection
      await _createPeerConnection();

      // Get local media stream
      await _getUserMedia(video: isVideo);

      // Create offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Send offer to callee via signaling server
      _socket?.emit('webrtc:call', {
        'calleeId': calleeId,
        'callerId': callerId,
        'orderId': orderId,
        'offer': offer.toMap(),
        'callType': isVideo ? 'video' : 'audio',
      });

      debugPrint('WebRTC: Call initiated to $calleeId');
    } catch (e) {
      debugPrint('Error initiating call: $e');
      _callState = CallState.error;
      notifyListeners();
      rethrow;
    }
  }

  /// Answer incoming call
  Future<void> answerCall(String callId, Map<String, dynamic> offer) async {
    try {
      _currentCallId = callId;
      _callState = CallState.connecting;
      notifyListeners();

      // Request permissions
      final hasPermission = await requestPermissions(video: _isVideoEnabled);
      if (!hasPermission) {
        throw Exception('Microphone permission required');
      }

      // Create peer connection
      await _createPeerConnection();

      // Get local media stream
      await _getUserMedia(video: _isVideoEnabled);

      // Set remote description (offer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer to caller
      _socket?.emit('webrtc:answer', {
        'callId': callId,
        'answer': answer.toMap(),
      });

      _callState = CallState.active;
      notifyListeners();

      debugPrint('WebRTC: Call answered');
    } catch (e) {
      debugPrint('Error answering call: $e');
      _callState = CallState.error;
      notifyListeners();
      rethrow;
    }
  }

  /// Reject incoming call
  void rejectCall(String callId) {
    _socket?.emit('webrtc:reject', {'callId': callId});
    _callState = CallState.rejected;
    notifyListeners();
    _cleanup();
  }

  /// End active call
  void endCall() {
    if (_currentCallId != null) {
      _socket?.emit('webrtc:end-call', {'callId': _currentCallId});
    }
    _callState = CallState.ended;
    notifyListeners();
    _cleanup();
  }

  /// Toggle mute
  void toggleMute() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      _isMuted = !audioTrack.enabled;
      notifyListeners();
    }
  }

  /// Toggle speaker
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    Helper.setSpeakerphoneOn(_isSpeakerOn);
    notifyListeners();
  }

  /// Toggle video (for video calls)
  void toggleVideo() {
    if (_localStream != null && _isVideoEnabled) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
      notifyListeners();
    }
  }

  /// Create RTCPeerConnection
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _socket?.emit('webrtc:ice-candidate', {
        'callId': _currentCallId,
        'candidate': candidate.toMap(),
        'targetUserId': _remoteUserId,
      });
    };

    // Handle remote stream
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        notifyListeners();
        debugPrint('WebRTC: Remote stream received');
      }
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('WebRTC: Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        endCall();
      }
    };
  }

  /// Get user media (audio/video)
  Future<void> _getUserMedia({bool video = false}) async {
    final constraints = {
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
              'width': 640,
              'height': 480,
            }
          : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);

    // Add tracks to peer connection
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    notifyListeners();
  }

  /// Socket event handlers
  void _handleIncomingCall(dynamic data) {
    final callId = data['callId'];
    final callerId = data['callerId'];
    final orderId = data['orderId'];
    final offer = data['offer'];
    final callType = data['callType'];

    _currentCallId = callId;
    _remoteUserId = callerId;
    _isVideoEnabled = callType == 'video';
    _callState = CallState.ringing;
    notifyListeners();

    debugPrint('WebRTC: Incoming call from $callerId');

    // You can show a dialog or notification here
    // The UI will handle this via listeners
  }

  void _handleCallRinging(dynamic data) {
    _currentCallId = data['callId'];
    _callState = CallState.ringing;
    notifyListeners();
    debugPrint('WebRTC: Call is ringing');
  }

  void _handleCallAnswered(dynamic data) async {
    final answer = data['answer'];

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answer['sdp'], answer['type']),
    );

    _callState = CallState.active;
    notifyListeners();
    debugPrint('WebRTC: Call answered');
  }

  void _handleIceCandidate(dynamic data) async {
    final candidate = data['candidate'];

    await _peerConnection!.addCandidate(
      RTCIceCandidate(
        candidate['candidate'],
        candidate['sdpMid'],
        candidate['sdpMLineIndex'],
      ),
    );
  }

  void _handleCallEnded(dynamic data) {
    _callState = CallState.ended;
    notifyListeners();
    _cleanup();
    debugPrint('WebRTC: Call ended');
  }

  void _handleCallRejected(dynamic data) {
    _callState = CallState.rejected;
    notifyListeners();
    _cleanup();
    debugPrint('WebRTC: Call rejected');
  }

  void _handleError(dynamic data) {
    debugPrint('WebRTC Error: ${data['error']}');
    _callState = CallState.error;
    notifyListeners();
    _cleanup();
  }

  /// Cleanup resources
  void _cleanup() {
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;

    _remoteStream?.getTracks().forEach((track) => track.stop());
    _remoteStream?.dispose();
    _remoteStream = null;

    _peerConnection?.close();
    _peerConnection = null;

    _currentCallId = null;
    _remoteUserId = null;
    _isMuted = false;
    _isSpeakerOn = false;
  }

  @override
  void dispose() {
    _cleanup();
    _socket?.off('webrtc:incoming-call');
    _socket?.off('webrtc:call-ringing');
    _socket?.off('webrtc:call-answered');
    _socket?.off('webrtc:ice-candidate');
    _socket?.off('webrtc:call-ended');
    _socket?.off('webrtc:call-rejected');
    _socket?.off('webrtc:error');
    super.dispose();
  }
}
```

### 2. Create Call Screen UI

**File**: `/packages/grab_go_customer/lib/features/call/view/call_screen.dart` (NEW)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';
import '../../../shared/services/webrtc_service.dart';

class CallScreen extends StatefulWidget {
  final String recipientName;
  final String? recipientAvatar;
  final bool isIncoming;
  final String? callId;
  final Map<String, dynamic>? offer;

  const CallScreen({
    super.key,
    required this.recipientName,
    this.recipientAvatar,
    this.isIncoming = false,
    this.callId,
    this.offer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderers();

    if (widget.isIncoming && widget.callId != null && widget.offer != null) {
      // Auto-answer or show answer UI
      // For now, we'll let the user answer manually
    }
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundSecondary,
      body: Consumer<WebRTCService>(
        builder: (context, webrtcService, child) {
          // Update renderers when streams change
          if (webrtcService.localStream != null) {
            _localRenderer.srcObject = webrtcService.localStream;
          }
          if (webrtcService.remoteStream != null) {
            _remoteRenderer.srcObject = webrtcService.remoteStream;
          }

          return SafeArea(
            child: Stack(
              children: [
                // Background
                _buildBackground(colors, webrtcService),

                // Main content
                Column(
                  children: [
                    // Header
                    _buildHeader(colors, webrtcService),

                    const Spacer(),

                    // Call status
                    _buildCallStatus(colors, webrtcService),

                    const Spacer(),

                    // Controls
                    _buildControls(colors, isDark, webrtcService),

                    SizedBox(height: 40.h),
                  ],
                ),

                // Video preview (for video calls)
                if (webrtcService.isVideoEnabled)
                  _buildVideoPreview(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackground(AppColorsExtension colors, WebRTCService service) {
    if (service.isVideoEnabled && service.remoteStream != null) {
      // Show remote video as background
      return SizedBox.expand(
        child: RTCVideoView(_remoteRenderer, mirror: false),
      );
    }

    // Show gradient background for audio calls
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.accentViolet.withValues(alpha: 0.3),
            colors.backgroundSecondary,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorsExtension colors, WebRTCService service) {
    return Padding(
      padding: EdgeInsets.all(20.r),
      child: Row(
        children: [
          // Recipient avatar
          Container(
            width: 50.w,
            height: 50.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accentViolet.withValues(alpha: 0.2),
              image: widget.recipientAvatar != null
                  ? DecorationImage(
                      image: NetworkImage(widget.recipientAvatar!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.recipientAvatar == null
                ? Icon(
                    Icons.person,
                    color: colors.accentViolet,
                    size: 24.sp,
                  )
                : null,
          ),

          SizedBox(width: 12.w),

          // Recipient name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipientName,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _getCallStateText(service.callState),
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallStatus(AppColorsExtension colors, WebRTCService service) {
    return Column(
      children: [
        // Large avatar (for audio calls)
        if (!service.isVideoEnabled)
          Container(
            width: 120.w,
            height: 120.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.accentViolet.withValues(alpha: 0.2),
              border: Border.all(
                color: colors.accentViolet.withValues(alpha: 0.5),
                width: 3,
              ),
              image: widget.recipientAvatar != null
                  ? DecorationImage(
                      image: NetworkImage(widget.recipientAvatar!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: widget.recipientAvatar == null
                ? Icon(
                    Icons.person,
                    color: colors.accentViolet,
                    size: 60.sp,
                  )
                : null,
          ),

        SizedBox(height: 24.h),

        // Call duration or status
        if (service.callState == CallState.active)
          _CallDurationTimer(colors: colors)
        else
          Text(
            _getCallStateText(service.callState),
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildControls(
    AppColorsExtension colors,
    bool isDark,
    WebRTCService service,
  ) {
    if (widget.isIncoming && service.callState == CallState.ringing) {
      // Show answer/reject buttons for incoming calls
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reject button
          _buildControlButton(
            icon: Icons.call_end,
            color: Colors.red,
            onTap: () {
              service.rejectCall(widget.callId!);
              Navigator.of(context).pop();
            },
          ),

          // Answer button
          _buildControlButton(
            icon: Icons.call,
            color: Colors.green,
            onTap: () async {
              await service.answerCall(widget.callId!, widget.offer!);
            },
          ),
        ],
      );
    }

    // Show call controls for active calls
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute button
        _buildControlButton(
          icon: service.isMuted ? Icons.mic_off : Icons.mic,
          color: service.isMuted ? Colors.red : colors.accentViolet,
          onTap: service.toggleMute,
        ),

        // Speaker button
        _buildControlButton(
          icon: service.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          color: colors.accentViolet,
          onTap: service.toggleSpeaker,
        ),

        // End call button
        _buildControlButton(
          icon: Icons.call_end,
          color: Colors.red,
          size: 70.w,
          iconSize: 32.sp,
          onTap: () {
            service.endCall();
            Navigator.of(context).pop();
          },
        ),

        // Video toggle (if video call)
        if (service.isVideoEnabled)
          _buildControlButton(
            icon: Icons.videocam_off,
            color: colors.accentViolet,
            onTap: service.toggleVideo,
          )
        else
          SizedBox(width: 60.w),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double? size,
    double? iconSize,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size ?? 60.w,
        height: size ?? 60.h,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: iconSize ?? 24.sp,
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Positioned(
      top: 100.h,
      right: 20.w,
      child: Container(
        width: 100.w,
        height: 150.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.r),
          child: RTCVideoView(_localRenderer, mirror: true),
        ),
      ),
    );
  }

  String _getCallStateText(CallState state) {
    switch (state) {
      case CallState.connecting:
        return 'Connecting...';
      case CallState.ringing:
        return widget.isIncoming ? 'Incoming call...' : 'Ringing...';
      case CallState.active:
        return 'Connected';
      case CallState.ended:
        return 'Call ended';
      case CallState.rejected:
        return 'Call rejected';
      case CallState.error:
        return 'Connection error';
      default:
        return '';
    }
  }
}

// Call duration timer widget
class _CallDurationTimer extends StatefulWidget {
  final AppColorsExtension colors;

  const _CallDurationTimer({required this.colors});

  @override
  State<_CallDurationTimer> createState() => _CallDurationTimerState();
}

class _CallDurationTimerState extends State<_CallDurationTimer> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _seconds ~/ 60;
    final seconds = _seconds % 60;

    return Text(
      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
      style: TextStyle(
        fontSize: 24.sp,
        fontWeight: FontWeight.w700,
        color: widget.colors.textPrimary,
      ),
    );
  }
}
```

### 3. Create Call Button Widget

**File**: `/packages/grab_go_customer/lib/shared/widgets/webrtc_call_button.dart` (NEW)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';
import '../services/webrtc_service.dart';
import '../../features/call/view/call_screen.dart';

class WebRTCCallButton extends StatelessWidget {
  final String recipientId;
  final String recipientName;
  final String? recipientAvatar;
  final String orderId;
  final String currentUserId;
  final bool isCompact;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool enableVideo;

  const WebRTCCallButton({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.recipientAvatar,
    required this.orderId,
    required this.currentUserId,
    this.isCompact = false,
    this.backgroundColor,
    this.iconColor,
    this.enableVideo = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: isCompact ? 40.h : 44.h,
      width: isCompact ? 40.w : 44.w,
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.backgroundPrimary,
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.inputBorder.withValues(alpha: 0.3),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleCallTap(context),
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 8.r : 10.r),
            child: Icon(
              enableVideo ? Icons.videocam : Icons.call,
              color: iconColor ?? colors.accentGreen,
              size: isCompact ? 20.sp : 24.sp,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCallTap(BuildContext context) async {
    final webrtcService = context.read<WebRTCService>();

    // Navigate to call screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          recipientName: recipientName,
          recipientAvatar: recipientAvatar,
          isIncoming: false,
        ),
      ),
    );

    // Initiate call
    try {
      await webrtcService.initiateCall(
        calleeId: recipientId,
        callerId: currentUserId,
        orderId: orderId,
        isVideo: enableVideo,
      );
    } catch (e) {
      // Handle error
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initiate call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
```

### 4. Setup Provider and Initialize

**File**: `/packages/grab_go_customer/lib/main.dart` (UPDATE)

```dart
import 'package:provider/provider.dart';
import 'shared/services/webrtc_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        // ... existing providers
        ChangeNotifierProvider(create: (_) => WebRTCService()),
      ],
      child: const MyApp(),
    ),
  );
}
```

**Initialize WebRTC when user logs in**:

```dart
// After successful login and socket connection
final webrtcService = context.read<WebRTCService>();
final socket = SocketService().socket; // Your existing socket
final userId = userService.getUserId();

await webrtcService.initialize(socket, userId);
```

### 5. Listen for Incoming Calls

**File**: Create a global listener or add to your main app state

```dart
class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupIncomingCallListener();
  }

  void _setupIncomingCallListener() {
    final webrtcService = context.read<WebRTCService>();

    webrtcService.addListener(() {
      if (webrtcService.callState == CallState.ringing) {
        // Show incoming call screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CallScreen(
              recipientName: 'Rider', // Get from call data
              isIncoming: true,
              callId: webrtcService.currentCallId,
              offer: {}, // Get from call data
            ),
          ),
        );
      }
    });
  }
}
```

---

## Call Flow

### Outgoing Call Flow

```
1. Customer taps call button
2. CallScreen opens
3. WebRTCService.initiateCall()
4. Request microphone permission
5. Create RTCPeerConnection
6. Get local media stream
7. Create SDP offer
8. Send offer to signaling server via Socket.IO
9. Server forwards offer to rider
10. Rider receives offer → CallScreen shows
11. Rider answers → creates SDP answer
12. Server forwards answer to customer
13. WebRTC P2P connection established
14. Audio/video streams flow directly between peers
```

### Incoming Call Flow

```
1. Server sends 'webrtc:incoming-call' event
2. WebRTCService updates state to 'ringing'
3. App shows CallScreen with answer/reject buttons
4. User taps answer
5. WebRTCService.answerCall()
6. Request permissions
7. Create RTCPeerConnection
8. Get local media stream
9. Set remote description (offer)
10. Create SDP answer
11. Send answer to signaling server
12. Server forwards answer to caller
13. WebRTC P2P connection established
```

---

## Testing

### 1. Local Testing

```bash
# Terminal 1: Start backend
cd backend
npm run dev

# Terminal 2: Run customer app
cd packages/grab_go_customer
flutter run

# Terminal 3: Run rider app (for testing)
cd packages/grab_go_rider
flutter run
```

### 2. Test Checklist

- [ ] Permissions requested correctly
- [ ] Outgoing call initiates
- [ ] Incoming call shows
- [ ] Answer call works
- [ ] Reject call works
- [ ] Audio streams both ways
- [ ] Mute/unmute works
- [ ] Speaker toggle works
- [ ] End call works
- [ ] Call duration shows correctly
- [ ] Video calls work (if enabled)
- [ ] Works on different networks (WiFi, 4G)
- [ ] Works through NAT/firewalls

---

## Production Considerations

### 1. TURN Server (Important!)

For production, you MUST add TURN servers for NAT traversal:

```dart
final Map<String, dynamic> _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {
      'urls': 'turn:your-turn-server.com:3478',
      'username': 'your-username',
      'credential': 'your-password',
    },
  ],
};
```

**TURN Server Options**:

- **Twilio TURN**: $0.0004/GB
- **Xirsys**: Free tier available
- **Self-hosted**: Using coturn (free but requires server)

### 2. Call Quality

- Implement network quality monitoring
- Auto-adjust bitrate based on connection
- Show connection quality indicator

### 3. Security

- Encrypt signaling messages
- Validate user permissions on server
- Implement rate limiting

### 4. Analytics

- Track call duration
- Monitor connection success rate
- Log call quality metrics

### 5. Error Handling

- Handle network disconnections
- Implement reconnection logic
- Show user-friendly error messages

### 6. Battery Optimization

- Release resources when call ends
- Minimize background processing
- Use efficient codecs

---

## Cost Analysis

### Infrastructure Costs

- **STUN Server**: Free (Google STUN)
- **TURN Server**:
  - Twilio: ~$0.0004/GB
  - Xirsys: Free tier (1GB/month)
  - Self-hosted: Server costs only
- **Signaling Server**: Your existing server (no extra cost)

### Estimated Monthly Cost (1000 calls, 3 min avg)

- TURN usage: 1000 calls × 3 min × 2MB/min = 6GB
- Twilio TURN: 6GB × $0.0004 = $2.40/month
- Xirsys: Free (under 1GB) or $10/month

**Total**: $0-10/month depending on volume

---

## Advantages of WebRTC

✅ **Privacy**: No phone numbers exposed  
✅ **Free**: No per-minute charges  
✅ **Quality**: HD audio/video  
✅ **Features**: Mute, speaker, video toggle  
✅ **Control**: Full customization  
✅ **Analytics**: Complete call tracking  
✅ **Scalable**: P2P = no server load

---

## Next Steps

1. ✅ Install `flutter_webrtc` package
2. ✅ Add platform permissions
3. ✅ Implement backend signaling service
4. ✅ Create WebRTCService in Flutter
5. ✅ Build CallScreen UI
6. ✅ Add call buttons to order tracking and chat
7. ✅ Test locally with two devices
8. ✅ Setup TURN server for production
9. ✅ Deploy and monitor

---

## Resources

- [flutter_webrtc Documentation](https://pub.dev/packages/flutter_webrtc)
- [WebRTC Basics](https://webrtc.org/getting-started/overview)
- [Coturn TURN Server](https://github.com/coturn/coturn)
- [Xirsys TURN Service](https://xirsys.com/)
- [Twilio TURN](https://www.twilio.com/docs/stun-turn)

---

## Support

If you encounter issues:

1. Check browser console for WebRTC errors
2. Verify STUN/TURN server connectivity
3. Test on different networks
4. Check firewall settings

Good luck with your implementation! 🚀
