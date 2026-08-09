import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:transmeet/core/constants/app_constants.dart';

/// Displays a personalised greeting for the currently authenticated user.
///
/// Falls back gracefully: display name → first part of email → "there".
class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({super.key, required this.user});

  final User user;

  /// Returns the best available display name for the greeting.
  String get _firstName {
    final name = user.displayName;
    if (name != null && name.trim().isNotEmpty) {
      // Use the first word of the full name (e.g. "Pragatheesh Raj" → "Pragatheesh").
      return name.trim().split(' ').first;
    }
    final email = user.email;
    if (email != null && email.isNotEmpty) {
      // Use the local part of the email (e.g. "john.doe@gmail.com" → "john.doe").
      return email.split('@').first;
    }
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: theme.textTheme.headlineMedium,
            children: [
              TextSpan(
                text: '${AppConstants.welcomeBack}, ',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: '$_firstName ',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: '👋'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          AppConstants.readyToConnect,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
