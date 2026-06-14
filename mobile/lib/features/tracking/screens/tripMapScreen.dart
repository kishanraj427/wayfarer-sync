import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:wayfarer_sync_mobile/features/tracking/models/realtimeEvent.dart';
import '../../../core/network/apiUrl.dart';
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
      final response = await client.get(ApiUrl.tripDetails(widget.tripId));
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
