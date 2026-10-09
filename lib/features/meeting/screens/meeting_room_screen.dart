import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/features/chat/widgets/chat_panel.dart';
import 'package:transmeet/features/meeting/models/meeting_model.dart';
import 'package:transmeet/features/meeting/models/participant_model.dart';
import 'package:transmeet/features/meeting/services/meeting_service.dart';
import 'package:transmeet/features/meeting/services/participant_service.dart';
import 'package:transmeet/features/meeting/services/webrtc_service.dart';
import 'package:transmeet/core/services/foreground_service_helper.dart';
import 'package:transmeet/features/meeting/widgets/admission_banner.dart';
import 'package:transmeet/features/meeting/widgets/live_transcription_panel.dart';
import 'package:transmeet/features/meeting/widgets/participant_panel.dart';
import 'package:transmeet/features/meeting/widgets/webrtc_video_view.dart';
import 'package:transmeet/features/translation/services/audio_capture_service.dart';
import 'package:transmeet/features/translation/widgets/translation_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Connection phase enum — explicit state machine.
// ─────────────────────────────────────────────────────────────────────────────
enum _Phase {
  initializing,
  waitingForPeer,
  connecting,
  connected,
  failed,
  ended,
}

class MeetingRoomScreen extends StatefulWidget {
  const MeetingRoomScreen({
    super.key,
    required this.meeting,
    this.initialCameraOff = false,
    this.initialMicMuted = false,
  });
  final MeetingModel meeting;
  final bool initialCameraOff;
  final bool initialMicMuted;

  @override
  State<MeetingRoomScreen> createState() => _MeetingRoomScreenState();
}

