import 'package:flutter/material.dart';

import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/features/meeting/models/meeting_model.dart';
import 'package:transmeet/features/meeting/screens/meeting_room_screen.dart';
import 'package:transmeet/features/meeting/widgets/meeting_action_buttons.dart';
import 'package:transmeet/features/meeting/widgets/meeting_id_display.dart';

/// Displays meeting details after creation or after finding a meeting to join.
///
/// [isNewlyCreated] controls whether the success header is shown.
/// [isHost] controls whether certain host-only actions are visible.
class MeetingDetailsScreen extends StatelessWidget {
  const MeetingDetailsScreen({
    super.key,
    required this.meeting,
    this.isNewlyCreated = false,
    this.isHost = true,
  });

  final MeetingModel meeting;
  final bool isNewlyCreated;
  final bool isHost;

  void _enterMeetingRoom(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MeetingRoomScreen(meeting: meeting),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.meetingDetails),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Success header for newly created meetings
              if (isNewlyCreated) ...[
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 48,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppConstants.meetingCreatedSuccess,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
              ],

              // Meeting info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meeting title
                    Text(
                      AppConstants.meetingTitle,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meeting.title,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),

                    // Meeting ID
                    Text(
                      AppConstants.meetingId,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    MeetingIdDisplay(meetingId: meeting.meetingId),
                    const SizedBox(height: 20),

                    // Host info
                    Text(
                      AppConstants.hostedBy,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: theme.colorScheme.primary
                              .withValues(alpha: 0.15),
                          child: Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meeting.hostName,
                              style: theme.textTheme.titleMedium,
                            ),
                            if (meeting.hostEmail.isNotEmpty)
                              Text(
                                meeting.hostEmail,
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ],
                    ),
                    // Status
                    const SizedBox(height: 20),

                    // Preferred language
                    Row(
                      children: [
                        Icon(
                          Icons.language_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppConstants.preferredLanguage,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            meeting.preferredLanguage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Status
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Text(
                          'Status',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: meeting.isActive
                                ? Colors.green.withValues(alpha: 0.15)
                                : theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            meeting.isActive
                                ? AppConstants.statusActive
                                : AppConstants.statusEnded,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: meeting.isActive
                                  ? Colors.green
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Action buttons
              MeetingActionButtons(
                meetingId: meeting.meetingId,
                meetingTitle: meeting.title,
                onEnterMeeting: () => _enterMeetingRoom(context),
                enterLabel: isHost ? null : AppConstants.joinMeetingAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
