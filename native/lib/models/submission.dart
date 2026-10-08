import 'dart:convert';

class SubmissionPart {
  final String? title;
  final String createdAt;
  final String? phoneNumber;
  final String? manualLocation;
  final List<String>? phoneNumbers;
  final List<String>? locations;

  SubmissionPart({
    this.title,
    required this.createdAt,
    this.phoneNumber,
    this.manualLocation,
    this.phoneNumbers,
    this.locations,
  });

  factory SubmissionPart.fromJson(Map<String, dynamic> json) {
    return SubmissionPart(
      title: json['title'] as String?,
      createdAt: (json['createdAt'] as String?) ?? '',
      phoneNumber: json['phoneNumber'] as String?,
      manualLocation: json['manualLocation'] as String?,
      phoneNumbers: (json['phoneNumbers'] as List<dynamic>?)?.cast<String>(),
      locations: (json['locations'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

class Submission {
  final String id;
  final String? what;
  final String? where;
  final String? when;
  final String createdAt;
  final String updatedAt;
  final List<SubmissionPart> parts;
  final List<MediaItem> media;
  final int mediaCount;
  final int threadCount;
  final dynamic metadata;

  Submission({
    required this.id,
    required this.what,
    required this.where,
    required this.when,
    required this.createdAt,
    required this.updatedAt,
    required this.parts,
    required this.media,
    required this.mediaCount,
    required this.threadCount,
    required this.metadata,
  });

  factory Submission.fromJson(Map<String, dynamic> json) {
    final metadata = _parseMetadata(json['metadata']);
    final rawMedia = (json['media'] as List<dynamic>?) ?? [];

    return Submission(
      id: json['id'] as String,
      what: json['what'] as String?,
      where: json['whereField'] as String? ?? json['where'] as String?,
      when: json['whenField'] as String? ?? json['when'] as String?,
      createdAt: json['createdAt'] as String,
      updatedAt: json['updatedAt'] as String,
      parts: _extractParts(metadata),
      media: rawMedia.map((m) => MediaItem.fromJson(m as Map<String, dynamic>)).toList(),
      mediaCount: (json['mediaCount'] as int?) ?? rawMedia.length,
      threadCount: json['threadCount'] as int? ?? 0,
      metadata: json['metadata'] ?? {},
    );
  }

  static Map<String, dynamic> _parseMetadata(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String) {
      try {
        return Map<String, dynamic>.from(
            Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        return {};
      }
    }
    return {};
  }

  static List<SubmissionPart> _extractParts(Map<String, dynamic> metadata) {
    final raw = metadata['parts'] as List<dynamic>?;
    if (raw == null || raw.isEmpty) return [];
    return raw.map((p) => SubmissionPart.fromJson(p as Map<String, dynamic>)).toList();
  }
}

class MediaItem {
  final String id;
  final String? s3Key;
  final String? mimeType;
  final int fileSizeBytes;
  final String? caption;
  final int partIndex;
  final String mediaType;

  MediaItem({
    required this.id,
    this.s3Key,
    this.mimeType,
    required this.fileSizeBytes,
    this.caption,
    required this.partIndex,
    required this.mediaType,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      s3Key: json['s3Key'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSizeBytes: _toInt(json['fileSizeBytes']),
      caption: json['caption'] as String?,
      partIndex: json['partIndex'] as int? ?? 0,
      mediaType: json['mediaType'] as String? ?? 'DOCUMENT',
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
