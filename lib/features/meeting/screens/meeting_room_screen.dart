import 'package:flutter/material.dart';

import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/features/meeting/models/meeting_model.dart';
import 'package:transmeet/features/meeting/widgets/meeting_id_display.dart';

/// Placeholder meeting room screen.
///
/// Displays basic meeting information and a Leave button.
/// The actual WebRTC video conferencing will be implemented in Module 4.
class MeetingRoomScreen extends StatelessWidget {
  const MeetingRoomScreen({
    super.key,
    required this.meeting,
  });

  final MeetingModel meeting;

  Future<void> _leaveMeeting(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(AppConstants.leaveConfirmTitle),
        content: const Text(AppConstants.leaveConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppConstants.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text(AppConstants.leaveMeeting),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Pop back to the Home screen.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveMeeting(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(meeting.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => _leaveMeeting(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Placeholder illustration
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.videocam_off_rounded,
                      size: 56,
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    meeting.title,
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Meeting ID
                  MeetingIdDisplay(meetingId: meeting.meetingId),
                  const SizedBox(height: 24),

                  // Placeholder message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            AppConstants.webrtcPlaceholder,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Leave button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _leaveMeeting(context),
                      icon: const Icon(Icons.call_end_rounded),
                      label: const Text(AppConstants.leaveMeeting),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
