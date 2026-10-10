import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// Full-width primary action button with a built-in loading state. Used for
/// the main call-to-action on a screen or card (Submit, Save, Authenticate…).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final child = loading
        ? SizedBox(
            width: AppIconSize.md,
            height: AppIconSize.md,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(c.onPrimary),
            ),
          )
        : (icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: AppIconSize.md),
                  AppSpacing.gapHSm,
                  Text(label),
                ],
              )
            : Text(label));

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        child: child,
      ),
    );
  }
}

/// Full-width secondary (outlined) action button, matching [PrimaryButton]'s
/// metrics.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: icon != null
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: AppIconSize.md),
              label: Text(label),
            )
          : OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
