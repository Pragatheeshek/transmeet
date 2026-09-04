import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/features/profile/screens/profile_screen.dart';
import 'package:transmeet/features/translation/models/translation_language.dart';
import 'package:transmeet/main.dart';

/// Settings screen for TransMeet.
///
/// Provides Profile, Language, Appearance, Audio & Video, and About sections.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selectedLanguageName = AppConstants.defaultLanguage;
  bool _isLoadingLanguage = true;

  // Audio & Video preferences (in-memory for now)
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  bool _speakerOn = true;
  String _cameraFacing = 'Front';

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingLanguage = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final langCode = data?['preferredLanguageCode'] as String? ?? 'en';
        final lang = TranslationLanguage.fromCode(langCode);
        if (lang != null && mounted) {
          setState(() => _selectedLanguageName = lang.name);
        }
      }
    } catch (_) {
      // Use default
    }

    if (mounted) setState(() => _isLoadingLanguage = false);
  }

  Future<void> _showLanguagePicker() async {
    final selected = await showDialog<TranslationLanguage>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text(AppConstants.selectMyLanguage),
        children: TranslationLanguage.supportedLanguages.map((lang) {
          final isSelected = lang.name == _selectedLanguageName;
          return SimpleDialogOption(
            onPressed: () => Navigator.of(ctx).pop(lang),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lang.name,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(ctx).colorScheme.primary
                          : null,
                    ),
                  ),
                ),
                Text(
                  lang.code.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_rounded,
                      size: 18, color: Theme.of(ctx).colorScheme.primary),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );

    if (selected != null && selected.name != _selectedLanguageName) {
      await _saveLanguagePreference(selected);
    }
  }

  Future<void> _saveLanguagePreference(TranslationLanguage language) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'preferredLanguageCode': language.code,
        'preferredLanguage': language.name,
        'displayName': user.displayName ?? '',
        'email': user.email ?? '',
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _selectedLanguageName = language.name);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text(AppConstants.languageSaved),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text(AppConstants.languageSaveFailed),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------

  String get _themeLabel {
    final mode = TransMeetApp.themeProvider.themeMode;
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _showThemePicker() {
    final provider = TransMeetApp.themeProvider;
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choose Theme'),
        children: [
          _themeOption(ctx, provider, ThemeMode.system, 'System Default',
              Icons.brightness_auto_rounded),
          _themeOption(ctx, provider, ThemeMode.light, 'Light',
              Icons.light_mode_rounded),
          _themeOption(ctx, provider, ThemeMode.dark, 'Dark',
              Icons.dark_mode_rounded),
        ],
      ),
    );
  }

  Widget _themeOption(BuildContext ctx, dynamic provider, ThemeMode mode,
      String label, IconData icon) {
    final isSelected = provider.themeMode == mode;
    return SimpleDialogOption(
      onPressed: () {
        provider.setThemeMode(mode);
        Navigator.of(ctx).pop();
        setState(() {}); // rebuild to update subtitle
      },
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: isSelected
                  ? Theme.of(ctx).colorScheme.primary
                  : Theme.of(ctx).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Theme.of(ctx).colorScheme.primary : null,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded,
                size: 18, color: Theme.of(ctx).colorScheme.primary),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Audio & Video

  // ---------------------------------------------------------------------------
  // About
  // ---------------------------------------------------------------------------

  void _showAboutScreen() {
    final theme = Theme.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('About TransMeet')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // App logo + name
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/transmeet_logo.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('TransMeet',
                          style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text('Version ${AppConstants.appVersion}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Description
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('About',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'TransMeet is an AI-powered video conferencing application '
                        'with real-time voice translation. Connect with anyone in '
                        'the world, speak in your language, and they hear it in theirs.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Features
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star_outline_rounded,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Features',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _featureItem(theme, 'HD Video Conferencing'),
                      _featureItem(theme, 'Real-Time AI Translation'),
                      _featureItem(theme, '15+ Language Support'),
                      _featureItem(theme, 'Host Controls & Admission'),
                      _featureItem(theme, 'Meeting History'),
                      _featureItem(theme, 'Dark & Light Theme'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Legal
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.gavel_rounded,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Legal',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('© 2026 TransMeet. All rights reserved.',
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text(
                        'By using this app, you agree to our Terms of Service '
                        'and Privacy Policy.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Made with ❤️ for global communication',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
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

  Widget _featureItem(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(text, style: theme.textTheme.bodyMedium),
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
        title: const Text(AppConstants.settings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Account ────────────────────────────────────────────────────
            _SectionHeader(label: 'Account'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              subtitle: 'Manage your account details',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen()),
                );
              },
            ),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Meeting alerts and reminders',
              onTap: () => _showNotificationSettings(),
            ),
            const SizedBox(height: 24),

            // ── Language ────────────────────────────────────────────────────
            _SectionHeader(label: 'Translation Language'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.translate_rounded,
              title: AppConstants.myLanguage,
              subtitle: 'Language for translation during meetings',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoadingLanguage)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(_selectedLanguageName,
                        style: TextStyle(
                            color: theme.colorScheme.primary, fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant, size: 20),
                ],
              ),
              onTap: _showLanguagePicker,
            ),
            const SizedBox(height: 24),

            // ── Theme ─────────────────────────────────────────────────────
            _SectionHeader(label: 'Appearance'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.dark_mode_rounded,
              title: 'Theme',
              subtitle: _themeLabel,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_themeLabel,
                      style: TextStyle(
                          color: theme.colorScheme.primary, fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant, size: 20),
                ],
              ),
              onTap: _showThemePicker,
            ),
            const SizedBox(height: 24),

            // ── Audio & Video ───────────────────────────────────────────────
            _SectionHeader(label: 'Audio & Video'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.mic_none_rounded,
              title: 'Microphone',
              subtitle: _micEnabled ? 'On by default' : 'Off by default',
              trailing: Switch(
                value: _micEnabled,
                onChanged: (val) => setState(() => _micEnabled = val),
                activeThumbColor: theme.colorScheme.primary,
              ),
              onTap: () => setState(() => _micEnabled = !_micEnabled),
            ),
            _SettingsTile(
              icon: Icons.videocam_outlined,
              title: 'Camera',
              subtitle: _cameraEnabled ? 'On by default' : 'Off by default',
              trailing: Switch(
                value: _cameraEnabled,
                onChanged: (val) => setState(() => _cameraEnabled = val),
                activeThumbColor: theme.colorScheme.primary,
              ),
              onTap: () =>
                  setState(() => _cameraEnabled = !_cameraEnabled),
            ),
            _SettingsTile(
              icon: Icons.volume_up_outlined,
              title: 'Speaker',
              subtitle: _speakerOn ? 'Speaker mode' : 'Earpiece mode',
              trailing: Switch(
                value: _speakerOn,
                onChanged: (val) => setState(() => _speakerOn = val),
                activeThumbColor: theme.colorScheme.primary,
              ),
              onTap: () => setState(() => _speakerOn = !_speakerOn),
            ),
            _SettingsTile(
              icon: Icons.flip_camera_android_rounded,
              title: 'Default Camera',
              subtitle: '$_cameraFacing camera',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_cameraFacing,
                      style: TextStyle(
                          color: theme.colorScheme.primary, fontSize: 13)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant, size: 20),
                ],
              ),
              onTap: () {
                setState(() {
                  _cameraFacing =
                      _cameraFacing == 'Front' ? 'Back' : 'Front';
                });
              },
            ),
            const SizedBox(height: 24),

            // ── About ────────────────────────────────────────────────────────
            _SectionHeader(label: 'About'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About TransMeet',
              subtitle: 'Version ${AppConstants.appVersion}',
              onTap: _showAboutScreen,
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              onTap: () => _showPrivacyPolicy(),
            ),
            _SettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Usage terms and conditions',
              onTap: () => _showTermsOfService(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Notification settings
  // ---------------------------------------------------------------------------

  void _showNotificationSettings() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool meetingReminders = true;
        bool joinAlerts = true;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Notifications',
                      style: theme.textTheme.titleLarge),
                  const SizedBox(height: 20),
                  _ToggleTile(
                    icon: Icons.alarm_rounded,
                    title: 'Meeting Reminders',
                    subtitle: 'Get reminded before scheduled meetings',
                    value: meetingReminders,
                    onChanged: (val) =>
                        setSheetState(() => meetingReminders = val),
                  ),
                  const SizedBox(height: 8),
                  _ToggleTile(
                    icon: Icons.person_add_rounded,
                    title: 'Join Alerts',
                    subtitle: 'Alert when someone joins your meeting',
                    value: joinAlerts,
                    onChanged: (val) =>
                        setSheetState(() => joinAlerts = val),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Privacy & Terms (scrollable text screens)
  // ---------------------------------------------------------------------------

  void _showPrivacyPolicy() {
    final theme = Theme.of(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Privacy Policy')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Privacy Policy', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Last updated: September 2026',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              _policySection(theme, 'Information We Collect',
                  'TransMeet collects minimal user data necessary for the video conferencing service. This includes your display name, email address, and meeting preferences stored securely in Firebase.'),
              _policySection(theme, 'Audio & Video Data',
                  'Video and audio streams are transmitted in real-time using WebRTC peer-to-peer connections. TransMeet does not record or store your audio/video data on our servers.'),
              _policySection(theme, 'Translation Data',
                  'Voice data sent for translation is processed in real-time and is not stored permanently. Translation results are cached temporarily for display purposes only.'),
              _policySection(theme, 'Data Security',
                  'We use Firebase Authentication and Firestore with security rules to protect your data. All data in transit is encrypted using TLS.'),
              _policySection(theme, 'Your Rights',
                  'You may delete your account and associated data at any time by contacting us or through the app settings.'),
            ],
          ),
        ),
      ),
    ));
  }

  void _showTermsOfService() {
    final theme = Theme.of(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Terms of Service')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Terms of Service',
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('Last updated: September 2026',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),
              _policySection(theme, 'Acceptance of Terms',
                  'By using TransMeet, you agree to these terms and conditions. If you do not agree, please do not use the application.'),
              _policySection(theme, 'Use of Service',
                  'TransMeet provides video conferencing with real-time translation capabilities. You agree to use the service only for lawful purposes and in accordance with these terms.'),
              _policySection(theme, 'User Conduct',
                  'You are responsible for your conduct during meetings. You may not use TransMeet for harassment, illegal activities, or any purpose that violates these terms.'),
              _policySection(theme, 'Intellectual Property',
                  'TransMeet and its content, features, and functionality are owned by the TransMeet team and are protected by international copyright laws.'),
              _policySection(theme, 'Limitation of Liability',
                  'TransMeet is provided "as is" without warranties of any kind. We are not liable for any damages arising from your use of the service.'),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _policySection(ThemeData theme, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(content, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: trailing ??
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: theme.colorScheme.primary,
        ),
        onTap: () => onChanged(!value),
      ),
    );
  }
}
