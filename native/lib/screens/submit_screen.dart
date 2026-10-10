import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mime/mime.dart';

import '../services/storage_service.dart';
import '../services/geolocation_service.dart';
import '../main.dart' as app;
import '../theme/theme.dart';
import '../widgets/date_formatter.dart';
import '../widgets/ui/ui.dart';
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
    showAppOptionsSheet(
      context,
      title: 'Add photo',
      options: [
        AppSheetOption(
          icon: Icons.camera_alt_outlined,
          label: 'Take Photo',
          onTap: () => _pickPhotos(ImageSource.camera),
        ),
        AppSheetOption(
          icon: Icons.photo_library_outlined,
          label: 'Choose from Gallery',
          onTap: () => _pickPhotos(ImageSource.gallery),
        ),
      ],
    );
  }

  void _showVideoSourcePicker() {
    showAppOptionsSheet(
      context,
      title: 'Add video',
      options: [
        AppSheetOption(
          icon: Icons.videocam_outlined,
          label: 'Record Video',
          onTap: () => _pickVideos(ImageSource.camera),
        ),
        AppSheetOption(
          icon: Icons.video_library_outlined,
          label: 'Choose from Gallery',
          onTap: () => _pickVideos(ImageSource.gallery),
        ),
      ],
    );
  }

  Future<void> _openMapPicker() async {
    _dismissKeyboard();
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null) {
      final coord =
          '${result.latitude.toStringAsFixed(6)},${result.longitude.toStringAsFixed(6)}';
      setState(() {
        _locationNames.add(coord);
        _locationCoords.add(coord);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Submission'),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
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
        padding: AppSpacing.screen,
        children: [
          AppTextField(
            label: 'Title',
            hintText: 'Brief description',
            controller: _titleCtrl,
            focusNode: _titleFocus,
            maxLines: 3,
          ),
          AppSpacing.gapXl,
          const SectionLabel('Attach Media'),
          AppSpacing.gapSm,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showPhotoSourcePicker,
                  icon: const Icon(Icons.photo_outlined, size: AppIconSize.md),
                  label: const Text('Photos'),
                ),
              ),
              AppSpacing.gapHMd,
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showVideoSourcePicker,
                  icon: const Icon(Icons.videocam_outlined, size: AppIconSize.md),
                  label: const Text('Videos'),
                ),
              ),
            ],
          ),
          if (_files.isNotEmpty) ...[
            AppSpacing.gapMd,
            Text(
              'Selected files (${_files.length})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            AppSpacing.gapSm,
            ...List.generate(
              _files.length,
              (i) => _buildFileCard(i, _files[i]),
            ),
          ],
          AppSpacing.gapXl,
          const SectionLabel('Phone Numbers'),
          AppSpacing.gapSm,
          _buildPhoneSection(),
          AppSpacing.gapLg,
          const SectionLabel('Locations'),
          AppSpacing.gapSm,
          _buildLocationSection(),
          if (_error != null) ...[
            AppSpacing.gapLg,
            StatusBanner(message: _error!),
          ],
          AppSpacing.gapXl,
          ListenableBuilder(
            listenable: _titleCtrl,
            builder: (context, child) {
              return PrimaryButton(
                label: 'Submit',
                loading: _submitting,
                onPressed: _hasContent ? _submit : null,
              );
            },
          ),
          AppSpacing.gapLg,
        ],
      ),
    );
  }

  Widget _buildFileCard(int idx, XFile file) {
    final c = context.colors;
    final isImage =
        file.mimeType?.startsWith('image/') == true ||
        lookupMimeType(file.path)?.startsWith('image/') == true;
    return Padding(
      key: ValueKey(file.path),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.xs,
          ),
          leading: Icon(
            isImage ? Icons.image_outlined : Icons.videocam_outlined,
            color: isImage ? c.accent : c.textSecondary,
          ),
          title: Text(
            file.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textPrimary,
                ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: FutureBuilder<int>(
            future: file.length(),
            builder: (_, snap) => Text(
              formatFileSize(snap.data ?? 0),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          trailing: IconButton(
            tooltip: 'Remove file',
            icon: Icon(Icons.close, size: AppIconSize.md, color: c.textTertiary),
            onPressed: () => setState(() => _files.removeAt(idx)),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneSection() {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._phoneNumbers.asMap().entries.map(
              (entry) => RemovableEntryTile(
                key: ValueKey(entry.value),
                icon: Icons.phone_outlined,
                iconColor: c.accent,
                title: entry.value,
                removeTooltip: 'Remove phone number',
                onRemove: () => setState(() => _phoneNumbers.removeAt(entry.key)),
              ),
            ),
        if (_showPhoneInput) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneInputCtrl,
                  focusNode: _phoneInputFocus,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'Phone number'),
                  onSubmitted: (_) => _commitPhone(),
                ),
              ),
              AppSpacing.gapHSm,
              ElevatedButton(
                onPressed: _commitPhone,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.buttonHeight),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                _phoneInputCtrl.clear();
                _showPhoneInput = false;
              }),
              child: const Text('Cancel'),
            ),
          ),
        ] else
          AddEntryButton(
            label: 'Add Phone Number',
            onPressed: () => setState(() => _showPhoneInput = true),
          ),
      ],
    );
  }

  void _commitPhone() {
    final text = _phoneInputCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _phoneNumbers.add(text);
        _phoneInputCtrl.clear();
        _showPhoneInput = false;
      });
    }
  }

  Widget _buildLocationSection() {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._locationCoords.asMap().entries.map(
              (entry) => RemovableEntryTile(
                key: ValueKey(entry.value),
                icon: Icons.location_on_outlined,
                iconColor: c.accent,
                title: _locationNames[entry.key],
                removeTooltip: 'Remove location',
                onRemove: () => setState(() {
                  _locationNames.removeAt(entry.key);
                  _locationCoords.removeAt(entry.key);
                }),
              ),
            ),
        AddEntryButton(
          label: 'Add Location',
          onPressed: _openMapPicker,
        ),
      ],
    );
  }
}
