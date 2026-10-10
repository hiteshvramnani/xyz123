import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../main.dart' as app;
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';
import 'home_screen.dart';
import 'submit_screen.dart';

class UploadingScreen extends StatefulWidget {
  final String submissionId;
  final List<Map<String, dynamic>> uploadUrls;
  final List<XFile> files;
  final bool hasFiles;

  const UploadingScreen({
    super.key,
    required this.submissionId,
    required this.uploadUrls,
    required this.files,
    required this.hasFiles,
  });

  @override
  State<UploadingScreen> createState() => _UploadingScreenState();
}

class _UploadingScreenState extends State<UploadingScreen> {
  String _progress = 'Creating submission...';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _upload());
  }

  Future<void> _upload() async {
    try {
      if (!widget.hasFiles) {
        _showSuccess();
        return;
      }

      final s3Keys = <String>[];
      for (int i = 0; i < widget.files.length; i++) {
        if (!mounted) return;
        setState(
          () => _progress = 'Uploading file ${i + 1}/${widget.files.length}...',
        );

        final file = widget.files[i];
        final urlData = widget.uploadUrls[i];
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

      if (!mounted) return;
      setState(() => _progress = 'Finalizing...');
      await app.apiService.finalizeEvidence(widget.submissionId, s3Keys);

      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showSuccess() {
    if (!mounted) return;
    final c = context.colors;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Submission uploaded'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSpacing.gapSm,
            Icon(Icons.check_circle_outline,
                size: AppIconSize.xl, color: c.primary),
            AppSpacing.gapMd,
            Text(
              'Your submission has been received.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          PrimaryButton(
            label: 'New Submission',
            icon: Icons.add,
            onPressed: () {
              Navigator.of(ctx).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SubmitScreen()),
                (route) => false,
              );
            },
          ),
          AppSpacing.gapSm,
          SecondaryButton(
            label: 'View My Submissions',
            onPressed: () {
              Navigator.of(ctx).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submitting')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: _error != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBanner(message: _error!),
                    AppSpacing.gapLg,
                    SecondaryButton(
                      label: 'Go Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    AppSpacing.gapXl,
                    Text(
                      _progress,
                      textAlign: TextAlign.center,
                      style: context.mono(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
