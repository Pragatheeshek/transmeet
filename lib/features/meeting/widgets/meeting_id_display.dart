import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:transmeet/core/constants/app_constants.dart';

/// Displays a meeting ID in a styled, read-only container with a copy button.
///
/// Used in [CreateMeetingScreen] and [MeetingDetailsScreen].
class MeetingIdDisplay extends StatelessWidget {
  const MeetingIdDisplay({
    super.key,
    required this.meetingId,
    this.showCopyButton = true,
  });

  final String meetingId;
  final bool showCopyButton;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.tag_rounded,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              meetingId,
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                letterSpacing: 1.5,
                fontSize: 18,
              ),
            ),
          ),
          if (showCopyButton)
            IconButton(
              onPressed: () => _copyToClipboard(context),
              icon: Icon(
                Icons.copy_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              tooltip: AppConstants.copyMeetingId,
            ),
        ],
      ),
    );
  }
}
