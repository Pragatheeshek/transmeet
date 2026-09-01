import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/features/meeting/screens/meeting_details_screen.dart';
import 'package:transmeet/features/meeting/services/meeting_service.dart';
import 'package:transmeet/features/meeting/widgets/meeting_id_display.dart';

/// Screen for creating a new meeting.
///
/// The user provides a meeting title. The meeting ID is generated
/// automatically. Host info is loaded from [FirebaseAuth.instance.currentUser].
class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _meetingService = MeetingService();

  String _selectedLanguage = AppConstants.supportedLanguages.first;
  bool _isCreating = false;
  bool _admissionControl = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  String? _validateTitle(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return AppConstants.meetingTitleRequired;
    if (trimmed.length < 2) return AppConstants.meetingTitleTooShort;
    if (trimmed.length > 80) return AppConstants.meetingTitleTooLong;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Create meeting
  // ---------------------------------------------------------------------------

  Future<void> _onCreateMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isCreating) return;

    setState(() => _isCreating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'You must be signed in to create a meeting.';
      }

      final meeting = await _meetingService.createMeeting(
        title: _titleController.text.trim(),
        hostUid: user.uid,
        hostName: user.displayName ?? user.email?.split('@').first ?? 'Host',
        hostEmail: user.email ?? '',
        preferredLanguage: _selectedLanguage,
        admissionControl: _admissionControl,
      );

      if (!mounted) return;

      // Navigate to details, replacing this screen.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MeetingDetailsScreen(
            meeting: meeting,
            isNewlyCreated: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e is String ? e : AppConstants.meetingCreateError,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.createMeeting),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
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
                      Icons.videocam_rounded,
                      size: 60,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  AppConstants.createMeeting,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a new video meeting instantly.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Meeting Title field
                Text(
                  AppConstants.meetingTitle,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  validator: _validateTitle,
                  decoration: const InputDecoration(
                    hintText: AppConstants.meetingTitleHint,
                    prefixIcon: Icon(Icons.title_rounded),
                  ),
                  textInputAction: TextInputAction.done,
                  enabled: !_isCreating,
                  onFieldSubmitted: (_) => _onCreateMeeting(),
                ),
                const SizedBox(height: 20),

                // Host name (read-only)
                Text(
                  AppConstants.yourName,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        user?.displayName ??
                            user?.email?.split('@').first ??
                            'You',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Meeting ID (auto-generated, read-only)
                Text(
                  AppConstants.meetingId,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                MeetingIdDisplay(
                  meetingId: 'TM-XXXXXX',
                  showCopyButton: false,
                ),
                const SizedBox(height: 20),

                // Preferred language selector
                Text(
                  AppConstants.preferredLanguage,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguage,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.language_rounded),
                  ),
                  items: AppConstants.supportedLanguages
                      .map((lang) => DropdownMenuItem(
                            value: lang,
                            child: Text(lang),
                          ))
                      .toList(),
                  onChanged: _isCreating
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedLanguage = value);
                          }
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return AppConstants.languageRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Admission control toggle
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.15),
                    ),
                  ),
                  child: SwitchListTile(
                    value: _admissionControl,
                    onChanged: _isCreating
                        ? null
                        : (value) =>
                            setState(() => _admissionControl = value),
                    title: const Text('Require admission'),
                    subtitle: Text(
                      _admissionControl
                          ? 'You must approve each participant'
                          : 'Anyone with the meeting ID can join',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    secondary: Icon(
                      _admissionControl
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Create button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCreating ? null : _onCreateMeeting,
                    icon: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.videocam_rounded),
                    label: Text(
                      _isCreating
                          ? AppConstants.creatingMeeting
                          : AppConstants.createMeeting,
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
