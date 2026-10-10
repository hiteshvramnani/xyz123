import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/theme.dart';
import 'date_formatter.dart';
import 'media_card.dart';
import 'media_item_data.dart';

class PartCard extends StatelessWidget {
  final int index;
  final String? title;
  final String? date;
  final String? phoneNumber;
  final String? location;
  final List<String>? phoneNumbers;
  final List<String>? locations;
  final List<MediaItemData> media;
  final Map<String, String> mediaUrls;
  final bool isOriginal;
  final void Function(MediaItemData)? onMediaTap;

  const PartCard({
    super.key,
    required this.index,
    this.title,
    this.date,
    this.phoneNumber,
    this.location,
    this.phoneNumbers,
    this.locations,
    required this.media,
    required this.mediaUrls,
    required this.isOriginal,
    this.onMediaTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final textTheme = Theme.of(context).textTheme;

    final allPhones = <String>[
      if (phoneNumber != null && phoneNumber!.isNotEmpty) phoneNumber!,
      ...?phoneNumbers,
    ];
    final allLocations = <String>[
      if (location != null && location!.isNotEmpty) location!,
      ...?locations,
    ];

    final isEmpty = (title == null || title!.isEmpty) &&
        media.isEmpty &&
        allPhones.isEmpty &&
        allLocations.isEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PartBadge(label: isOriginal ? 'Original' : 'Addition $index'),
                if (date != null) ...[
                  AppSpacing.gapHSm,
                  Text(
                    formatDate(date),
                    style: context.mono(fontSize: 11, color: c.textTertiary),
                  ),
                ],
              ],
            ),
            if (title != null && title!.isNotEmpty) ...[
              AppSpacing.gapMd,
              Text(title!, style: textTheme.bodyLarge),
            ] else if (isEmpty) ...[
              AppSpacing.gapMd,
              Text(
                'No title submitted',
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            for (final phone in allPhones) ...[
              AppSpacing.gapSm,
              _IconLine(
                icon: Icons.phone_outlined,
                iconColor: c.accent,
                child: Text(phone, style: context.mono(color: c.textPrimary)),
              ),
            ],
            for (final loc in allLocations) ...[
              AppSpacing.gapSm,
              _IconLine(
                icon: Icons.location_on_outlined,
                iconColor: c.accent,
                child: Text(loc, style: context.mono(color: c.textPrimary)),
              ),
              if (_isCoords(loc)) ...[
                AppSpacing.gapSm,
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMaps(loc),
                    icon: const Icon(Icons.map_outlined, size: AppIconSize.sm),
                    label: const Text('Open in Maps'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      textStyle: textTheme.labelSmall,
                    ),
                  ),
                ),
              ],
            ],
            if (media.isNotEmpty) ...[
              AppSpacing.gapMd,
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: media
                    .map((m) => MediaCard(
                          mediaItem: m,
                          mediaUrls: mediaUrls,
                          onTap:
                              onMediaTap != null ? () => onMediaTap!(m) : null,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isCoords(String loc) {
    return RegExp(r'^[-0-9.]+,[-0-9.]+$').hasMatch(loc);
  }

  Future<void> _openMaps(String loc) async {
    final uri = Uri.parse('https://www.google.com/maps?q=$loc');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _PartBadge extends StatelessWidget {
  const _PartBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: AppRadii.brSm,
        border: Border.all(color: c.outline),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: c.textSecondary, letterSpacing: 0.6),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: AppIconSize.sm, color: iconColor),
        ),
        AppSpacing.gapHSm,
        Expanded(child: child),
      ],
    );
  }
}
