import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/features/meeting/models/meeting_model.dart';
import 'package:transmeet/features/meeting/services/webrtc_service.dart';
import 'package:transmeet/features/meeting/widgets/webrtc_video_view.dart';

class MeetingRoomScreen extends StatefulWidget {
  const MeetingRoomScreen({
    super.key,
    required this.meeting,
  });

  final MeetingModel meeting;

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen> {
  final _webRTCService = WebRTCService();
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isInitializing = true;
  String _statusMessage = 'Connecting...';

  @override
  void initState() {
    super.initState();
    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    try {
      // Request permissions
      final status = await [Permission.camera, Permission.microphone].request();
      if (status[Permission.camera] != PermissionStatus.granted ||
          status[Permission.microphone] != PermissionStatus.granted) {
        throw 'Camera and microphone permissions are required.';
      }

      await _webRTCService.initLocalStream();
      setState(() {});

      final user = FirebaseAuth.instance.currentUser;
      final isHost = user?.uid == widget.meeting.hostUid;

      if (isHost) {
        await _webRTCService.createOffer(widget.meeting.docId);
      } else {
        await _webRTCService.createAnswer(widget.meeting.docId);
      }

      setState(() => _isInitializing = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = 'Connection failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize WebRTC: $e')),
        );
      }
    }
  }

  void _toggleMic() {
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
    _webRTCService.toggleMicrophone(!_isMicMuted);
  }

  void _toggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    _webRTCService.toggleCamera(!_isCameraOff);
  }

  void _switchCamera() {
    _webRTCService.switchCamera();
  }

  Future<void> _leaveMeeting(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(AppConstants.leaveConfirmTitle),
        content: const Text(AppConstants.leaveConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppConstants.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text(AppConstants.leaveMeeting),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Pop back to the Home screen.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _webRTCService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveMeeting(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black, // Dark background for video room
        appBar: AppBar(
          backgroundColor: Colors.black54,
          elevation: 0,
          title: Text(widget.meeting.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _leaveMeeting(context),
          ),
          actions: [
            StreamBuilder<RTCPeerConnectionState>(
              stream: _webRTCService.onConnectionState,
              builder: (context, snapshot) {
                final state = snapshot.data;
                Color statusColor = Colors.grey;
                String statusText = 'Connecting';

                if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
                  statusColor = Colors.green;
                  statusText = 'Connected';
                } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                    state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
                  statusColor = Colors.red;
                  statusText = 'Disconnected';
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(statusText, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // Remote Video (Full Screen)
              Positioned.fill(
                child: StreamBuilder<MediaStream>(
                  stream: _webRTCService.onRemoteStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return WebRTCVideoView(
                        stream: snapshot.data,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      );
                    }
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _isInitializing ? _statusMessage : 'Waiting for others to join...',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Local Video (Floating Preview)
              if (_webRTCService.localStream != null && !_isCameraOff)
                Positioned(
                  right: 16,
                  bottom: 100, // Above controls
                  width: 100,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: WebRTCVideoView(
                        stream: _webRTCService.localStream,
                        mirror: true,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              // Bottom Controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 20,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildControlButton(
                          icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          color: _isMicMuted ? theme.colorScheme.error : Colors.white,
                          backgroundColor: _isMicMuted ? theme.colorScheme.error.withValues(alpha: 0.2) : Colors.white24,
                          onPressed: _toggleMic,
                        ),
                        const SizedBox(width: 16),
                        _buildControlButton(
                          icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                          color: _isCameraOff ? theme.colorScheme.error : Colors.white,
                          backgroundColor: _isCameraOff ? theme.colorScheme.error.withValues(alpha: 0.2) : Colors.white24,
                          onPressed: _toggleCamera,
                        ),
                        const SizedBox(width: 16),
                        _buildControlButton(
                          icon: Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                          onPressed: _switchCamera,
                        ),
                        const SizedBox(width: 24),
                        _buildControlButton(
                          icon: Icons.call_end_rounded,
                          color: Colors.white,
                          backgroundColor: theme.colorScheme.error,
                          onPressed: () => _leaveMeeting(context),
                          isLarge: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
    bool isLarge = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          padding: EdgeInsets.all(isLarge ? 16 : 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: isLarge ? 28 : 24,
          ),
        ),
      ),
    );
  }
}
