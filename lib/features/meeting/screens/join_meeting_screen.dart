import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/core/utils/meeting_id_generator.dart';
import 'package:transmeet/features/meeting/screens/meeting_details_screen.dart';
import 'package:transmeet/features/meeting/services/meeting_service.dart';

/// Screen for joining an existing meeting by entering a Meeting ID.
///
/// Validates the ID format, queries Firestore, and navigates to
/// [MeetingDetailsScreen] if the meeting is found and active.
class JoinMeetingScreen extends StatefulWidget {
  const JoinMeetingScreen({super.key});

  @override
  State<JoinMeetingScreen> createState() => _JoinMeetingScreenState();
}

class _JoinMeetingScreenState extends State<JoinMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _meetingIdController = TextEditingController();
  final _meetingService = MeetingService();

  bool _isSearching = false;
  String? _searchError;

  @override
  void dispose() {
    _meetingIdController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  String? _validateMeetingId(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return AppConstants.meetingIdRequired;
    if (!MeetingIdGenerator.isValidFormat(trimmed)) {
      return AppConstants.meetingIdInvalidFormat;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Join flow
  // ---------------------------------------------------------------------------

  Future<void> _onJoinMeeting() async {
    // Clear previous search error.
    setState(() => _searchError = null);

    if (!_formKey.currentState!.validate()) return;
    if (_isSearching) return;

    setState(() => _isSearching = true);

    try {
      final inputId = _meetingIdController.text.trim();
      final meeting = await _meetingService.getMeetingByMeetingId(inputId);

      if (!mounted) return;

      if (meeting == null) {
        setState(() {
          _searchError = AppConstants.meetingNotFound;
          _isSearching = false;
        });
        return;
      }

      if (!meeting.isActive) {
        setState(() {
          _searchError = AppConstants.meetingEnded;
          _isSearching = false;
        });
        return;
      }

      // Meeting found and active — show confirmation dialog.
      final confirmed = await _showJoinConfirmation(
        title: meeting.title,
        hostName: meeting.hostName,
        meetingId: meeting.meetingId,
      );

      if (!mounted) return;
      setState(() => _isSearching = false);

      if (confirmed == true) {
        // Increment participant count.
        final user = FirebaseAuth.instance.currentUser;
        final isHost = user != null && user.uid == meeting.hostUid;

        if (!isHost) {
          await _meetingService.incrementParticipantCount(meeting.docId);
        }

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MeetingDetailsScreen(
              meeting: meeting,
              isNewlyCreated: false,
              isHost: isHost,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e is String ? e : AppConstants.meetingJoinError,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    }
  }

  Future<bool?> _showJoinConfirmation({
    required String title,
    required String hostName,
    required String meetingId,
  }) {
    final theme = Theme.of(context);

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.videocam_rounded,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            const Text('Join Meeting?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  '${AppConstants.hostedBy}: $hostName',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.tag_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  meetingId,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.primary,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppConstants.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppConstants.joinMeetingAction),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.joinMeeting),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isSearching ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header illustration
                Center(
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.link_rounded,
                      size: 60,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  AppConstants.joinMeeting,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter a meeting ID to join an existing meeting.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Meeting ID field
                Text(
                  AppConstants.enterMeetingId,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _meetingIdController,
                  validator: _validateMeetingId,
                  decoration: InputDecoration(
                    hintText: AppConstants.meetingIdHint,
                    prefixIcon: const Icon(Icons.tag_rounded),
                    errorText: _searchError,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  enabled: !_isSearching,
                  onFieldSubmitted: (_) => _onJoinMeeting(),
                  onChanged: (_) {
                    // Clear search error when user types.
                    if (_searchError != null) {
                      setState(() => _searchError = null);
                    }
                  },
                ),
                const SizedBox(height: 32),

                // Join button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSearching ? null : _onJoinMeeting,
                    icon: _isSearching
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.login_rounded),
                    label: Text(
                      _isSearching
                          ? AppConstants.findingMeeting
                          : AppConstants.joinMeeting,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
