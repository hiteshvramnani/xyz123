import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final http.Client _client;
  final String baseUrl;

  ApiService({http.Client? client, required this.baseUrl})
      : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.Request(method, uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['ngrok-skip-browser-warning'] = 'true';

    if (body != null && (method == 'POST' || method == 'PUT' || method == 'PATCH')) {
      request.body = jsonEncode(body);
    }

    final response = await _client.send(request);
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode >= 500) {
      try {
        return await _request(path, method: method, body: body);
      } catch (_) {
        rethrow;
      }
    }

    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    if ((data['success'] as bool?) != true) {
      throw Exception(
          data['error']['message'] as String? ?? 'Request failed');
    }
    return data;
  }

  Future<void> _uploadToS3(String uploadUrl, List<int> bytes, String mimeType) async {
    final request = http.Request('PUT', Uri.parse(uploadUrl))
      ..headers['Content-Type'] = mimeType
      ..headers['ngrok-skip-browser-warning'] = 'true'
      ..bodyBytes = bytes;

    final response = await _client.send(request);
    if (response.statusCode >= 400) {
      throw Exception('Upload failed with status ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> submitEvidence({
    String? title,
    required List<Map<String, dynamic>> files,
    String? location,
    String? deviceInfo,
    String? timezone,
    required String browserId,
    String? phoneNumber,
    String? manualLocation,
    List<String>? phoneNumbers,
    List<String>? locations,
  }) {
    return _request(
      '/api/v1/evidence',
      method: 'POST',
      body: {
        'title': title,
        'files': files,
        'location': location,
        'deviceInfo': deviceInfo,
        'timezone': timezone,
        'browserId': browserId,
        'phoneNumber': phoneNumber,
        'manualLocation': manualLocation,
        'phoneNumbers': phoneNumbers,
        'locations': locations,
      },
    );
  }

  Future<Map<String, dynamic>> finalizeEvidence(
    String submissionId,
    List<String> s3Keys,
  ) {
    return _request(
      '/api/v1/evidence/$submissionId/finalize',
      method: 'POST',
      body: {'s3Keys': s3Keys},
    );
  }

  Future<Map<String, dynamic>> addToSubmission(
    String submissionId, {
    String? title,
    required List<Map<String, dynamic>> files,
    String? phoneNumber,
    String? manualLocation,
    List<String>? phoneNumbers,
    List<String>? locations,
  }) {
    return _request(
      '/api/v1/evidence/$submissionId/add',
      method: 'POST',
      body: {
        'title': title,
        'files': files,
        'phoneNumber': phoneNumber,
        'manualLocation': manualLocation,
        'phoneNumbers': phoneNumbers,
        'locations': locations,
      },
    );
  }

  Future<Map<String, dynamic>> updateSubmissionTitle(
    String submissionId,
    String title,
  ) {
    return _request(
      '/api/v1/evidence/$submissionId/title',
      method: 'PATCH',
      body: {'title': title},
    );
  }

  Future<Map<String, dynamic>> listMySubmissions(
    String browserId, {
    String? q,
    bool? hasImage,
    bool? hasVideo,
    bool? hasPhoneNumber,
    bool? hasLocation,
    bool? hasTitle,
    int page = 1,
    int limit = 20,
  }) {
    final params = <String, dynamic>{'browserId': browserId, 'page': page, 'limit': limit};
    if (q != null) params['q'] = q;
    if (hasImage != null) params['hasImage'] = hasImage.toString();
    if (hasVideo != null) params['hasVideo'] = hasVideo.toString();
    if (hasPhoneNumber != null) params['hasPhoneNumber'] = hasPhoneNumber.toString();
    if (hasLocation != null) params['hasLocation'] = hasLocation.toString();
    if (hasTitle != null) params['hasTitle'] = hasTitle.toString();
    final queryString = params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}').join('&');
    return _request('/api/v1/evidence/my-submissions?$queryString');
  }

  // Pagination-aware version that wraps the data
  Future<Map<String, dynamic>> listMySubmissionsWithPagination(
    String browserId, {
    String? q,
    bool? hasImage,
    bool? hasVideo,
    bool? hasPhoneNumber,
    bool? hasLocation,
    bool? hasTitle,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'browserId': browserId, 'page': page, 'limit': limit};
    if (q != null) params['q'] = q;
    if (hasImage != null) params['hasImage'] = hasImage.toString();
    if (hasVideo != null) params['hasVideo'] = hasVideo.toString();
    if (hasPhoneNumber != null) params['hasPhoneNumber'] = hasPhoneNumber.toString();
    if (hasLocation != null) params['hasLocation'] = hasLocation.toString();
    if (hasTitle != null) params['hasTitle'] = hasTitle.toString();
    final queryString = params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}').join('&');
    final result = await _request('/api/v1/evidence/my-submissions?$queryString');

    final data = result['data'];
    List<dynamic> submissions = [];
    int totalItems = 0;

    if (data is List) {
      submissions = data;
    } else if (data is Map && data['submissions'] is List) {
      submissions = data['submissions'] as List<dynamic>;
      totalItems = (data['totalItems'] as num?)?.toInt() ?? 0;
    }

    final pag = result['pagination'];
    if (pag is Map) {
      totalItems = (pag['totalItems'] as num?)?.toInt() ??
          (pag['total'] as num?)?.toInt() ??
          totalItems;
    }
    if (totalItems == 0) totalItems = submissions.length;

    final pageSize = limit > 0 ? limit : 20;
    
    // Fallback: if the server ignored `limit` and sent everything,
    // paginate on the client instead.
    if (submissions.length > pageSize) {
      totalItems = submissions.length;
      final safePage = page < 1 ? 1 : page;
      final start = (safePage - 1) * pageSize;
      submissions = submissions.skip(start).take(pageSize).toList();
    }

    return {
      'data': {
        'submissions': submissions,
        'totalItems': totalItems,
      },
      'pagination': {
        'currentPage': page,
        'totalItems': totalItems,
        'totalPages': (totalItems / pageSize).ceil(),
        'pageSize': pageSize,
      },
    };
  }

  Future<Map<String, dynamic>> getSubmission(String id) {
    return _request('/api/v1/submissions/$id');
  }

  Future<Map<String, dynamic>> getMediaDownloadUrl(String mediaId) {
    return _request('/api/v1/media/$mediaId/download-url');
  }

  Future<String> getMediaStreamUrl(String mediaId) {
    return Future.value('$baseUrl/api/v1/media/$mediaId/stream');
  }

  Future<void> uploadFile(String uploadUrl, List<int> bytes, String mimeType) {
    return _uploadToS3(uploadUrl, bytes, mimeType);
  }

  void dispose() => _client.close();
}
