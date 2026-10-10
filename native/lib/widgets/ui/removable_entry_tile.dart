import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A compact pill row showing a captured entry (a phone number or a location)
/// with a leading semantic icon, optional secondary line, and a remove button.
/// Previously this exact block was duplicated four times across the submit and
/// detail screens.
class RemovableEntryTile extends StatelessWidget {
  const RemovableEntryTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.onRemove,
    this.removeTooltip = 'Remove',
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
        right: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: AppRadii.brSm,
        border: Border.all(color: c.outline),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.sm, color: iconColor),
          AppSpacing.gapHSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.mono(fontSize: 13, color: c.textPrimary),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: context.mono(fontSize: 11, color: c.textTertiary),
                  ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: removeTooltip,
            icon: Icon(Icons.close, size: AppIconSize.sm, color: c.textTertiary),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// A leading-icon text button used to reveal an "add" affordance
/// (e.g. "Add Phone Number", "Add Location").
class AddEntryButton extends StatelessWidget {
  const AddEntryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: AppIconSize.md),
        label: Text(label),
      ),
    );
  }
}
