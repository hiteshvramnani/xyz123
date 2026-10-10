import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A padded surface card built on the themed [Card] (border, radius and colour
/// come from `cardTheme`). Optionally renders a [title] header row.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.padding = AppSpacing.cardPadding,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card(
      margin: margin,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleMedium),
              AppSpacing.gapMd,
              Divider(height: 1, color: c.outline),
              AppSpacing.gapMd,
            ],
            child,
          ],
        ),
      ),
    );
  }
}
