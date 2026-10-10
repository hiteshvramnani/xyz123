import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mime/mime.dart';

import '../models/submission.dart';
import '../widgets/map_picker.dart';
import '../widgets/part_card.dart';
import '../widgets/media_item_data.dart';
import '../main.dart' as app;
import 'home_screen.dart';
import 'media_viewer.dart';
import 'submit_screen.dart';

class SubmissionDetailScreen extends StatefulWidget {
  final String submissionId;

  const SubmissionDetailScreen({super.key, required this.submissionId});

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  Submission? _submission;
  Map<String, String> _mediaUrls = {};
  String? _error;
  bool _loading = true;

  // Title edit state
  final TextEditingController _titleEditCtrl = TextEditingController();
  final FocusNode _titleEditFocus = FocusNode();
  bool _savingTitle = false;

  // Add-to-submission state
  final _addTitleCtrl = TextEditingController();
  final _addTitleFocus = FocusNode();
  final _imagePicker = ImagePicker();
  final List<XFile> _addFiles = [];

  // Phone numbers (uniform flow)
  final List<String> _addPhoneNumbers = [];
  final TextEditingController _addPhoneInputCtrl = TextEditingController();
  final FocusNode _addPhoneInputFocus = FocusNode();
  bool _showAddPhoneInput = false;

  // Locations (uniform flow)
  final List<String> _addLocationNames = [];
  final List<String> _addLocationCoords = [];

  bool _adding = false;
  String? _addError;

  bool get _hasAddContent {
    final hasPendingPhone = _addPhoneInputCtrl.text.trim().isNotEmpty;
    return _addTitleCtrl.text.trim().isNotEmpty ||
        _addFiles.isNotEmpty ||
        _addPhoneNumbers.isNotEmpty ||
        hasPendingPhone ||
        _addLocationCoords.isNotEmpty;
  }

  void _dismissAddKeyboard() {
    _addTitleFocus.unfocus();
    _addPhoneInputFocus.unfocus();
    FocusScope.of(context).unfocus();
  }

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  Future<void> _loadSubmission() async {
    try {
      final result = await app.apiService.getSubmission(widget.submissionId);
      final raw = result['data'] as Map<String, dynamic>;
      final submission = Submission.fromJson(raw);
      setState(() {
        _submission = submission;
        _loading = false;
      });
      _loadMediaUrls(submission);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _loadMediaUrls(Submission submission) async {
    final urls = <String, String>{};
    for (final media in submission.media) {
      if (media.mediaType == 'IMAGE' || media.mediaType == 'VIDEO') {
        try {
          final streamUrl = await app.apiService.getMediaStreamUrl(media.id);
          urls[media.id] = streamUrl;
        } catch (_) {}
      }
    }
    setState(() => _mediaUrls = urls);
  }

  void _openMediaViewer(MediaItemData mediaItem) {
    final url = _mediaUrls[mediaItem.id];
    if (url == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          streamUrl: url,
          mediaType: mediaItem.mediaType,
          mimeType: mediaItem.mimeType,
        ),
      ),
    );
  }

  Future<void> _saveTitle() async {
    final text = _titleEditCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _savingTitle = true);

