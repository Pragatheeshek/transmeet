import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:transmeet/features/meeting/models/meeting_model.dart';

/// Displays the user's meeting history — all meetings they hosted.
///
/// Shows meeting title, date, host, status, and participant count.
class MeetingHistoryScreen extends StatelessWidget {
  const MeetingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: user == null
            ? const Center(child: Text('Not signed in.'))
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('meetings')
                    .where('hostUid', isEqualTo: user.uid)
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load meetings.\n${snapshot.error}',
                        style: TextStyle(
                            color: theme.colorScheme.error, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_rounded,
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No meetings yet',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Meetings you host will appear here.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final meetings = docs
                      .map((doc) => MeetingModel.fromFirestore(doc))
                      .toList();

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: meetings.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final m = meetings[index];
                      return _HistoryCard(meeting: m, theme: theme);
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.meeting, required this.theme});

  final MeetingModel meeting;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(meeting.createdAt);
    final isActive = meeting.isActive;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    meeting.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withValues(alpha: 0.15)
                        : theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Ended',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isActive
                          ? Colors.green
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.tag_rounded,
                    size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  meeting.meetingId,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Icon(Icons.calendar_today_rounded,
                    size: 13, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  dateStr,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  '${meeting.participantCount} participant${meeting.participantCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                Icon(Icons.language_rounded,
                    size: 14, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  meeting.preferredLanguage,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      // Use manual formatting to avoid intl dependency issues
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }
  }
}
