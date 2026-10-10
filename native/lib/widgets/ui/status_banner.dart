import 'package:flutter/material.dart';

import '../../theme/theme.dart';

enum StatusBannerKind { error, success, info }

/// A consistent inline message block used for errors, success and info across
/// the app — replacing the many hand-rolled coloured `Container`s that each
/// repeated their own padding, radius and colour maths.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.kind = StatusBannerKind.error,
    this.icon,
  });

  final String message;
  final StatusBannerKind kind;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (Color bg, Color border, Color fg, IconData defaultIcon) =
        switch (kind) {
      StatusBannerKind.error => (
          c.dangerSubtleBg,
          c.dangerBorder,
          c.dangerText,
          Icons.error_outline,
        ),
      StatusBannerKind.success => (
          c.successSubtleBg,
          c.success.withValues(alpha: 0.5),
          c.success,
          Icons.check_circle_outline,
        ),
      StatusBannerKind.info => (
          c.primarySubtle,
          c.primary.withValues(alpha: 0.4),
          c.accent,
          Icons.info_outline,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.brSm,
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, size: AppIconSize.md, color: fg),
          AppSpacing.gapHSm,
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}