    try {
      await app.apiService.updateSubmissionTitle(widget.submissionId, text);
      await _loadSubmission();
      if (mounted) setState(() => _savingTitle = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _savingTitle = false;
        });
      }
    }
  }

  Widget _buildTitleEditCard() {
    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF1F2937)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Title',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E7EB),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleEditCtrl,
              focusNode: _titleEditFocus,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Brief description'),
            ),
            const SizedBox(height: 12),
            ListenableBuilder(
              listenable: _titleEditCtrl,
              builder: (context, child) {
                final isEmpty =
                    _titleEditCtrl.text.trim().isEmpty || _savingTitle;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isEmpty ? null : _saveTitle,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _savingTitle
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save', style: TextStyle(fontSize: 14)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddMapPicker() async {
    _dismissAddKeyboard();
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _addLocationNames.add(
          '${result.latitude.toStringAsFixed(6)},${result.longitude.toStringAsFixed(6)}',
        );
        _addLocationCoords.add(
          '${result.latitude.toStringAsFixed(6)},${result.longitude.toStringAsFixed(6)}',
        );
      });
    }
  }

  Future<void> _pickAddPhotos(ImageSource source) async {
    _dismissAddKeyboard();
    try {
      if (source == ImageSource.camera) {
        final picked = await _imagePicker.pickImage(
          source: source,
          imageQuality: 80,
        );
        if (picked != null && mounted) setState(() => _addFiles.add(picked));
      } else {
        final picked = await _imagePicker.pickMultiImage(imageQuality: 80);
        if (mounted) setState(() => _addFiles.addAll(picked));
      }
    } catch (_) {}
  }

  Future<void> _pickAddVideos(ImageSource source) async {
    _dismissAddKeyboard();
    try {
      final picked = await _imagePicker.pickVideo(source: source);
      if (picked != null && mounted) setState(() => _addFiles.add(picked));
    } catch (_) {}
  }

  void _showAddPhotoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF9CA3AF)),
              title: const Text(
                'Take Photo',
                style: TextStyle(color: Color(0xFFE5E7EB)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAddPhotos(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF9CA3AF),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Color(0xFFE5E7EB)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAddPhotos(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showAddVideoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam, color: Color(0xFF9CA3AF)),
              title: const Text(
                'Record Video',
                style: TextStyle(color: Color(0xFFE5E7EB)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAddVideos(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.video_library,
                color: Color(0xFF9CA3AF),
              ),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Color(0xFFE5E7EB)),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickAddVideos(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _addToSubmission() async {
    if (!_hasAddContent) return;
    setState(() {
      _adding = true;
      _addError = null;
    });

    try {
      final fileMeta = <Map<String, dynamic>>[];
      for (final f in _addFiles) {
        fileMeta.add({
          'mimeType':
              f.mimeType ??
              lookupMimeType(f.path) ??
              'application/octet-stream',
          'fileSizeBytes': await f.length(),
          'fileName': f.name,
        });
      }

      final result = await app.apiService.addToSubmission(
        widget.submissionId,
        title: _addTitleCtrl.text.trim().isEmpty
            ? null
            : _addTitleCtrl.text.trim(),
        files: fileMeta,
        phoneNumbers: _addPhoneNumbers,
        locations: _addLocationCoords,
      );

      final uploadUrls = List<Map<String, dynamic>>.from(
        result['data']['uploadUrls'] ?? [],
      );

      // Upload files
      if (_addFiles.isNotEmpty) {
        final s3Keys = <String>[];
        for (int i = 0; i < _addFiles.length; i++) {
          final file = _addFiles[i];
          final urlData = uploadUrls[i];
          final mimeType =
              file.mimeType ??
              lookupMimeType(file.path) ??
              'application/octet-stream';
          final bytes = await file.readAsBytes();
          await app.apiService.uploadFile(
            urlData['uploadUrl'] as String,
            bytes,
            mimeType,
          );
          s3Keys.add(urlData['s3Key'] as String);
        }
        await app.apiService.finalizeEvidence(widget.submissionId, s3Keys);
      }

      // Clear add form
      _addTitleCtrl.clear();
      setState(() {
        _addFiles.clear();
        _addPhoneNumbers.clear();
        _addPhoneInputCtrl.clear();
        _addLocationNames.clear();
        _addLocationCoords.clear();
        _showAddPhoneInput = false;
      });

      // Reload
      await _loadSubmission();
      if (mounted) setState(() => _adding = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _addError = e.toString().replaceAll('Exception: ', '');
          _adding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Submission'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                Navigator.of(context).canPop() ? Navigator.pop(context) : null,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => app.showMenu(
                context,
                onNavigateNew: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubmitScreen()),
                ),
                onNavigateSubmissions: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HomeScreen()),
                ),
                onLock: app.logoutHandler,
              ),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _submission == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Submission'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                Navigator.of(context).canPop() ? Navigator.pop(context) : null,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => app.showMenu(
                context,
                onNavigateNew: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubmitScreen()),
                ),
                onNavigateSubmissions: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HomeScreen()),
                ),
                onLock: app.logoutHandler,
              ),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? 'Not found',
                style: const TextStyle(color: Color(0xFFFCA5A5)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final parts = _submission!.parts;
    final allMedia = _submission!.media;
    final partsWithMedia = _buildUnifiedParts(parts, allMedia);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.of(context).canPop() ? Navigator.pop(context) : null,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => app.showMenu(
              context,
              onNavigateNew: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubmitScreen()),
              ),
              onNavigateSubmissions: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HomeScreen()),
              ),
              onLock: app.logoutHandler,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_submission!.what == null ||
              _submission!.what!.trim().isEmpty) ...[
            _buildTitleEditCard(),
            const SizedBox(height: 12),
          ],
          ...partsWithMedia.map(
            (p) => PartCard(
              index: p['index'] as int,
              title: p['title'] as String?,
              date: p['date'] as String?,
              phoneNumber: p['phoneNumber'] as String?,
              location: p['location'] as String?,
              phoneNumbers: p['phoneNumbers'] as List<String>?,
              locations: p['locations'] as List<String>?,
              media: p['media'] as List<MediaItemData>,
              mediaUrls: _mediaUrls,
              isOriginal: p['isOriginal'] as bool,
              onMediaTap: _openMediaViewer,
            ),
          ),
          _buildAddToSubmission(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Add-to-submission phone section ─────────────────────

  Widget _buildAddPhoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Existing phone chips
        if (_addPhoneNumbers.isNotEmpty) ...[
          ..._addPhoneNumbers.asMap().entries.map((entry) {
            final idx = entry.key;
            final phone = entry.value;
            return Container(
              key: ValueKey(phone),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF374151).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Color(0xFF60A5FA)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFD1D5DB),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    onPressed: () =>
                        setState(() => _addPhoneNumbers.removeAt(idx)),
                  ),
                ],
              ),
            );
          }),
        ],

        // Input field (shown when user taps "+ Add Phone Number")
        if (_showAddPhoneInput) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: TextField(
                  controller: _addPhoneInputCtrl,
                  focusNode: _addPhoneInputFocus,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ElevatedButton(
                    onPressed: () {
                      final text = _addPhoneInputCtrl.text.trim();
                      if (text.isNotEmpty) {
                        setState(() {
                          _addPhoneNumbers.add(text);
                          _addPhoneInputCtrl.clear();
                          _showAddPhoneInput = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                    ),
                    child: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => setState(() {
              _addPhoneInputCtrl.clear();
              _showAddPhoneInput = false;
            }),
            child: const Text('Cancel'),
          ),
        ],

        // Always show the "+ Add Phone Number" button when not in input mode
        if (!_showAddPhoneInput) ...[
          if (_addPhoneNumbers.isNotEmpty) const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => setState(() => _showAddPhoneInput = true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Phone Number'),
          ),
        ],
      ],
    );
  }

  // ── Add-to-submission location section ──────────────────

  Widget _buildAddLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Existing location chips
        if (_addLocationCoords.isNotEmpty) ...[
          ..._addLocationCoords.asMap().entries.map((entry) {
            final idx = entry.key;
            final coords = entry.value;
            final name = _addLocationNames[idx];
            return Container(
              key: ValueKey(coords),
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF374151).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Color(0xFF22C55E),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        Text(
                          coords,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF6B7280),
                    ),
                    onPressed: () => setState(() {
                      _addLocationNames.removeAt(idx);
                      _addLocationCoords.removeAt(idx);
                    }),
                  ),
                ],
              ),
            );
          }),
        ],

        // Always show the "+ Add Location" button
        TextButton.icon(
          onPressed: _openAddMapPicker,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Location'),
        ),
      ],
    );
  }

  // ── Add-to-submission card ──────────────────────────────

  Widget _buildAddToSubmission() {
    return Card(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF1F2937)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add to this Submission',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE5E7EB),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            const Text(
              'Title',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addTitleCtrl,
              focusNode: _addTitleFocus,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Brief Description'),
            ),
            const SizedBox(height: 12),

            // Media
            const Text(
              'Attach Media',
              style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _adding ? null : _showAddPhotoSourcePicker,
                    icon: const Icon(Icons.photo_outlined, size: 18),
                    label: const Text('Photos'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF374151)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _adding ? null : _showAddVideoSourcePicker,
                    icon: const Icon(Icons.videocam_outlined, size: 18),
                    label: const Text('Videos'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF374151)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Selected files
            if (_addFiles.isNotEmpty) ...[
              Text(
                '${_addFiles.length} file(s) selected',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 4),
              ...List.generate(
                _addFiles.length,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _addFiles[i].name,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFD1D5DB),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFF6B7280),
                        ),
                        onPressed: () => setState(() => _addFiles.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Phone
            _buildAddPhoneSection(),

            // Location
            const SizedBox(height: 4),
            _buildAddLocationSection(),

            // Error
            if (_addError != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFFB91C1C).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _addError!,
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Submit
            ListenableBuilder(
              listenable: _addTitleCtrl,
              builder: (context, child) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _adding || !_hasAddContent
                        ? null
                        : _addToSubmission,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _adding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Add Submission',
                            style: TextStyle(fontSize: 14),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Unified parts builder (display) ─────────────────────

  List<Map<String, dynamic>> _buildUnifiedParts(
    List<SubmissionPart> parts,
    List<MediaItem> allMedia,
  ) {
    final result = <Map<String, dynamic>>[];
    final mediaByPart = <int, List<MediaItemData>>{};
    for (final m in allMedia) {
      mediaByPart.putIfAbsent(m.partIndex, () => []);
      mediaByPart[m.partIndex]!.add(
        MediaItemData.fromJson({
          'id': m.id,
          'mimeType': m.mimeType,
          'mediaType': m.mediaType,
        }),
      );
    }

    final origMedia = mediaByPart[0] ?? [];
    if (parts.isNotEmpty) {
      result.add({
        'index': 0,
        'title': parts[0].title,
        'date': parts[0].createdAt,
        'phoneNumber': parts[0].phoneNumber,
        'location': parts[0].manualLocation,
        'phoneNumbers': parts[0].phoneNumbers,
        'locations': parts[0].locations,
        'media': origMedia,
        'isOriginal': true,
      });
    } else if (origMedia.isNotEmpty) {
      result.add({
        'index': 0,
        'title': null,
        'date': null,
        'phoneNumber': null,
        'location': null,
        'phoneNumbers': null,
        'locations': null,
        'media': origMedia,
        'isOriginal': true,
      });
    }

    for (int i = 1; i < parts.length; i++) {
      result.add({
        'index': i,
        'title': parts[i].title,
        'date': parts[i].createdAt,
        'phoneNumber': parts[i].phoneNumber,
        'location': parts[i].manualLocation,
        'phoneNumbers': parts[i].phoneNumbers,
        'locations': parts[i].locations,
        'media': mediaByPart[i] ?? [],
        'isOriginal': false,
      });
    }

    return result;
  }

  @override
  void dispose() {
    _titleEditCtrl.dispose();
    _titleEditFocus.dispose();
    _addTitleCtrl.dispose();
    _addTitleFocus.dispose();
    _addPhoneInputCtrl.dispose();
    _addPhoneInputFocus.dispose();
    super.dispose();
  }
}
