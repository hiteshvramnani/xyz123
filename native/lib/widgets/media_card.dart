import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/theme.dart';
import 'media_item_data.dart';

class MediaCard extends StatefulWidget {
  final MediaItemData mediaItem;
  final Map<String, String> mediaUrls;
  final void Function()? onTap;

  const MediaCard({
    super.key,
    required this.mediaItem,
    required this.mediaUrls,
    this.onTap,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  Uint8List? _imageBytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  @override
  void didUpdateWidget(MediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mediaUrls[widget.mediaItem.id] !=
        oldWidget.mediaUrls[oldWidget.mediaItem.id]) {
      setState(() {
        _imageBytes = null;
        _loading = true;
        _error = false;
      });
      _fetchImage();
    }
  }

  Future<void> _fetchImage() async {
    if (widget.mediaItem.mediaType != 'IMAGE') return;
    final url = widget.mediaUrls[widget.mediaItem.id];
    if (url == null) return;

    try {
      final response = await http
          .get(Uri.parse(url), headers: {'ngrok-skip-browser-warning': 'true'})
          .timeout(const Duration(seconds: 30));

      if (mounted) {
        setState(() {
          if (response.statusCode == 200) {
            _imageBytes = response.bodyBytes;
          } else {
            _error = true;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final url = widget.mediaUrls[widget.mediaItem.id];
    final isImage = widget.mediaItem.mediaType == 'IMAGE';
    final isVideo = widget.mediaItem.mediaType == 'VIDEO';

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: AppSizes.thumbnail,
        height: AppSizes.thumbnail,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isImage && url != null)
              _buildImage(c)
            else if (isVideo)
              _buildVideoPlaceholder(c)
            else
              Container(
                decoration: BoxDecoration(
                  color: c.surfaceVariant,
                  borderRadius: AppRadii.brMd,
                  border: Border.all(color: c.outline),
                ),
                child: Icon(
                  Icons.insert_drive_file_outlined,
                  size: AppIconSize.xl,
                  color: c.textTertiary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder(AppColors c) {
    return ClipRRect(
      borderRadius: AppRadii.brMd,
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: AppRadii.brMd,
          border: Border.all(color: c.outline),
        ),
        child: Center(
          child: Icon(
            Icons.play_arrow_rounded,
            size: AppIconSize.xl,
            color: c.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildImage(AppColors c) {
    Widget child;
    if (_loading) {
      child = const Center(
        child: SizedBox(
          width: AppIconSize.md,
          height: AppIconSize.md,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (_error || _imageBytes == null) {
      child = Icon(
        Icons.broken_image_outlined,
        size: AppIconSize.xl,
        color: c.textTertiary,
      );
    } else {
      child = Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return ClipRRect(
      borderRadius: AppRadii.brMd,
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: AppRadii.brMd,
          border: Border.all(color: c.outline),
        ),
        child: child,
      ),
    );
  }
}
