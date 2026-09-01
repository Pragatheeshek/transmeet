import 'package:cloud_firestore/cloud_firestore.dart';

/// Strongly-typed model representing a meeting stored in Firestore.
///
/// Follows the existing TransMeet architecture — plain Dart class with
/// factory constructors for Firestore serialization.
class MeetingModel {
  const MeetingModel({
    required this.docId,
    required this.meetingId,
    required this.title,
    required this.hostUid,
    required this.hostName,
    required this.hostEmail,
    required this.preferredLanguage,
    required this.createdAt,
    required this.status,
    required this.participantCount,
    this.admissionControl = false,
  });

  /// Firestore document ID (internal — never exposed to the user).
  final String docId;

  /// User-facing meeting ID (e.g. `TM-7K4P92`).
  final String meetingId;

  /// Meeting title provided by the host.
  final String title;

  /// Firebase UID of the host who created the meeting.
  final String hostUid;

  /// Display name of the host.
  final String hostName;

  /// Email of the host.
  final String hostEmail;

  /// Preferred language for translation in this meeting.
  final String preferredLanguage;

  /// Timestamp when the meeting was created.
  final DateTime createdAt;

  /// Current status: `"active"` or `"ended"`.
  final String status;

  /// Number of participants (host counts as 1).
  final int participantCount;

  /// Whether participants need host approval to join.
  ///
  /// `true`  = Google Meet "Host must approve" — participants wait in lobby.
  /// `false` = Anyone with the meeting ID can join directly.
  final bool admissionControl;

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  /// Creates a [MeetingModel] from a Firestore document snapshot.
  factory MeetingModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MeetingModel(
      docId: doc.id,
      meetingId: data['meetingId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      hostUid: data['hostUid'] as String? ?? '',
      hostName: data['hostName'] as String? ?? '',
      hostEmail: data['hostEmail'] as String? ?? '',
      preferredLanguage: data['preferredLanguage'] as String? ?? 'English',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'active',
      participantCount: data['participantCount'] as int? ?? 1,
      admissionControl: data['admissionControl'] as bool? ?? false,
    );
  }

  /// Creates a [MeetingModel] from a raw Firestore data map.
  ///
  /// Useful when constructing from query snapshots that provide
  /// the document ID separately.
  factory MeetingModel.fromMap(String docId, Map<String, dynamic> data) {
    return MeetingModel(
      docId: docId,
      meetingId: data['meetingId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      hostUid: data['hostUid'] as String? ?? '',
      hostName: data['hostName'] as String? ?? '',
      hostEmail: data['hostEmail'] as String? ?? '',
      preferredLanguage: data['preferredLanguage'] as String? ?? 'English',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'active',
      participantCount: data['participantCount'] as int? ?? 1,
      admissionControl: data['admissionControl'] as bool? ?? false,
    );
  }

  /// Converts this model to a Firestore-compatible map for writing.
  ///
  /// Uses [FieldValue.serverTimestamp] for `createdAt` to ensure
  /// server-side consistency.
  Map<String, dynamic> toFirestore() {
    return {
      'meetingId': meetingId,
      'title': title,
      'hostUid': hostUid,
      'hostName': hostName,
      'hostEmail': hostEmail,
      'preferredLanguage': preferredLanguage,
      'createdAt': FieldValue.serverTimestamp(),
      'status': status,
      'participantCount': participantCount,
      'admissionControl': admissionControl,
    };
  }

  /// Converts this model to a map with a raw [Timestamp] instead of
  /// [FieldValue.serverTimestamp], useful for testing and local operations.
  Map<String, dynamic> toMap() {
    return {
      'meetingId': meetingId,
      'title': title,
      'hostUid': hostUid,
      'hostName': hostName,
      'hostEmail': hostEmail,
      'preferredLanguage': preferredLanguage,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'participantCount': participantCount,
      'admissionControl': admissionControl,
    };
  }

  /// Whether this meeting is currently active.
  bool get isActive => status == 'active';

  /// Whether this meeting has ended.
  bool get isEnded => status == 'ended';
}
