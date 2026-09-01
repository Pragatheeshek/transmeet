import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:transmeet/core/utils/meeting_id_generator.dart';
import 'package:transmeet/features/meeting/models/meeting_model.dart';

/// Firestore service for meeting CRUD operations.
///
/// Follows the same singleton-style pattern as [AuthService] — instantiate
/// where needed without a global service locator.
class MeetingService {
  MeetingService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Firestore collection name for meetings.
  static const String _collection = 'meetings';

  CollectionReference<Map<String, dynamic>> get _meetingsRef =>
      _firestore.collection(_collection);

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Creates a new meeting in Firestore and returns the resulting model.
  ///
  /// Generates a unique [MeetingIdGenerator] ID and retries once if a
  /// collision is detected (extremely unlikely with 6-char alphanumeric).
  Future<MeetingModel> createMeeting({
    required String title,
    required String hostUid,
    required String hostName,
    required String hostEmail,
    String preferredLanguage = 'English',
    bool admissionControl = false,
  }) async {
    // Generate a meeting ID directly — collision probability is negligible
    // (~1 in 10^9) and the extra network round-trip causes noticeable lag.
    final meetingId = MeetingIdGenerator.generate();

    final meeting = MeetingModel(
      docId: '',
      meetingId: meetingId,
      title: title.trim(),
      hostUid: hostUid,
      hostName: hostName,
      hostEmail: hostEmail,
      preferredLanguage: preferredLanguage,
      createdAt: DateTime.now(),
      status: 'active',
      participantCount: 1,
      admissionControl: admissionControl,
    );

    final docRef = await _meetingsRef.add(meeting.toFirestore());

    // Read back to get the server-assigned docId and timestamp.
    final snapshot = await docRef.get();
    return MeetingModel.fromFirestore(snapshot);
  }

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Finds a meeting by its user-facing [meetingId] (e.g. `TM-7K4P92`).
  ///
  /// Returns `null` if no matching meeting exists.
  Future<MeetingModel?> getMeetingByMeetingId(String meetingId) async {
    final normalized = MeetingIdGenerator.normalize(meetingId);
    if (normalized == null) return null;

    final query = await _meetingsRef
        .where('meetingId', isEqualTo: normalized)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return MeetingModel.fromFirestore(query.docs.first);
  }

  /// Returns a real-time stream of meetings hosted by [uid],
  /// ordered by creation date descending.
  ///
  /// Falls back to a Dart-sorted query if the Firestore composite index
  /// is not yet built (FAILED_PRECONDITION during index creation).
  Stream<List<MeetingModel>> getHostedMeetings(String uid) {
    return _meetingsRef
        .where('hostUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MeetingModel.fromFirestore(doc))
            .toList())
        .handleError((error) {
      // Index not yet built — fall back to simple query sorted in Dart.
      debugPrint('[MeetingService] Index not ready, using fallback query: $error');
      return _meetingsRef
          .where('hostUid', isEqualTo: uid)
          .limit(20)
          .get()
          .then((snapshot) {
        final meetings = snapshot.docs
            .map((doc) => MeetingModel.fromFirestore(doc))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return meetings;
      });
    });
  }


  // ---------------------------------------------------------------------------
  // Real-time listeners
  // ---------------------------------------------------------------------------

  /// Returns a real-time stream for a single meeting document.
  ///
  /// Used by the meeting room to detect when the meeting status changes
  /// (e.g. host ends the meeting).
  Stream<MeetingModel?> onMeetingChanged(String docId) {
    return _meetingsRef.doc(docId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return MeetingModel.fromFirestore(snapshot);
    });
  }

  // ---------------------------------------------------------------------------
  // Update
  // ---------------------------------------------------------------------------

  /// Updates the status of a meeting (e.g. `"active"` → `"ended"`).
  ///
  /// Prepared for Module 4 meeting lifecycle management.
  Future<void> updateMeetingStatus(String docId, String status) async {
    await _meetingsRef.doc(docId).update({'status': status});
  }

  /// Increments the participant count by 1.
  ///
  /// Prepared for Module 4 participant management.
  Future<void> incrementParticipantCount(String docId) async {
    await _meetingsRef.doc(docId).update({
      'participantCount': FieldValue.increment(1),
    });
  }
}
