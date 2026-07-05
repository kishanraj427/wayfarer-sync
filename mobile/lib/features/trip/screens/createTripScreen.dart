import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/network/authTokenProvider.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTheme.dart';
import '../../../core/theme/appTokens.dart';
import '../../../core/util/text_input_rules.dart';
import '../../../core/widgets/glassPanel.dart';
import '../../../core/widgets/primaryButton.dart';
import '../providers/trips_provider.dart';
import '../repositories/trip_repository.dart';
import '../services/tripShare.dart';

class CreateTripScreen extends ConsumerStatefulWidget {
  const CreateTripScreen({super.key});

  @override
  ConsumerState<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends ConsumerState<CreateTripScreen> {
  final _titleController = TextEditingController();
  final _searchController = TextEditingController();
  final MapController _mapController = MapController();

  LatLng? _selectedLocation;
  String? _selectedLocationName;
  List<dynamic> _suggestions = [];
  bool _isSearching = false;
  bool _isSaving = false;
  bool _isLocating = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    _mapController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounceTimer = Timer(
      const Duration(milliseconds: 500),
      () => _searchPlaces(query),
    );
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.wayfarersync.mobile'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _suggestions = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Nominatim query failed: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.wayfarersync.mobile'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _selectedLocationName = data['display_name'] ?? 'Custom Location';
          _searchController.text = _selectedLocationName!;
        });
      } else {
        setState(() {
          _selectedLocationName =
              'Location at (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
          _searchController.text = _selectedLocationName!;
        });
      }
    } catch (e) {
      setState(() {
        _selectedLocationName =
            'Location at (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
        _searchController.text = _selectedLocationName!;
      });
    }
  }

  /// Fetches the device's current GPS position and centres the map on it.
  /// If no destination is pinned yet, it also drops a marker and reverse-geocodes.
  Future<void> _locateMe() async {
    setState(() => _isLocating = true);
    try {
      // Ensure permission is granted before calling the hardware
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission is required.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final here = LatLng(position.latitude, position.longitude);
      _mapController.move(here, 15.0);

      // If no destination chosen yet, drop a pin here
      if (_selectedLocation == null) {
        setState(() {
          _selectedLocation = here;
          _selectedLocationName = 'Fetching address...';
          _searchController.text = 'Fetching address...';
        });
        await _reverseGeocode(here);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _selectLocation(LatLng point, String name) {
    setState(() {
      _selectedLocation = point;
      _selectedLocationName = name;
      _searchController.text = name;
      _suggestions = [];
    });
    _mapController.move(point, 14.0);
  }

  Future<void> _startTrip() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a trip name.')),
      );
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or pin a destination location.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final createdTrip = await ref
          .read(tripRepositoryProvider)
          .createTrip(
            title: _titleController.text.trim(),
            startedAt: DateTime.now(),
            destinations: [
              {
                'name': _selectedLocationName ?? 'Destination',
                'latitude': _selectedLocation!.latitude,
                'longitude': _selectedLocation!.longitude,
                'order': 0,
              },
            ],
          );
      ref.read(tripsProvider.notifier).refresh();
      if (mounted) {
        await _showTripCreatedDialog(createdTrip.id, createdTrip.title);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start trip: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showTripCreatedDialog(String tripId, String tripTitle) async {
    final userId = ref.read(currentUserIdProvider) ?? 'unknown';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 48,
              color: context.semantic.signalOnline,
            ),
            const SizedBox(height: AppSpace.md),
            Text('Trip created', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpace.xs),
            const Text('Share this Trip ID so friends can join:'),
            const SizedBox(height: AppSpace.sm),
            SelectableText(
              tripId,
              style: monoData(context, size: 16, weight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Copy'),
            onPressed: () async {
              await copyTripId(tripId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trip ID copied to clipboard.')),
                );
              }
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            onPressed: () => shareTrip(tripId: tripId, title: tripTitle),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.pushReplacement('/trip/$tripId/map/$userId');
            },
            child: const Text('Open Live Map'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start new trip')),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(
                20.5937,
                78.9629,
              ), // Default center on India
              initialZoom: 5.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLocation = point;
                  _selectedLocationName = 'Fetching address...';
                  _searchController.text = 'Fetching address...';
                });
                _reverseGeocode(point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wayfarersync.mobile',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 45,
                      height: 45,
                      child: Icon(
                        Icons.location_on,
                        color: context.semantic.route,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: AppSpace.md,
            left: AppSpace.md,
            right: AppSpace.md,
            child: GlassPanel(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      inputFormatters: inputRules(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Trip name',
                        prefixIcon: Icon(Icons.edit_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      inputFormatters: inputRules(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Search destination',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    if (_suggestions.isNotEmpty) ...[
                      const SizedBox(height: AppSpace.sm),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            final name =
                                suggestion['display_name'] ??
                                'Unknown location';
                            final lat = double.parse(suggestion['lat']);
                            final lon = double.parse(suggestion['lon']);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () =>
                                  _selectLocation(LatLng(lat, lon), name),
                            );
                          },
                        ),
                      ),
                    ] else if (_selectedLocation != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_selectedLocation!.latitude.toStringAsFixed(5)}, '
                          '${_selectedLocation!.longitude.toStringAsFixed(5)}',
                          style: monoData(context, size: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // ── Bottom controls: locate-me + Start Trip bar ───────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Locate-me button floats above the bar, right-aligned
                  Padding(
                    padding: const EdgeInsets.only(
                      right: AppSpace.md,
                      bottom: AppSpace.sm,
                    ),
                    child: GlassPanel(
                      padding: const EdgeInsets.all(AppSpace.xs),
                      child: _isLocating
                          ? const SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.my_location),
                              tooltip: 'Locate me',
                              onPressed: _locateMe,
                            ),
                    ),
                  ),
                  // Start Trip bar — full width
                  Container(
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(color: context.semantic.hairline),
                      ),
                    ),
                    child: PrimaryButton(
                      label: 'Start trip',
                      icon: Icons.flag_outlined,
                      loading: _isSaving,
                      onPressed: (_isSaving || _selectedLocation == null)
                          ? null
                          : _startTrip,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
