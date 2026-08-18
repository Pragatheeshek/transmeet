import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Service to handle WebRTC media and signaling.
class WebRTCService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  
  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get onRemoteStream => _remoteStreamController.stream;

  final _connectionStateController = StreamController<RTCPeerConnectionState>.broadcast();
  Stream<RTCPeerConnectionState> get onConnectionState => _connectionStateController.stream;

  String? roomId;
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<QuerySnapshot>? _candidateSubscription;

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
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      }
    };

    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  }

  /// Creates a peer connection and adds local tracks.
  Future<void> _createPeerConnection() async {
    peerConnection = await createPeerConnection(configuration, offerSdpConstraints);

    peerConnection?.onTrack = (RTCTrackEvent event) {
      if (event.track.kind == 'video' || event.track.kind == 'audio') {
        remoteStream ??= event.streams.first;
        if (remoteStream != null) {
           _remoteStreamController.add(remoteStream!);
        }
      }
    };

    peerConnection?.onConnectionState = (RTCPeerConnectionState state) {
      _connectionStateController.add(state);
    };

    localStream?.getTracks().forEach((track) {
      peerConnection?.addTrack(track, localStream!);
    });
  }

  /// Called by the HOST to create an offer and listen for an answer.
  Future<void> createOffer(String meetingId) async {
    roomId = meetingId;
    await _createPeerConnection();

    final roomRef = _firestore.collection('meetings').doc(roomId);
    final callerCandidatesCollection = roomRef.collection('callerCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      callerCandidatesCollection.add(candidate.toMap());
    };

    RTCSessionDescription offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    await roomRef.update({'offer': offer.toMap()});

    // Listen for remote answer
    _roomSubscription = roomRef.snapshots().listen((snapshot) async {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        if (peerConnection?.getRemoteDescription() == null && data['answer'] != null) {
          var answer = RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          );
          await peerConnection?.setRemoteDescription(answer);
        }
      }
    });

    // Listen for remote ICE candidates
    _candidateSubscription = roomRef.collection('calleeCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          peerConnection!.addCandidate(
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
    roomId = meetingId;
    await _createPeerConnection();

    final roomRef = _firestore.collection('meetings').doc(roomId);
    final calleeCandidatesCollection = roomRef.collection('calleeCandidates');

    peerConnection?.onIceCandidate = (RTCIceCandidate candidate) {
      calleeCandidatesCollection.add(candidate.toMap());
    };

    final roomDoc = await roomRef.get();
    if (!roomDoc.exists) throw 'Meeting room does not exist.';

    final data = roomDoc.data() as Map<String, dynamic>;
    if (data['offer'] != null) {
      var offer = RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      );
      await peerConnection?.setRemoteDescription(offer);

      var answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);

      await roomRef.update({'answer': answer.toMap()});
    } else {
       throw 'No offer found for this meeting.';
    }

    // Listen for remote ICE candidates
    _candidateSubscription = roomRef.collection('callerCandidates').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          peerConnection!.addCandidate(
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

  /// Cleans up resources.
  Future<void> dispose() async {
    localStream?.getTracks().forEach((track) => track.stop());
    await localStream?.dispose();
    await remoteStream?.dispose();
    await peerConnection?.close();
    await _roomSubscription?.cancel();
    await _candidateSubscription?.cancel();
    _remoteStreamController.close();
    _connectionStateController.close();
  }
}
