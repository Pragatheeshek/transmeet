import 'dart:async';

import 'package:flutter/material.dart';

import 'package:transmeet/features/meeting/models/participant_model.dart';
import 'package:transmeet/features/meeting/services/participant_service.dart';

/// Banner shown at the top of the host's meeting room when participants
/// are waiting for admission.
///
/// Displays each waiting participant with Admit / Deny buttons,
/// similar to Google Meet's admission notification.
class AdmissionBanner extends StatefulWidget {
  const AdmissionBanner({
    super.key,
    required this.meetingDocId,
  });

  final String meetingDocId;

  @override
  State<AdmissionBanner> createState() => _AdmissionBannerState();
}

class _AdmissionBannerState extends State<AdmissionBanner>
    with SingleTickerProviderStateMixin {
  final _participantService = ParticipantService();
  StreamSubscription<List<ParticipantModel>>? _subscription;
  List<ParticipantModel> _waitingParticipants = [];

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation =
        Tween<double>(begin: 0.7, end: 1.0).animate(_pulseController);

    _subscription = _participantService
        .onWaitingParticipants(widget.meetingDocId)
        .listen((waiting) {
      if (mounted) {
        setState(() => _waitingParticipants = waiting);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _admit(ParticipantModel p) async {
    await _participantService.admitParticipant(
        widget.meetingDocId, p.uid);
  }

  Future<void> _deny(ParticipantModel p) async {
    await _participantService.denyParticipant(
        widget.meetingDocId, p.uid);
  }

  Future<void> _admitAll() async {
    for (final p in _waitingParticipants) {
      await _participantService.admitParticipant(
          widget.meetingDocId, p.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_waitingParticipants.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12 * _pulseAnimation.value),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.front_hand_rounded,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_waitingParticipants.length} '
                      '${_waitingParticipants.length == 1 ? 'person wants' : 'people want'} '
                      'to join',
                      style: TextStyle(
                        color: Colors.amber[200],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_waitingParticipants.length > 1)
                    TextButton(
                      onPressed: _admitAll,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Admit all',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Waiting participant tiles
              ...(_waitingParticipants.map((p) => _WaitingTile(
                    participant: p,
                    onAdmit: () => _admit(p),
                    onDeny: () => _deny(p),
                  ))),
            ],
          ),
        );
      },
    );
  }
}

class _WaitingTile extends StatelessWidget {
  const _WaitingTile({
    required this.participant,
    required this.onAdmit,
    required this.onDeny,
  });

  final ParticipantModel participant;
  final VoidCallback onAdmit;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final initial = participant.displayName.isNotEmpty
        ? participant.displayName[0].toUpperCase()
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.deepPurple.withValues(alpha: 0.7),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  participant.preferredLanguage,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
          // Deny button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onDeny,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Deny',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Admit button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAdmit,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Admit',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
