import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A single tappable row in an options bottom sheet.
class AppSheetOption {
  const AppSheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
}

/// Shows a themed bottom sheet with arbitrary [child] content. Styling
/// (background, radius, drag handle) comes from `bottomSheetTheme`.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget child,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(child: child),
  );
}

/// Shows a themed bottom sheet listing [options] as rows. Each row pops the
/// sheet before invoking its action, so callers don't repeat that dance.
Future<void> showAppOptionsSheet(
  BuildContext context, {
  String? title,
  required List<AppSheetOption> options,
}) {
  return showAppSheet<void>(
    context,
    child: Builder(
      builder: (context) {
        final c = context.colors;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            for (final option in options)
              ListTile(
                leading: Icon(
                  option.icon,
                  color: option.isDestructive ? c.danger : c.textSecondary,
                ),
                title: Text(
                  option.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color:
                            option.isDestructive ? c.danger : c.textPrimary,
                      ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  option.onTap();
                },
              ),
            AppSpacing.gapSm,
          ],
        );
      },
    ),
  );
}
