import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a participant in a meeting.
///
/// Stored in Firestore at: meetings/{meetingId}/participants/{userId}
class ParticipantModel {
  const ParticipantModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.preferredLanguage,
    required this.isHost,
    required this.isCameraOn,
    required this.isMicOn,
    required this.status,
    required this.joinedAt,
  });

  /// Firebase UID (also the Firestore document ID).
  final String uid;

  /// Display name of the participant.
  final String displayName;

  /// Email of the participant.
  final String email;

  /// Preferred language for translation (e.g. "English", "Tamil").
  final String preferredLanguage;

  /// Whether this participant is the meeting host.
  final bool isHost;

  /// Whether the participant's camera is enabled.
  final bool isCameraOn;

  /// Whether the participant's microphone is enabled.
  final bool isMicOn;

  /// Participant status: "joined" or "left".
  final String status;

  /// Timestamp when the participant joined the meeting.
  final DateTime joinedAt;

  /// Whether this participant is currently active in the meeting.
  bool get isJoined => status == 'joined';

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  factory ParticipantModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ParticipantModel(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'Guest',
      email: data['email'] as String? ?? '',
      preferredLanguage: data['preferredLanguage'] as String? ?? 'English',
      isHost: data['isHost'] as bool? ?? false,
      isCameraOn: data['isCameraOn'] as bool? ?? true,
      isMicOn: data['isMicOn'] as bool? ?? true,
      status: data['status'] as String? ?? 'joined',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Creates a [ParticipantModel] from a raw map (for testing).
  factory ParticipantModel.fromMap(String uid, Map<String, dynamic> data) {
    return ParticipantModel(
      uid: uid,
      displayName: data['displayName'] as String? ?? 'Guest',
      email: data['email'] as String? ?? '',
      preferredLanguage: data['preferredLanguage'] as String? ?? 'English',
      isHost: data['isHost'] as bool? ?? false,
      isCameraOn: data['isCameraOn'] as bool? ?? true,
      isMicOn: data['isMicOn'] as bool? ?? true,
      status: data['status'] as String? ?? 'joined',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts to a Firestore-compatible map for writing.
  /// Uses [FieldValue.serverTimestamp] for `joinedAt`.
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'preferredLanguage': preferredLanguage,
      'isHost': isHost,
      'isCameraOn': isCameraOn,
      'isMicOn': isMicOn,
      'status': status,
      'joinedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Converts to a map with a raw [Timestamp] for testing.
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'preferredLanguage': preferredLanguage,
      'isHost': isHost,
      'isCameraOn': isCameraOn,
      'isMicOn': isMicOn,
      'status': status,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}
