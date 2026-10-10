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
    TranslationLanguage(code: 'en-US', name: 'English'),
    TranslationLanguage(code: 'ta-IN', name: 'Tamil'),
  ];

  /// Looks up a [TranslationLanguage] by its code.
  /// Returns `null` if no match is found.
  static TranslationLanguage? fromCode(String code) {
    final lowerCode = code.toLowerCase();
    for (final lang in supportedLanguages) {
      if (lang.code.toLowerCase() == lowerCode) return lang;
    }
    // Fallback if someone asks for 'en', 'ta', or 'ml'
    if (lowerCode == 'en') return supportedLanguages[0];
    if (lowerCode == 'ta') return supportedLanguages[1];
    return null;
  }

  /// Looks up a [TranslationLanguage] by its display name (case-insensitive).
  /// Returns `null` if no match is found.
  static TranslationLanguage? fromName(String name) {
    final lowerName = name.toLowerCase();
    for (final lang in supportedLanguages) {
      if (lang.name.toLowerCase() == lowerName) return lang;
    }
    // Handle Whisper API outputs which are just 'english', 'tamil', or 'malayalam'
    if (lowerName == 'english') return supportedLanguages[0];
    if (lowerName == 'tamil') return supportedLanguages[1];
    return null;
  }

  /// Converts a display name (e.g. "Tamil", "english") to a language code.
  /// Returns `null` if the name is not recognized.
  static String? nameToCode(String name) => fromName(name)?.code;

  /// Converts a language code (e.g. "ta") to a display name (e.g. "Tamil").
  /// Returns `null` if the code is not recognized.
  static String? codeToName(String code) => fromCode(code)?.name;

  /// Returns the ISO 639-1 base language code (e.g. 'en' for 'en-GB').
  /// This is required for Google Translate API, which often rejects regional codes.
  static String baseCode(String code) {
    if (code.toLowerCase() == 'auto') return 'auto';
    final lowerCode = code.toLowerCase();
    if (lowerCode.startsWith('en')) return 'en';
    if (lowerCode.startsWith('ta')) return 'ta';
    
    final base = code.split('-').first.toLowerCase();
    // If the base code is longer than 3 characters, it's likely a full name
    // (e.g. "hindi", "malayalam") that was unrecognized. Use auto-detect.
    if (base.length > 3) return 'auto';
    return base;
  }

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
