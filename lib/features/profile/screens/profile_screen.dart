import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/core/services/auth_service.dart';

/// Profile screen for the authenticated user.
///
/// Displays Firebase user information: avatar, display name, email,
/// and the sign-in provider. Provides access to logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  bool _isLoggingOut = false;

  /// Returns a human-readable provider label from the Firebase provider ID.
  String _providerLabel(User user) {
    if (user.providerData.isEmpty) return 'Email & Password';
    final id = user.providerData.first.providerId;
    switch (id) {
      case 'google.com':
        return 'Google';
      case 'microsoft.com':
        return 'Microsoft';
      case 'password':
        return 'Email & Password';
      default:
        return id;
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppConstants.signOutConfirmTitle),
        content: const Text(AppConstants.signOutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppConstants.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text(AppConstants.confirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isLoggingOut = true);

    try {
      await _authService.signOut();
      // Navigation is handled by main.dart StreamBuilder.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = _authService.currentUser;

    if (user == null) {
      // Defensive: shouldn't happen since ProfileScreen is auth-gated.
      return const Scaffold(
        body: Center(child: Text('No user data available.')),
      );
    }

    final displayName = user.displayName ?? '';
    final email = user.email ?? '';
    final provider = _providerLabel(user);
    final photoUrl = user.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.profile),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Avatar section ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Column(
                  children: [
                    _buildAvatar(context, photoUrl, displayName, email),
                    const SizedBox(height: 16),
                    if (displayName.isNotEmpty)
                      Text(
                        displayName,
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Provider badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'via $provider',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Action tiles ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _ActionTile(
                      icon: Icons.edit_outlined,
                      label: 'Edit Profile',
                      subtitle: 'Update your display name and photo',
                      onTap: () {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            const SnackBar(
                              content:
                                  Text(AppConstants.featureComingSoon),
                            ),
                          );
                      },
                    ),
                    const SizedBox(height: 8),
                    _ActionTile(
                      icon: Icons.lock_outline_rounded,
                      label: 'Change Password',
                      subtitle: 'Update your account password',
                      onTap: () {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            const SnackBar(
                              content:
                                  Text(AppConstants.featureComingSoon),
                            ),
                          );
                      },
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Logout tile
                    _ActionTile(
                      icon: Icons.logout_rounded,
                      label: AppConstants.signOut,
                      subtitle: 'Sign out of your account',
                      isDestructive: true,
                      onTap: _isLoggingOut ? null : _confirmSignOut,
                      trailing: _isLoggingOut
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the user avatar — profile photo if available, initials otherwise.
  Widget _buildAvatar(
    BuildContext context,
    String? photoUrl,
    String displayName,
    String email,
  ) {
    final theme = Theme.of(context);

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 52,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {},
      );
    }

    // Generate initials from display name or email.
    String initials = '';
    if (displayName.isNotEmpty) {
      final parts = displayName.trim().split(' ');
      initials = parts.map((p) => p.isNotEmpty ? p[0] : '').join('');
      if (initials.length > 2) initials = initials.substring(0, 2);
    } else if (email.isNotEmpty) {
      initials = email[0].toUpperCase();
    }

    return CircleAvatar(
      radius: 52,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      child: initials.isNotEmpty
          ? Text(
              initials.toUpperCase(),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            )
          : Icon(
              Icons.person_rounded,
              size: 52,
              color: theme.colorScheme.primary,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private action tile widget
// ---------------------------------------------------------------------------

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isDestructive ? theme.colorScheme.error : theme.colorScheme.primary;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        title: Text(
          label,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isDestructive ? theme.colorScheme.error : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall,
        ),
        trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: color),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}
