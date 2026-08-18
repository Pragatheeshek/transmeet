import 'package:flutter/material.dart';

import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/features/meeting/models/meeting_model.dart';

/// A card displaying a single meeting's summary information.
///
/// Used in the Recent Meetings section of the Home dashboard.
class MeetingCard extends StatelessWidget {
  const MeetingCard({
    super.key,
    required this.meeting,
    required this.onTap,
  });

  final MeetingModel meeting;
  final VoidCallback onTap;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final meetingDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(meetingDate).inDays;

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    if (difference == 0) return 'Today, $timeStr';
    if (difference == 1) return 'Yesterday, $timeStr';

    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    if (difference < 7) {
      return '${weekdays[date.weekday - 1]}, $timeStr';
    }
    return '${months[date.month - 1]} ${date.day}, $timeStr';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Leading icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: meeting.isActive
                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                      : theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  meeting.isActive
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  size: 22,
                  color: meeting.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),

              // Meeting info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meeting.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          meeting.meetingId,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDate(meeting.createdAt),
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
