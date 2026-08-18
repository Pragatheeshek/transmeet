import 'dart:math';

/// Generates unique, human-friendly meeting IDs in the format `TM-XXXXXX`.
///
/// Uses [Random.secure] for cryptographically strong random values.
/// Characters are uppercase alphanumeric (0-9, A-Z) for easy typing/sharing.
abstract final class MeetingIdGenerator {

  static const String _prefix = 'TM-';
  static const int _idLength = 6;
  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // Excludes I, O, 0, 1 to avoid ambiguity when reading aloud or typing.

  static final _random = Random.secure();

  /// Generates a single meeting ID (e.g. `TM-7K4P92`).
  static String generate() {
    final buffer = StringBuffer(_prefix);
    for (var i = 0; i < _idLength; i++) {
      buffer.write(_chars[_random.nextInt(_chars.length)]);
    }
    return buffer.toString();
  }

  /// Validates that [id] matches the expected meeting ID format.
  ///
  /// Accepts with or without the `TM-` prefix (case-insensitive).
  static bool isValidFormat(String id) {
    final normalized = normalize(id);
    if (normalized == null) return false;
    return RegExp(r'^TM-[A-Z2-9]{6}$').hasMatch(normalized);
  }

  /// Normalizes a user-entered meeting ID to uppercase with `TM-` prefix.
  ///
  /// Returns `null` if the input is empty after trimming.
  static String? normalize(String input) {
    final trimmed = input.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('TM-')) return trimmed;
    return 'TM-$trimmed';
  }
}
