import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/features/meeting/models/meeting_model.dart';
import 'package:transmeet/features/meeting/screens/meeting_details_screen.dart';
import 'package:transmeet/features/meeting/services/meeting_service.dart';
import 'package:transmeet/features/meeting/widgets/meeting_card.dart';

/// Displays the Recent Meetings section on the Home dashboard.
///
/// Streams meetings hosted by the current user from Firestore in real-time.
class RecentMeetingsSection extends StatelessWidget {
  const RecentMeetingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          AppConstants.recentMeetings,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),

        if (user == null)
          _buildEmptyState(theme)
        else
          _buildMeetingsList(context, theme, user.uid),
      ],
    );
  }

  Widget _buildMeetingsList(
    BuildContext context,
    ThemeData theme,
    String uid,
  ) {
    final meetingService = MeetingService();

    return StreamBuilder<List<MeetingModel>>(
      stream: meetingService.getHostedMeetings(uid),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.12),
              ),
            ),
            child: const Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: theme.colorScheme.error.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unable to load meetings.',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        // Data loaded
        final meetings = snapshot.data ?? [];

        if (meetings.isEmpty) {
          return _buildEmptyState(theme);
        }

        return Column(
          children: meetings
              .map(
                (meeting) => MeetingCard(
                  meeting: meeting,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MeetingDetailsScreen(
                          meeting: meeting,
                          isNewlyCreated: false,
                          isHost: true,
                        ),
                      ),
                    );
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 48,
            color:
                theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
    );
  }
}
