import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'package:transmeet/features/translation/models/translation_result.dart';
import 'package:transmeet/features/translation/models/translation_status.dart';
import 'package:transmeet/features/translation/services/translation_api_client.dart';

/// Orchestrates the complete translation pipeline:
///
/// Record audio segment → Whisper STT → Translate → Google TTS → Play audio
///
/// Exposes streams for UI consumption:
/// - [statusNotifier] — current pipeline state
/// - [onResult] — translation results (original + translated text)
class TranslationPipelineService {
  TranslationPipelineService({
    TranslationApiClient? apiClient,
  }) : _apiClient = apiClient ?? TranslationApiClient();

  final TranslationApiClient _apiClient;
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Current pipeline status for UI display.
  final ValueNotifier<TranslationStatus> statusNotifier =
      ValueNotifier(TranslationStatus.idle);

  /// Emits translation results as they complete.
  final _resultController = StreamController<TranslationResult>.broadcast();
  Stream<TranslationResult> get onResult => _resultController.stream;

  /// Emits error messages.
  final _errorController = StreamController<String>.broadcast();
  Stream<String> get onError => _errorController.stream;

  bool _isDisposed = false;

  // ---------------------------------------------------------------------------
  // Full Pipeline
  // ---------------------------------------------------------------------------

  /// Runs the complete translation pipeline on an audio segment.
  ///
  /// [audioBytes] — raw audio data (WAV or similar format)
  /// [sourceLanguageCode] — detected or user-specified source language
  /// [targetLanguageCode] — user's preferred language
  Future<void> processAudioSegment({
    required Uint8List audioBytes,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  }) async {
    if (_isDisposed) return;

    try {
      // Step 1: Transcribe
      statusNotifier.value = TranslationStatus.transcribing;
      final transcription = await _apiClient.transcribe(audioBytes);
      final text = transcription['text'] as String? ?? '';
      final detectedLanguage =
          sourceLanguageCode ?? (transcription['language'] as String? ?? 'en');

      if (text.trim().isEmpty) {
        statusNotifier.value = TranslationStatus.idle;
        return;
      }

      // Skip translation if source == target
      if (detectedLanguage == targetLanguageCode) {
        final result = TranslationResult.fromTranscriptionAndTranslation(
          originalText: text,
          translatedText: text,
          sourceLanguage: detectedLanguage,
          targetLanguage: targetLanguageCode,
        );
        _resultController.add(result);
        statusNotifier.value = TranslationStatus.completed;
        await Future.delayed(const Duration(seconds: 2));
        if (!_isDisposed) statusNotifier.value = TranslationStatus.idle;
        return;
      }

      // Step 2: Translate
      statusNotifier.value = TranslationStatus.translating;
      final translation = await _apiClient.translate(
        text: text,
        sourceLanguage: detectedLanguage,
        targetLanguage: targetLanguageCode,
      );
      final translatedText = translation['translatedText'] as String? ?? '';

      final result = TranslationResult.fromTranscriptionAndTranslation(
        originalText: text,
        translatedText: translatedText,
        sourceLanguage: detectedLanguage,
        targetLanguage: targetLanguageCode,
      );
      _resultController.add(result);

      // Step 3: Synthesize
      statusNotifier.value = TranslationStatus.synthesizing;
      final ttsResponse = await _apiClient.synthesize(
        text: translatedText,
        languageCode: targetLanguageCode,
      );
      final audioContent = ttsResponse['audioContent'] as String? ?? '';

      if (audioContent.isNotEmpty) {
        // Step 4: Play
        statusNotifier.value = TranslationStatus.playing;
        await _playBase64Audio(audioContent);
      }

      statusNotifier.value = TranslationStatus.completed;
      await Future.delayed(const Duration(seconds: 2));
      if (!_isDisposed) statusNotifier.value = TranslationStatus.idle;
    } catch (e) {
      if (_isDisposed) return;
      statusNotifier.value = TranslationStatus.error;
      _errorController.add(e.toString());

      // Reset to idle after showing error
      await Future.delayed(const Duration(seconds: 3));
      if (!_isDisposed) statusNotifier.value = TranslationStatus.idle;
    }
  }

  // ---------------------------------------------------------------------------
  // Audio Playback
  // ---------------------------------------------------------------------------

  /// Decodes base64 audio and plays it via just_audio.
  Future<void> _playBase64Audio(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/tts_output_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);

      await _audioPlayer.setFilePath(file.path);
      await _audioPlayer.play();

      // Wait for playback to complete
      await _audioPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );

      // Clean up temp file
      try {
        await file.delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('[TranslationPipeline] Audio playback error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Releases all resources.
  Future<void> dispose() async {
    _isDisposed = true;
    statusNotifier.dispose();
    await _resultController.close();
    await _errorController.close();
    await _audioPlayer.dispose();
    _apiClient.dispose();
  }
}
