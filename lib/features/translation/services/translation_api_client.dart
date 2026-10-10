import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/features/translation/models/translation_language.dart';

/// HTTP client for communicating with the TransMeet translation backend.
///
/// All AI service calls (Whisper, Google Translate, Google TTS) are routed
/// through the Node.js backend so that API keys never touch the Flutter client.
class TranslationApiClient {
  TranslationApiClient({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => AppConstants.backendBaseUrl;

  /// Timeout for API calls.
  ///
  /// Set generously because:
  /// - The Google Translate API cold-start can take 15–20s on first call.
  /// - Multipart uploads for Whisper STT are larger and slower on mobile.
  static const Duration _timeout = Duration(seconds: 45);

  // ---------------------------------------------------------------------------
  // Speech-to-Text (Whisper)
  // ---------------------------------------------------------------------------

  /// Sends raw audio bytes to the backend for transcription.
  ///
  /// Returns a map with `text` and `language` keys.
  /// Throws a user-friendly [String] on failure.
  Future<Map<String, dynamic>> transcribe(Uint8List audioBytes, {String filename = 'audio.wav', String? language}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/translation/transcribe');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: filename,
        ));

      if (language != null && language.isNotEmpty && language != 'auto') {
        request.fields['language'] = TranslationLanguage.baseCode(language);
      }

      // Timeout covers both the upload AND the Whisper processing time.
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      final error = _parseError(response);
      throw error;
    } on http.ClientException {
      throw 'Cannot reach the translation server. Check your network.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Speech recognition failed: ${e.runtimeType}';
    }
  }

  // ---------------------------------------------------------------------------
  // Text Translation (Google Translate)
  // ---------------------------------------------------------------------------

  /// Translates text from [sourceLanguage] to [targetLanguage].
  ///
  /// Returns a map with `translatedText`, `sourceLanguage`, `targetLanguage`.
  /// Throws a user-friendly [String] on failure.
  Future<Map<String, dynamic>> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/translation/translate');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'sourceLanguage': sourceLanguage == 'auto' ? 'auto' : TranslationLanguage.baseCode(sourceLanguage),
              'targetLanguage': TranslationLanguage.baseCode(targetLanguage),
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      final error = _parseError(response);
      throw error;
    } on http.ClientException {
      throw 'No internet connection. Please check your network.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Translation failed. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Text-to-Speech (Google TTS)
  // ---------------------------------------------------------------------------

  /// Synthesizes speech from text in the given language.
  ///
  /// Returns a map with `audioContent` (base64-encoded audio).
  /// Throws a user-friendly [String] on failure.
  Future<Map<String, dynamic>> synthesize({
    required String text,
    required String languageCode,
  }) async {
    try {
      final safeCode = TranslationLanguage.fromCode(languageCode)?.code ?? TranslationLanguage.nameToCode(languageCode) ?? languageCode;
      final uri = Uri.parse('$_baseUrl/api/translation/synthesize');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'languageCode': safeCode,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      final error = _parseError(response);
      throw error;
    } on http.ClientException {
      throw 'No internet connection. Please check your network.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Text-to-speech failed. Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Health Check
  // ---------------------------------------------------------------------------

  /// Checks if the backend is reachable.
  ///
  /// Retries once after 2 seconds if the first attempt fails, because the
  /// first HTTP call on Android can be slow (DNS resolution, TCP handshake,
  /// cleartext policy checks).
  Future<bool> isHealthy() async {
    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final uri = Uri.parse('$_baseUrl/api/translation/health');
        final response = await _client
            .get(uri)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) return true;
      } catch (e) {
        debugPrint('[TranslationApiClient] Health check attempt $attempt failed: $e');
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _parseError(http.Response response) {
    try {
      final body = json.decode(response.body) as Map<String, dynamic>;
      return body['error'] as String? ?? 'An unexpected error occurred.';
    } catch (_) {
      return 'Server error (${response.statusCode}). Please try again.';
    }
  }

  /// Disposes the underlying HTTP client.
  void dispose() {
    _client.close();
  }
}
