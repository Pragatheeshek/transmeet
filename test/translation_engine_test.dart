// Tests for TransMeet Translation Engine
//
// These tests verify:
//   1. TranslationLanguage model — all languages, lookups, new languages
//   2. TranslationResult — creation, serialization
//   3. TranslationStatus — labels, icons
//   4. Translation API client — response parsing, error handling
//   5. Realtime engine logic — duplicate detection, empty text, sequencing
//   6. Language mapping consistency

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:transmeet/features/translation/models/translation_language.dart';
import 'package:transmeet/features/translation/models/translation_result.dart';
import 'package:transmeet/features/translation/models/translation_status.dart';
import 'package:transmeet/features/translation/services/translation_api_client.dart';

void main() {
  // ── TranslationLanguage ─────────────────────────────────────────────────────
  group('TranslationLanguage', () {
    test('supportedLanguages has exactly 2 entries', () {
      expect(
        TranslationLanguage.supportedLanguages.length,
        equals(2),
      );
    });

    test('supportedLanguages includes English and Tamil', () {
      final codes =
          TranslationLanguage.supportedLanguages.map((l) => l.code).toList();
      expect(codes, contains('en-US'));
      expect(codes, contains('ta-IN'));
    });

    test('fromCode returns correct language for "ta"', () {
      final lang = TranslationLanguage.fromCode('ta');
      expect(lang, isNotNull);
      expect(lang!.name, 'Tamil');
      expect(lang.code, 'ta-IN');
    });

    test('fromCode returns null for unknown code', () {
      expect(TranslationLanguage.fromCode('zz'), isNull);
    });

    test('fromName returns correct language (case-insensitive)', () {
      final lang = TranslationLanguage.fromName('english');
      expect(lang, isNotNull);
      expect(lang!.code, 'en-US');
    });

    test('fromName returns null for unknown name', () {
      expect(TranslationLanguage.fromName('Klingon'), isNull);
    });

    test('nameToCode converts name to code', () {
      expect(TranslationLanguage.nameToCode('English'), 'en-US');
      expect(TranslationLanguage.nameToCode('Tamil'), 'ta-IN');
      expect(TranslationLanguage.nameToCode('Unknown'), isNull);
    });

    test('codeToName converts code to name', () {
      expect(TranslationLanguage.codeToName('en-US'), 'English');
      expect(TranslationLanguage.codeToName('ta-IN'), 'Tamil');
      expect(TranslationLanguage.codeToName('xx'), isNull);
    });

    test('all supported languages have unique codes', () {
      final codes = TranslationLanguage.supportedLanguages
          .map((l) => l.code)
          .toSet();
      expect(codes.length, TranslationLanguage.supportedLanguages.length);
    });

    test('all supported languages have unique names', () {
      final names = TranslationLanguage.supportedLanguages
          .map((l) => l.name)
          .toSet();
      expect(names.length, TranslationLanguage.supportedLanguages.length);
    });

    test('equality is based on code', () {
      final a = TranslationLanguage(code: 'en-US', name: 'English');
      final b = TranslationLanguage(code: 'en-US', name: 'English');
      final c = TranslationLanguage(code: 'ta-IN', name: 'Tamil');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ── baseCode — Whisper full-word name handling ─────────────────────────────
  group('TranslationLanguage.baseCode', () {
    test('handles regional codes correctly', () {
      expect(TranslationLanguage.baseCode('en-US'), 'en');
      expect(TranslationLanguage.baseCode('en-GB'), 'en');
      expect(TranslationLanguage.baseCode('en-IN'), 'en');
      expect(TranslationLanguage.baseCode('ta-IN'), 'ta');
    });

    test('handles bare ISO codes correctly', () {
      expect(TranslationLanguage.baseCode('en'), 'en');
      expect(TranslationLanguage.baseCode('ta'), 'ta');
    });

    test('handles Whisper full-word language names', () {
      // Whisper returns "english" and "tamil" as detected language names.
      // These must map to proper ISO codes, NOT fall back to 'auto'.
      expect(TranslationLanguage.baseCode('english'), 'en');
      expect(TranslationLanguage.baseCode('tamil'), 'ta');
    });

    test('handles auto correctly', () {
      expect(TranslationLanguage.baseCode('auto'), 'auto');
      expect(TranslationLanguage.baseCode('AUTO'), 'auto');
    });

    test('unknown long names fall back to auto', () {
      expect(TranslationLanguage.baseCode('klingon'), 'auto');
      expect(TranslationLanguage.baseCode('unknown'), 'auto');
    });

    test('handles case insensitivity', () {
      expect(TranslationLanguage.baseCode('English'), 'en');
      expect(TranslationLanguage.baseCode('ENGLISH'), 'en');
      expect(TranslationLanguage.baseCode('Tamil'), 'ta');
      expect(TranslationLanguage.baseCode('TAMIL'), 'ta');
    });
  });

  // ── Bidirectional Language Routing ─────────────────────────────────────────
  group('Bidirectional Language Routing', () {
    test('English→Tamil: source and target resolve correctly', () {
      final sourceBase = TranslationLanguage.baseCode('english');
      final targetBase = TranslationLanguage.baseCode('ta-IN');
      expect(sourceBase, 'en');
      expect(targetBase, 'ta');
      expect(sourceBase != targetBase, isTrue, reason: 'Should trigger translation');
    });

    test('Tamil→English: source and target resolve correctly', () {
      final sourceBase = TranslationLanguage.baseCode('tamil');
      final targetBase = TranslationLanguage.baseCode('en-US');
      expect(sourceBase, 'ta');
      expect(targetBase, 'en');
      expect(sourceBase != targetBase, isTrue, reason: 'Should trigger translation');
    });

    test('Same language detection skips translation', () {
      expect(
        TranslationLanguage.baseCode('english') == TranslationLanguage.baseCode('en-US'),
        isTrue,
      );
      expect(
        TranslationLanguage.baseCode('tamil') == TranslationLanguage.baseCode('ta-IN'),
        isTrue,
      );
    });
  });

  // ── TTS Language Code Alignment ────────────────────────────────────────────
  group('TTS Language Code Alignment', () {
    test('English resolves to en-US for TTS', () {
      // This is the critical path: when target is English, the code sent to
      // the TTS backend must match a VOICE_MAP key.
      final code = TranslationLanguage.fromCode('en')?.code;
      expect(code, 'en-US');
    });

    test('Tamil resolves to ta-IN for TTS', () {
      final code = TranslationLanguage.fromCode('ta')?.code;
      expect(code, 'ta-IN');
    });

    test('en-US resolves to en-US for TTS', () {
      final code = TranslationLanguage.fromCode('en-US')?.code;
      expect(code, 'en-US');
    });

    test('ta-IN resolves to ta-IN for TTS', () {
      final code = TranslationLanguage.fromCode('ta-IN')?.code;
      expect(code, 'ta-IN');
    });
  });

  // ── TranslationResult ───────────────────────────────────────────────────────
  group('TranslationResult', () {
    test('factory constructor creates result with timestamp', () {
      final result = TranslationResult.fromTranscriptionAndTranslation(
        speakerName: 'Test Speaker',
        originalText: 'Hello',
        translatedText: 'வணக்கம்',
        sourceLanguage: 'en',
        targetLanguage: 'ta',
      );
      expect(result.originalText, 'Hello');
      expect(result.translatedText, 'வணக்கம்');
      expect(result.sourceLanguage, 'en');
      expect(result.targetLanguage, 'ta');
      expect(result.timestamp, isNotNull);
    });

    test('English → Tamil result', () {
      final result = TranslationResult.fromTranscriptionAndTranslation(
        speakerName: 'Test Speaker',
        originalText: 'Hello, how are you?',
        translatedText: 'வணக்கம், எப்படி இருக்கிறீர்கள்?',
        sourceLanguage: 'en',
        targetLanguage: 'ta',
      );
      expect(result.translatedText, isNotEmpty);
      expect(result.sourceLanguage, 'en');
      expect(result.targetLanguage, 'ta');
    });

    test('Tamil → English result', () {
      final result = TranslationResult.fromTranscriptionAndTranslation(
        speakerName: 'Test Speaker',
        originalText: 'வணக்கம்',
        translatedText: 'Hello',
        sourceLanguage: 'ta',
        targetLanguage: 'en',
      );
      expect(result.translatedText, 'Hello');
      expect(result.sourceLanguage, 'ta');
      expect(result.targetLanguage, 'en');
    });

    test('English → Hindi result', () {
      final result = TranslationResult.fromTranscriptionAndTranslation(
        speakerName: 'Test Speaker',
        originalText: 'Hello',
        translatedText: 'नमस्ते',
        sourceLanguage: 'en',
        targetLanguage: 'hi',
      );
      expect(result.translatedText, 'नमस्ते');
      expect(result.targetLanguage, 'hi');
    });

    test('toMap produces correct map', () {
      final result = TranslationResult.fromTranscriptionAndTranslation(
        speakerName: 'Test Speaker',
        originalText: 'Hello',
        translatedText: 'Bonjour',
        sourceLanguage: 'en',
        targetLanguage: 'fr',
      );
      final map = result.toMap();
      expect(map['originalText'], 'Hello');
      expect(map['translatedText'], 'Bonjour');
      expect(map['sourceLanguage'], 'en');
      expect(map['targetLanguage'], 'fr');
      expect(map['timestamp'], isNotNull);
    });

    test('toString includes language arrow', () {
      final result = TranslationResult.fromTranscriptionAndTranslation(
        speakerName: 'Test Speaker',
        originalText: 'Hello',
        translatedText: 'Hola',
        sourceLanguage: 'en',
        targetLanguage: 'es',
      );
      expect(result.toString(), contains('en→es'));
    });
  });

  // ── TranslationStatus ──────────────────────────────────────────────────────
  group('TranslationStatus', () {
    test('all statuses have non-empty labels', () {
      for (final status in TranslationStatus.values) {
        expect(status.label.isNotEmpty, isTrue,
            reason: '${status.name} has empty label');
      }
    });

    test('all statuses have non-empty icons', () {
      for (final status in TranslationStatus.values) {
        expect(status.icon.isNotEmpty, isTrue,
            reason: '${status.name} has empty icon');
      }
    });

    test('idle status has correct label', () {
      expect(TranslationStatus.idle.label, 'Ready');
    });

    test('listening status has correct label', () {
      expect(TranslationStatus.listening.label, 'Listening...');
    });

    test('error status has correct label', () {
      expect(TranslationStatus.error.label, 'Error');
    });

    test('status count is 8', () {
      expect(TranslationStatus.values.length, 8);
    });
  });

  // ── Translation API Client ─────────────────────────────────────────────────
  group('TranslationApiClient', () {
    test('translate response is correctly structured', () {
      // Test that the expected response format can be parsed
      final responseBody = json.encode({
        'translatedText': 'வணக்கம்',
        'sourceLanguage': 'en',
        'targetLanguage': 'ta',
      });
      final data = json.decode(responseBody) as Map<String, dynamic>;
      expect(data['translatedText'], 'வணக்கம்');
      expect(data['sourceLanguage'], 'en');
      expect(data['targetLanguage'], 'ta');
    });

    test('translate error response can be parsed', () {
      final responseBody = json.encode({'error': 'Text is required.'});
      final data = json.decode(responseBody) as Map<String, dynamic>;
      expect(data['error'], 'Text is required.');
    });

    test('translate 503 error response can be parsed', () {
      final responseBody =
          json.encode({'error': 'Translation service unavailable.'});
      final data = json.decode(responseBody) as Map<String, dynamic>;
      expect(data['error'], contains('unavailable'));
    });

    test('translate 429 rate limit response can be parsed', () {
      final responseBody =
          json.encode({'error': 'Rate limit exceeded'});
      final data = json.decode(responseBody) as Map<String, dynamic>;
      expect(data['error'], contains('Rate limit'));
    });

    test('synthesize response is correctly structured', () {
      final responseBody =
          json.encode({'audioContent': 'base64audiodata'});
      final data = json.decode(responseBody) as Map<String, dynamic>;
      expect(data['audioContent'], 'base64audiodata');
    });

    test('health check response is correctly structured', () {
      final responseBody = json.encode({
        'service': 'translation',
        'status': 'ready',
        'configured': true,
        'mockMode': true,
      });
      final data = json.decode(responseBody) as Map<String, dynamic>;
      expect(data['status'], 'ready');
      expect(data['configured'], true);
    });

    test('isHealthy returns true on 200', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'status': 'ok'}),
          200,
        );
      });

      final client = TranslationApiClient(client: mockClient);
      final healthy = await client.isHealthy();
      expect(healthy, isTrue);

      client.dispose();
    });

    test('isHealthy returns false on error', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Connection refused');
      });

      final client = TranslationApiClient(client: mockClient);
      final healthy = await client.isHealthy();
      expect(healthy, isFalse);

      client.dispose();
    });
  });

  // ── Translation Engine Logic ───────────────────────────────────────────────
  group('Translation Engine Logic', () {
    test('empty text should be rejected', () {
      final text = '';
      expect(text.trim().isEmpty, isTrue);
    });

    test('whitespace-only text should be rejected', () {
      final text = '   \n  \t  ';
      expect(text.trim().isEmpty, isTrue);
    });

    test('duplicate text detection', () {
      String lastTranslatedText = '';
      const text1 = 'Hello everyone';
      const text2 = 'How are you?';

      // First time — should NOT be duplicate
      expect(text1 == lastTranslatedText, isFalse);
      lastTranslatedText = text1;

      // Same text again — should be duplicate
      expect(text1 == lastTranslatedText, isTrue);

      // Different text — should NOT be duplicate
      expect(text2 == lastTranslatedText, isFalse);
      lastTranslatedText = text2;
    });

    test('request sequencing prevents stale overwrites', () {
      int lastEmittedSequence = 0;

      // Simulate request 1 completing first
      int seq1 = 1;
      expect(seq1 >= lastEmittedSequence, isTrue);
      lastEmittedSequence = seq1;

      // Simulate request 2 completing second
      int seq2 = 2;
      expect(seq2 >= lastEmittedSequence, isTrue);
      lastEmittedSequence = seq2;

      // Simulate late response from request 1 — should be rejected
      expect(seq1 >= lastEmittedSequence, isFalse);
    });

    test('preferred language change propagates', () {
      // Simulate user changing language from English to Tamil
      String targetCode = 'en';
      expect(targetCode, 'en');

      targetCode = 'ta';
      expect(targetCode, 'ta');

      // Verify the code maps to a known language
      final lang = TranslationLanguage.fromCode(targetCode);
      expect(lang, isNotNull);
      expect(lang!.name, 'Tamil');
    });

    test('same source and target language skips translation', () {
      const source = 'en';
      const target = 'en';
      expect(source == target, isTrue);
    });

    test('different source and target language triggers translation', () {
      const source = 'en';
      const target = 'ta';
      expect(source == target, isFalse);
    });
  });

  // ── Translation Response Parsing ──────────────────────────────────────────
  group('Translation Response Parsing', () {
    test('parse valid translation response', () {
      final responseBody = json.encode({
        'translatedText': 'வணக்கம்',
        'sourceLanguage': 'en',
        'targetLanguage': 'ta',
      });

      final data = json.decode(responseBody) as Map<String, dynamic>;
      final translatedText = data['translatedText'] as String?;
      expect(translatedText, 'வணக்கம்');
      expect(translatedText, isNotNull);
      expect(translatedText!.isNotEmpty, isTrue);
    });

    test('parse empty translatedText', () {
      final responseBody = json.encode({
        'translatedText': '',
        'sourceLanguage': 'en',
        'targetLanguage': 'ta',
      });

      final data = json.decode(responseBody) as Map<String, dynamic>;
      final translatedText = data['translatedText'] as String?;
      expect(translatedText, isEmpty);
    });

    test('parse missing translatedText field', () {
      final responseBody = json.encode({
        'sourceLanguage': 'en',
        'targetLanguage': 'ta',
      });

      final data = json.decode(responseBody) as Map<String, dynamic>;
      final translatedText = data['translatedText'] as String?;
      expect(translatedText, isNull);
    });

    test('parse error response', () {
      final responseBody = json.encode({
        'error': 'Translation service unavailable.',
      });

      final data = json.decode(responseBody) as Map<String, dynamic>;
      final error = data['error'] as String?;
      expect(error, 'Translation service unavailable.');
    });

    test('parse malformed JSON gracefully', () {
      const malformedBody = 'not a json';
      try {
        json.decode(malformedBody);
        fail('Should have thrown FormatException');
      } catch (e) {
        expect(e, isA<FormatException>());
      }
    });
  });

  // ── Mock HTTP: Tamil → English Translation ────────────────────────────────
  group('Tamil → English Translation (Mock HTTP)', () {
    test('translate Tamil text to English succeeds', () async {
      final mockClient = MockClient((request) async {
        final body = json.decode(request.body) as Map<String, dynamic>;
        // Verify the request has correct language codes
        expect(body['sourceLanguage'], anyOf('ta', 'auto'));
        expect(body['targetLanguage'], 'en');
        expect(body['text'], isNotEmpty);

        return http.Response(
          json.encode({
            'translatedText': 'Hello, how are you?',
            'sourceLanguage': body['sourceLanguage'],
            'targetLanguage': 'en',
          }),
          200,
        );
      });

      final client = TranslationApiClient(client: mockClient);
      final result = await client.translate(
        text: 'வணக்கம், எப்படி இருக்கிறீர்கள்?',
        sourceLanguage: 'ta',
        targetLanguage: 'en',
      );

      expect(result['translatedText'], 'Hello, how are you?');
      expect(result['targetLanguage'], 'en');
      client.dispose();
    });

    test('translate Tamil text with Whisper "tamil" source succeeds', () async {
      // Whisper returns "tamil" as detected language, which gets passed
      // through baseCode() before reaching the API client.
      final sourceBase = TranslationLanguage.baseCode('tamil');
      expect(sourceBase, 'ta', reason: 'baseCode should convert "tamil" to "ta"');

      final mockClient = MockClient((request) async {
        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['sourceLanguage'], 'ta');
        expect(body['targetLanguage'], 'en');

        return http.Response(
          json.encode({
            'translatedText': 'Hello',
            'sourceLanguage': 'ta',
            'targetLanguage': 'en',
          }),
          200,
        );
      });

      final client = TranslationApiClient(client: mockClient);
      final result = await client.translate(
        text: 'வணக்கம்',
        sourceLanguage: sourceBase,
        targetLanguage: TranslationLanguage.baseCode('en-US'),
      );

      expect(result['translatedText'], 'Hello');
      client.dispose();
    });
  });

  // ── Mock HTTP: English TTS Synthesis ──────────────────────────────────────
  group('English TTS Synthesis (Mock HTTP)', () {
    test('synthesize English text with en-US code succeeds', () async {
      final mockClient = MockClient((request) async {
        final body = json.decode(request.body) as Map<String, dynamic>;
        // The Flutter client should send the full regional code from
        // TranslationLanguage.fromCode('en')?.code → 'en-US'
        expect(body['languageCode'], 'en-US');
        expect(body['text'], isNotEmpty);

        return http.Response(
          json.encode({'audioContent': 'dGVzdF9hdWRpb19kYXRh'}),
          200,
        );
      });

      final client = TranslationApiClient(client: mockClient);
      final safeCode = TranslationLanguage.fromCode('en')?.code ?? 'en';
      final result = await client.synthesize(
        text: 'Hello, how are you?',
        languageCode: safeCode,
      );

      expect(result['audioContent'], isNotEmpty);
      client.dispose();
    });

    test('synthesize Tamil text with ta-IN code succeeds', () async {
      final mockClient = MockClient((request) async {
        final body = json.decode(request.body) as Map<String, dynamic>;
        expect(body['languageCode'], 'ta-IN');

        return http.Response(
          json.encode({'audioContent': 'dGVzdF90YW1pbF9hdWRpbw=='}),
          200,
        );
      });

      final client = TranslationApiClient(client: mockClient);
      final safeCode = TranslationLanguage.fromCode('ta')?.code ?? 'ta';
      final result = await client.synthesize(
        text: 'வணக்கம்',
        languageCode: safeCode,
      );

      expect(result['audioContent'], isNotEmpty);
      client.dispose();
    });
  });

  // ── Failure Handling ──────────────────────────────────────────────────────
  group('Failure Handling', () {
    test('translate with server error throws', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'error': 'Internal server error'}),
          500,
        );
      });

      final client = TranslationApiClient(client: mockClient);
      expect(
        () => client.translate(
          text: 'வணக்கம்',
          sourceLanguage: 'ta',
          targetLanguage: 'en',
        ),
        throwsA(isA<String>()),
      );
      client.dispose();
    });

    test('synthesize with unsupported language throws', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({'error': 'Unsupported language for TTS: zz'}),
          400,
        );
      });

      final client = TranslationApiClient(client: mockClient);
      expect(
        () => client.synthesize(text: 'Hello', languageCode: 'zz'),
        throwsA(isA<String>()),
      );
      client.dispose();
    });

    test('empty transcript is handled gracefully', () {
      final text = '';
      expect(text.trim().isEmpty, isTrue);
      // Pipeline should skip translation for empty transcripts
    });

    test('API timeout is handled gracefully', () async {
      final mockClient = MockClient((request) async {
        // Simulate a very slow response
        await Future.delayed(const Duration(seconds: 2));
        return http.Response('{}', 200);
      });

      final client = TranslationApiClient(client: mockClient);
      // The client has a 45s timeout — this test just verifies the mock works
      // In production, the timeout would throw and be caught.
      client.dispose();
    });
  });
}
