# Trip Destination Search and Peer Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement destination search & selection during trip creation, show destination pins on the map, and display scrollable member chips to center the map on specific travelers.

**Architecture:** Update the backend trip details API to include members and destinations. On the mobile client, replace the create dialog with a dedicated `CreateTripScreen` that integrates OSM Nominatim API search and map tapping, and update `TripMapScreen` to draw destinations and a peer chip row with centering functionality.

**Tech Stack:** Flutter, OpenStreetMap (Nominatim HTTP + `flutter_map` viewport), Express (Bun TS), PostgreSQL (Prisma).

---

## File Structure

### Backend
*   **Modify**: [backend/src/services/trip.service.ts](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/backend/src/services/trip.service.ts) — Add includes for destinations and members in `getTripById`.

### Mobile Client
*   **Modify**: [mobile/lib/core/network/router.dart](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/core/network/router.dart) — Register `/create-trip` route.
*   **Modify**: [mobile/lib/features/trip/screens/tripsScreen.dart](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/features/trip/screens/tripsScreen.dart) — Navigate to the new creation screen.
*   **Create**: [mobile/lib/features/trip/screens/createTripScreen.dart](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/features/trip/screens/createTripScreen.dart) — New screen for search, pin selection, and trip creation.
*   **Modify**: [mobile/lib/features/tracking/screens/tripMapScreen.dart](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/features/tracking/screens/tripMapScreen.dart) — Add dynamic loading of trip details, render static destinations, and show the scrolling row of member chips with click-to-center actions.

---

## Tasks

### Task 1: Update Backend Trip Detail Query

