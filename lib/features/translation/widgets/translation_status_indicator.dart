import 'package:flutter/material.dart';

import 'package:transmeet/features/translation/models/translation_status.dart';

/// Displays the current translation pipeline status with an icon and label.
class TranslationStatusIndicator extends StatelessWidget {
  const TranslationStatusIndicator({
    super.key,
    required this.status,
  });

  final TranslationStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == TranslationStatus.idle) {
      return const SizedBox.shrink();
    }

    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == TranslationStatus.error)
            Icon(Icons.error_outline_rounded, size: 14, color: color)
          else if (status == TranslationStatus.completed)
            Icon(Icons.check_circle_outline_rounded, size: 14, color: color)
          else
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: color,
              ),
            ),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(TranslationStatus status) {
    switch (status) {
      case TranslationStatus.listening:
        return Colors.greenAccent;
      case TranslationStatus.transcribing:
        return Colors.amberAccent;
      case TranslationStatus.translating:
        return Colors.cyanAccent;
      case TranslationStatus.synthesizing:
        return Colors.purpleAccent;
      case TranslationStatus.playing:
        return Colors.lightBlueAccent;
      case TranslationStatus.error:
        return Colors.redAccent;
      case TranslationStatus.completed:
        return Colors.greenAccent;
      default:
        return Colors.white70;
    }
  }
}
