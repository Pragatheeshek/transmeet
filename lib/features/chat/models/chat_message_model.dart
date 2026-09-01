import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single chat message in a meeting.
///
/// Stored in Firestore at: meetings/{meetingId}/messages/{messageId}
class ChatMessageModel {
  const ChatMessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  /// Firestore document ID.
  final String messageId;

  /// Firebase UID of the sender.
  final String senderId;

  /// Display name of the sender.
  final String senderName;

  /// Message text content.
  final String text;

  /// When the message was sent.
  final DateTime timestamp;

  // ---------------------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------------------

  factory ChatMessageModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ChatMessageModel(
      messageId: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Guest',
      text: data['text'] as String? ?? '',
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts to Firestore map for writing.
  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
