import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mime/mime.dart';

import '../services/storage_service.dart';
import '../services/geolocation_service.dart';
import '../main.dart' as app;
import '../widgets/map_picker.dart';
import 'uploading_screen.dart';
import 'home_screen.dart';

class SubmitScreen extends StatefulWidget {
  const SubmitScreen({super.key});

  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  final _titleCtrl = TextEditingController();
  final _titleFocus = FocusNode();
  final _imagePicker = ImagePicker();
  final List<XFile> _files = [];

  final List<String> _phoneNumbers = [];
  final TextEditingController _phoneInputCtrl = TextEditingController();
  final FocusNode _phoneInputFocus = FocusNode();
  bool _showPhoneInput = false;

  final List<String> _locationNames = [];
  final List<String> _locationCoords = [];

  bool _submitting = false;
  String? _error;

  bool get _hasContent {
    final hasPendingPhone = _phoneInputCtrl.text.trim().isNotEmpty;
    return _titleCtrl.text.trim().isNotEmpty ||
        _files.isNotEmpty ||
        _phoneNumbers.isNotEmpty ||
        hasPendingPhone ||
        _locationCoords.isNotEmpty;
  }

  void _dismissKeyboard() {
    _titleFocus.unfocus();
    _phoneInputFocus.unfocus();
    FocusScope.of(context).unfocus();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _titleFocus.dispose();
    _phoneInputCtrl.dispose();
    _phoneInputFocus.dispose();
    super.dispose();
  }

  void _pickPhotos(ImageSource source) async {
    _dismissKeyboard();
    try {
      if (source == ImageSource.camera) {
        final picked = await _imagePicker.pickImage(
          source: source,
          imageQuality: 80,
        );
        if (picked != null && mounted) setState(() => _files.add(picked));
      } else {
        final picked = await _imagePicker.pickMultiImage(imageQuality: 80);
        if (mounted) setState(() => _files.addAll(picked));
      }
    } catch (_) {}
  }

  void _pickVideos(ImageSource source) async {
    _dismissKeyboard();
    try {
      final picked = await _imagePicker.pickVideo(source: source);
      if (picked != null && mounted) setState(() => _files.add(picked));
    } catch (_) {}
  }

  void _showPhotoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
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
                _pickPhotos(ImageSource.camera);
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
                _pickPhotos(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showVideoSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111827),
      shape: const RoundedRectangleBorder(
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
                _pickVideos(ImageSource.camera);
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
                _pickVideos(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _openMapPicker() async {
    _dismissKeyboard();
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null) {
      setState(() {
        _locationNames.add(
          '${result.latitude.toStringAsFixed(6)},${result.longitude.toStringAsFixed(6)}',
        );
        _locationCoords.add(
          '${result.latitude.toStringAsFixed(6)},${result.longitude.toStringAsFixed(6)}',
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_hasContent) return;
    _dismissKeyboard();

    if (_phoneInputCtrl.text.trim().isNotEmpty) {
      _phoneNumbers.add(_phoneInputCtrl.text.trim());
      _phoneInputCtrl.clear();
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final browserId = await StorageService.getBrowserId();
      final gpsLocation = await GeolocationService.getPosition();
      final deviceInfo = await GeolocationService.getDeviceInfo();
      final timezone = GeolocationService.getTimezone();

      final fileMeta = <Map<String, dynamic>>[];
      for (final f in _files) {
        final bytes = await f.readAsBytes();
        fileMeta.add({
          'mimeType':
              f.mimeType ??
              lookupMimeType(f.path) ??
              'application/octet-stream',
          'fileSizeBytes': bytes.length,
          'fileName': f.name,
        });
      }

      final result = await app.apiService.submitEvidence(
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        files: fileMeta,
        location:
            gpsLocation ??
            (_locationCoords.isNotEmpty ? _locationCoords.first : null),
        deviceInfo: deviceInfo,
        timezone: timezone,
        browserId: browserId,
        phoneNumbers: _phoneNumbers,
        locations: _locationCoords,
      );

      final uploadUrls = List<Map<String, dynamic>>.from(
        result['data']['uploadUrls'] ?? [],
      );
      final submissionId = result['data']['submissionId'] as String;

      if (!mounted) return;
      setState(() => _submitting = false);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UploadingScreen(
            submissionId: submissionId,
            uploadUrls: uploadUrls,
            files: _files,
            hasFiles: _files.isNotEmpty,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _submitting = false;
        });
      }
    }
  }

  Widget _buildFileCard(int idx, XFile file) {
    final isImage =
        file.mimeType?.startsWith('image/') == true ||
        lookupMimeType(file.path)?.startsWith('image/') == true;
    return Card(
      key: ValueKey(file.path),
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF1F2937)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Icon(
          isImage ? Icons.image : Icons.videocam,
          color: isImage ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
        title: Text(
          file.name,
          style: const TextStyle(fontSize: 13, color: Color(0xFFE5E7EB)),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: FutureBuilder<int>(
          future: file.length(),
          builder: (_, snap) => Text(
            formatFileSize(snap.data ?? 0),
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18, color: Color(0xFF6B7280)),
          onPressed: () => setState(() => _files.removeAt(idx)),
        ),
      ),
    );
  }

  Widget _buildPhoneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_phoneNumbers.isNotEmpty) ...[
          ..._phoneNumbers.asMap().entries.map((entry) {
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
                        setState(() => _phoneNumbers.removeAt(idx)),
                  ),
                ],
              ),
            );
          }),
        ],
        if (_showPhoneInput) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: TextField(
                  controller: _phoneInputCtrl,
                  focusNode: _phoneInputFocus,
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
                      final text = _phoneInputCtrl.text.trim();
                      if (text.isNotEmpty) {
                        setState(() {
                          _phoneNumbers.add(text);
                          _phoneInputCtrl.clear();
                          _showPhoneInput = false;
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
              _phoneInputCtrl.clear();
              _showPhoneInput = false;
            }),
            child: const Text('Cancel'),
          ),
        ],
        if (!_showPhoneInput) ...[
          if (_phoneNumbers.isNotEmpty) const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => setState(() => _showPhoneInput = true),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Phone Number'),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_locationCoords.isNotEmpty) ...[
          ..._locationCoords.asMap().entries.map((entry) {
            final idx = entry.key;
            final coords = entry.value;
            final name = _locationNames[idx];
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
                      _locationNames.removeAt(idx);
                      _locationCoords.removeAt(idx);
                    }),
                  ),
                ],
              ),
            );
          }),
        ],
        TextButton.icon(
          onPressed: _openMapPicker,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Location'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Submission'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => app.showMenu(
              context,
              onNavigateSubmissions: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              ),
              onLock: app.logoutHandler,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Title',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            focusNode: _titleFocus,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Brief Description'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Attach Media',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showPhotoSourcePicker,
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Photos'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF374151)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showVideoSourcePicker,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Videos'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF374151)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_files.isNotEmpty) ...[
            Text(
              'Selected files (${_files.length})',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 4),
            ...List.generate(
              _files.length,
              (i) => _buildFileCard(i, _files[i]),
            ),
            const SizedBox(height: 16),
          ],
          _buildPhoneSection(),
          const SizedBox(height: 4),
          _buildLocationSection(),
          const SizedBox(height: 8),
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7F1D1D).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFB91C1C).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ListenableBuilder(
            listenable: _titleCtrl,
            builder: (context, child) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting || !_hasContent ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

String formatFileSize(int bytes) {
  if (bytes <= 0) return "0 B";
  if (bytes < 1024) return "$bytes B";
  if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
  return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
}
