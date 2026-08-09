import 'package:flutter/material.dart';

/// A large, tappable card used for the primary meeting actions on the Home
/// screen (Create Meeting and Join Meeting).
///
/// Uses the theme's card colour and a primary-coloured icon container to
/// look prominent without needing heavy external packages.
class MeetingActionCard extends StatelessWidget {
  const MeetingActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isPrimary = false,
  });

  /// The icon to display inside the coloured container.
  final IconData icon;

  /// Main label text (e.g. "Create Meeting").
  final String title;

  /// Short description shown below the title.
  final String subtitle;

  /// Callback invoked when the card is tapped.
  final VoidCallback onTap;

  /// When true, the card uses the primary colour as the background accent.
  /// When false, it uses a lighter surface variant.
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final cardColor = theme.cardColor;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? primary.withValues(alpha: 0.5)
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon container
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? primary
                      : primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isPrimary ? Colors.white : primary,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),

              // Subtitle
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
