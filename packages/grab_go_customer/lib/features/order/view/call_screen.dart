import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class CallScreen extends StatefulWidget {
  final String otherUserId;
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? orderId;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.otherUserId,
    this.otherUserName,
    this.otherUserAvatar,
    this.orderId,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _durationTimer;
  int _callDuration = 0;
  WebRTCService? _webrtcService;

  @override
  void initState() {
    super.initState();
    _setupCallListener();

    if (widget.isIncoming) {
      // For incoming calls, wait for user to answer
    } else {
      // For outgoing calls, initiate immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initiateCall();
      });
    }
  }

  void _setupCallListener() {
    _webrtcService = context.read<WebRTCService>();
    _webrtcService!.addListener(_onCallStateChanged);
  }

  void _onCallStateChanged() {
    final webrtcService = context.read<WebRTCService>();

    // Start duration timer when call becomes active
    if (webrtcService.callState == CallState.active && _durationTimer == null) {
      _startDurationTimer();
    }

    // End call and close screen when call ends
    if (webrtcService.callState == CallState.ended) {
      _durationTimer?.cancel();
      Navigator.of(context).pop();
    }

    setState(() {});
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _callDuration++;
      });
    });
  }

  Future<void> _initiateCall() async {
    final webrtcService = context.read<WebRTCService>();
    await webrtcService.initiateCall(calleeId: widget.otherUserId, orderId: widget.orderId ?? '');
  }

  Future<void> _answerCall() async {
    final webrtcService = context.read<WebRTCService>();
    await webrtcService.answerCall();
  }

  Future<void> _rejectCall() async {
    final webrtcService = context.read<WebRTCService>();
    await webrtcService.rejectCall();
    Navigator.of(context).pop();
  }

  Future<void> _endCall() async {
    final webrtcService = context.read<WebRTCService>();
    await webrtcService.endCall();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _webrtcService?.removeListener(_onCallStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Consumer<WebRTCService>(
        builder: (context, webrtcService, child) {
          return SafeArea(
            child: Column(
              children: [
                _buildHeader(colors),

                const Spacer(),

                // Call status
                _buildCallStatus(colors, webrtcService),

                const Spacer(),

                // Controls
                _buildControls(colors, isDark, webrtcService),

                SizedBox(height: 40.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppColorsExtension colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.accentViolet.withValues(alpha: 0.8), colors.backgroundPrimary.withValues(alpha: 0)],
        ),
      ),
      padding: EdgeInsets.all(20.w),
      child: Row(
        children: [
          // User avatar
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.cardBackground,
              image: widget.otherUserAvatar != null
                  ? DecorationImage(image: NetworkImage(widget.otherUserAvatar!), fit: BoxFit.cover)
                  : null,
            ),
            child: widget.otherUserAvatar == null ? Icon(Icons.person, size: 30.sp, color: colors.border) : null,
          ),

          SizedBox(width: 12.w),

          // Recipient name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName ?? 'Unknown',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                if (widget.orderId != null)
                  Text(
                    'Order #${widget.orderId}',
                    style: TextStyle(fontSize: 12.sp, color: colors.border),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallStatus(AppColorsExtension colors, WebRTCService service) {
    String statusText;
    IconData statusIcon;

    switch (service.callState) {
      case CallState.idle:
        statusText = 'Initializing...';
        statusIcon = Icons.phone_in_talk;
        break;
      case CallState.ringing:
        statusText = widget.isIncoming ? 'Incoming call...' : 'Ringing...';
        statusIcon = Icons.phone_callback;
        break;
      case CallState.connecting:
        statusText = 'Connecting...';
        statusIcon = Icons.sync;
        break;
      case CallState.active:
        statusText = _formatDuration(_callDuration);
        statusIcon = Icons.phone_in_talk;
        break;
      case CallState.ended:
        statusText = 'Call ended';
        statusIcon = Icons.call_end;
        break;
    }

    return Column(
      children: [
        // Status icon
        Container(
          width: 80.w,
          height: 80.w,
          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange.withValues(alpha: 0.2)),
          child: Icon(statusIcon, size: 40.sp, color: colors.accentOrange),
        ),

        SizedBox(height: 24.h),

        // Call duration or status
        Text(
          statusText,
          style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildControls(AppColorsExtension colors, bool isDark, WebRTCService service) {
    if (widget.isIncoming && service.callState == CallState.ringing) {
      // Incoming call controls
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Reject button
          _buildControlButton(icon: Icons.call_end, label: 'Reject', color: Colors.red, onTap: _rejectCall),

          // Answer button
          _buildControlButton(icon: Icons.call, label: 'Answer', color: Colors.green, onTap: _answerCall),
        ],
      );
    }

    // Active call controls
    return Wrap(
      spacing: 20.w,
      runSpacing: 20.h,
      alignment: WrapAlignment.center,
      children: [
        // Mute button
        _buildControlButton(
          icon: service.isMuted ? Icons.mic_off : Icons.mic,
          label: service.isMuted ? 'Unmute' : 'Mute',
          color: service.isMuted ? Colors.red : colors.accentViolet,
          onTap: service.toggleMute,
        ),

        // Speaker button
        _buildControlButton(
          icon: service.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
          label: service.isSpeakerOn ? 'Speaker' : 'Earpiece',
          onTap: service.toggleSpeaker,
        ),

        // End call button
        _buildControlButton(
          icon: Icons.call_end,
          label: 'End',
          color: Colors.red,
          onTap: () async {
            await _endCall();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? colors.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: (color ?? colors.cardBackground).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 28.sp, color: color != null ? Colors.white : colors.textPrimary),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: colors.border),
          ),
        ],
      ),
    );
  }
}
