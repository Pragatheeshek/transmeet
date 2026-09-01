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

  /// Whether the local stream has been successfully initialized.
  bool get isReady => localStream != null && !_disposed;

  /// STUN servers configuration
  final Map<String, dynamic> configuration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302'
        ]
      }
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

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });
    debugPrint('[WebRTC] Local tracks added to PeerConnection');
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
        if (peerConnection?.getRemoteDescription() == null && data['answer'] != null) {
          debugPrint('[WebRTC] Answer received from Firestore');
          var answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );
          await peerConnection?.setRemoteDescription(answer);
          debugPrint('[WebRTC] Remote description (answer) set');
        }
      }
    });

    // Listen for remote ICE candidates
    _candidateSubscription = roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          debugPrint('[WebRTC] Callee ICE candidate received');
          final data = change.doc.data() as Map<String, dynamic>;
          peerConnection?.addCandidate(
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
        if (peerConnection?.getRemoteDescription() == null && data['offer'] != null) {
          debugPrint('[WebRTC] Offer received from Firestore');
          var offer = RTCSessionDescription(
            data['offer']['sdp'],
            data['offer']['type'],
          );
          await peerConnection?.setRemoteDescription(offer);
          debugPrint('[WebRTC] Remote description (offer) set');

          var answer = await peerConnection!.createAnswer();
          await peerConnection!.setLocalDescription(answer);
          debugPrint('[WebRTC] Answer created and set as local description');

          await roomRef.update({'answer': answer.toMap()});
          debugPrint('[WebRTC] Answer written to Firestore');
        }
      }
    });

    // Listen for remote ICE candidates
    _candidateSubscription = roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          debugPrint('[WebRTC] Caller ICE candidate received');
          final data = change.doc.data() as Map<String, dynamic>;
          peerConnection?.addCandidate(
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
