import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_search.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _initialCenter = const LatLng(20, 0);
  final _mapController = MapController();
  LatLng? _selectedLocation;
  bool _gettingLocation = false;

  // Search
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  List<LocationSearchResult> _suggestions = [];
  bool _searchLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void _searchLocation(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions.clear());
      return;
    }
    setState(() => _searchLoading = true);
    _debounce = Timer(const Duration(milliseconds: 500), () {
      searchLocations(query).then((results) {
        if (mounted) {
          setState(() {
            _suggestions = results;
            _searchLoading = false;
          });
        }
      });
    });
  }

  Future<void> _selectSuggestion(LocationSearchResult result) async {
    final point = LatLng(result.lat, result.lon);
    setState(() {
      _selectedLocation = point;
      _suggestions.clear();
    });
    _searchFocus.unfocus();
    // Wait for keyboard animation to settle before moving the map
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await _mapController.move(point, 14);
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _gettingLocation = true);
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _gettingLocation = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _gettingLocation = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _gettingLocation = false;
      });
      await _mapController.move(_selectedLocation!, 16);
    } catch (_) {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.of(context).padding.top;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardHeight > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Full screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13,
              onTap: (tappingPoint, position) {
                _searchFocus.unfocus();
                setState(() {
                  _selectedLocation = position;
                  _suggestions.clear();
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: NetworkTileProvider(
                  headers: {
                    'User-Agent': 'DataCollectionApp/1.0',
                  },
                ),
              ),
              MarkerLayer(
                markers: _selectedLocation != null
                    ? [
                        Marker(
                          point: _selectedLocation!,
                          width: 44,
                          height: 44,
                          child: Icon(
                            Icons.location_on,
                            color: const Color(0xFFDC2626),
                            size: 44,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ]
                    : [],
              ),
            ],
          ),

          // Top controls - close button only
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search bar + suggestions
          Positioned(
            top: statusBar + 68,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    focusNode: _searchFocus,
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search for a place',
                      hintStyle:
                          const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: Color(0xFF9CA3AF)),
                      suffixIcon: _searchLoading
                          ? SizedBox(
                              width: 32,
                              height: 32,
                              child: Align(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: const AlwaysStoppedAnimation<
                                        Color>(Color(0xFF2563EB)),
                                  ),
                                ),
                              ),
                            )
                          : _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear,
                                      size: 18, color: Color(0xFF9CA3AF)),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _suggestions.clear());
                                    _searchFocus.requestFocus();
                                  },
                                )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: false,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    ),
                    onChanged: (val) {
                      if (val.trim().isEmpty) {
                        setState(() => _suggestions.clear());
                      } else {
                        _searchLocation(val);
                      }
                    },
                  ),
                ),

                // Suggestions dropdown - opaque GestureDetector wraps the
                // list to block taps from reaching the map underneath
                if (_suggestions.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      // Absorb tap - prevents the map from receiving the tap
                      // that would overwrite _selectedLocation
                    },
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Material(
                        color: const Color(0xFF111827),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(12)),
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.3,
                          ),
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _suggestions.length.clamp(0, 5),
                            separatorBuilder: (_, _) => const Divider(
                                height: 1, color: Color(0xFF1F2937)),
                            itemBuilder: (_, i) {
                              final s = _suggestions[i];
                              return ListTile(
                                leading: const Icon(Icons.location_on,
                                    size: 18, color: Color(0xFF60A5FA)),
                                title: Text(
                                  s.displayName,
                                  style: const TextStyle(
                                      color: Color(0xFFE5E7EB), fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _selectSuggestion(s),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // My Location button - hide when keyboard open
          if (!keyboardOpen)
            Positioned(
              right: 16,
              bottom: 90,
              child: GestureDetector(
                onTap: _getCurrentLocation,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _gettingLocation
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      Color(0xFF2563EB)),
                            ),
                          )
                        : const Icon(Icons.my_location,
                            size: 24, color: Color(0xFF9CA3AF)),
                  ),
                ),
              ),
            ),

          // Insert Location button - bottom, full width
          Positioned(
            left: 16,
            right: 16,
            bottom: 36,
            child: AnimatedOpacity(
              opacity: _selectedLocation != null ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedLocation != null
                      ? () =>
                          Navigator.pop(context, _selectedLocation)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor:
                        const Color(0xFF2563EB).withValues(alpha: 0.3),
                    disabledForegroundColor: const Color(0xFF6B7280),
                    elevation: 4,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Insert Location',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ),
            ),
          ),

          // Loading spinner (only on initial load)
          if (_gettingLocation && _selectedLocation == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
