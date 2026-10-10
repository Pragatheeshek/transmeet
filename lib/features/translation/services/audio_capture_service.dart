import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:transmeet/features/translation/services/translation_api_client.dart';

/// Real-time speech capture using OpenAI Whisper API.
///
/// Records audio in short segments using the `record` package, sends each
/// segment to the Whisper API for transcription, then broadcasts the result
/// to Firestore for other meeting participants.
///
/// Flow:
///   Mic → Record segment → Whisper API → Firestore broadcast
///
/// Latency: ~1–3s per segment (recording + Whisper round-trip)
///
/// ## Segment Strategy
///
/// Records 5-second segments back-to-back. Each segment is encoded as AAC
/// (M4A container) which keeps file size small (~40–80 KB per 5s segment)
/// and is natively supported by Whisper.
///
/// ## Why file-based recording (not streaming)?
///
/// The `record` package's `startStream()` only supports `pcm16bits` and
/// `opus` encoders for streaming on Android. WAV streaming is NOT supported
/// and throws `PlatformException`. File-based recording with AAC avoids
/// this entirely and produces compact files that Whisper accepts natively.
class AudioCaptureService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TranslationApiClient _apiClient = TranslationApiClient();
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRunning = false;
  bool _isDisposed = false;
  bool _isPaused = false;

  /// Whether the capture is currently active.
  bool get isRunning => _isRunning;

  /// Pauses or resumes the audio capture (e.g. to prevent recording TTS output).
  Future<void> pauseCapture(bool pause) async {
    if (_isPaused == pause) return;
    _isPaused = pause;
    debugPrint('[AudioCapture] Capture paused: $pause');
    if (_isRunning && !_isDisposed) {
      try {
        if (pause && await _recorder.isRecording()) {
          await _recorder.pause();
        } else if (!pause && await _recorder.isPaused()) {
          await _recorder.resume();
        }
      } catch (e) {
        debugPrint('[AudioCapture] Pause/resume error: $e');
      }
    }
  }

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

  /// Duration of each recording segment.
  static const Duration _segmentDuration = Duration(seconds: 5);

  /// Startup delay to let WebRTC's audio session settle before
  /// opening a second mic via the recorder.
  static const Duration _startupDelay = Duration(milliseconds: 1500);

  String? _preferredLanguage;

  /// Starts real-time speech capture and Firestore broadcasting.
  Future<void> start({required String meetingId, String? preferredLanguage}) async {
    if (_isRunning || _isDisposed) return;
    _meetingId = meetingId;
    _preferredLanguage = preferredLanguage;
    _isRunning = true;
    _lastBroadcastText = '';

    debugPrint('[AudioCapture] Starting Whisper-based speech capture');

    // Check backend health with retries — the first HTTP call on Android
    // can be slow (DNS, cleartext policy init, TCP handshake).
    bool isHealthy = false;
    for (int attempt = 1; attempt <= 3; attempt++) {
      isHealthy = await _apiClient.isHealthy();
      if (isHealthy) break;
      debugPrint('[AudioCapture] Health check attempt $attempt/3 failed');
      if (attempt < 3) {
        await Future.delayed(const Duration(seconds: 3));
        if (!_isRunning || _isDisposed) return;
      }
    }
    if (!isHealthy) {
      _errorController.add(
          'Translation backend is unreachable. Please check your connection.');
      _isRunning = false;
      return;
    }

    // Check microphone permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _errorController.add('Microphone permission denied.');
      _isRunning = false;
      return;
    }

    // Give WebRTC's getUserMedia time to fully initialize the audio
    // session. Starting recording too early on Android can cause
    // conflicts with the audio focus.
    debugPrint('[AudioCapture] Waiting ${_startupDelay.inMilliseconds}ms '
        'for WebRTC audio session to settle...');
    await Future.delayed(_startupDelay);

    if (!_isRunning || _isDisposed) return;

    // Start the record-transcribe loop
    _recordLoop();
  }

  /// Continuously records audio segments to temp files and sends them
  /// to Whisper.
  ///
  /// Uses file-based recording (`_recorder.start()`) with the AAC encoder
  /// instead of streaming, because `startStream()` does NOT support WAV
  /// on Android and throws a PlatformException.
  Future<void> _recordLoop() async {
    // Get a temp directory once — reuse across segments
    final tempDir = await getTemporaryDirectory();
    int segmentIndex = 0;

    while (_isRunning && !_isDisposed) {
      final segmentPath =
          '${tempDir.path}/transmeet_segment_${segmentIndex++}.m4a';

      try {
        // ── Record to file ────────────────────────────────────────────────
        // Stop any existing recording first (defensive — avoids
        // 'already recording' exception on some Android devices).
        if (await _recorder.isRecording()) {
          await _recorder.stop();
        }

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            sampleRate: 16000,
            numChannels: 1,
            bitRate: 128000,
          ),
          path: segmentPath,
        );

        // Wait for the segment duration in 100ms chunks to allow mid-segment pause/resume
        final chunks = _segmentDuration.inMilliseconds ~/ 100;
        for (int i = 0; i < chunks; i++) {
          if (!_isRunning || _isDisposed) break;
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Stop recording — returns the file path (or null on error)
        final resultPath = await _recorder.stop();

        if (!_isRunning || _isDisposed) break;

        // ── Read the recorded file ────────────────────────────────────────
        final file = File(resultPath ?? segmentPath);
        if (!await file.exists()) {
          debugPrint('[AudioCapture] Segment file not found, skipping');
          continue;
        }

        final audioBytes = await file.readAsBytes();

        // Clean up temp file immediately
        try {
          await file.delete();
        } catch (_) {}

        // Skip if too little audio was captured (likely silence/noise)
        if (audioBytes.length < 1000) {
          debugPrint(
              '[AudioCapture] Segment too short (${audioBytes.length} bytes), skipping');
          continue;
        }

        debugPrint(
            '[AudioCapture] Recorded segment: ${audioBytes.length} bytes');

        // Send to Whisper in the background (don't block the next segment)
        _transcribeAndBroadcast(audioBytes);
      } catch (e) {
        debugPrint('[AudioCapture] Recording error: $e');
        if (!_isDisposed) {
          _errorController.add('Recording error: $e');
        }
        // Wait before retrying
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Sends audio to the backend for transcription and broadcasts the result to Firestore.
  Future<void> _transcribeAndBroadcast(Uint8List audioBytes) async {
    if (!_isRunning || _isDisposed) return;

    try {
      final result = await _apiClient.transcribe(
        audioBytes,
        filename: 'segment.m4a',
        language: _preferredLanguage,
      );

      final text = (result['text'] as String? ?? '').trim();
      final detectedLanguage = result['language'] as String? ?? 'auto';

      if (text.isEmpty) {
        debugPrint('[AudioCapture] Whisper returned empty text, skipping');
        return;
      }

      // Skip if this is the same text we just broadcast (duplicate)
      if (text == _lastBroadcastText) {
        debugPrint('[AudioCapture] Duplicate text, skipping');
        return;
      }
      _lastBroadcastText = text;

      debugPrint('[AudioCapture] Whisper result: "$text" (lang: $detectedLanguage)');
      await _broadcastToFirestore(text, detectedLanguage);
    } catch (e) {
      debugPrint('[AudioCapture] Whisper error: $e');
      if (!_isDisposed) {
        _errorController.add(e.toString());
      }
    }
  }

  /// Writes the recognized text to Firestore.
  Future<void> _broadcastToFirestore(
      String text, String detectedLanguage) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
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

      debugPrint(
          '[AudioCapture] Broadcast: "$text" (lang: $detectedLanguage)');

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

  /// Stops the capture.
  ///
  /// Note: this sets the running flag synchronously and then stops the
  /// recorder. The [_recordLoop] will break on the next iteration check.
  void stop() {
    debugPrint('[AudioCapture] Stopping');
    _isRunning = false;
    // Stop the recorder without awaiting — the loop will break on its own.
    // We cannot await here because stop() is synchronous by design.
    _recorder.stop().catchError((e) {
      debugPrint('[AudioCapture] Recorder stop error (ignored): $e');
      return null; // stop() returns Future<String?> — null is a valid result.
    });
  }

  /// Releases all resources.
  Future<void> dispose() async {
    _isDisposed = true;
    _isRunning = false;
    try {
      await _recorder.stop();
      _recorder.dispose();
    } catch (_) {}
    _apiClient.dispose();
    await _errorController.close();
    await _transcriptionController.close();
  }
}
