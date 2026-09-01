import 'package:flutter/material.dart';

import 'package:transmeet/features/translation/models/translation_result.dart';
import 'package:transmeet/features/translation/models/translation_language.dart';

/// Displays original and translated text as a caption overlay.
class TranslatedCaption extends StatelessWidget {
  const TranslatedCaption({
    super.key,
    required this.result,
  });

  final TranslationResult? result;

  @override
  Widget build(BuildContext context) {
    if (result == null) return const SizedBox.shrink();

    final srcName =
        TranslationLanguage.codeToName(result!.sourceLanguage) ??
            result!.sourceLanguage.toUpperCase();
    final tgtName =
        TranslationLanguage.codeToName(result!.targetLanguage) ??
            result!.targetLanguage.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Original text
          Text(
            srcName,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            result!.originalText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(color: Colors.white24, height: 12),
          // Translated text
          Text(
            '$tgtName Translation',
            style: const TextStyle(
              color: Colors.cyanAccent,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            result!.translatedText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
