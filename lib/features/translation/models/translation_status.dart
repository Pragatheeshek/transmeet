/// Represents the current state of the translation pipeline.
enum TranslationStatus {
  /// Pipeline is idle, not processing.
  idle('Ready', '⏸️'),

  /// Listening/recording audio from the microphone.
  listening('Listening...', '🎤'),

  /// Sending audio to Whisper for transcription.
  transcribing('Transcribing...', '📝'),

  /// Translating the transcribed text.
  translating('Translating...', '🌐'),

  /// Generating speech from translated text.
  synthesizing('Synthesizing...', '🔊'),

  /// Playing the translated audio.
  playing('Playing...', '▶️'),

  /// An error occurred during the pipeline.
  error('Error', '❌'),

  /// Pipeline completed successfully.
  completed('Done', '✅');

  const TranslationStatus(this.label, this.icon);

  /// Human-readable label for this status.
  final String label;

  /// Emoji icon for this status.
  final String icon;
}
