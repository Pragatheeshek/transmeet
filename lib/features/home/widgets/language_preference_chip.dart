import 'package:flutter/material.dart';
import 'package:transmeet/core/constants/app_constants.dart';

/// UI-only language preference chip displayed on the Home dashboard.
///
/// The actual language persistence and switching system will be implemented
/// in a later module. This widget serves as a visual placeholder that fits
/// into the overall layout and reminds the user of the feature.
class LanguagePreferenceChip extends StatelessWidget {
  const LanguagePreferenceChip({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppConstants.preferredLanguage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppConstants.defaultLanguage,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        // "Coming Soon" chip — will become a dropdown in a later module.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language_rounded, size: 16, color: primary),
              const SizedBox(width: 6),
              Text(
                AppConstants.defaultLanguage,
                style: theme.textTheme.labelLarge?.copyWith(color: primary),
              ),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: primary),
            ],
          ),
        ),
      ],
    );
  }
}
