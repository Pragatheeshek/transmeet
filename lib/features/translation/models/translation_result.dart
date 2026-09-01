/// Holds the result of a single translation operation.
class TranslationResult {
  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });

  /// The original spoken text (from Whisper).
  final String originalText;

  /// The translated text.
  final String translatedText;

  /// Source language code (e.g. "en").
  final String sourceLanguage;

  /// Target language code (e.g. "ta").
  final String targetLanguage;

  /// When this translation was created.
  final DateTime timestamp;

  /// Creates a [TranslationResult] from a JSON map (backend response merge).
  factory TranslationResult.fromTranscriptionAndTranslation({
    required String originalText,
    required String translatedText,
    required String sourceLanguage,
    required String targetLanguage,
  }) {
    return TranslationResult(
      originalText: originalText,
      translatedText: translatedText,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      timestamp: DateTime.now(),
    );
  }

  /// Converts to a Firestore-compatible map for optional metadata storage.
  Map<String, dynamic> toMap() {
    return {
      'originalText': originalText,
      'translatedText': translatedText,
      'sourceLanguage': sourceLanguage,
      'targetLanguage': targetLanguage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'TranslationResult($sourceLanguage→$targetLanguage: "$originalText" → "$translatedText")';
}
