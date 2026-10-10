import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class PeerConnectionState {
  final RTCPeerConnection peerConnection;
  MediaStream? remoteStream;
  List<RTCIceCandidate> pendingCandidates = [];
  bool remoteDescriptionSet = false;
  StreamSubscription? documentSub;
  StreamSubscription? callerCandidateSub;
  StreamSubscription? calleeCandidateSub;

  PeerConnectionState(this.peerConnection);

  Future<void> dispose() async {
    await documentSub?.cancel();
    await callerCandidateSub?.cancel();
    await calleeCandidateSub?.cancel();
    remoteStream?.getTracks().forEach((t) => t.stop());
    await remoteStream?.dispose();
    await peerConnection.close();
  }
}

class WebRTCService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  MediaStream? localStream;
  MediaStream? localScreenStream;

  String? _roomId;
  String? _myUid;
  bool _disposed = false;

  // connectionId -> PeerConnectionState
  final Map<String, PeerConnectionState> _connections = {};

  final _remoteStreamsController =
      StreamController<Map<String, MediaStream>>.broadcast();
  Stream<Map<String, MediaStream>> get onRemoteStreamsChanged =>
      _remoteStreamsController.stream;

  Map<String, MediaStream> get currentRemoteStreams {
    final streams = <String, MediaStream>{};
    _connections.forEach((id, state) {
      if (state.remoteStream != null) {
        streams[id] = state.remoteStream!;
      }
    });
    return streams;
  }

  void _notifyStreamsChanged() {
    if (!_disposed) {
      _remoteStreamsController.add(currentRemoteStreams);
    }
  }

  final Map<String, dynamic> configuration = {
    'iceServers': [
      {'urls': ['stun:stun1.l.google.com:19302', 'stun:stun2.l.google.com:19302']},
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

  Future<void> initLocalStream() async {
    if (_disposed) return;
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': {'facingMode': 'user'}
    });
  }

  void joinRoom(String meetingId, String myUid) {
    _roomId = meetingId;
    _myUid = myUid;
    debugPrint('[MeshWebRTC] Joined room: $meetingId as $myUid');
  }

  /// Connect to a remote user (camera). Called when participant list updates.
  Future<void> connectToPeer(String remoteUid) async {
    if (_disposed || _roomId == null || _myUid == null || localStream == null) return;
    if (remoteUid == _myUid) return;

    // Lexicographical sort to determine caller/callee consistently
    final isCaller = _myUid!.compareTo(remoteUid) < 0;
    final connectionId = isCaller ? '${_myUid}_$remoteUid' : '${remoteUid}_$_myUid';

    if (_connections.containsKey(connectionId)) return; // Already connecting/connected

    debugPrint('[MeshWebRTC] Connecting to $remoteUid, connectionId: $connectionId (isCaller: $isCaller)');
    await _establishConnection(connectionId, isCaller, localStream!, remoteUid);
  }

  /// Start screen sharing and connect to all existing remote UIDs.
  Future<void> startScreenShare(List<String> remoteUids) async {
    if (_disposed || _roomId == null || _myUid == null) return;
    
    try {
      localScreenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });

      // Notify Firestore that I am screen sharing
      await _firestore.collection('meetings').doc(_roomId)
          .collection('screenShares').doc(_myUid).set({
        'active': true,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // The screencaster is ALWAYS the caller for their screen share
      for (final remoteUid in remoteUids) {
        if (remoteUid == _myUid) continue;
        final connectionId = '${_myUid}_${remoteUid}_screen';
        if (!_connections.containsKey(connectionId)) {
          await _establishConnection(connectionId, true, localScreenStream!, remoteUid);
        }
      }
      
      // Stop tracking on ended
      localScreenStream?.getVideoTracks().firstOrNull?.onEnded = () {
        stopScreenShare();
      };
    } catch (e) {
      debugPrint('[MeshWebRTC] Screen share failed: $e');
      rethrow;
    }
  }

  /// Connect to a remote user's screen share.
  Future<void> acceptRemoteScreenShare(String remoteUid) async {
    if (_disposed || _roomId == null || _myUid == null || localStream == null) return;
    // For remote screen share, remote is the caller, I am the callee
    final connectionId = '${remoteUid}_${_myUid}_screen';
    if (_connections.containsKey(connectionId)) return;

    // We can use localStream (or an empty stream) as we just need to receive
    await _establishConnection(connectionId, false, localStream!, remoteUid);
  }

  /// Stop screen sharing and close all screen share connections.
  Future<void> stopScreenShare() async {
    if (localScreenStream != null) {
      localScreenStream!.getTracks().forEach((t) => t.stop());
      await localScreenStream!.dispose();
      localScreenStream = null;
    }

    if (_roomId != null && _myUid != null) {
      try {
        await _firestore.collection('meetings').doc(_roomId)
            .collection('screenShares').doc(_myUid).delete();
      } catch (_) {}
    }

    // Close all connections ending with '_screen' where I am the caller
    final keysToRemove = _connections.keys.where((k) => k.startsWith('${_myUid}_') && k.endsWith('_screen')).toList();
    for (final key in keysToRemove) {
      await _connections[key]?.dispose();
      _connections.remove(key);
      _cleanupSignaling(key);
    }
    _notifyStreamsChanged();
  }
  
  Future<void> _establishConnection(String connectionId, bool isCaller, MediaStream streamToSend, String targetUid) async {
    final pc = await createPeerConnection(configuration, offerSdpConstraints);
    final state = PeerConnectionState(pc);
    _connections[connectionId] = state;

    pc.onTrack = (event) {
      if (event.track.kind == 'video' || event.track.kind == 'audio') {
        if (event.streams.isNotEmpty) {
          state.remoteStream ??= event.streams.first;
        } else {
          // If streams array is empty, we must create one.
          // However, flutter_webrtc usually provides onAddStream for this.
        }
        _notifyStreamsChanged();
      }
    };

    pc.onAddStream = (stream) {
      state.remoteStream = stream;
      _notifyStreamsChanged();
    };

    streamToSend.getTracks().forEach((track) {
      pc.addTrack(track, streamToSend);
    });

    final docRef = _firestore.collection('meetings').doc(_roomId).collection('connections').doc(connectionId);
    final callerCandidates = docRef.collection('callerCandidates');
    final calleeCandidates = docRef.collection('calleeCandidates');

    pc.onIceCandidate = (candidate) {
      if (isCaller) {
        callerCandidates.add(candidate.toMap());
      } else {
        calleeCandidates.add(candidate.toMap());
      }
    };

    if (isCaller) {
      // 1. Clean stale data
      await _cleanupSignaling(connectionId);
      
      // 2. Create Offer
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await docRef.set({'offer': offer.toMap()});

      // 3. Listen for Answer
      state.documentSub = docRef.snapshots().listen((snapshot) async {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data['answer'] != null && !state.remoteDescriptionSet) {
            final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
            await pc.setRemoteDescription(answer);
            state.remoteDescriptionSet = true;
            _drainPendingCandidates(state);
          }
        }
      });

      // 4. Listen for Callee Candidates
      state.calleeCandidateSub = calleeCandidates.snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>;
            _addIceCandidate(state, RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
          }
        }
      });
    } else {
      // 1. Listen for Offer
      state.documentSub = docRef.snapshots().listen((snapshot) async {
        if (snapshot.exists) {
          final data = snapshot.data();
          if (data != null && data['offer'] != null && !state.remoteDescriptionSet) {
            final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
            await pc.setRemoteDescription(offer);
            state.remoteDescriptionSet = true;
            _drainPendingCandidates(state);

            final answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);
            await docRef.update({'answer': answer.toMap()});
          }
        }
      });

      // 2. Listen for Caller Candidates
      state.callerCandidateSub = callerCandidates.snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>;
            _addIceCandidate(state, RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
          }
        }
      });
    }
  }

  Future<void> _addIceCandidate(PeerConnectionState state, RTCIceCandidate candidate) async {
    if (state.remoteDescriptionSet) {
      await state.peerConnection.addCandidate(candidate);
    } else {
      state.pendingCandidates.add(candidate);
    }
  }

  Future<void> _drainPendingCandidates(PeerConnectionState state) async {
    for (final candidate in state.pendingCandidates) {
      await state.peerConnection.addCandidate(candidate);
    }
    state.pendingCandidates.clear();
  }

  Future<void> _cleanupSignaling(String connectionId) async {
    if (_roomId == null) return;
    final docRef = _firestore.collection('meetings').doc(_roomId).collection('connections').doc(connectionId);
    try { await docRef.delete(); } catch (_) {}
    try {
      final caller = await docRef.collection('callerCandidates').get();
      for (var doc in caller.docs) await doc.reference.delete();
      final callee = await docRef.collection('calleeCandidates').get();
      for (var doc in callee.docs) await doc.reference.delete();
    } catch (_) {}
  }

  /// Remove peer (e.g. when they leave)
  Future<void> removePeer(String remoteUid) async {
    final keysToRemove = _connections.keys.where((k) => k.contains(remoteUid)).toList();
    for (final key in keysToRemove) {
      await _connections[key]?.dispose();
      _connections.remove(key);
    }
    _notifyStreamsChanged();
  }

  /// Clean up all connections for current meeting
  Future<void> cleanupSignalingRoom(String meetingId) async {
    // Only cleanup connections where I am caller
    for (final key in _connections.keys) {
      if (key.startsWith('${_myUid}_')) {
        await _cleanupSignaling(key);
      }
    }
  }
  
  void toggleMicrophone(bool enabled) {
    if (localStream != null) {
      for (var track in localStream!.getAudioTracks()) track.enabled = enabled;
    }
  }

  void toggleCamera(bool enabled) {
    if (localStream != null) {
      for (var track in localStream!.getVideoTracks()) track.enabled = enabled;
    }
  }

  Future<void> switchCamera() async {
    if (localStream != null) {
      final videoTrack = localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    }
  }

  void muteRemoteAudio(bool mute) {
    for (final state in _connections.values) {
      if (state.remoteStream != null) {
        final audioTracks = state.remoteStream!.getAudioTracks();
        for (final track in audioTracks) {
          track.enabled = !mute;
        }
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final state in _connections.values) {
      await state.dispose();
    }
    _connections.clear();
    
    localStream?.getTracks().forEach((t) => t.stop());
    await localStream?.dispose();
    
    if (localScreenStream != null) {
      localScreenStream!.getTracks().forEach((t) => t.stop());
      await localScreenStream!.dispose();
    }
    
    _remoteStreamsController.close();
  }
}
