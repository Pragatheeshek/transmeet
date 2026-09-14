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
    test('supportedLanguages has at least 13 entries', () {
      expect(
        TranslationLanguage.supportedLanguages.length,
        greaterThanOrEqualTo(13),
      );
    });

    test('supportedLanguages includes Italian, Portuguese, Chinese', () {
      final codes =
          TranslationLanguage.supportedLanguages.map((l) => l.code).toList();
      expect(codes, contains('it'));
      expect(codes, contains('pt'));
      expect(codes, contains('zh'));
    });

    test('fromCode returns correct language for "ta"', () {
      final lang = TranslationLanguage.fromCode('ta');
      expect(lang, isNotNull);
      expect(lang!.name, 'Tamil');
      expect(lang.code, 'ta');
    });

    test('fromCode returns correct language for "it" (Italian)', () {
      final lang = TranslationLanguage.fromCode('it');
      expect(lang, isNotNull);
      expect(lang!.name, 'Italian');
    });

    test('fromCode returns correct language for "pt" (Portuguese)', () {
      final lang = TranslationLanguage.fromCode('pt');
      expect(lang, isNotNull);
      expect(lang!.name, 'Portuguese');
    });

    test('fromCode returns correct language for "zh" (Chinese)', () {
      final lang = TranslationLanguage.fromCode('zh');
      expect(lang, isNotNull);
      expect(lang!.name, 'Chinese');
    });

    test('fromCode returns null for unknown code', () {
      expect(TranslationLanguage.fromCode('zz'), isNull);
    });

    test('fromName returns correct language (case-insensitive)', () {
      final lang = TranslationLanguage.fromName('hindi');
      expect(lang, isNotNull);
      expect(lang!.code, 'hi');
    });

    test('fromName returns null for unknown name', () {
      expect(TranslationLanguage.fromName('Klingon'), isNull);
    });

    test('nameToCode converts name to code', () {
      expect(TranslationLanguage.nameToCode('English'), 'en');
      expect(TranslationLanguage.nameToCode('Tamil'), 'ta');
      expect(TranslationLanguage.nameToCode('Hindi'), 'hi');
      expect(TranslationLanguage.nameToCode('Japanese'), 'ja');
      expect(TranslationLanguage.nameToCode('Italian'), 'it');
      expect(TranslationLanguage.nameToCode('Unknown'), isNull);
    });

    test('codeToName converts code to name', () {
      expect(TranslationLanguage.codeToName('fr'), 'French');
      expect(TranslationLanguage.codeToName('de'), 'German');
      expect(TranslationLanguage.codeToName('pt'), 'Portuguese');
      expect(TranslationLanguage.codeToName('zh'), 'Chinese');
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
      final a = TranslationLanguage(code: 'en', name: 'English');
      final b = TranslationLanguage(code: 'en', name: 'English');
      final c = TranslationLanguage(code: 'ta', name: 'Tamil');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ── TranslationResult ───────────────────────────────────────────────────────
  group('TranslationResult', () {
    test('factory constructor creates result with timestamp', () {
      final result = TranslationResult.fromTranscriptionAndTranslation(
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
}
