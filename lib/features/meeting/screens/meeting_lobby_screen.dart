import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:transmeet/features/meeting/models/meeting_model.dart';
import 'package:transmeet/features/meeting/screens/meeting_room_screen.dart';
import 'package:transmeet/features/meeting/services/participant_service.dart';

/// Pre-join lobby screen with camera/mic preview and admission waiting.
///
/// Shown before entering the meeting room. Allows the user to preview
/// their camera feed and toggle mic/camera before joining.
/// If admission control is enabled, the participant waits for host approval.
class MeetingLobbyScreen extends StatefulWidget {
  const MeetingLobbyScreen({super.key, required this.meeting});
  final MeetingModel meeting;

  @override
  State<MeetingLobbyScreen> createState() => _MeetingLobbyScreenState();
}

class _MeetingLobbyScreenState extends State<MeetingLobbyScreen> {
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isLoading = true;
  bool _hasPermissions = false;
  String _errorMessage = '';

  // Admission control state
  bool _isWaitingForAdmission = false;
  bool _wasDenied = false;

  final _participantService = ParticipantService();
  StreamSubscription<String?>? _admissionSubscription;

  MediaStream? _localStream;
  final RTCVideoRenderer _renderer = RTCVideoRenderer();

  bool get _isHost =>
      FirebaseAuth.instance.currentUser?.uid == widget.meeting.hostUid;

  @override
  void initState() {
    super.initState();
    _initPreview();
  }

  @override
  void dispose() {
    _admissionSubscription?.cancel();
    _localStream?.dispose();
    _renderer.dispose();
    super.dispose();
  }

  Future<void> _initPreview() async {
    try {
      await _renderer.initialize();

      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasPermissions = false;
            _errorMessage = 'Camera and microphone permissions are required.';
          });
        }
        return;
      }

      final stream = await navigator.mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
        'audio': true,
      });

      if (!mounted) {
        stream.dispose();
        return;
      }

      _renderer.srcObject = stream;

      setState(() {
        _localStream = stream;
        _isLoading = false;
        _hasPermissions = true;
      });
    } catch (e) {
      debugPrint('[Lobby] Preview init error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to access camera: $e';
        });
      }
    }
  }

  void _toggleMic() {
    setState(() => _isMicOn = !_isMicOn);
    if (_localStream != null) {
      for (final track in _localStream!.getAudioTracks()) {
        track.enabled = _isMicOn;
      }
    }
  }

  void _toggleCamera() {
    setState(() => _isCameraOn = !_isCameraOn);
    if (_localStream != null) {
      for (final track in _localStream!.getVideoTracks()) {
        track.enabled = _isCameraOn;
      }
    }
  }

  void _joinMeeting() {
    final needsAdmission = widget.meeting.admissionControl && !_isHost;

    if (needsAdmission) {
      _requestAdmission();
    } else {
      _enterMeetingRoom();
    }
  }

  /// Registers as 'waiting' and listens for host admission.
  Future<void> _requestAdmission() async {
    setState(() => _isWaitingForAdmission = true);

    try {
      // Read preferred language
      String preferredLanguage = widget.meeting.preferredLanguage;
      try {
        preferredLanguage =
            await _participantService.getUserPreferredLanguage(
          defaultLanguage: widget.meeting.preferredLanguage,
        );
      } catch (_) {}

      await _participantService.joinMeeting(
        meetingId: widget.meeting.docId,
        isHost: false,
        preferredLanguage: preferredLanguage,
        initialStatus: 'waiting',
      );

      // Listen for status changes
      _admissionSubscription = _participantService
          .onMyStatusChanged(widget.meeting.docId)
          .listen((status) {
        if (!mounted) return;
        debugPrint('[Lobby] My status changed: $status');

        if (status == 'joined') {
          _admissionSubscription?.cancel();
          _enterMeetingRoom();
        } else if (status == 'denied' || status == null) {
          _admissionSubscription?.cancel();
          setState(() {
            _isWaitingForAdmission = false;
            _wasDenied = true;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isWaitingForAdmission = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text('Failed to join: $e')));
      }
    }
  }

  void _enterMeetingRoom() {
    // Capture lobby state before disposing preview
    final cameraOff = !_isCameraOn;
    final micMuted = !_isMicOn;

    // Dispose preview stream — the meeting room will create its own.
    _localStream?.dispose();
    _localStream = null;
    _renderer.srcObject = null;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MeetingRoomScreen(
          meeting: widget.meeting,
          initialCameraOff: cameraOff,
          initialMicMuted: micMuted,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'You';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isWaitingForAdmission ? 'Waiting to be admitted' : 'Ready to join?',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            // If waiting, clean up the participant entry
            if (_isWaitingForAdmission) {
              _participantService.leaveMeeting(widget.meeting.docId);
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Camera preview ──────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _buildPreview(displayName),
                  ),
                ),
              ),
            ),

            // ── Meeting info ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    widget.meeting.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.meeting.meetingId,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 14,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                  ),
                  // Admission badge
                  if (widget.meeting.admissionControl && !_isHost) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded,
                              size: 13, color: Colors.amber),
                          const SizedBox(width: 5),
                          Text(
                            'Host must approve',
                            style: TextStyle(
                              color: Colors.amber[200],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Waiting / Denied state ──────────────────────────────────────
            if (_wasDenied) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.block_rounded, color: Colors.redAccent, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The host denied your request to join.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Go Back',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ] else if (_isWaitingForAdmission) ...[
              // Waiting animation
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.amber),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Asking to be let in...',
                            style: TextStyle(
                              color: Colors.amber[200],
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'The host will see your request',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ] else ...[
              // ── Media toggles ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MediaToggle(
                    icon:
                        _isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    label: _isMicOn ? 'Mic on' : 'Mic off',
                    isOn: _isMicOn,
                    onTap: _hasPermissions ? _toggleMic : null,
                  ),
                  const SizedBox(width: 24),
                  _MediaToggle(
                    icon: _isCameraOn
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    label: _isCameraOn ? 'Camera on' : 'Camera off',
                    isOn: _isCameraOn,
                    onTap: _hasPermissions ? _toggleCamera : null,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Join button ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _joinMeeting,
                    icon: Icon(widget.meeting.admissionControl && !_isHost
                        ? Icons.front_hand_rounded
                        : Icons.videocam_rounded),
                    label: Text(
                      widget.meeting.admissionControl && !_isHost
                          ? 'Ask to Join'
                          : 'Join Now',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(String displayName) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Text('Starting camera...',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded,
                  color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isCameraOn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[700],
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(displayName,
                style: const TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Camera is off',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return RTCVideoView(
      _renderer,
      mirror: true,
      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    );
  }
}

// ---------------------------------------------------------------------------
// Private media toggle widget
// ---------------------------------------------------------------------------

class _MediaToggle extends StatelessWidget {
  const _MediaToggle({
    required this.icon,
    required this.label,
    required this.isOn,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isOn;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isOn
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.redAccent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isOn ? Colors.white24 : Colors.redAccent,
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                color: isOn ? Colors.white : Colors.redAccent,
                size: 26,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isOn ? Colors.white60 : Colors.redAccent,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
