import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for transcribing audio via the OpenAI Whisper API.
///
/// The API key is loaded from the `.env` file bundled with the app.
/// Audio bytes (WAV/M4A) are sent as a multipart upload to
/// `https://api.openai.com/v1/audio/transcriptions`.
class WhisperService {
  WhisperService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Using Groq's free OpenAI-compatible API for Whisper
  static const String _whisperUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';

  /// Timeout for Whisper API calls.
  static const Duration _timeout = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // API Key Management
  // ---------------------------------------------------------------------------

  /// Retrieves the OpenAI API key from the .env file, or null if not set.
  static String? getApiKey() {
    final key = dotenv.env['OPENAI_API_KEY'];
    return (key != null && key.isNotEmpty && key != 'your_openai_api_key_here')
        ? key
        : null;
  }

  /// Returns true if an API key is configured in the .env file.
  static bool hasApiKey() {
    return getApiKey() != null;
  }

  // ---------------------------------------------------------------------------
  // Transcription
  // ---------------------------------------------------------------------------

  /// Transcribes audio bytes using the OpenAI Whisper API.
  ///
  /// [audioBytes] — raw audio data (WAV, M4A, MP3, etc.)
  /// [filename] — name with appropriate extension (e.g. `audio.m4a`)
  /// [language] — optional ISO-639-1 code to hint the language (e.g. `en`)
  ///
  /// Returns a map with:
  /// - `text`: the transcribed text
  /// - `language`: detected language (if available)
  ///
  /// Throws a user-friendly [String] on failure.
  Future<Map<String, dynamic>> transcribe(
    Uint8List audioBytes, {
    String filename = 'audio.m4a',
    String? language,
  }) async {
    final apiKey = getApiKey();
    if (apiKey == null) {
      throw 'OpenAI API key not set. Please add it in the .env file.';
    }

    try {
      final uri = Uri.parse(_whisperUrl);
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = 'whisper-large-v3-turbo'
        ..fields['response_format'] = 'verbose_json'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          audioBytes,
          filename: filename,
        ));

      // If a language hint is provided, pass it to Whisper
      if (language != null && language.isNotEmpty && language != 'auto') {
        request.fields['language'] = language;
      }

      debugPrint('[Whisper] Sending ${audioBytes.length} bytes to Whisper API');
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        final text = body['text'] as String? ?? '';
        final detectedLang = body['language'] as String? ?? '';

        debugPrint('[Whisper] Transcription: "$text" (lang: $detectedLang)');
        return {
          'text': text.trim(),
          'language': detectedLang,
        };
      }

      // Handle specific error codes
      switch (response.statusCode) {
        case 401:
          throw 'Invalid OpenAI API key. Please check your key in the .env file.';
        case 429:
          throw 'OpenAI rate limit reached. Please wait a moment.';
        case 413:
          throw 'Audio file too large. Maximum is 25MB.';
        default:
          String errorMsg;
          try {
            final errorBody =
                json.decode(response.body) as Map<String, dynamic>;
            final errorObj = errorBody['error'] as Map<String, dynamic>?;
            errorMsg =
                errorObj?['message'] as String? ?? 'Unknown error';
          } catch (_) {
            errorMsg = 'Server error (${response.statusCode})';
          }
          throw 'Whisper API error: $errorMsg';
      }
    } on http.ClientException {
      throw 'No internet connection. Please check your network.';
    } catch (e) {
      if (e is String) rethrow;
      throw 'Speech recognition failed: $e';
    }
  }

  /// Disposes the HTTP client.
  void dispose() {
    _client.close();
  }
}
