import 'package:flutter/material.dart';
import 'package:transmeet/core/constants/app_constants.dart';

/// Displays the Recent Meetings section on the Home dashboard.
///
/// Currently shows an empty state because Meeting Management (Module 3)
/// has not been implemented yet.
///
/// Architecture note: This widget is designed to accept meeting data
/// from Module 3. Add a `meetings` parameter when wiring Firestore.
class RecentMeetingsSection extends StatelessWidget {
  const RecentMeetingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          AppConstants.recentMeetings,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),

        // Empty state card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.video_library_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                AppConstants.noRecentMeetings,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppConstants.noRecentMeetingsSubtext,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
