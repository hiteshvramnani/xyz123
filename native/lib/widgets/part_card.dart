import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF1F2937)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isOriginal ? 'Original' : 'Addition $index',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500),
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(width: 8),
                  Text(formatDate(date),
                      style:
                          const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                ],
              ],
            ),
            // Title
            if (title != null && title!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Title',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(title!,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFE5E7EB),
                      height: 1.4)),
            ] else if (isOriginal &&
                media.isEmpty &&
                phoneNumber == null &&
                location == null &&
                (phoneNumbers == null || phoneNumbers!.isEmpty) &&
                (locations == null || locations!.isEmpty)) ...[
              const SizedBox(height: 12),
              const Text('No title submitted',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontStyle: FontStyle.italic)),
            ],
            // Phone (single)
            if (phoneNumber != null && phoneNumber!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, size: 14, color: Color(0xFF60A5FA)),
                  const SizedBox(width: 6),
                  Text(phoneNumber!,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFD1D5DB))),
                ],
              ),
            ],
            // Phone (array)
            if (phoneNumbers != null && phoneNumbers!.isNotEmpty) ...[
              for (int i = 0; i < phoneNumbers!.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Color(0xFF60A5FA)),
                      const SizedBox(width: 6),
                      Text(phoneNumbers![i],
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFD1D5DB))),
                    ],
                  ),
                ),
            ],
            // Location (single)
            if (location != null && location!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Color(0xFF22C55E)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(location!,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFFD1D5DB))),
                  ),
                ],
              ),
              if (_isCoords(location!)) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMaps(location!),
                    icon: const Icon(Icons.map, size: 16),
                    label: const Text('Open in Maps'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      side: const BorderSide(color: Color(0xFF3B82F6), width: 1),
                      backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                      textStyle: const TextStyle(fontSize: 12),
                    ).copyWith(
                      foregroundColor: WidgetStateProperty.all(const Color(0xFF60A5FA)),
                    ),
                  ),
                ),
              ],
            ],
            // Location (array)
            if (locations != null && locations!.isNotEmpty) ...[
              for (int i = 0; i < locations!.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Color(0xFF22C55E)),
                          const SizedBox(width: 6),
                          Text(locations![i],
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFFD1D5DB))),
                        ],
                      ),
                      if (_isCoords(locations![i])) ...[
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openMaps(locations![i]),
                            icon: const Icon(Icons.map, size: 14),
                            label: const Text('Open in Maps'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                              side: const BorderSide(color: Color(0xFF3B82F6), width: 1),
                              backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                              textStyle: const TextStyle(fontSize: 11),
                            ).copyWith(
                              foregroundColor: WidgetStateProperty.all(const Color(0xFF60A5FA)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
            // Media
            if (media.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: media
                    .map((m) => MediaCard(
                          mediaItem: m,
                          mediaUrls: mediaUrls,
                          onTap: onMediaTap != null ? () => onMediaTap!(m) : null,
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
