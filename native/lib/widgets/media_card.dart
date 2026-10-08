import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
          .get(Uri.parse(url), headers: {
        'ngrok-skip-browser-warning': 'true',
      }).timeout(
        const Duration(seconds: 30),
      );

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
    final url = widget.mediaUrls[widget.mediaItem.id];
    final isImage = widget.mediaItem.mediaType == 'IMAGE';
    final isVideo = widget.mediaItem.mediaType == 'VIDEO';

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isImage && url != null)
              _buildImage()
            else if (isVideo)
              _buildVideoPlaceholder()
            else
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file, size: 32, color: Color(0xFF6B7280)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1F2937),
              const Color(0xFF111827),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF374151).withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.videocam,
              size: 32,
              color: Color(0xFF6B7280),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    size: 36,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    Widget child;
    if (_loading) {
      child = const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (_error || _imageBytes == null) {
      child = const Icon(Icons.broken_image, size: 32, color: Color(0xFF6B7280));
    } else {
      child = Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: _loading || _error ? const Color(0xFF1F2937) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}
