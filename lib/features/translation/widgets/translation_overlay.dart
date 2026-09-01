import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:transmeet/features/translation/models/translation_language.dart';
import 'package:transmeet/features/translation/models/translation_result.dart';
import 'package:transmeet/features/translation/models/translation_status.dart';
import 'package:transmeet/features/translation/services/translation_pipeline_service.dart';
import 'package:transmeet/features/translation/widgets/translated_caption.dart';
import 'package:transmeet/features/translation/widgets/translation_status_indicator.dart';

/// Full-screen overlay for translation controls and captions on the meeting screen.
///
/// Manages recording audio segments, sending them through the translation pipeline,
/// and displaying results.
class TranslationOverlay extends StatefulWidget {
  const TranslationOverlay({
    super.key,
    required this.isEnabled,
    required this.meetingDocId,
    required this.localStream,
  });

  /// Whether translation is currently enabled.
  final bool isEnabled;

  /// Firestore document ID of the current meeting.
  final String meetingDocId;

  /// The local media stream (for audio recording).
  final MediaStream? localStream;

  @override
  State<TranslationOverlay> createState() => _TranslationOverlayState();
}

class _TranslationOverlayState extends State<TranslationOverlay> {
  final _pipelineService = TranslationPipelineService();
  TranslationResult? _lastResult;
  TranslationStatus _status = TranslationStatus.idle;
  String? _errorMessage;
  bool _isRecording = false;

  String _myLanguageCode = 'en';
  String _myLanguageName = 'English';

  StreamSubscription<TranslationResult>? _resultSub;
  StreamSubscription<String>? _errorSub;

  // Audio recording
  MediaRecorder? _mediaRecorder;

  @override
  void initState() {
    super.initState();
    _loadUserLanguage();

    _pipelineService.statusNotifier.addListener(_onStatusChanged);
    _resultSub = _pipelineService.onResult.listen((result) {
      if (mounted) setState(() => _lastResult = result);
    });
    _errorSub = _pipelineService.onError.listen((error) {
      if (mounted) setState(() => _errorMessage = error);
    });
  }

  void _onStatusChanged() {
    if (mounted) {
      setState(() => _status = _pipelineService.statusNotifier.value);
    }
  }

  Future<void> _loadUserLanguage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final langCode = data?['preferredLanguageCode'] as String? ?? 'en';
        final lang = TranslationLanguage.fromCode(langCode);
        if (lang != null && mounted) {
          setState(() {
            _myLanguageCode = lang.code;
            _myLanguageName = lang.name;
          });
        }
      }
    } catch (_) {
      // Use default English
    }
  }

  /// Records a short audio segment and sends it through the pipeline.
  Future<void> _recordAndTranslate() async {
    if (_isRecording || _status != TranslationStatus.idle) return;

    setState(() {
      _isRecording = true;
      _status = TranslationStatus.listening;
      _errorMessage = null;
    });

    _pipelineService.statusNotifier.value = TranslationStatus.listening;

    try {
      // Use flutter_webrtc's MediaRecorder to capture audio from the local stream
      final stream = widget.localStream;
      if (stream == null) {
        throw 'No microphone stream available.';
      }

      // Create a media recorder
      _mediaRecorder = MediaRecorder();
      await _mediaRecorder!.start(
        stream.id,
        audioChannel: RecorderAudioChannel.INPUT,
      );

      // Record for 4 seconds
      await Future.delayed(const Duration(seconds: 4));

      // Stop recording and get the file path
      final filePath = await _mediaRecorder!.stop();

      setState(() => _isRecording = false);

      if (filePath != null) {
        // Read the recorded file
        final file = File(filePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) {
            await _pipelineService.processAudioSegment(
              audioBytes: Uint8List.fromList(bytes),
              targetLanguageCode: _myLanguageCode,
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _errorMessage = e.toString();
      });
      _pipelineService.statusNotifier.value = TranslationStatus.error;
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        _pipelineService.statusNotifier.value = TranslationStatus.idle;
      }
    }
  }

  @override
  void dispose() {
    _pipelineService.statusNotifier.removeListener(_onStatusChanged);
    _resultSub?.cancel();
    _errorSub?.cancel();
    _pipelineService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status indicator
          Center(
            child: TranslationStatusIndicator(status: _status),
          ),
          const SizedBox(height: 8),

          // Error message
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Captions
          if (_lastResult != null) ...[
            const SizedBox(height: 8),
            TranslatedCaption(result: _lastResult),
          ],

          const SizedBox(height: 8),

          // Translation info + record button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.translate_rounded,
                    color: Colors.cyanAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Translating → $_myLanguageName',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
                // Record button
                GestureDetector(
                  onTap: _isRecording || _status != TranslationStatus.idle
                      ? null
                      : _recordAndTranslate,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? Colors.redAccent
                          : Colors.cyanAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: _isRecording ? Colors.white : Colors.cyanAccent,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
