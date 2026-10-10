import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Centered empty / placeholder state: a restrained icon, a message and an
/// optional action. Used for "no submissions yet", "no matching results", etc.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.message,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String message;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: c.textTertiary),
            AppSpacing.gapLg,
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: c.textSecondary),
            ),
            if (detail != null) ...[
              AppSpacing.gapSm,
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            ],
            if (action != null) ...[
              AppSpacing.gapLg,
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Centered loading spinner, themed to the primary colour.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            AppSpacing.gapLg,
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
