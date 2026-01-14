import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:grab_go_shared/shared/services/user_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum CallState { idle, ringing, connecting, active, ended }

class WebRTCService extends ChangeNotifier {
  // Singleton pattern
  WebRTCService._();
  static final WebRTCService _instance = WebRTCService._();
  factory WebRTCService() => _instance;

  // WebRTC components
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Socket
  IO.Socket? _socket;

  // State
  CallState _callState = CallState.idle;
  String? _currentCallId;
  String? _otherUserId;
  String? _orderId;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isIncoming = false;
  Map<String, dynamic>? _incomingOffer;

  // Getters
  CallState get callState => _callState;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  String? get currentCallId => _currentCallId;
  String? get otherUserId => _otherUserId;
  String? get orderId => _orderId;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isIncoming => _isIncoming;

  // STUN/TURN servers configuration
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'turn:34.136.2.17:3478', 'username': 'testuser', 'credential': 'testpass'},
    ],
  };

  // Peer connection configuration
  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  /// Initialize WebRTC service with socket
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
    _socket?.on('webrtc:call-timeout', _handleCallTimeout);
    _socket?.on('webrtc:error', _handleError);
  }

  /// Request permissions for microphone
  Future<bool> requestPermissions() async {
    try {
      final Map<String, dynamic> mediaConstraints = {'audio': true, 'video': false};

      final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      await stream.dispose();
      return true;
    } catch (e) {
      debugPrint('Permission denied: $e');
      return false;
    }
  }

  /// Initiate an audio call
  Future<void> initiateCall({required String calleeId, required String orderId}) async {
    if (_callState != CallState.idle) {
      debugPrint('Cannot initiate call: already in a call');
      return;
    }

    try {
      _callState = CallState.connecting;
      _otherUserId = calleeId;
      _orderId = orderId;
      _isIncoming = false;
      notifyListeners();

      // Get user media (audio only)
      final Map<String, dynamic> mediaConstraints = {'audio': true, 'video': false};

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      // Create peer connection
      await _createPeerConnection();

      // Add local stream to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Create offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Send offer to server
      _socket?.emit('webrtc:call', {
        'calleeId': calleeId,
        'callerId': UserService().currentUser?.id,
        'orderId': orderId,
        'offer': offer.toMap(),
        'callType': 'audio',
      });

      debugPrint('Call initiated to $calleeId');
    } catch (e) {
      debugPrint('Error initiating call: $e');
      await endCall();
    }
  }

  /// Answer an incoming call
  Future<void> answerCall() async {
    if (_callState != CallState.ringing || !_isIncoming || _incomingOffer == null) {
      debugPrint('Cannot answer: no incoming call');
      return;
    }

    try {
      _callState = CallState.connecting;
      notifyListeners();

      // Get user media (audio only)
      final Map<String, dynamic> mediaConstraints = {'audio': true, 'video': false};

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      // Create peer connection
      await _createPeerConnection();

      // Add local stream to peer connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Set remote description (offer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(_incomingOffer!['sdp'], _incomingOffer!['type']),
      );

      // Create answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer to server
      _socket?.emit('webrtc:answer', {'callId': _currentCallId, 'answer': answer.toMap()});

      debugPrint('Call answered');
    } catch (e) {
      debugPrint('Error answering call: $e');
      await endCall();
    }
  }

  /// Reject an incoming call
  Future<void> rejectCall() async {
    if (_currentCallId == null) return;

    _socket?.emit('webrtc:reject', {'callId': _currentCallId});

    await _cleanup();
    debugPrint('Call rejected');
  }

  /// End the current call
  Future<void> endCall() async {
    if (_currentCallId != null) {
      _socket?.emit('webrtc:end-call', {'callId': _currentCallId});
    }

    await _cleanup();
    debugPrint('Call ended');
  }

  /// Toggle mute
  void toggleMute() {
    if (_localStream == null) return;

    _isMuted = !_isMuted;
    _localStream!.getAudioTracks().forEach((track) {
      track.enabled = !_isMuted;
    });

    notifyListeners();
    debugPrint('Mute toggled: $_isMuted');
  }

  /// Toggle speaker
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    Helper.setSpeakerphoneOn(_isSpeakerOn);
    notifyListeners();
    debugPrint('Speaker toggled: $_isSpeakerOn');
  }

  /// Create peer connection
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers, _config);

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (candidate) {
      _socket?.emit('webrtc:ice-candidate', {
        'callId': _currentCallId,
        'candidate': candidate.toMap(),
        'targetUserId': _otherUserId,
      });
    };

    // Handle remote stream
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        notifyListeners();
        debugPrint('Remote stream received');
      }
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (state) {
      debugPrint('Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _callState = CallState.active;
        notifyListeners();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        endCall();
      }
    };
  }

  /// Handle incoming call
  void _handleIncomingCall(dynamic data) {
    final callId = data['callId'];
    final callerId = data['callerId'];
    final orderId = data['orderId'];
    final offer = data['offer'];

    _currentCallId = callId;
    _otherUserId = callerId;
    _orderId = orderId;
    _incomingOffer = offer;
    _isIncoming = true;
    _callState = CallState.ringing;
    notifyListeners();

    debugPrint('WebRTC: Incoming call from $callerId');
  }

  /// Handle call ringing
  void _handleCallRinging(dynamic data) {
    _callState = CallState.ringing;
    notifyListeners();
    debugPrint('WebRTC: Call is ringing');
  }

  /// Handle call answered
  void _handleCallAnswered(dynamic data) async {
    final answer = data['answer'];

    if (_peerConnection == null) {
      debugPrint('WebRTC: Cannot set remote description - peer connection is null');
      return;
    }

    await _peerConnection!.setRemoteDescription(RTCSessionDescription(answer['sdp'], answer['type']));

    debugPrint('WebRTC: Call answered');
  }

  /// Handle ICE candidate
  void _handleIceCandidate(dynamic data) async {
    final candidate = data['candidate'];

    if (_peerConnection == null) {
      debugPrint('WebRTC: Cannot add ICE candidate - peer connection is null');
      return;
    }

    await _peerConnection!.addCandidate(
      RTCIceCandidate(candidate['candidate'], candidate['sdpMid'], candidate['sdpMLineIndex']),
    );

    debugPrint('WebRTC: ICE candidate added');
  }

  /// Handle call ended
  void _handleCallEnded(dynamic data) {
    debugPrint('WebRTC: Call ended by other party');
    _cleanup();
  }

  /// Handle call rejected
  void _handleCallRejected(dynamic data) {
    debugPrint('WebRTC: Call rejected');
    _cleanup();
  }

  /// Handle call timeout
  void _handleCallTimeout(dynamic data) {
    debugPrint('WebRTC: Call timeout (no answer)');
    _cleanup();
  }

  /// Handle error
  void _handleError(dynamic data) {
    debugPrint('WebRTC Error: ${data['error']}');
    _cleanup();
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    _callState = CallState.ended;
    notifyListeners();

    // Wait a bit before full cleanup to allow UI to update
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await _localStream?.dispose();
      await _remoteStream?.dispose();
      await _peerConnection?.close();
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }

    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _currentCallId = null;
    _otherUserId = null;
    _orderId = null;
    _isMuted = false;
    _isSpeakerOn = false;
    _isIncoming = false;
    _incomingOffer = null;
    _callState = CallState.idle;

    notifyListeners();
  }

  /// Dispose
  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
