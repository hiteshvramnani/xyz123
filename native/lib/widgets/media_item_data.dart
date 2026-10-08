/// Shared media item data used by media_card and part_card
class MediaItemData {
  final String id;
  final String? mimeType;
  final String mediaType;

  const MediaItemData({
    required this.id,
    this.mimeType,
    required this.mediaType,
  });

  factory MediaItemData.fromJson(Map<String, dynamic> json) {
    return MediaItemData(
      id: json['id'] as String,
      mimeType: json['mimeType'] as String?,
      mediaType: json['mediaType'] as String? ?? 'DOCUMENT',
    );
  }
}
