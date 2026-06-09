import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:wayfarer_sync_mobile/features/tracking/models/realtimeEvent.dart';
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

  @override
  void initState() {
    super.initState();
    // Fire up the physical hardware GPS loop the second this viewport mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(locationTrackingServiceProvider)
          .startTracking(widget.tripId, widget.currentUserId);
    });
  }

  @override
  void dispose() {
    // Terminate GPS collection streams when exiting map view to conserve battery
    ref.read(locationTrackingServiceProvider).stopTracking();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveMarkerMap = ref.watch(mapStateProvider);

    // Auto-center map on first coordinates received
    final userPosition = liveMarkerMap.positions[widget.currentUserId];
    if (!_hasCentered && userPosition != null) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(userPosition, 15.0);
      });
    }

    // Listen to the real-time WebSocket channel for updates from other members
    ref.listen<
      AsyncValue<MemberLocationUpdate>
    >(liveLocationStreamProvider(widget.tripId), (previous, next) {
      if (next is AsyncData<MemberLocationUpdate>) {
        final update = next.value;
        // Pipe incoming location packets directly into our rendering state engine
        ref
            .read(mapStateProvider.notifier)
            .updateMemberPosition(
              update.userId,
              LatLng(update.latitude, update.longitude),
            );
      }
    });

    // Convert live user coordinate maps into visual map markers
    final userMarkers = liveMarkerMap.positions.entries.map((entry) {
      final userId = entry.key;
      final position = entry.value;
      final isMe = userId == widget.currentUserId;

      return Marker(
        point: position,
        width: 40,
        height: 40,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.deepOrange,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Trip Map'),
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
                    SnackBar(
                      content: Text('Sync failed: $e'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: LatLng(
            0.0,
            0.0,
          ), // Defaults to center of earth before GPS locks
          initialZoom: 13.0,
        ),
        children: [
          // 1. Base Tile Engine Layer (Loads OpenStreetMap Imagery)
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.wayfarersync.mobile',
          ),

          // 2. Polyline Layer (Renders the colorful tracking breadcrumb tail trails)
          PolylineLayer(
            polylines: [
              Polyline(
                points: liveMarkerMap.positions.values.toList(),
                color: const Color(0xFF3388FF),
                strokeWidth: 4.0,
              ),
            ],
          ),

          // 3. User Marker Avatars Layer (Pins live avatars over tracking heads)
          MarkerLayer(markers: userMarkers),
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
