import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:transmeet/features/meeting/models/participant_model.dart';

/// Service for managing participant presence in a meeting.
///
/// Participants are stored in: meetings/{meetingId}/participants/{userId}
class ParticipantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns a real-time stream of active participants for a meeting.
  ///
  /// Filters in Dart (not Firestore) to avoid requiring a composite index
  /// that may not be deployed — a missing index silently returns 0 results.
  Stream<List<ParticipantModel>> onParticipantsChanged(String meetingId) {
    return _firestore
        .collection('meetings')
        .doc(meetingId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ParticipantModel.fromFirestore(doc))
          .where((p) => p.status == 'joined')
          .toList();
    });
  }

  /// Returns a real-time stream of participants waiting for admission.
  Stream<List<ParticipantModel>> onWaitingParticipants(String meetingId) {
    return _firestore
        .collection('meetings')
        .doc(meetingId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ParticipantModel.fromFirestore(doc))
          .where((p) => p.status == 'waiting')
          .toList();
    });
  }

  /// Adds the current user as a participant in the meeting.
  ///
  /// Uses `set()` so re-joining is idempotent (no duplicate records).
  /// If [initialStatus] is 'waiting', the participant waits for host approval.
  Future<void> joinMeeting({
    required String meetingId,
    required bool isHost,
    required String preferredLanguage,
    String initialStatus = 'joined',
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw 'User not authenticated';

    debugPrint('[Meeting] Participant joining: ${user.displayName ?? user.email}');

    final participantRef = _firestore
        .collection('meetings')
        .doc(meetingId)
        .collection('participants')
        .doc(user.uid);

    await participantRef.set({
      'displayName': user.displayName ?? user.email?.split('@').first ?? 'Guest',
      'email': user.email ?? '',
      'preferredLanguage': preferredLanguage,
      'isHost': isHost,
      'isCameraOn': true,
      'isMicOn': true,
      'status': initialStatus,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    debugPrint('[Meeting] Participant status: $initialStatus');
  }

  /// Marks the current user as "left" and then deletes the participant document.
  Future<void> leaveMeeting(String meetingId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    debugPrint('[Meeting] Participant leaving: ${user.uid}');

    final participantRef = _firestore
        .collection('meetings')
        .doc(meetingId)
        .collection('participants')
        .doc(user.uid);

    try {
      // First mark as left so listeners see the status change immediately.
      await participantRef.update({'status': 'left'});
      // Then delete the document.
      await participantRef.delete();
      debugPrint('[Meeting] Participant removed from Firestore');
    } catch (e) {
      // Document may already be deleted — safe to ignore.
      debugPrint('[Meeting] Leave cleanup error (safe to ignore): $e');
    }
  }

  /// Updates the camera/mic status for the current user.
  Future<void> updateMediaStatus({
    required String meetingId,
    bool? isCameraOn,
    bool? isMicOn,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{};
    if (isCameraOn != null) updates['isCameraOn'] = isCameraOn;
    if (isMicOn != null) updates['isMicOn'] = isMicOn;

    if (updates.isNotEmpty) {
      try {
        final participantRef = _firestore
            .collection('meetings')
            .doc(meetingId)
            .collection('participants')
            .doc(user.uid);
        await participantRef.update(updates);
      } catch (e) {
        debugPrint('[Meeting] Failed to update media status: $e');
      }
    }
  }

  /// Reads the user's preferred language from the `users` collection.
  ///
  /// Falls back to [defaultLanguage] if not set.
  Future<String> getUserPreferredLanguage({String defaultLanguage = 'English'}) async {
    final user = _auth.currentUser;
    if (user == null) return defaultLanguage;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['preferredLanguage'] as String? ?? defaultLanguage;
      }
    } catch (e) {
      debugPrint('[Meeting] Failed to read preferred language: $e');
    }

    return defaultLanguage;
  }

  // ---------------------------------------------------------------------------
  // Admission Control
  // ---------------------------------------------------------------------------

  /// Admits a waiting participant (host only).
  Future<void> admitParticipant(String meetingId, String participantUid) async {
    try {
      await _firestore
          .collection('meetings')
          .doc(meetingId)
          .collection('participants')
          .doc(participantUid)
          .update({'status': 'joined'});
      debugPrint('[Admission] Admitted participant: $participantUid');
    } catch (e) {
      debugPrint('[Admission] Failed to admit: $e');
    }
  }

  /// Denies a waiting participant (host only) — removes their document.
  Future<void> denyParticipant(String meetingId, String participantUid) async {
    try {
      await _firestore
          .collection('meetings')
          .doc(meetingId)
          .collection('participants')
          .doc(participantUid)
          .update({'status': 'denied'});
      // Then delete after a short delay so the participant's listener fires.
      await Future.delayed(const Duration(milliseconds: 500));
      await _firestore
          .collection('meetings')
          .doc(meetingId)
          .collection('participants')
          .doc(participantUid)
          .delete();
      debugPrint('[Admission] Denied participant: $participantUid');
    } catch (e) {
      debugPrint('[Admission] Failed to deny: $e');
    }
  }

  /// Returns a real-time stream of the current user's participant status.
  ///
  /// Used by the lobby to detect when the host admits/denies.
  Stream<String?> onMyStatusChanged(String meetingId) {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('meetings')
        .doc(meetingId)
        .collection('participants')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return 'denied';
      return snapshot.data()?['status'] as String?;
    });
  }
}