class _MeetingRoomScreenState extends State<MeetingRoomScreen>
    with WidgetsBindingObserver {
  // ─── Services ──────────────────────────────────────────────────────────────
  final _webRTCService = WebRTCService();
  final _participantService = ParticipantService();
  final _meetingService = MeetingService();

  // ─── UI state ──────────────────────────────────────────────────────────────
  _Phase _phase = _Phase.initializing;
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  bool _isTranslationEnabled = false;
  bool _isScreenSharing = false;
  bool _isLiveTranscriptionOn = false;
  bool _isPipMode = false;
  String _initError = '';

  AudioCaptureService? _captureService;
  StreamSubscription<String>? _captureErrorSub;

  // ─── Screen share ──────────────────────────────────────────────────────────
  MediaStream? _screenStream;
  MediaStreamTrack? _savedCameraTrack;
  Timer? _screenShareCheckTimer;

  // ─── Transcription ──────────────────────────────────────────────────────────
  final List<TranscriptionEntry> _transcriptionEntries = [];

  // ─── Participant / WebRTC state ─────────────────────────────────────────────
  List<ParticipantModel> _participants = [];
  Map<String, MediaStream> _remoteStreams = {};
  bool _isHost = false;
  bool _webrtcInitiated = false;

  // ─── Subscriptions ──────────────────────────────────────────────────────────
  StreamSubscription<List<ParticipantModel>>? _participantsSub;
  StreamSubscription<RTCPeerConnectionState>? _connectionStateSub;
  StreamSubscription<Map<String, MediaStream>>? _remoteStreamsSub;
  StreamSubscription<dynamic>? _meetingStatusSub;
  StreamSubscription<dynamic>? _screenSharesSub;

  // ─── Guards ─────────────────────────────────────────────────────────────────
  bool _hasLeftMeeting = false;
  bool _meetingEndedByHost = false;
  bool _phaseAReady = false;
  bool _phaseBReady = false;
  Timer? _connectingTimeout;
  Timer? _disconnectTimer;

  // ─── Meeting timer ──────────────────────────────────────────────────────────
  final Stopwatch _meetingStopwatch = Stopwatch();
  Timer? _clockTimer;

  // ─────────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Apply initial lobby state
    _isCameraOff = widget.initialCameraOff;
    _isMicMuted = widget.initialMicMuted;
    WidgetsBinding.instance.addObserver(this);
    _meetingStopwatch.start();
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
    // Defer heavy initialization to allow the page transition to complete smoothly
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _initPhaseA();
        _initPhaseB();
        _listenMeetingStatus();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[Meeting] Lifecycle: $state');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectingTimeout?.cancel();
    _disconnectTimer?.cancel();
    _screenShareCheckTimer?.cancel();
    _clockTimer?.cancel();
    _meetingStopwatch.stop();
    _meetingStatusSub?.cancel();
    if (!_hasLeftMeeting) {
      _performLeave();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Phase A — local camera + microphone
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _initPhaseA() async {
    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        throw 'Camera and microphone permissions are required.\n\nPlease grant permissions in Settings and rejoin.';
      }

      await _webRTCService.initLocalStream();

      // Apply initial lobby state: disable tracks if user turned them off
      if (_isCameraOff) {
        _webRTCService.toggleCamera(false);
      }
      if (_isMicMuted) {
        _webRTCService.toggleMicrophone(false);
      }

      try {
        await Helper.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('[Meeting] setSpeakerphoneOn non-fatal: $e');
      }

      if (!mounted) return;
      setState(() {
        _phaseAReady = true;
        if (_phase == _Phase.initializing) _phase = _Phase.waitingForPeer;
      });

      _maybeStartWebRTC();
    } catch (e) {
      debugPrint('[Meeting] Phase A error: $e');
      if (mounted) {
        setState(() => _initError = e.toString());
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Phase B — Firestore presence + real-time listeners
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _initPhaseB() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Not authenticated.';

      _isHost = user.uid == widget.meeting.hostUid;

      String preferredLanguage = widget.meeting.preferredLanguage;
      try {
        preferredLanguage = await _participantService.getUserPreferredLanguage(
          defaultLanguage: widget.meeting.preferredLanguage,
        );
      } catch (e) {
        debugPrint('[Meeting] Language read failed (using default): $e');
      }

      await _participantService.joinMeeting(
        meetingId: widget.meeting.docId,
        isHost: _isHost,
        preferredLanguage: preferredLanguage,
      );

      if (!mounted) return;

      _webRTCService.joinRoom(widget.meeting.docId, user.uid);

      _remoteStreamsSub = _webRTCService.onRemoteStreamsChanged.listen((streams) {
        if (!mounted) return;
        debugPrint('[Meeting] Remote streams changed');
        setState(() => _remoteStreams = streams);
      });

      _participantsSub = _participantService
          .onParticipantsChanged(widget.meeting.docId)
          .listen((participants) {
        if (!mounted) return;
        final prev = _participants.length;
        setState(() => _participants = participants);
        debugPrint('[Meeting] Participants: ${participants.length}');
        _onParticipantListChanged(prev, participants.length);
      });

      if (mounted) {
        setState(() => _phaseBReady = true);
      }

      _screenSharesSub = FirebaseFirestore.instance
          .collection('meetings')
          .doc(widget.meeting.docId)
          .collection('screenShares')
          .snapshots()
          .listen((snapshot) {
        for (var doc in snapshot.docs) {
          if (doc.id != user.uid && doc.data()['active'] == true) {
            _webRTCService.acceptRemoteScreenShare(doc.id);
          }
        }
      });

      // Keep call connection alive in background via foreground service
      ForegroundServiceHelper.startCall(
        title: widget.meeting.title,
        text: 'Meeting in progress',
      );
      // Start audio capture service for translation broadcast
      _captureService = AudioCaptureService();
      _captureErrorSub = _captureService!.onError.listen((error) {
        debugPrint('[Meeting] Capture error: $error');
      });
      // Do NOT start automatically. Wait for user to toggle translation on.
      
      _maybeStartWebRTC();
    } catch (e) {
      debugPrint('[Meeting] Phase B error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meeting setup error: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // WebRTC gate
  // ─────────────────────────────────────────────────────────────────────────────

  void _maybeStartWebRTC() {
    if (!_phaseAReady || !_phaseBReady) return;
    if (_webrtcInitiated) return;
    _webrtcInitiated = true;
    setState(() => _phase = _Phase.connected);
    
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid != null) {
      for (var p in _participants) {
        if (p.uid != myUid) {
          _webRTCService.connectToPeer(p.uid);
        }
      }
    }
  }

  void _onWebRTCStateChanged(RTCPeerConnectionState state) {
    // Handled internally in MeshWebRTCService
  }

  void _onParticipantListChanged(int prev, int current) {
    if (!_phaseAReady || !_phaseBReady) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    
    if (!_webrtcInitiated && current >= 1) {
      _maybeStartWebRTC();
    } else if (_webrtcInitiated) {
      final currentUids = _participants.map((p) => p.uid).toSet();
      for (var p in _participants) {
        if (p.uid != myUid) {
          _webRTCService.connectToPeer(p.uid);
        }
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Meeting status listener
  // ─────────────────────────────────────────────────────────────────────────────

  void _listenMeetingStatus() {
    _meetingStatusSub = _meetingService
        .onMeetingChanged(widget.meeting.docId)
        .listen((meeting) {
      if (meeting == null) return;
      if (meeting.status == 'ended' && !_isHost && !_meetingEndedByHost) {
        _meetingEndedByHost = true;
        _showMeetingEndedDialog();
      }
    });
  }

  Future<void> _showMeetingEndedDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.meeting_room_outlined,
            size: 48, color: Colors.redAccent),
        title: const Text('Meeting Ended'),
        content: const Text(
          'The host has ended this meeting.\nYou will be returned to the home screen.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) {
      await _performLeave();
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Controls
  // ─────────────────────────────────────────────────────────────────────────────

  void _toggleMic() {
    final newMuted = !_isMicMuted;
    setState(() => _isMicMuted = newMuted);
    _webRTCService.toggleMicrophone(!newMuted);
    _participantService.updateMediaStatus(
      meetingId: widget.meeting.docId,
      isMicOn: !newMuted,
    );
    if (_isTranslationEnabled) {
      _captureService?.pauseCapture(newMuted);
    }
  }

  void _toggleCamera() {
    final newOff = !_isCameraOff;
    setState(() => _isCameraOff = newOff);
    _webRTCService.toggleCamera(!newOff);
    _participantService.updateMediaStatus(
      meetingId: widget.meeting.docId,
      isCameraOn: !newOff,
    );
  }

  void _switchCamera() => _webRTCService.switchCamera();

  void _toggleSpeaker() {
    final newState = !_isSpeakerOn;
    setState(() => _isSpeakerOn = newState);
    try {
      Helper.setSpeakerphoneOn(newState);
    } catch (e) {
      debugPrint('[Meeting] Speaker toggle error: $e');
    }
  }

  void _toggleTranslation() {
    setState(() => _isTranslationEnabled = !_isTranslationEnabled);
    if (_isTranslationEnabled) {
      _captureService?.start(meetingId: widget.meeting.docId);
      _captureService?.pauseCapture(_isMicMuted);
    } else {
      _captureService?.stop();
    }
  }

  Future<void> _toggleScreenShare() async {
    if (_isScreenSharing) {
      // ── Stop screen share ──────────────────────────────────────────────────
      _screenShareCheckTimer?.cancel();
      _screenShareCheckTimer = null;

      await _webRTCService.stopScreenShare();

      await ForegroundServiceHelper.stopScreenShare();
      if (mounted) setState(() => _isScreenSharing = false);
      debugPrint('[Meeting] Screen sharing stopped');
    } else {
      // ── Start screen share ─────────────────────────────────────────────────
      try {
        await ForegroundServiceHelper.startScreenShare();

        final remoteUids = _participants.map((p) => p.uid).toList();
        await _webRTCService.startScreenShare(remoteUids);

        if (mounted) setState(() => _isScreenSharing = true);
        debugPrint('[Meeting] Screen sharing started');

        // Poll for track end — onEnded is unreliable on Android
        _screenShareCheckTimer?.cancel();
        _screenShareCheckTimer =
            Timer.periodic(const Duration(seconds: 1), (_) {
          final tracks = _webRTCService.localScreenStream?.getVideoTracks();
          if (tracks == null ||
              tracks.isEmpty ||
              !tracks.first.enabled) {
            if (_isScreenSharing && mounted) {
              _toggleScreenShare();
            }
          }
        });
      } catch (e) {
        await ForegroundServiceHelper.stopScreenShare();
        debugPrint('[Meeting] Screen share failed: $e');
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text('Screen sharing failed: $e'),
                behavior: SnackBarBehavior.floating,
              ),
            );
        }
      }
    }
  }

  void _toggleLiveTranscription() {
    setState(() {
      _isLiveTranscriptionOn = !_isLiveTranscriptionOn;
      if (_isLiveTranscriptionOn && _transcriptionEntries.isEmpty) {
        // Add initial entry
        _transcriptionEntries.add(TranscriptionEntry(
          speaker: 'System',
          text: 'Live transcription started. Captions will appear here.',
        ));
      }
    });
  }

  /// Adds a transcription entry to the live captions.
  ///
  /// Called by speech recognition when a phrase is detected.
  // ignore: unused_element — used externally by speech recognition integration
  void addTranscriptionEntry(String speaker, String text) {
    if (!mounted) return;
    setState(() {
      _transcriptionEntries.add(TranscriptionEntry(
        speaker: speaker,
        text: text,
      ));
    });
  }

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatPanel(meetingDocId: widget.meeting.docId),
    );
  }

  void _openParticipants() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParticipantPanel(
        participants: _participants,
        currentUserId: FirebaseAuth.instance.currentUser?.uid,
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Screen Share
              ListTile(
                leading: Icon(
                  _isScreenSharing
                      ? Icons.stop_screen_share_rounded
                      : Icons.screen_share_rounded,
                  color: _isScreenSharing
                      ? Colors.orangeAccent
                      : Colors.white70,
                ),
                title: Text(
                  _isScreenSharing
                      ? 'Stop Screen Share'
                      : 'Share Screen',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleScreenShare();
                },
              ),
              // Live Transcription
              ListTile(
                leading: Icon(
                  Icons.closed_caption_rounded,
                  color: _isLiveTranscriptionOn
                      ? Colors.cyanAccent
                      : Colors.white70,
                ),
                title: Text(
                  _isLiveTranscriptionOn
                      ? 'Turn Off Captions'
                      : 'Turn On Captions',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleLiveTranscription();
                },
              ),
              // Translation
              ListTile(
                leading: Icon(
                  Icons.translate_rounded,
                  color: _isTranslationEnabled
                      ? Colors.cyanAccent
                      : Colors.white70,
                ),
                title: Text(
                  _isTranslationEnabled
                      ? 'Disable Translation'
                      : 'Enable Translation',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  _toggleTranslation();
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flip_camera_ios_rounded,
                    color: Colors.white70),
                title: const Text('Switch Camera',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  _switchCamera();
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat_rounded, color: Colors.white70),
                title:
                    const Text('Chat', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _openChat();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.people_rounded, color: Colors.white70),
                title: const Text('Participants',
                    style: TextStyle(color: Colors.white)),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${_participants.length}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openParticipants();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Leave / Cleanup
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _performLeave() async {
    if (_hasLeftMeeting) return;
    _hasLeftMeeting = true;
    debugPrint('[Meeting] Performing leave cleanup');

    // Stop screen share if active
    _screenShareCheckTimer?.cancel();
    _screenShareCheckTimer = null;
    await _webRTCService.stopScreenShare();

    _connectingTimeout?.cancel();
    _disconnectTimer?.cancel();
    _captureErrorSub?.cancel();
    _captureService?.stop();

    await _participantsSub?.cancel();
    await _connectionStateSub?.cancel();
    await _remoteStreamsSub?.cancel();
    await _meetingStatusSub?.cancel();
    await _screenSharesSub?.cancel();
    _participantsSub = null;
    _connectionStateSub = null;
    _remoteStreamsSub = null;
    _meetingStatusSub = null;
    _screenSharesSub = null;

    if (_isHost) {
      try {
        await _meetingService.updateMeetingStatus(
            widget.meeting.docId, 'ended');
      } catch (e) {
        debugPrint('[Meeting] Failed to end meeting: $e');
      }
      await _webRTCService.cleanupSignalingRoom(widget.meeting.docId);
    }

    await _participantService.leaveMeeting(widget.meeting.docId);
    await _webRTCService.dispose();
    await ForegroundServiceHelper.stopService();

    debugPrint('[Meeting] Leave cleanup complete');
  }

  Future<void> _promptLeave(BuildContext ctx) async {
    if (_isHost) {
      final result = await showDialog<String>(
        context: ctx,
        barrierDismissible: false,
        builder: (dlgCtx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Leave meeting?'),
          content: const Text(
              'As the host, leaving will end the meeting for everyone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop('cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop('leave'),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dlgCtx).colorScheme.error),
              child: const Text('End for everyone'),
            ),
          ],
        ),
      );
      if (result == 'leave' && ctx.mounted) {
        await _performLeave();
        if (ctx.mounted) Navigator.of(ctx).popUntil((r) => r.isFirst);
      }
    } else {
      final confirmed = await showDialog<bool>(
        context: ctx,
        barrierDismissible: false,
        builder: (dlgCtx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(AppConstants.leaveConfirmTitle),
          content: const Text(AppConstants.leaveConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(false),
              child: const Text(AppConstants.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dlgCtx).pop(true),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dlgCtx).colorScheme.error),
              child: const Text(AppConstants.leaveMeeting),
            ),
          ],
        ),
      );
      if (confirmed == true && ctx.mounted) {
        await _performLeave();
        if (ctx.mounted) Navigator.of(ctx).popUntil((r) => r.isFirst);
      }
    }
  }

  void _retryWebRTC() async {
    // Retry logic is now handled in Mesh WebRTC implicitly
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  String get _elapsedTime {
    final d = _meetingStopwatch.elapsed;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get _myDisplayName {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? 'You';
  }

  String get _myInitial {
    final name = _myDisplayName;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD — Column layout. No Stack sizing bugs.
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _promptLeave(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: SafeArea(
          child: Column(
            children: [
              // ── 1. Top bar ─────────────────────────────────────────────────
              _buildTopBar(),

              // ── Screen share indicator ──────────────────────────────────────
              if (_isScreenSharing)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.screen_share_rounded,
                          color: Colors.orangeAccent, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'You are sharing your screen',
                        style: TextStyle(
                            color: Colors.orangeAccent, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _toggleScreenShare,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Stop',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── 2. Admission banner (host only) ────────────────────────────
              if (_isHost && widget.meeting.admissionControl)
                AdmissionBanner(meetingDocId: widget.meeting.docId),

              // ── 3. Video area (fills remaining space) ──────────────────────
              Expanded(child: _buildVideoArea()),

              // ── 4. Translation overlay (above controls) ────────────────────
              TranslationOverlay(
                isCaptionsEnabled: _isLiveTranscriptionOn,
                isTtsEnabled: _isTranslationEnabled,
                meetingDocId: widget.meeting.docId,
                onCaptionReceived: (speaker, text) => addTranscriptionEntry(speaker, text),
                onMuteRemoteAudio: (mute) =>
                    _webRTCService.muteRemoteAudio(mute),
              ),

              // ── Live Transcription panel ────────────────────────────────────
              if (_isLiveTranscriptionOn)
                LiveTranscriptionPanel(
                  entries: _transcriptionEntries,
                  onClose: _toggleLiveTranscription,
                ),

              // ── 5. Bottom control bar ──────────────────────────────────────
              _buildBottomControlBar(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. TOP BAR — meeting title, timer, participant count, status dot
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const BoxDecoration(
        color: Color(0xFF16162A),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          // Hamburger / back
          IconButton(
            icon:
                const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () => _promptLeave(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          // Title + timer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.meeting.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _elapsedTime,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          // Camera switch
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded,
                color: Colors.white70, size: 20),
            onPressed: _switchCamera,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Layout toggle (Grid vs PiP)
          if (_phase == _Phase.connected && _remoteStreams.isNotEmpty)
            IconButton(
              icon: Icon(
                _isPipMode
                    ? Icons.grid_view_rounded
                    : Icons.picture_in_picture_alt_rounded,
                color: Colors.white70,
                size: 20,
              ),
              tooltip: _isPipMode ? 'Switch to Grid View' : 'Switch to PiP View',
              onPressed: () => setState(() => _isPipMode = !_isPipMode),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          // Participants
          IconButton(
            icon: const Icon(Icons.people_outline_rounded,
                color: Colors.white70, size: 20),
            onPressed: _openParticipants,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Status dot
          _buildStatusDot(),
        ],
      ),
    );
  }

  Widget _buildStatusDot() {
    Color dot;
    switch (_phase) {
      case _Phase.initializing:
      case _Phase.waitingForPeer:
        dot = Colors.amber;
      case _Phase.connecting:
        dot = Colors.blue;
      case _Phase.connected:
        dot = Colors.greenAccent;
      case _Phase.failed:
      case _Phase.ended:
        dot = Colors.redAccent;
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 3. VIDEO AREA — the main content
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildVideoArea() {
    // ── Error state ────────────────────────────────────────────────────────────
    if (_initError.isNotEmpty) {
      return _buildErrorState();
    }

    // ── Connected with remote video — grid layout ──────────────────────────────
    if (_phase == _Phase.connected) {
      return _buildConnectedGrid();
    }

    // ── All other states — show local camera with overlay ──────────────────────
    return _buildLocalVideoWithOverlay();
  }

  /// When alone or connecting: shows local camera full-size with state chip.
  Widget _buildLocalVideoWithOverlay() {
    final localStream = _webRTCService.localStream;
    // When screen sharing, show the screen stream instead of camera
    final displayStream = _isScreenSharing ? _screenStream : localStream;
    
    final hasVideoTracks = displayStream?.getVideoTracks().isNotEmpty ?? false;
    final hasVideo = displayStream != null && hasVideoTracks && (!_isCameraOff || _isScreenSharing);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Local video / screen share / avatar ──────────────────────────────
          if (hasVideo)
            WebRTCVideoView(
              stream: displayStream,
              mirror: !_isScreenSharing, // don't mirror screen share
              objectFit: _isScreenSharing
                  ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                  : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            _buildAvatarPlaceholder(_myInitial, _myDisplayName, large: true),

          // ── "You" label ──────────────────────────────────────────────────────
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('You',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
          ),

          // ── State overlay (centered) ─────────────────────────────────────────
          Center(child: _buildPhaseChip()),

          // ── Meeting ID (when waiting) ────────────────────────────────────────
          if (_phase == _Phase.waitingForPeer || _phase == _Phase.initializing)
            Positioned(
              left: 0,
              right: 0,
              top: 16,
              child: Center(child: _buildMeetingIdChip()),
            ),
        ],
      ),
    );
  }

  /// When connected:
  /// - When _isPipMode is false (default): 50/50 vertical split grid (equal height).
  /// - When _isPipMode is true: Fullscreen remote with floating draggable/corner PiP card.
  Widget _buildConnectedGrid() {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    final List<Widget> tiles = [];

    // 1. Local participant
    tiles.add(_buildVideoTile(
      stream: _isScreenSharing ? _webRTCService.localScreenStream : _webRTCService.localStream,
      name: _isScreenSharing ? 'Your Screen' : 'You',
      isMicOn: !_isMicMuted,
      isCameraOff: _isScreenSharing ? false : _isCameraOff,
      initial: _myInitial,
      mirror: !_isScreenSharing,
      objectFit: _isScreenSharing
          ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
          : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    ));

    // 2. Remote participants
    for (var p in _participants) {
      if (p.uid == myUid) continue;
      MediaStream? stream;
      _remoteStreams.forEach((id, s) {
        if (id.contains(p.uid) && !id.endsWith('_screen')) stream = s;
      });
      tiles.add(_buildVideoTile(
        stream: stream,
        name: p.displayName.isNotEmpty ? p.displayName : 'Participant',
        isMicOn: p.isMicOn,
        isCameraOff: !p.isCameraOn,
        initial: p.displayName.isNotEmpty ? p.displayName[0].toUpperCase() : '?',
        mirror: false,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ));
    }

    // 3. Screen shares
    _remoteStreams.forEach((id, stream) {
      if (id.endsWith('_screen')) {
        final sharerUid = id.split('_').firstWhere((part) => part != myUid && part != 'screen', orElse: () => '');
        final p = _participants.where((p) => p.uid == sharerUid).firstOrNull;
        tiles.add(_buildVideoTile(
          stream: stream,
          name: p != null ? '${p.displayName}\'s Screen' : 'Screen Share',
          isMicOn: true,
          isCameraOff: false,
          initial: 'S',
          mirror: false,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
        ));
      }
    });

    if (_isPipMode && tiles.length > 1) {
      return Stack(
        fit: StackFit.expand,
        children: [
          tiles[1], // main
          Positioned(
            right: 16,
            bottom: 16,
            width: 110,
            height: 155,
            child: GestureDetector(
              onTap: () => setState(() => _isPipMode = false),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildVideoTile(
                  stream: _isScreenSharing ? _webRTCService.localScreenStream : _webRTCService.localStream,
                  name: _isScreenSharing ? 'Your Screen' : 'You',
                  isMicOn: !_isMicMuted,
                  isCameraOff: _isScreenSharing ? false : _isCameraOff,
                  initial: _myInitial,
                  mirror: !_isScreenSharing,
                  isCompact: true,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Padding(
      padding: const EdgeInsets.all(6),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: isLandscape ? (tiles.length > 2 ? 3 : 2) : (tiles.length > 2 ? 2 : 1),
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: isLandscape ? 1.5 : (tiles.length > 2 ? 1.0 : 1.2),
        ),
        itemCount: tiles.length,
        itemBuilder: (context, index) => tiles[index],
      ),
    );
  }

  /// Reusable card tile for a participant's stream with name pill and mic status.
  Widget _buildVideoTile({
    required MediaStream? stream,
    required String name,
    required bool isMicOn,
    required bool isCameraOff,
    required String initial,
    required bool mirror,
    RTCVideoViewObjectFit objectFit =
        RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
    bool isCompact = false,
  }) {
    final hasVideoTracks = stream?.getVideoTracks().isNotEmpty ?? false;
    final hasVideo = stream != null && hasVideoTracks && !isCameraOff;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161626),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasVideo)
            WebRTCVideoView(
              stream: stream,
              mirror: mirror,
              objectFit: objectFit,
              placeholderLabel: name,
            )
          else
            _buildAvatarPlaceholder(initial, name, large: !isCompact),

          // Name pill + mic status
          Positioned(
            left: isCompact ? 6 : 12,
            bottom: isCompact ? 6 : 12,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 6 : 10,
                vertical: isCompact ? 3 : 5,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 10 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    color: isMicOn ? Colors.greenAccent : Colors.redAccent,
                    size: isCompact ? 11 : 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Phase chip overlays
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPhaseChip() {
    switch (_phase) {
      case _Phase.initializing:
        return _chipWidget(
          icon: const SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          label: 'Setting up camera...',
        );
      case _Phase.waitingForPeer:
        return _chipWidget(
          icon: const Icon(Icons.people_outline_rounded,
              color: Colors.white70, size: 18),
          label: 'Waiting for others to join...',
        );
      case _Phase.connecting:
        return _chipWidget(
          icon: const SizedBox(
            width: 16,
            height: 16,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          label: 'Connecting...',
        );
      case _Phase.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chipWidget(
              icon: const Icon(Icons.signal_wifi_bad_rounded,
                  color: Colors.redAccent, size: 18),
              label: 'Connection failed',
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _retryWebRTC,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white12,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        );
      case _Phase.ended:
        return _chipWidget(
          icon: const Icon(Icons.meeting_room_outlined,
              color: Colors.redAccent, size: 18),
          label: 'Meeting ended',
        );
      case _Phase.connected:
        return const SizedBox.shrink();
    }
  }

  Widget _chipWidget({required Widget icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 10),
          Text(label,
              style:
                  const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Avatar placeholder
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildAvatarPlaceholder(String initial, String name,
      {required bool large}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF0D0D1A)],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLarge = large && constraints.maxHeight > 120;
          return Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: isLarge ? 48 : 24,
                    backgroundColor: Colors.deepPurple.withValues(alpha: 0.6),
                    child: Text(initial,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isLarge ? 40 : 18,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                  if (isLarge) ...[
                    const SizedBox(height: 10),
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Meeting ID chip
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildMeetingIdChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          const Text('Meeting ID',
              style: TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            widget.meeting.meetingId,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Error state
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 56),
            const SizedBox(height: 16),
            Text(
              _initError,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Go Back'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings_rounded, size: 18),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 5. BOTTOM CONTROL BAR — labeled icons matching wireframe
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildBottomControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF16162A),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _labeledControl(
            icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: 'Mic',
            active: !_isMicMuted,
            onTap: _toggleMic,
          ),
          _labeledControl(
            icon: _isCameraOff
                ? Icons.videocam_off_rounded
                : Icons.videocam_rounded,
            label: 'Camera',
            active: !_isCameraOff,
            onTap: _toggleCamera,
          ),
          _labeledControl(
            icon: _isSpeakerOn
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: 'Speaker',
            active: _isSpeakerOn,
            onTap: _toggleSpeaker,
          ),
          _labeledControl(
            icon: Icons.more_horiz_rounded,
            label: 'More',
            active: true,
            onTap: _showMoreOptions,
          ),
          // Leave button — prominent red
          GestureDetector(
            onTap: () => _promptLeave(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_end_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(height: 2),
                const Text('Leave',
                    style: TextStyle(color: Colors.redAccent, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledControl({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.redAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: active ? Colors.white : Colors.redAccent, size: 20),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                color: active ? Colors.white60 : Colors.redAccent,
                fontSize: 10,
              )),
        ],
      ),
    );
  }
}
