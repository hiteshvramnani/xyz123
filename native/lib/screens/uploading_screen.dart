import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../main.dart' as app;
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Submission Uploaded',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.check_circle, size: 64, color: Color(0xFF22C55E)),
            const SizedBox(height: 12),
            const Text(
              'Your submission has been received successfully. Thank you for contributing.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const SubmitScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'New Submission',
                  style: TextStyle(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Color(0xFF374151)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'View My Submissions',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submitting')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
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
                    style: const TextStyle(
                      color: Color(0xFFFCA5A5),
                      fontSize: 13,
                    ),
                  ),
                )
              else ...[
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
                const SizedBox(height: 24),
                Text(
                  _progress,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
