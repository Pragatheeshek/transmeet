import 'package:flutter/material.dart';
import 'package:transmeet/core/constants/app_constants.dart';

/// Placeholder screen for Join Meeting.
///
/// Navigation is fully functional. Meeting ID validation and Firestore lookup
/// will be implemented in Module 3 — Meeting Management.
class JoinMeetingScreen extends StatefulWidget {
  const JoinMeetingScreen({super.key});

  @override
  State<JoinMeetingScreen> createState() => _JoinMeetingScreenState();
}

class _JoinMeetingScreenState extends State<JoinMeetingScreen> {
  final _meetingIdController = TextEditingController();

  @override
  void dispose() {
    _meetingIdController.dispose();
    super.dispose();
  }

  void _onJoinTapped() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text(AppConstants.joinMeetingComingSoon),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.joinMeeting),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header illustration
              Center(
                child: Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                'Meeting ID',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _meetingIdController,
                decoration: const InputDecoration(
                  hintText: 'e.g. abc-defg-hij',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),

              // Module 3 note
              Container(
                padding: const EdgeInsets.all(14),
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
                      Icons.info_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Meeting ID validation and joining will be enabled in the next module.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Join button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onJoinTapped,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text(AppConstants.joinMeeting),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