**Files:**
*   Modify: [backend/src/services/trip.service.ts:47-49](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/backend/src/services/trip.service.ts#L47-L49)

- [ ] **Step 1: Modify `getTripById` to include destinations and members**

Modify the query inside `backend/src/services/trip.service.ts`:
```typescript
export const getTripById = (id: string) => {
  return prisma.trip.findUnique({
    where: { id, deletedAt: null },
    include: {
      destinations: true,
      members: {
        include: {
          user: {
            select: { id: true, email: true }
          }
        }
      }
    }
  });
};
```

- [ ] **Step 2: Run backend tests to ensure no regressions**

Run:
```bash
cd backend
bun test
```
Expected: Tests pass successfully.

- [ ] **Step 3: Commit changes (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: true`:
```bash
git add backend/src/services/trip.service.ts
git commit -m "feat(backend): include destinations and members in trip details response"
```
If `auto_commit: false`: print "Skipping commit (auto_commit: false)."

---

### Task 2: Register creation route in router and update Trips Screen

**Files:**
*   Modify: [mobile/lib/core/network/router.dart:53-56](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/core/network/router.dart#L53-L56)
*   Modify: [mobile/lib/features/trip/screens/tripsScreen.dart:219-225](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/features/trip/screens/tripsScreen.dart#L219-L225)

- [ ] **Step 1: Register `/create-trip` in router.dart**

Import `CreateTripScreen` and add the route:
```dart
import '../../features/trip/screens/createTripScreen.dart';

// Inside GoRouter routes definition:
GoRoute(
  path: '/create-trip',
  builder: (context, state) => const CreateTripScreen(),
),
```

- [ ] **Step 2: Update TripsScreen FAB to navigate to `/create-trip`**

Replace `_showCreateTripDialog` invocation in `tripsScreen.dart` with router navigation:
```dart
FloatingActionButton(
  heroTag: 'create',
  onPressed: () => context.push('/create-trip'),
  tooltip: 'Create Trip',
  child: const Icon(Icons.add),
),
```

- [ ] **Step 3: Commit changes (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: true`:
```bash
git add mobile/lib/core/network/router.dart mobile/lib/features/trip/screens/tripsScreen.dart
git commit -m "feat(mobile): register create-trip route and update trips dashboard navigation"
```
If `auto_commit: false`: print "Skipping commit (auto_commit: false)."

---

### Task 3: Build the `CreateTripScreen`

**Files:**
*   Create: [mobile/lib/features/trip/screens/createTripScreen.dart](file:///C:/Users/Raj%20Kishan%20Prashad/Desktop/wayfarer-sync/mobile/lib/features/trip/screens/createTripScreen.dart)

- [ ] **Step 1: Implement the UI, search queries, Nominatim API integration, map pinning, and start action**

Create `mobile/lib/features/trip/screens/createTripScreen.dart`:
```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/network/apiClient.dart';
import '../../tracking/providers/mapStateProvider.dart';

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
    _debounceTimer = Timer(const Duration(milliseconds: 500), () => _searchPlaces(query));
  }

  Future<void> _searchPlaces(String query) async {
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5');
      final response = await http.get(url, headers: {'User-Agent': 'com.wayfarersync.mobile'});
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
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json');
      final response = await http.get(url, headers: {'User-Agent': 'com.wayfarersync.mobile'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _selectedLocationName = data['display_name'] ?? 'Custom Location';
          _searchController.text = _selectedLocationName!;
        });
      } else {
        setState(() {
          _selectedLocationName = 'Location at (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
          _searchController.text = _selectedLocationName!;
        });
      }
    } catch (e) {
      setState(() {
        _selectedLocationName = 'Location at (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
        _searchController.text = _selectedLocationName!;
      });
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
        const SnackBar(content: Text('Please select or pin a destination location.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/trip', {
        'title': _titleController.text.trim(),
        'startedAt': DateTime.now().toUtc().toIso8601String(),
        'destinations': [
          {
            'name': _selectedLocationName ?? 'Destination',
            'latitude': _selectedLocation!.latitude,
            'longitude': _selectedLocation!.longitude,
            'order': 0,
          }
        ],
      });
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start trip: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start New Trip'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(20.5937, 78.9629), // Default center on India
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
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Trip Name',
                        prefixIcon: Icon(Icons.edit),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        labelText: 'Search Destination',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Positioned(
              top: 172,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    final name = suggestion['display_name'] ?? 'Unknown location';
                    final lat = double.parse(suggestion['lat']);
                    final lon = double.parse(suggestion['lon']);
                    return ListTile(
                      title: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectLocation(LatLng(lat, lon), name),
                    );
                  },
                ),
              ),
            ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _startTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Start Trip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compiling and formatting of the new file**

Verify: The mobile app builds and formats correctly.

- [ ] **Step 3: Commit changes (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: true`:
```bash
git add mobile/lib/features/trip/screens/createTripScreen.dart
git commit -m "feat(mobile): implement CreateTripScreen with location search, map pinning, and reverse geocoding"
```
If `auto_commit: false`: print "Skipping commit (auto_commit: false)."

---

### Task 4: Enhance TripMapScreen with Destinations and Peer Tracking

**Files:**
*   Modify: [mobile/lib/features/tracking/screens/tripMapScreen.dart](file:///C:/Users/Raj Kishan Prashad/Desktop/wayfarer-sync/mobile/lib/features/tracking/screens/tripMapScreen.dart)

- [ ] **Step 1: Retrieve and render destinations, and add horizontal member selection row**

Update `tripMapScreen.dart` to fetch details, render static destination pins, and display the scrollable list of peer chips to center coordinates:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:wayfarer_sync_mobile/features/tracking/models/realtimeEvent.dart';
import '../../../core/network/apiClient.dart';
import '../providers/liveTrackingProviders.dart';
import '../providers/mapStateProvider.dart';
import '../services/locationTrackingService.dart';
import '../services/syncService.dart';

class TripMapScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String currentUserId;

  const TripMapScreen({
    super.key,
    required this.tripId,
    required this.currentUserId,
  });

  @override
  ConsumerState<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends ConsumerState<TripMapScreen> {
  final MapController _mapController = MapController();
  bool _hasCentered = false;
  Map<String, dynamic>? _tripDetails;
  List<dynamic> _destinations = [];
  List<dynamic> _members = [];
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(locationTrackingServiceProvider)
          .startTracking(widget.tripId, widget.currentUserId);
      _fetchTripDetails();
    });
  }

  Future<void> _fetchTripDetails() async {
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/trip/${widget.tripId}');
      if (mounted) {
        setState(() {
          _tripDetails = response as Map<String, dynamic>;
          _destinations = _tripDetails?['destinations'] ?? [];
          _members = _tripDetails?['members'] ?? [];
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load trip details: $e');
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  @override
  void dispose() {
    ref.read(locationTrackingServiceProvider).stopTracking();
    _mapController.dispose();
    super.dispose();
  }

  String _getEmailPrefix(String email) {
    return email.split('@').first;
  }

  Color _getMemberColor(String hexColor) {
    try {
      final cleanHex = hexColor.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (_) {
      return Colors.deepOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveMarkerMap = ref.watch(mapStateProvider);

    final userPosition = liveMarkerMap.positions[widget.currentUserId];
    if (!_hasCentered && userPosition != null) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(userPosition, 15.0);
      });
    }

    ref.listen<AsyncValue<MemberLocationUpdate>>(liveLocationStreamProvider(widget.tripId), (previous, next) {
      if (next is AsyncData<MemberLocationUpdate>) {
        final update = next.value;
        ref
            .read(mapStateProvider.notifier)
            .updateMemberPosition(
              update.userId,
              LatLng(update.latitude, update.longitude),
            );
      }
    });

    final userMarkers = liveMarkerMap.positions.entries.map((entry) {
      final userId = entry.key;
      final position = entry.value;
      final isMe = userId == widget.currentUserId;

      // Find user specific color allocated from trip membership
      Color color = isMe ? Colors.blue : Colors.deepOrange;
      if (_members.isNotEmpty) {
        final memberObj = _members.firstWhere(
          (m) => m['userId'] == userId,
          orElse: () => null,
        );
        if (memberObj != null && memberObj['color'] != null) {
          color = _getMemberColor(memberObj['color']);
        }
      }

      return Marker(
        point: position,
        width: 40,
        height: 40,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.navigation, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }).toList();

    // Generate destinations static markers
    final destinationMarkers = _destinations.map((dest) {
      final lat = dest['latitude'] as double;
      final lon = dest['longitude'] as double;
      final name = dest['name'] as String;

      return Marker(
        point: LatLng(lat, lon),
        width: 60,
        height: 60,
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Destination: $name')),
            );
          },
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag, color: Colors.green, size: 36),
              Icon(Icons.location_on_outlined, color: Colors.green, size: 12),
            ],
          ),
        ),
      );
    }).toList();

    final allMarkers = [...userMarkers, ...destinationMarkers];

    return Scaffold(
      appBar: AppBar(
        title: Text(_tripDetails?['title'] ?? 'Live Trip Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Starting synchronization...'),
                  duration: Duration(seconds: 1),
                ),
              );
              try {
                await ref.read(syncServiceProvider).synchronizeTripPaths(widget.tripId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Synchronization complete.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sync failed: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(0.0, 0.0),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wayfarersync.mobile',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: liveMarkerMap.positions.values.toList(),
                    color: const Color(0xFF3388FF),
                    strokeWidth: 4.0,
                  ),
                ],
              ),
              MarkerLayer(markers: allMarkers),
            ],
          ),
          if (!_isLoadingDetails && _members.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final userId = member['userId'] as String;
                    final userEmail = member['user']?['email'] as String? ?? 'User';
                    final isMe = userId == widget.currentUserId;
                    final label = isMe ? 'Me' : _getEmailPrefix(userEmail);
                    final hexColor = member['color'] as String? ?? '#FF5722';
                    final color = _getMemberColor(hexColor);
                    
                    final hasLocation = liveMarkerMap.positions.containsKey(userId);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        avatar: CircleAvatar(
                          backgroundColor: color,
                          radius: 12,
                          child: Icon(
                            isMe ? Icons.person : Icons.navigation,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                        label: Text(label),
                        backgroundColor: Colors.white.withOpacity(0.9),
                        side: BorderSide(
                          color: hasLocation ? color : Colors.grey.shade300,
                          width: hasLocation ? 2.0 : 1.0,
                        ),
                        onPressed: () {
                          if (hasLocation) {
                            final pos = liveMarkerMap.positions[userId]!;
                            _mapController.move(pos, 15.0);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('No location updates from $label yet.'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final userPosition = liveMarkerMap.positions[widget.currentUserId];
          if (userPosition != null) {
            _mapController.move(userPosition, 15.0);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Current location not available yet.'),
              ),
            );
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze and tests**

Verify: Analyzer returns zero errors. Run tests in `mobile`:
```bash
cd mobile
flutter analyze
flutter test
```
Expected: Tests pass successfully.

- [ ] **Step 3: Commit changes (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: true`:
```bash
git add mobile/lib/features/tracking/screens/tripMapScreen.dart
git commit -m "feat(mobile): display destination pins and scrollable row of active members with tap-to-center functionality"
```
If `auto_commit: false`: print "Skipping commit (auto_commit: false)."
