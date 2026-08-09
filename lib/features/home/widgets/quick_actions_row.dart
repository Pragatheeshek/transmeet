import 'package:flutter/material.dart';

/// A single quick-action tile used inside the quick-actions row.
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontally scrollable row of quick-action shortcuts.
///
/// Accepts a list of [QuickAction] descriptors so the home screen can
/// supply the actual navigation callbacks without this widget knowing
/// about routing.
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions
            .map(
              (action) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _QuickActionTile(
                  icon: action.icon,
                  label: action.label,
                  onTap: action.onTap,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Data class representing a single quick action.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
