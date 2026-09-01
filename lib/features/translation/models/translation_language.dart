/// Represents a language supported by the TransMeet translation pipeline.
class TranslationLanguage {
  const TranslationLanguage({
    required this.code,
    required this.name,
  });

  /// BCP-47 language code (e.g. "ta", "en").
  final String code;

  /// Human-readable name (e.g. "Tamil", "English").
  final String name;

  /// All languages supported by the TransMeet translation system.
  static const List<TranslationLanguage> supportedLanguages = [
    TranslationLanguage(code: 'en', name: 'English'),
    TranslationLanguage(code: 'ta', name: 'Tamil'),
    TranslationLanguage(code: 'hi', name: 'Hindi'),
    TranslationLanguage(code: 'te', name: 'Telugu'),
    TranslationLanguage(code: 'ml', name: 'Malayalam'),
    TranslationLanguage(code: 'kn', name: 'Kannada'),
    TranslationLanguage(code: 'es', name: 'Spanish'),
    TranslationLanguage(code: 'fr', name: 'French'),
    TranslationLanguage(code: 'de', name: 'German'),
    TranslationLanguage(code: 'ja', name: 'Japanese'),
  ];

  /// Looks up a [TranslationLanguage] by its code.
  /// Returns `null` if no match is found.
  static TranslationLanguage? fromCode(String code) {
    final lowerCode = code.toLowerCase();
    for (final lang in supportedLanguages) {
      if (lang.code == lowerCode) return lang;
    }
    return null;
  }

  /// Looks up a [TranslationLanguage] by its display name (case-insensitive).
  /// Returns `null` if no match is found.
  static TranslationLanguage? fromName(String name) {
    final lowerName = name.toLowerCase();
    for (final lang in supportedLanguages) {
      if (lang.name.toLowerCase() == lowerName) return lang;
    }
    return null;
  }

  /// Converts a display name (e.g. "Tamil") to a language code (e.g. "ta").
  /// Returns `null` if the name is not recognized.
  static String? nameToCode(String name) => fromName(name)?.code;

  /// Converts a language code (e.g. "ta") to a display name (e.g. "Tamil").
  /// Returns `null` if the code is not recognized.
  static String? codeToName(String code) => fromCode(code)?.name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranslationLanguage &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => 'TranslationLanguage($code, $name)';
}
