import 'dart:typed_data';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class MediaViewerScreen extends StatefulWidget {
  final String streamUrl;
  final String mediaType;
  final String? mimeType;

  const MediaViewerScreen({
    super.key,
    required this.streamUrl,
    required this.mediaType,
    this.mimeType,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> with WidgetsBindingObserver {
  Uint8List? _imageBytes;
  bool _loading = true;
  bool _error = false;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.mediaType == 'IMAGE') {
      _fetchImage();
    } else if (widget.mediaType == 'VIDEO') {
      _loadVideo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _videoController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_videoController == null) return;
    if (state == AppLifecycleState.paused) {
      _videoController?.pause();
    }
  }

  Future<void> _fetchImage() async {
    try {
      final response = await http
          .get(Uri.parse(widget.streamUrl), headers: {
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

  Future<void> _loadVideo() async {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl));
      await _videoController!.initialize();
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: false,
          showControlsOnInitialize: true,
          aspectRatio: _videoController!.value.aspectRatio,
          materialProgressColors: ChewieProgressColors(
            playedColor: const Color(0xFF2563EB),
            handleColor: const Color(0xFF60A5FA),
            backgroundColor: const Color(0xFF374151),
          ),
        );
        _loading = false;
      });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Media')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _buildMedia(),
        ),
      ),
    );
  }

  Widget _buildMedia() {
    if (widget.mediaType == 'IMAGE') {
      return _buildImage();
    } else if (widget.mediaType == 'VIDEO') {
      return _buildVideoPlayer();
    } else {
      return _buildDocument();
    }
  }

  Widget _buildImage() {
    Widget child;
    if (_loading) {
      child = const Center(child: CircularProgressIndicator());
    } else if (_error || _imageBytes == null) {
      child = _buildError();
    } else {
      child = InteractiveViewer(
        panEnabled: true,
        boundaryMargin: const EdgeInsets.all(20),
        minScale: 0.5,
        maxScale: 4.0,
        child: Image.memory(
          _imageBytes!,
          fit: BoxFit.contain,
        ),
      );
    }
    return child;
  }

  Widget _buildVideoPlayer() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error || _chewieController == null) {
      return _buildError();
    }
    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Chewie(controller: _chewieController!),
    );
  }

  Widget _buildDocument() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file, size: 64, color: Color(0xFF6B7280)),
        const SizedBox(height: 16),
        const Text(
          'Document',
          style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF)),
        ),
        if (widget.mimeType != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.mimeType!,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
        ],
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.broken_image, size: 64, color: Color(0xFF6B7280)),
        const SizedBox(height: 16),
        const Text(
          'Failed to load media',
          style: TextStyle(fontSize: 16, color: Color(0xFFFCA5A5)),
        ),
        const SizedBox(height: 8),
        Text(
          'Status: ${widget.streamUrl}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
