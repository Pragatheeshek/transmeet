import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'package:transmeet/core/constants/app_constants.dart';

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
  static const Duration _timeout = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // Speech-to-Text (Whisper)
  // ---------------------------------------------------------------------------

  /// Sends raw audio bytes to the backend for transcription.
  ///
  /// Returns a map with `text` and `language` keys.
  /// Throws a user-friendly [String] on failure.
  Future<Map<String, dynamic>> transcribe(Uint8List audioBytes, {String filename = 'audio.wav'}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/translation/transcribe');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: filename,
        ));

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      final error = _parseError(response);
      throw error;
    } on http.ClientException {
      throw 'No internet connection. Please check your network.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Speech recognition failed. Please try again.';
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
              'sourceLanguage': sourceLanguage,
              'targetLanguage': targetLanguage,
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
      final uri = Uri.parse('$_baseUrl/api/translation/synthesize');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': text,
              'languageCode': languageCode,
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
  Future<bool> isHealthy() async {
    try {
      final uri = Uri.parse('$_baseUrl/api/translation/health');
      final response = await _client.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
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
