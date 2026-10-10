import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/theme.dart';
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
    _mapController.move(point, 14);
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
      _mapController.move(_selectedLocation!, 16);
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
    final c = context.colors;
    final statusBar = MediaQuery.of(context).padding.top;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final keyboardOpen = keyboardHeight > 0;

    final floatShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
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
                  headers: {'User-Agent': 'DataCollectionApp/1.0'},
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
                            color: c.danger,
                            size: 44,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.35),
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

          // Close button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    _MapIconButton(
                      icon: Icons.close,
                      tooltip: 'Close',
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Search bar + suggestions
          Positioned(
            top: statusBar + 68,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: AppRadii.brMd,
                    border: Border.all(color: c.outline),
                    boxShadow: floatShadow,
                  ),
                  child: TextField(
                    focusNode: _searchFocus,
                    controller: _searchCtrl,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: c.textPrimary),
                    decoration: InputDecoration(
                      filled: false,
                      hintText: 'Search for a place',
                      prefixIcon: Icon(Icons.search,
                          size: AppIconSize.md, color: c.textSecondary),
                      suffixIcon: _searchLoading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: AppIconSize.sm,
                                height: AppIconSize.sm,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      size: AppIconSize.md,
                                      color: c.textSecondary),
                                  tooltip: 'Clear',
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _suggestions.clear());
                                    _searchFocus.requestFocus();
                                  },
                                )
                              : null,
                      border: const OutlineInputBorder(
                        borderRadius: AppRadii.brMd,
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: const OutlineInputBorder(
                        borderRadius: AppRadii.brMd,
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: AppRadii.brMd,
                        borderSide: BorderSide.none,
                      ),
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
                if (_suggestions.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Container(
                      margin: const EdgeInsets.only(top: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: AppRadii.brMd,
                        border: Border.all(color: c.outline),
                        boxShadow: floatShadow,
                      ),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadii.brMd,
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length.clamp(0, 5),
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: c.outline),
                          itemBuilder: (_, i) {
                            final s = _suggestions[i];
                            return ListTile(
                              leading: Icon(Icons.location_on_outlined,
                                  size: AppIconSize.md, color: c.accent),
                              title: Text(
                                s.displayName,
                                style: Theme.of(context).textTheme.bodyMedium,
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
              ],
            ),
          ),

          // My Location button
          if (!keyboardOpen)
            Positioned(
              right: AppSpacing.lg,
              bottom: 90,
              child: _MapIconButton(
                icon: Icons.my_location,
                tooltip: 'My location',
                loading: _gettingLocation,
                onTap: _getCurrentLocation,
              ),
            ),

          // Insert Location button
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.xxl,
            child: AnimatedOpacity(
              opacity: _selectedLocation != null ? 1.0 : 0.0,
              duration: AppDurations.medium,
              child: ElevatedButton(
                onPressed: _selectedLocation != null
                    ? () => Navigator.pop(context, _selectedLocation)
                    : null,
                child: const Text('Insert Location'),
              ),
            ),
          ),

          if (_gettingLocation && _selectedLocation == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

/// Floating square control button used over the map (close, my-location).
class _MapIconButton extends StatelessWidget {
  const _MapIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: AppRadii.brMd,
      elevation: 2,
      child: InkWell(
        borderRadius: AppRadii.brMd,
        onTap: onTap,
        child: Container(
          width: AppSizes.minTouchTarget,
          height: AppSizes.minTouchTarget,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AppRadii.brMd,
            border: Border.all(color: c.outline),
          ),
          child: loading
              ? const SizedBox(
                  width: AppIconSize.md,
                  height: AppIconSize.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Tooltip(
                  message: tooltip ?? '',
                  child: Icon(icon, size: AppIconSize.lg, color: c.textSecondary),
                ),
        ),
      ),
    );
  }
}
