import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../utils/config.dart';
import 'secure_storage_service.dart';
import 'turn_credentials_service.dart';

enum CallState { idle, ringing, connecting, active, ended }

class WebRTCService extends ChangeNotifier {
  WebRTCService._();
  static final WebRTCService _instance = WebRTCService._();
  factory WebRTCService() => _instance;

  static const String _voiceCallType = 'audio';

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  io.Socket? _socket;
  String? _userId;

  CallState _callState = CallState.idle;
  String? _currentCallId;
  String? _otherUserId;
  String? _orderId;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isIncoming = false;
  Map<String, dynamic>? _incomingOffer;

  Map<String, dynamic> _peerConnectionIceConfig = {
    'iceServers': const [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  final Map<String, dynamic> _peerConnectionConfig = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final _httpClient = http.Client();

  // Reusable listener references so we can cleanly unbind.
  late final void Function(dynamic) _incomingCallListener = _handleIncomingCall;
  late final void Function(dynamic) _callRingingListener = _handleCallRinging;
  late final void Function(dynamic) _callAnsweredListener = _handleCallAnswered;
  late final void Function(dynamic) _iceCandidateListener = _handleIceCandidate;
  late final void Function(dynamic) _callEndedListener = _handleCallEnded;
  late final void Function(dynamic) _callRejectedListener = _handleCallRejected;
  late final void Function(dynamic) _callTimeoutListener = _handleCallTimeout;
  late final void Function(dynamic) _errorListener = _handleError;
  late final void Function(dynamic) _socketConnectedListener =
      _handleSocketConnected;
  late final void Function(dynamic) _socketDisconnectedListener =
      _handleSocketDisconnected;

  CallState get callState => _callState;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  String? get currentCallId => _currentCallId;
  String? get otherUserId => _otherUserId;
  String? get orderId => _orderId;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isIncoming => _isIncoming;
  bool get hasPendingIncomingCall =>
      _isIncoming && _callState == CallState.ringing && _currentCallId != null;

  Future<void> initialize(io.Socket socket, String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return;

    final previousSocket = _socket;
    if (previousSocket != null && !identical(previousSocket, socket)) {
      _unbindSocketListeners(previousSocket);
    }

    _socket = socket;
    _userId = normalizedUserId;

    if (previousSocket == null || !identical(previousSocket, socket)) {
      _bindSocketListeners(socket);
    }

    await _refreshIceServers();
    _registerForSignaling();

    debugPrint('WebRTC service initialized for user: $normalizedUserId');
  }

  Future<void> _refreshIceServers({bool forceRefresh = false}) async {
    final credentials = await TurnCredentialsService.fetchTurnCredentials(
      forceRefresh: forceRefresh,
    );
    final dynamic iceServers = credentials['iceServers'];

    if (iceServers is List && iceServers.isNotEmpty) {
      _peerConnectionIceConfig = {'iceServers': iceServers};
      return;
    }

    _peerConnectionIceConfig = {
      'iceServers': const [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    };
  }

  void _bindSocketListeners(io.Socket socket) {
    socket.on('webrtc:incoming-call', _incomingCallListener);
    socket.on('webrtc:call-ringing', _callRingingListener);
    socket.on('webrtc:call-answered', _callAnsweredListener);
    socket.on('webrtc:ice-candidate', _iceCandidateListener);
    socket.on('webrtc:call-ended', _callEndedListener);
    socket.on('webrtc:call-rejected', _callRejectedListener);
    socket.on('webrtc:call-timeout', _callTimeoutListener);
    socket.on('webrtc:error', _errorListener);

    // Re-register after reconnects.
    socket.on('connect', _socketConnectedListener);
    socket.on('disconnect', _socketDisconnectedListener);
  }

  void _unbindSocketListeners(io.Socket socket) {
    socket.off('webrtc:incoming-call', _incomingCallListener);
    socket.off('webrtc:call-ringing', _callRingingListener);
    socket.off('webrtc:call-answered', _callAnsweredListener);
    socket.off('webrtc:ice-candidate', _iceCandidateListener);
    socket.off('webrtc:call-ended', _callEndedListener);
    socket.off('webrtc:call-rejected', _callRejectedListener);
    socket.off('webrtc:call-timeout', _callTimeoutListener);
    socket.off('webrtc:error', _errorListener);

    socket.off('connect', _socketConnectedListener);
    socket.off('disconnect', _socketDisconnectedListener);
  }

  void _handleSocketConnected(dynamic _) {
    _registerForSignaling();
  }

  void _handleSocketDisconnected(dynamic _) {
    debugPrint('WebRTC signaling socket disconnected');
  }

  void _registerForSignaling() {
    final socket = _socket;
    final userId = _userId;
    if (socket == null || userId == null || userId.isEmpty) return;

    if (socket.connected) {
      socket.emit('webrtc:register', userId);
    }
  }

  Future<bool> requestPermissions() async {
    try {
      const Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': false,
      };

      final stream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      await stream.dispose();
      return true;
    } catch (error) {
      debugPrint('Permission denied: $error');
      return false;
    }
  }

  Future<void> initiateCall({
    required String calleeId,
    required String orderId,
  }) async {
    if (_callState != CallState.idle) {
      debugPrint('Cannot initiate call: already in a call');
      return;
    }

    if (_socket?.connected != true) {
      debugPrint('Cannot initiate call: signaling socket is disconnected');
      return;
    }

    final normalizedCalleeId = calleeId.trim();
    final normalizedOrderId = orderId.trim();

    if (normalizedCalleeId.isEmpty || normalizedOrderId.isEmpty) {
      debugPrint('Cannot initiate call: missing calleeId/orderId');
      return;
    }

    try {
      _callState = CallState.connecting;
      _otherUserId = normalizedCalleeId;
      _orderId = normalizedOrderId;
      _isIncoming = false;
      notifyListeners();

      const Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': false,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );

      await _createPeerConnection();

      for (final track in _localStream!.getTracks()) {
        _peerConnection!.addTrack(track, _localStream!);
      }

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await _peerConnection!.setLocalDescription(offer);

      _socket?.emit('webrtc:call', {
        'calleeId': normalizedCalleeId,
        'callerId': _userId,
        'orderId': normalizedOrderId,
        'offer': offer.toMap(),
        'callType': _voiceCallType,
      });

      debugPrint('Voice call initiated to $normalizedCalleeId');
    } catch (error) {
      debugPrint('Error initiating call: $error');
      await endCall();
    }
  }

  Future<void> answerCall() async {
    if (_callState != CallState.ringing ||
        !_isIncoming ||
        _incomingOffer == null) {
      debugPrint('Cannot answer: no incoming call');
      return;
    }

    if (_socket?.connected != true) {
      debugPrint('Cannot answer call: signaling socket is disconnected');
      return;
    }

    try {
      _callState = CallState.connecting;
      notifyListeners();

      const Map<String, dynamic> mediaConstraints = {
        'audio': true,
        'video': false,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );

      await _createPeerConnection();

      for (final track in _localStream!.getTracks()) {
        _peerConnection!.addTrack(track, _localStream!);
      }

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(_incomingOffer!['sdp'], _incomingOffer!['type']),
      );

      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': false,
      });
      await _peerConnection!.setLocalDescription(answer);

      _socket?.emit('webrtc:answer', {
        'callId': _currentCallId,
        'answer': answer.toMap(),
      });

      debugPrint('Voice call answered');
    } catch (error) {
      debugPrint('Error answering call: $error');
      await endCall();
    }
  }

  Future<void> rejectCall() async {
    if (_currentCallId == null) return;

    _socket?.emit('webrtc:reject', {'callId': _currentCallId});
    await _cleanup();
  }

  Future<void> endCall() async {
    if (_currentCallId != null) {
      _socket?.emit('webrtc:end-call', {'callId': _currentCallId});
    }

    await _cleanup();
  }

  void toggleMute() {
    if (_localStream == null) return;

    _isMuted = !_isMuted;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !_isMuted;
    }

    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    Helper.setSpeakerphoneOn(_isSpeakerOn);
    notifyListeners();
  }

  Future<void> _createPeerConnection() async {
    await _refreshIceServers();
    _peerConnection = await createPeerConnection(
      _peerConnectionIceConfig,
      _peerConnectionConfig,
    );

    _peerConnection!.onIceCandidate = (candidate) {
      if (_currentCallId == null || _otherUserId == null) {
        return;
      }

      _socket?.emit('webrtc:ice-candidate', {
        'callId': _currentCallId,
        'candidate': candidate.toMap(),
      });
    };

    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        notifyListeners();
      }
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _callState = CallState.active;
        notifyListeners();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        endCall();
      }
    };
  }

  bool _isValidSessionDescriptionMap(dynamic payload) {
    if (payload is! Map) return false;
    final sdp = payload['sdp'];
    final type = payload['type'];
    if (sdp is! String || sdp.trim().isEmpty) return false;
    if (type is! String || type.trim().isEmpty) return false;
    return true;
  }

  /// Rebuild pending incoming call state from a push-notification call ID.
  Future<bool> hydrateIncomingCallFromCallId(String callId) async {
    final normalizedCallId = callId.trim();
    if (normalizedCallId.isEmpty) {
      return false;
    }

    final token = await SecureStorageService.getAuthToken();
    final baseUrl = AppConfig.apiBaseUrl;

    if (token == null || token.isEmpty || baseUrl.isEmpty) {
      return false;
    }

    try {
      final normalizedBaseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final response = await _httpClient.get(
        Uri.parse('$normalizedBaseUrl/api/calls/$normalizedCallId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        return false;
      }

      final body = json.decode(response.body);
      if (body is! Map<String, dynamic>) {
        return false;
      }

      final callType = (body['callType'] ?? '').toString().toLowerCase();
      if (callType != _voiceCallType) {
        return false;
      }

      final offer = body['offer'];
      if (!_isValidSessionDescriptionMap(offer)) {
        return false;
      }

      _currentCallId = (body['callId'] ?? normalizedCallId).toString();
      _otherUserId = (body['callerId'] ?? '').toString();
      _orderId = (body['orderId'] ?? '').toString();
      _incomingOffer = Map<String, dynamic>.from(offer as Map);
      _isIncoming = true;
      _callState = CallState.ringing;
      notifyListeners();

      return true;
    } catch (error) {
      debugPrint('Failed to hydrate incoming call from callId: $error');
      return false;
    }
  }

  void _handleIncomingCall(dynamic data) {
    if (data is! Map) {
      return;
    }

    final callType = (data['callType'] ?? '').toString().toLowerCase();
    final callId = (data['callId'] ?? '').toString();
    final callerId = (data['callerId'] ?? '').toString();
    final orderId = (data['orderId'] ?? '').toString();
    final offer = data['offer'];

    if (callType != _voiceCallType) {
      if (callId.isNotEmpty) {
        _socket?.emit('webrtc:reject', {'callId': callId});
      }
      return;
    }

    if (callId.isEmpty ||
        callerId.isEmpty ||
        !_isValidSessionDescriptionMap(offer)) {
      debugPrint('Ignoring malformed incoming call payload');
      return;
    }

    _currentCallId = callId;
    _otherUserId = callerId;
    _orderId = orderId;
    _incomingOffer = Map<String, dynamic>.from(offer as Map);
    _isIncoming = true;
    _callState = CallState.ringing;
    notifyListeners();
  }

  void _handleCallRinging(dynamic _) {
    _callState = CallState.ringing;
    notifyListeners();
  }

  Future<void> _handleCallAnswered(dynamic data) async {
    if (data is! Map) {
      return;
    }

    final answer = data['answer'];
    if (_peerConnection == null || !_isValidSessionDescriptionMap(answer)) {
      return;
    }

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(answer['sdp'] as String, answer['type'] as String),
    );

    final connectionState = await _peerConnection!.getConnectionState();
    if (connectionState ==
        RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _callState = CallState.active;
      notifyListeners();
    }
  }

  Future<void> _handleIceCandidate(dynamic data) async {
    if (data is! Map) {
      return;
    }

    final candidate = data['candidate'];
    if (_peerConnection == null || candidate is! Map) {
      return;
    }

    final rawCandidate = candidate['candidate'];
    if (rawCandidate is! String || rawCandidate.trim().isEmpty) {
      return;
    }

    await _peerConnection!.addCandidate(
      RTCIceCandidate(
        rawCandidate,
        candidate['sdpMid']?.toString(),
        candidate['sdpMLineIndex'] is int
            ? candidate['sdpMLineIndex'] as int
            : null,
      ),
    );
  }

  void _handleCallEnded(dynamic _) {
    _cleanup();
  }

  void _handleCallRejected(dynamic _) {
    _cleanup();
  }

  void _handleCallTimeout(dynamic _) {
    _cleanup();
  }

  void _handleError(dynamic data) {
    final message = data is Map ? data['error'] : null;
    debugPrint('WebRTC signaling error: $message');
    _cleanup();
  }

  Future<void> _cleanup() async {
    _callState = CallState.ended;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await _localStream?.dispose();
      await _remoteStream?.dispose();
      await _peerConnection?.close();
    } catch (error) {
      debugPrint('Error during call cleanup: $error');
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

  @override
  void dispose() {
    final socket = _socket;
    if (socket != null) {
      _unbindSocketListeners(socket);
    }

    _httpClient.close();
    _cleanup();
    super.dispose();
  }
}
