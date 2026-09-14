import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Service to handle WebRTC media and signaling via Firestore.
///
/// Signaling structure:
///   meetings/{meetingId}          → offer, answer fields
///   meetings/{meetingId}/callerCandidates/{auto}  → Host ICE candidates
///   meetings/{meetingId}/calleeCandidates/{auto}  → Guest ICE candidates
class WebRTCService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? _remoteStream;

  MediaStream? get remoteStream => _remoteStream;

  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get onRemoteStream => _remoteStreamController.stream;

  final _connectionStateController = StreamController<RTCPeerConnectionState>.broadcast();
  Stream<RTCPeerConnectionState> get onConnectionState => _connectionStateController.stream;

  String? roomId;
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<QuerySnapshot>? _candidateSubscription;
  bool _disposed = false;

  /// Tracks whether the remote description has been set on the peer connection.
  ///
  /// This replaces the buggy `peerConnection?.getRemoteDescription() == null`
  /// check — that method returns a Future, so comparing it to null was always
  /// false, which prevented the host from ever setting the answer.
  bool _remoteDescriptionSet = false;

  /// Buffers ICE candidates that arrive before the remote description is set.
  ///
  /// Without buffering, candidates received before setRemoteDescription()
  /// are silently discarded by WebRTC, causing connectivity checks to fail.
  final List<RTCIceCandidate> _pendingCandidates = [];

  /// Whether the local stream has been successfully initialized.
  bool get isReady => localStream != null && !_disposed;

  /// ICE servers configuration — includes both STUN and TURN servers.
  ///
  /// STUN-only works when both peers have a direct route (open/cone NAT).
  /// Mobile networks (4G/5G) almost always use symmetric NAT, which requires
  /// a TURN relay server as fallback. Without TURN, connections between
  /// mobile devices will fail consistently.
  final Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ]
      },
      // Free TURN servers from Open Relay Project (metered.ca)
      // These provide relay capability for NAT traversal on mobile networks.
      {
        'urls': 'turn:a.relay.metered.ca:80',
        'username': 'e8dd65b92f070a50a37e811a',
        'credential': '5sJJpEbOmOFErEuh',
      },
      {
        'urls': 'turn:a.relay.metered.ca:80?transport=tcp',
        'username': 'e8dd65b92f070a50a37e811a',
        'credential': '5sJJpEbOmOFErEuh',
      },
      {
        'urls': 'turn:a.relay.metered.ca:443',
        'username': 'e8dd65b92f070a50a37e811a',
        'credential': '5sJJpEbOmOFErEuh',
      },
      {
        'urls': 'turns:a.relay.metered.ca:443?transport=tcp',
        'username': 'e8dd65b92f070a50a37e811a',
        'credential': '5sJJpEbOmOFErEuh',
      },
    ]
  };

  final Map<String, dynamic> offerSdpConstraints = {
    "mandatory": {
      "OfferToReceiveAudio": true,
      "OfferToReceiveVideo": true,
    },
    "optional": [],
  };

  /// Initializes local media (camera and mic).
  Future<void> initLocalStream() async {
    debugPrint('[WebRTC] Initializing local stream');
    if (_disposed) return;
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      }
    };

    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    debugPrint('[WebRTC] Local stream initialized: ${localStream?.id}');
  }

  /// Creates a peer connection and adds local tracks.
  Future<void> _createPeerConnection() async {
    debugPrint('[WebRTC] Creating PeerConnection');

    // Reset state for new connection
    _remoteDescriptionSet = false;
    _pendingCandidates.clear();

    peerConnection = await createPeerConnection(configuration, offerSdpConstraints);

    peerConnection?.onTrack = (RTCTrackEvent event) {
      debugPrint('[WebRTC] Remote track received: ${event.track.kind}');
      if (event.track.kind == 'video' || event.track.kind == 'audio') {
        _remoteStream ??= event.streams.first;
        if (_remoteStream != null && !_disposed) {
          _remoteStreamController.add(_remoteStream!);
        }
      }
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRTC] Connection state: $state');
      if (!_disposed) {
        _connectionStateController.add(state);
      }
    };

    peerConnection?.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[WebRTC] ICE connection state: $state');
    };

    peerConnection?.onIceGatheringState = (RTCIceGatheringState state) {
      debugPrint('[WebRTC] ICE gathering state: $state');
    };

    peerConnection?.onSignalingState = (RTCSignalingState state) {
      debugPrint('[WebRTC] Signaling state: $state');
    };

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });
    debugPrint('[WebRTC] Local tracks added to PeerConnection');
  }

  /// Adds buffered ICE candidates after the remote description has been set.
  Future<void> _drainPendingCandidates() async {
    debugPrint('[WebRTC] Draining ${_pendingCandidates.length} buffered ICE candidates');
    for (final candidate in _pendingCandidates) {
      try {
        await peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('[WebRTC] Failed to add buffered candidate: $e');
      }
    }
    _pendingCandidates.clear();
  }

  /// Adds an ICE candidate, buffering it if the remote description isn't set yet.
  Future<void> _addIceCandidate(RTCIceCandidate candidate) async {
    if (_remoteDescriptionSet) {
      try {
        await peerConnection?.addCandidate(candidate);
      } catch (e) {
        debugPrint('[WebRTC] Failed to add ICE candidate: $e');
      }
    } else {
      debugPrint('[WebRTC] Buffering ICE candidate (remote desc not set yet)');
      _pendingCandidates.add(candidate);
    }
  }

  /// Deletes stale signaling data (offer, answer, ICE candidates) from Firestore.
  ///
  /// Called before creating a new offer to prevent stale SDP issues.
  Future<void> cleanupSignaling(String meetingId) async {
    debugPrint('[WebRTC] Cleaning up stale signaling data');
    final roomRef = _firestore.collection('meetings').doc(meetingId);

    try {
      // Remove offer and answer fields from the meeting document.
      await roomRef.update({
        'offer': FieldValue.delete(),
        'answer': FieldValue.delete(),
      });
    } catch (e) {
      debugPrint('[WebRTC] Failed to clear offer/answer (may not exist): $e');
    }

    // Delete all caller candidates.
    try {
      final callerCandidates = await roomRef.collection('callerCandidates').get();
      for (final doc in callerCandidates.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('[WebRTC] Failed to clear callerCandidates: $e');
    }

    // Delete all callee candidates.
    try {
      final calleeCandidates = await roomRef.collection('calleeCandidates').get();
      for (final doc in calleeCandidates.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('[WebRTC] Failed to clear calleeCandidates: $e');
    }

    debugPrint('[WebRTC] Signaling data cleaned up');
  }

  /// Resets the peer connection without disposing localStream.
  ///
  /// Called when the remote participant leaves so the host can re-establish
  /// a connection when a new participant joins.
  Future<void> resetConnection() async {
    debugPrint('[WebRTC] Resetting connection');

    await _roomSubscription?.cancel();
    _roomSubscription = null;

    await _candidateSubscription?.cancel();
    _candidateSubscription = null;

    await _remoteStream?.dispose();
    _remoteStream = null;

    _remoteDescriptionSet = false;
    _pendingCandidates.clear();

    await peerConnection?.close();
    peerConnection = null;

    debugPrint('[WebRTC] Connection reset complete');
  }

  /// Called by the HOST to create an offer and listen for an answer.
  Future<void> createOffer(String meetingId) async {
    if (_disposed) return;
    if (localStream == null) {
      throw 'Local stream not ready — call initLocalStream() first.';
    }
    debugPrint('[WebRTC] Host creating offer for meeting: $meetingId');
    roomId = meetingId;

    // Clean stale signaling data before creating a new offer.
    await cleanupSignaling(meetingId);

    await _createPeerConnection();

    final roomRef = _firestore.collection('meetings').doc(roomId);
    final callerCandidatesCollection = roomRef.collection('callerCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      debugPrint('[WebRTC] Host ICE candidate generated');
      callerCandidatesCollection.add(candidate.toMap());
    };

    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);
    debugPrint('[WebRTC] Offer created and set as local description');

    await roomRef.update({'offer': offer.toMap()});
    debugPrint('[WebRTC] Offer written to Firestore');

    // Listen for remote answer
    _roomSubscription = roomRef.snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (!_remoteDescriptionSet && data['answer'] != null) {
          debugPrint('[WebRTC] Answer received from Firestore');
          try {
            var answer = RTCSessionDescription(
              data['answer']['sdp'],
              data['answer']['type'],
            );
            await peerConnection?.setRemoteDescription(answer);
            _remoteDescriptionSet = true;
            debugPrint('[WebRTC] Remote description (answer) set');

            // Drain any ICE candidates that arrived before the answer.
            await _drainPendingCandidates();
          } catch (e) {
            debugPrint('[WebRTC] Failed to set remote description (answer): $e');
          }
        }
      }
    });

    // Listen for remote ICE candidates
    _candidateSubscription = roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          debugPrint('[WebRTC] Callee ICE candidate received');
          final data = change.doc.data() as Map<String, dynamic>;
          _addIceCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });
  }

  /// Called by the GUEST to create an answer to an existing offer.
  Future<void> createAnswer(String meetingId) async {
    if (_disposed) return;
    if (localStream == null) {
      throw 'Local stream not ready — call initLocalStream() first.';
    }
    debugPrint('[WebRTC] Guest creating answer for meeting: $meetingId');
    roomId = meetingId;
    await _createPeerConnection();

    final roomRef = _firestore.collection('meetings').doc(roomId);
    final calleeCandidatesCollection = roomRef.collection('calleeCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      debugPrint('[WebRTC] Guest ICE candidate generated');
      calleeCandidatesCollection.add(candidate.toMap());
    };

    // Listen for the offer from the host (caller).
    // The offer may not exist yet if both participants joined simultaneously.
    _roomSubscription = roomRef.snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (!_remoteDescriptionSet && data['offer'] != null) {
          debugPrint('[WebRTC] Offer received from Firestore');
          try {
            var offer = RTCSessionDescription(
              data['offer']['sdp'],
              data['offer']['type'],
            );
            await peerConnection?.setRemoteDescription(offer);
            _remoteDescriptionSet = true;
            debugPrint('[WebRTC] Remote description (offer) set');

            // Drain any ICE candidates that arrived before the offer.
            await _drainPendingCandidates();

            var answer = await peerConnection!.createAnswer();
            await peerConnection!.setLocalDescription(answer);
            debugPrint('[WebRTC] Answer created and set as local description');

            await roomRef.update({'answer': answer.toMap()});
            debugPrint('[WebRTC] Answer written to Firestore');
          } catch (e) {
            debugPrint('[WebRTC] Failed to process offer: $e');
          }
        }
      }
    });

    // Listen for remote ICE candidates
    _candidateSubscription = roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          debugPrint('[WebRTC] Caller ICE candidate received');
          final data = change.doc.data() as Map<String, dynamic>;
          _addIceCandidate(
            RTCIceCandidate(
              data['candidate'],
              data['sdpMid'],
              data['sdpMLineIndex'],
            ),
          );
        }
      }
    });
  }

  /// Toggles the local microphone.
  void toggleMicrophone(bool enabled) {
    if (localStream != null) {
      final audioTracks = localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = enabled;
      }
    }
  }

  /// Toggles the local camera.
  void toggleCamera(bool enabled) {
    if (localStream != null) {
      final videoTracks = localStream!.getVideoTracks();
      for (var track in videoTracks) {
        track.enabled = enabled;
      }
    }
  }

  /// Switches between front and back camera.
  Future<void> switchCamera() async {
    if (localStream != null) {
      final videoTrack = localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    }
  }

  /// Replaces the video track being sent to the remote peer.
  ///
  /// Used for screen sharing — swaps camera track with display track
  /// and vice versa without renegotiation.
  Future<void> replaceVideoTrack(MediaStreamTrack newTrack) async {
    final senders = await peerConnection?.getSenders();
    if (senders == null) return;
    for (final sender in senders) {
      if (sender.track?.kind == 'video') {
        await sender.replaceTrack(newTrack);
        debugPrint('[WebRTC] Video track replaced');
        return;
      }
    }
  }

  /// Mutes or unmutes the remote audio track.
  ///
  /// When translation is enabled, the remote audio is muted so the user
  /// only hears the synthesized translated speech (via just_audio).
  /// When translation is disabled, the remote audio is restored.
  void muteRemoteAudio(bool mute) {
    if (_remoteStream == null) return;
    final audioTracks = _remoteStream!.getAudioTracks();
    for (final track in audioTracks) {
      track.enabled = !mute;
      debugPrint('[WebRTC] Remote audio track ${mute ? "muted" : "unmuted"}');
    }
  }


  /// Cleans up all resources. Safe to call multiple times.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    debugPrint('[WebRTC] Disposing WebRTCService');

    localStream?.getTracks().forEach((track) => track.stop());
    await localStream?.dispose();
    localStream = null;

    await _remoteStream?.dispose();
    _remoteStream = null;

    _remoteDescriptionSet = false;
    _pendingCandidates.clear();

    await peerConnection?.close();
    peerConnection = null;

    await _roomSubscription?.cancel();
    _roomSubscription = null;

    await _candidateSubscription?.cancel();
    _candidateSubscription = null;

    _remoteStreamController.close();
    _connectionStateController.close();

    debugPrint('[WebRTC] WebRTCService disposed');
  }
}
