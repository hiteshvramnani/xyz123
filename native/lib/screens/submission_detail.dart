import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mime/mime.dart';

import '../models/submission.dart';
import '../theme/theme.dart';
import '../widgets/map_picker.dart';
import '../widgets/part_card.dart';
import '../widgets/media_item_data.dart';
import '../widgets/ui/ui.dart';
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

  Future<void> _openAddMapPicker() async {
    _dismissAddKeyboard();
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => const MapPickerScreen()),
    );
    if (result != null) {
      final coord =
          '${result.latitude.toStringAsFixed(6)},${result.longitude.toStringAsFixed(6)}';
      setState(() {
        _addLocationNames.add(coord);
        _addLocationCoords.add(coord);
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
    showAppOptionsSheet(
      context,
      title: 'Add photo',
      options: [
        AppSheetOption(
          icon: Icons.camera_alt_outlined,
          label: 'Take Photo',
          onTap: () => _pickAddPhotos(ImageSource.camera),
        ),
        AppSheetOption(
          icon: Icons.photo_library_outlined,
          label: 'Choose from Gallery',
          onTap: () => _pickAddPhotos(ImageSource.gallery),
        ),
      ],
    );
  }

  void _showAddVideoSourcePicker() {
    showAppOptionsSheet(
      context,
      title: 'Add video',
      options: [
        AppSheetOption(
          icon: Icons.videocam_outlined,
          label: 'Record Video',
          onTap: () => _pickAddVideos(ImageSource.camera),
        ),
        AppSheetOption(
          icon: Icons.video_library_outlined,
          label: 'Choose from Gallery',
          onTap: () => _pickAddVideos(ImageSource.gallery),
        ),
      ],
    );
  }

  Future<void> _addToSubmission() async {
    if (!_hasAddContent) return;

    if (_addPhoneInputCtrl.text.trim().isNotEmpty) {
      _addPhoneNumbers.add(_addPhoneInputCtrl.text.trim());
      _addPhoneInputCtrl.clear();
    }

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

      _addTitleCtrl.clear();
      setState(() {
        _addFiles.clear();
        _addPhoneNumbers.clear();
        _addPhoneInputCtrl.clear();
        _addLocationNames.clear();
        _addLocationCoords.clear();
        _showAddPhoneInput = false;
      });

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

  void _openMenu() => app.showMenu(
        context,
        onNavigateNew: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubmitScreen()),
        ),
        onNavigateSubmissions: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        ),
        onLock: app.logoutHandler,
      );

  AppBar _appBar() => AppBar(
        title: const Text('Submission'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () =>
              Navigator.of(context).canPop() ? Navigator.pop(context) : null,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: _openMenu,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: _appBar(), body: const LoadingView());
    }

    if (_error != null || _submission == null) {
      return Scaffold(
        appBar: _appBar(),
        body: Center(
          child: Padding(
            padding: AppSpacing.screen,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBanner(message: _error ?? 'Not found'),
                AppSpacing.gapLg,
                SecondaryButton(
                  label: 'Go Back',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final parts = _submission!.parts;
    final allMedia = _submission!.media;
    final partsWithMedia = _buildUnifiedParts(parts, allMedia);
    final needsTitle =
        _submission!.what == null || _submission!.what!.trim().isEmpty;

    return Scaffold(
      appBar: _appBar(),
      body: ListView(
        padding: AppSpacing.screen,
        children: [
          if (needsTitle) ...[
            _buildTitleEditCard(),
            AppSpacing.gapMd,
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
          AppSpacing.gapLg,
        ],
      ),
    );
  }

  Widget _buildTitleEditCard() {
    return AppCard(
      title: 'Add title',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            hintText: 'Brief description',
            controller: _titleEditCtrl,
            focusNode: _titleEditFocus,
            maxLines: 3,
          ),
          AppSpacing.gapMd,
          ListenableBuilder(
            listenable: _titleEditCtrl,
            builder: (context, child) {
              final canSave =
                  _titleEditCtrl.text.trim().isNotEmpty && !_savingTitle;
              return PrimaryButton(
                label: 'Save',
                loading: _savingTitle,
                onPressed: canSave ? _saveTitle : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddToSubmission() {
    final c = context.colors;
    return AppCard(
      title: 'Add to this submission',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'Title',
            hintText: 'Brief description',
            controller: _addTitleCtrl,
            focusNode: _addTitleFocus,
            maxLines: 3,
          ),
          AppSpacing.gapLg,
          const SectionLabel('Attach Media'),
          AppSpacing.gapSm,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _adding ? null : _showAddPhotoSourcePicker,
                  icon: const Icon(Icons.photo_outlined, size: AppIconSize.md),
                  label: const Text('Photos'),
                ),
              ),
              AppSpacing.gapHMd,
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _adding ? null : _showAddVideoSourcePicker,
                  icon:
                      const Icon(Icons.videocam_outlined, size: AppIconSize.md),
                  label: const Text('Videos'),
                ),
              ),
            ],
          ),
          if (_addFiles.isNotEmpty) ...[
            AppSpacing.gapSm,
            ...List.generate(_addFiles.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined,
                        size: AppIconSize.sm, color: c.textTertiary),
                    AppSpacing.gapHSm,
                    Expanded(
                      child: Text(
                        _addFiles[i].name,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Remove file',
                      icon: Icon(Icons.close,
                          size: AppIconSize.sm, color: c.textTertiary),
                      onPressed: () => setState(() => _addFiles.removeAt(i)),
                    ),
                  ],
                ),
              );
            }),
          ],
          AppSpacing.gapLg,
          const SectionLabel('Phone Numbers'),
          AppSpacing.gapSm,
          _buildAddPhoneSection(),
          AppSpacing.gapMd,
          const SectionLabel('Locations'),
          AppSpacing.gapSm,
          _buildAddLocationSection(),
          if (_addError != null) ...[
            AppSpacing.gapMd,
            StatusBanner(message: _addError!),
          ],
          AppSpacing.gapLg,
          ListenableBuilder(
            listenable: _addTitleCtrl,
            builder: (context, child) {
              return PrimaryButton(
                label: 'Add Submission',
                loading: _adding,
                onPressed: _hasAddContent ? _addToSubmission : null,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAddPhoneSection() {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._addPhoneNumbers.asMap().entries.map(
              (entry) => RemovableEntryTile(
                key: ValueKey(entry.value),
                icon: Icons.phone_outlined,
                iconColor: c.accent,
                title: entry.value,
                removeTooltip: 'Remove phone number',
                onRemove: () =>
                    setState(() => _addPhoneNumbers.removeAt(entry.key)),
              ),
            ),
        if (_showAddPhoneInput) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addPhoneInputCtrl,
                  focusNode: _addPhoneInputFocus,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'Phone number'),
                  onSubmitted: (_) => _commitAddPhone(),
                ),
              ),
              AppSpacing.gapHSm,
              ElevatedButton(
                onPressed: _commitAddPhone,
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
                _addPhoneInputCtrl.clear();
                _showAddPhoneInput = false;
              }),
              child: const Text('Cancel'),
            ),
          ),
        ] else
          AddEntryButton(
            label: 'Add Phone Number',
            onPressed: () => setState(() => _showAddPhoneInput = true),
          ),
      ],
    );
  }

  void _commitAddPhone() {
    final text = _addPhoneInputCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _addPhoneNumbers.add(text);
        _addPhoneInputCtrl.clear();
        _showAddPhoneInput = false;
      });
    }
  }

  Widget _buildAddLocationSection() {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ..._addLocationCoords.asMap().entries.map(
              (entry) => RemovableEntryTile(
                key: ValueKey(entry.value),
                icon: Icons.location_on_outlined,
                iconColor: c.accent,
                title: _addLocationNames[entry.key],
                removeTooltip: 'Remove location',
                onRemove: () => setState(() {
                  _addLocationNames.removeAt(entry.key);
                  _addLocationCoords.removeAt(entry.key);
                }),
              ),
            ),
        AddEntryButton(
          label: 'Add Location',
          onPressed: _openAddMapPicker,
        ),
      ],
    );
  }

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
}
