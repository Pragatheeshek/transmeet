import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:transmeet/core/constants/app_constants.dart';

/// A row of action buttons for meeting details: Copy, Share, and Enter/Join.
///
/// Reusable across [MeetingDetailsScreen] for both host and joiner flows.
class MeetingActionButtons extends StatelessWidget {
  const MeetingActionButtons({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
    required this.onEnterMeeting,
    this.enterLabel,
  });

  final String meetingId;
  final String meetingTitle;
  final VoidCallback onEnterMeeting;

  /// Label for the primary button. Defaults to "Enter Meeting".
  final String? enterLabel;

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: meetingId));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text(AppConstants.meetingIdCopied),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  void _shareMeeting() {
    final shareText = AppConstants.shareTemplate
        .replaceAll('{title}', meetingTitle)
        .replaceAll('{meetingId}', meetingId);
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Copy & Share row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _copyToClipboard(context),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text(AppConstants.copyMeetingId),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _shareMeeting,
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text(AppConstants.shareMeeting),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Enter/Join meeting button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onEnterMeeting,
            icon: Icon(
              enterLabel != null
                  ? Icons.login_rounded
                  : Icons.videocam_rounded,
              size: 20,
            ),
            label: Text(enterLabel ?? AppConstants.enterMeeting),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
        ),
      ],
    );
  }
}
