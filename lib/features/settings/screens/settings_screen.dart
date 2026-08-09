import 'package:flutter/material.dart';
import 'package:transmeet/core/constants/app_constants.dart';

/// Settings screen for TransMeet.
///
/// UI-only placeholder for Module 2. Actual functionality will be wired
/// in future modules.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              onTap: () => _showComingSoon(context),
            ),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Meeting alerts and reminders',
              onTap: () => _showComingSoon(context),
            ),
            const SizedBox(height: 24),

            // ── Language ────────────────────────────────────────────────────
            _SectionHeader(label: 'Preferred Language'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.language_rounded,
              title: AppConstants.defaultLanguage,
              subtitle: 'App interface and translation language',
              trailing: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('English',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey, size: 20),
                ],
              ),
              onTap: () => _showComingSoon(context),
            ),
            const SizedBox(height: 24),

            // ── Audio & Video ───────────────────────────────────────────────
            _SectionHeader(label: 'Audio & Video'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.mic_none_rounded,
              title: 'Microphone',
              subtitle: 'Configure default microphone',
              onTap: () => _showComingSoon(context),
            ),
            _SettingsTile(
              icon: Icons.videocam_outlined,
              title: 'Camera',
              subtitle: 'Configure default camera',
              onTap: () => _showComingSoon(context),
            ),
            _SettingsTile(
              icon: Icons.volume_up_outlined,
              title: 'Speaker',
              subtitle: 'Configure audio output',
              onTap: () => _showComingSoon(context),
            ),
            const SizedBox(height: 24),

            // ── About ────────────────────────────────────────────────────────
            _SectionHeader(label: 'About'),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'About TransMeet',
              subtitle: 'Version ${AppConstants.appVersion}',
              onTap: () => _showAboutDialog(context, theme),
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              onTap: () => _showComingSoon(context),
            ),
            _SettingsTile(
              icon: Icons.description_outlined,
              title: 'Terms of Service',
              subtitle: 'Usage terms and conditions',
              onTap: () => _showComingSoon(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text(AppConstants.featureComingSoon),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showAboutDialog(BuildContext context, ThemeData theme) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationLegalese: '© 2026 TransMeet',
      children: [
        const SizedBox(height: 12),
        const Text(
          'TransMeet is an AI-powered video conferencing application '
          'with real-time voice translation.',
        ),
      ],
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
