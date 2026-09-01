import 'package:flutter/material.dart';
import 'package:transmeet/core/constants/app_constants.dart';
import 'package:transmeet/core/services/auth_service.dart';
import 'package:transmeet/features/home/widgets/language_preference_chip.dart';
import 'package:transmeet/features/home/widgets/meeting_action_card.dart';
import 'package:transmeet/features/home/widgets/quick_actions_row.dart';
import 'package:transmeet/features/home/widgets/recent_meetings_section.dart';
import 'package:transmeet/features/home/widgets/welcome_header.dart';
import 'package:transmeet/features/meeting/screens/create_meeting_screen.dart';
import 'package:transmeet/features/meeting/screens/join_meeting_screen.dart';
import 'package:transmeet/features/meeting/screens/meeting_history_screen.dart';
import 'package:transmeet/features/profile/screens/profile_screen.dart';
import 'package:transmeet/features/settings/screens/settings_screen.dart';

/// Main dashboard screen shown to authenticated users.
///
/// Provides quick access to: Create Meeting, Join Meeting, Recent Meetings,
/// Profile, Settings, and Logout.
///
/// Navigation back to [LoginScreen] after logout is handled automatically
/// by the [StreamBuilder<User?>] in [main.dart].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  bool _isLoggingOut = false;

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openCreateMeeting() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
    );
  }

  void _openJoinMeeting() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JoinMeetingScreen()),
    );
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MeetingHistoryScreen()),
    );
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    // Defensive: if user is null the StreamBuilder in main.dart will redirect.
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome ──────────────────────────────────────────────────
              WelcomeHeader(user: user),
              const SizedBox(height: 28),

              // ── Meeting action cards ──────────────────────────────────────
              _buildActionCards(context),
              const SizedBox(height: 28),

              // ── Quick actions ─────────────────────────────────────────────
              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              QuickActionsRow(
                actions: [
                  QuickAction(
                    icon: Icons.videocam_rounded,
                    label: 'Create',
                    onTap: _openCreateMeeting,
                  ),
                  QuickAction(
                    icon: Icons.link_rounded,
                    label: 'Join',
                    onTap: _openJoinMeeting,
                  ),
                  QuickAction(
                    icon: Icons.history_rounded,
                    label: 'History',
                    onTap: _openHistory,
                  ),
                  QuickAction(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    onTap: _openProfile,
                  ),
                  QuickAction(
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: _openSettings,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Language preference ───────────────────────────────────────
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: const LanguagePreferenceChip(),
                ),
              ),
              const SizedBox(height: 28),

              // ── Recent meetings ───────────────────────────────────────────
              const RecentMeetingsSection(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  AppBar _buildAppBar(BuildContext context) {
    final user = _authService.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? user?.email ?? '';

    return AppBar(
      title: const Text(AppConstants.appName),
      centerTitle: false,
      actions: [
        if (_isLoggingOut)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Row(
            children: [
              IconButton(
                tooltip: 'Profile',
                onPressed: _openProfile,
                icon: _buildAvatarIcon(context, photoUrl, displayName),
              ),
              PopupMenuButton<String>(
                tooltip: 'More options',
                onSelected: (value) {
                  if (value == 'logout') _confirmSignOut();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 20),
                        SizedBox(width: 12),
                        Text(AppConstants.signOut),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  /// Builds the small avatar in the AppBar — photo, initials, or icon.
  Widget _buildAvatarIcon(
    BuildContext context,
    String? photoUrl,
    String displayName,
  ) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 17,
        backgroundColor: primary.withValues(alpha: 0.15),
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {},
      );
    }

    String initials = '';
    if (displayName.isNotEmpty) {
      final parts = displayName.trim().split(' ');
      initials = parts.map((p) => p.isNotEmpty ? p[0] : '').join('');
      if (initials.length > 2) initials = initials.substring(0, 2);
    }

    return CircleAvatar(
      radius: 17,
      backgroundColor: primary.withValues(alpha: 0.15),
      child: initials.isNotEmpty
          ? Text(
              initials.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: primary,
              ),
            )
          : Icon(Icons.person_rounded, size: 20, color: primary),
    );
  }

  /// Builds the two primary action cards adaptively:
  /// - Side by side when the screen is wide enough (≥ 360dp each card).
  /// - Stacked vertically on narrow screens.
  Widget _buildActionCards(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRow = constraints.maxWidth >= 360;

        final createCard = MeetingActionCard(
          icon: Icons.videocam_rounded,
          title: AppConstants.createMeeting,
          subtitle: 'Start a new video meeting',
          onTap: _openCreateMeeting,
          isPrimary: true,
        );

        final joinCard = MeetingActionCard(
          icon: Icons.link_rounded,
          title: AppConstants.joinMeeting,
          subtitle: 'Enter a meeting ID to join',
          onTap: _openJoinMeeting,
        );

        if (useRow) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: createCard),
                const SizedBox(width: 12),
                Expanded(child: joinCard),
              ],
            ),
          );
        }

        return Column(
          children: [
            createCard,
            const SizedBox(height: 12),
            joinCard,
          ],
        );
      },
    );
  }
}
