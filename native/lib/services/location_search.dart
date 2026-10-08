import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationSearchResult {
  final String displayName;
  final double lat;
  final double lon;

  LocationSearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory LocationSearchResult.fromJson(Map<String, dynamic> json) {
    return LocationSearchResult(
      displayName: json['display_name'] as String,
      lat: double.tryParse(json['lat'].toString()) ?? 0,
      lon: double.tryParse(json['lon'].toString()) ?? 0,
    );
  }
}

/// Searches locations via OpenStreetMap Nominatim API
Future<List<LocationSearchResult>> searchLocations(String query) async {
  if (query.trim().isEmpty) return [];

  final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/search')
      .replace(queryParameters: {
    'q': query,
    'format': 'json',
    'limit': '5',
  });

  final response = await http.get(uri, headers: {
    'User-Agent': 'DataApp/1.0',
  });

  if (response.statusCode != 200) return [];

  final List<dynamic> results = jsonDecode(response.body) as List<dynamic>;
  return results
      .map((r) => LocationSearchResult.fromJson(r as Map<String, dynamic>))
      .toList();
}
