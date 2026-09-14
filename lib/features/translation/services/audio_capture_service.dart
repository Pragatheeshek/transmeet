import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Real-time speech capture using on-device speech recognition.
///
/// Uses the `speech_to_text` package which runs natively on Android/iOS
/// for near-instant speech recognition — no file recording, no Whisper API,
/// no network latency for the STT step.
///
/// Flow:
///   Mic → On-device SR (real-time) → Firestore broadcast
///
/// Latency: ~0.3–0.5s (on-device recognition)
class AudioCaptureService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SpeechToText _speech = SpeechToText();

  bool _isRunning = false;
  bool _isDisposed = false;
  bool _isInitialized = false;

  /// Whether the capture is currently active.
  bool get isRunning => _isRunning;

  /// Emits error messages for UI display.
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get onError => _errorController.stream;

  /// Emits when a transcription is successfully broadcast.
  final _transcriptionController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onTranscription =>
      _transcriptionController.stream;

  String _meetingId = '';
  String _lastBroadcastText = '';

  /// Starts real-time speech capture and Firestore broadcasting.
  Future<void> start({required String meetingId}) async {
    if (_isRunning || _isDisposed) return;
    _meetingId = meetingId;
    _isRunning = true;
    _lastBroadcastText = '';

    debugPrint('[AudioCapture] Starting real-time speech capture');

    try {
      if (!_isInitialized) {
        _isInitialized = await _speech.initialize(
          onStatus: _onSpeechStatus,
          onError: (error) {
            debugPrint('[AudioCapture] Speech error: ${error.errorMsg}');
            // These errors are normal operating behavior (silence, no speech
            // detected, or timeout). They are NOT failures — just the speech
            // recognizer saying "I didn't hear anything." Don't show to user.
            const ignoredErrors = {
              'error_no_match',     // Listened but no speech detected
              'error_speech_timeout', // Timed out waiting for speech
              'error_busy',         // Recognizer busy (restarting)
            };
            if (!_isDisposed &&
                !ignoredErrors.contains(error.errorMsg)) {
              _errorController.add(error.errorMsg);
            }
          },
        );
      }

      if (!_isInitialized) {
        _errorController.add('Speech recognition not available on this device');
        _isRunning = false;
        return;
      }

      _startListening();
    } catch (e) {
      debugPrint('[AudioCapture] Init error: $e');
      _errorController.add(e.toString());
      _isRunning = false;
    }
  }

  /// Starts a single listening session.
  void _startListening() {
    if (!_isRunning || _isDisposed || !_isInitialized) return;

    debugPrint('[AudioCapture] Starting listen session');
    _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        autoPunctuation: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  /// Called when speech recognition status changes.
  void _onSpeechStatus(String status) {
    debugPrint('[AudioCapture] Speech status: $status');

    // Auto-restart listening when it stops (due to pause/timeout)
    if (status == 'notListening' || status == 'done') {
      if (_isRunning && !_isDisposed) {
        // Brief delay before restarting to avoid tight loops
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_isRunning && !_isDisposed) {
            _startListening();
          }
        });
      }
    }
  }

  /// Called when speech recognition produces a result.
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!_isRunning || _isDisposed) return;

    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;

    // Only broadcast final results to avoid duplicates
    if (result.finalResult && text != _lastBroadcastText) {
      _lastBroadcastText = text;
      debugPrint('[AudioCapture] Final: "$text"');
      _broadcastToFirestore(text);
    }
  }

  /// Writes the recognized text to Firestore.
  Future<void> _broadcastToFirestore(String text) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Use 'auto' to let Google Translate auto-detect the source language
      final detectedLanguage = _getLanguageFromLocale();

      final docData = {
        'text': text,
        'detectedLanguage': detectedLanguage,
        'speakerUid': user.uid,
        'speakerName':
            user.displayName ?? user.email?.split('@').first ?? 'User',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('meetings')
          .doc(_meetingId)
          .collection('transcriptions')
          .add(docData);

      debugPrint('[AudioCapture] Broadcast: "$text" (lang: $detectedLanguage)');

      if (!_isDisposed) {
        _transcriptionController.add({
          'text': text,
          'detectedLanguage': detectedLanguage,
        });
      }
    } catch (e) {
      debugPrint('[AudioCapture] Broadcast error: $e');
      if (!_isDisposed) {
        _errorController.add('Failed to broadcast: $e');
      }
    }
  }

  /// Returns 'auto' so Google Translate auto-detects the source language.
  /// This avoids needing to know what language the speaker is using.
  String _getLanguageFromLocale() {
    return 'auto';
  }

  /// Stops the capture.
  void stop() {
    debugPrint('[AudioCapture] Stopping');
    _isRunning = false;
    try {
      _speech.stop();
    } catch (_) {}
  }

  /// Releases all resources.
  Future<void> dispose() async {
    _isDisposed = true;
    _isRunning = false;
    try {
      _speech.stop();
      _speech.cancel();
    } catch (_) {}
    await _errorController.close();
    await _transcriptionController.close();
  }
}
