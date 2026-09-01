import 'package:flutter/material.dart';

import 'package:transmeet/features/meeting/models/participant_model.dart';

/// Bottom sheet listing all participants in the current meeting.
///
/// Shows name, host badge, mic/camera status, and preferred language.
class ParticipantPanel extends StatelessWidget {
  const ParticipantPanel({
    super.key,
    required this.participants,
    required this.currentUserId,
  });

  final List<ParticipantModel> participants;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_rounded,
                    color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Participants (${participants.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Participant list
          Expanded(
            child: participants.isEmpty
                ? const Center(
                    child: Text(
                      'No participants',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: participants.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final p = participants[index];
                      final isSelf = p.uid == currentUserId;
                      return _ParticipantTile(
                          participant: p, isSelf: isSelf);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.participant, required this.isSelf});

  final ParticipantModel participant;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = participant.displayName.isNotEmpty
        ? participant.displayName[0].toUpperCase()
        : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSelf
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: isSelf
                ? theme.colorScheme.primary
                : Colors.deepPurple.withValues(alpha: 0.7),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        participant.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '(You)',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                    if (participant.isHost) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            color: Colors.amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  participant.preferredLanguage,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),

          // Mic / Camera status
          Icon(
            participant.isMicOn
                ? Icons.mic_rounded
                : Icons.mic_off_rounded,
            color:
                participant.isMicOn ? Colors.greenAccent : Colors.redAccent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Icon(
            participant.isCameraOn
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            color: participant.isCameraOn
                ? Colors.greenAccent
                : Colors.redAccent,
            size: 18,
          ),
        ],
      ),
    );
  }
}
