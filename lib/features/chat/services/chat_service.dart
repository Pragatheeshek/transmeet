import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:transmeet/features/chat/models/chat_message_model.dart';

/// Service for sending and receiving chat messages in a meeting.
///
/// Messages are stored in: meetings/{meetingDocId}/messages/{auto}
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Returns a real-time stream of chat messages for a meeting,
  /// ordered by timestamp ascending (oldest first).
  Stream<List<ChatMessageModel>> onMessagesChanged(String meetingDocId) {
    return _firestore
        .collection('meetings')
        .doc(meetingDocId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessageModel.fromFirestore(doc))
            .toList());
  }

  /// Sends a text message in the given meeting.
  ///
  /// Returns silently on success. Throws a user-friendly [String] on failure.
  Future<void> sendMessage({
    required String meetingDocId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw 'You must be signed in to send a message.';

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    try {
      await _firestore
          .collection('meetings')
          .doc(meetingDocId)
          .collection('messages')
          .add({
        'senderId': user.uid,
        'senderName':
            user.displayName ?? user.email?.split('@').first ?? 'Guest',
        'text': trimmed,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[Chat] Failed to send message: $e');
      throw 'Failed to send message. Please try again.';
    }
  }
}
