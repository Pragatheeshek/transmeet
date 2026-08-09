import 'package:flutter/material.dart';
import 'package:transmeet/core/services/auth_service.dart';

/// Temporary authenticated landing screen.
///
/// Displays the current user's email and display name (if available),
/// and provides a logout button. This screen will later be replaced
/// by the full TransMeet meeting dashboard.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  bool _isLoggingOut = false;

  Future<void> _signOut() async {
    setState(() => _isLoggingOut = true);

    try {
      await _authService.signOut();
      // Navigation is handled by the auth state listener in main.dart.
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
    final displayName = user?.displayName;
    final email = user?.email ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: const Text('TransMeet'),
        actions: [
          _isLoggingOut
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Sign Out',
                  onPressed: _signOut,
                ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ---- Avatar ----
              CircleAvatar(
                radius: 44,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                child: Icon(
                  Icons.person_rounded,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              // ---- Welcome text ----
              Text(
                'Welcome to TransMeet',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // ---- Display name ----
              if (displayName != null && displayName.isNotEmpty) ...[
                Text(
                  displayName,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
              ],

              // ---- Email ----
              Text(
                email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // ---- Logout button ----
              SizedBox(
                width: 200,
                child: OutlinedButton.icon(
                  onPressed: _isLoggingOut ? null : _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: _isLoggingOut
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign Out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
