import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:wayfarer_sync_mobile/features/tracking/models/realtimeEvent.dart';
import '../../../core/network/apiUrl.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTheme.dart';
import '../../../core/theme/appTokens.dart';
import '../../../core/widgets/glassPanel.dart';
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
      return context.semantic.peerFallback;
    }
  }

  Color _trailColorForUser(String userId) {
    if (userId == widget.currentUserId) return context.semantic.selfMarker;
    final member = _members.firstWhere(
      (member) => member['userId'] == userId,
      orElse: () => null,
    );
    final hexColor = member?['color'] as String?;
    if (hexColor != null) return _getMemberColor(hexColor);
    return context.semantic.peerFallback;
  }

  Future<void> _syncNow() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting synchronization...'),
        duration: Duration(seconds: 1),
      ),
    );
    try {
      await ref.read(syncServiceProvider).synchronizeTripPaths(widget.tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronization complete.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  void _recenterOnSelf() {
    final userPosition = ref.read(mapStateProvider).positions[widget.currentUserId];
    if (userPosition != null) {
      _mapController.move(userPosition, 15.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location not available yet.')),
      );
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

      final color = _trailColorForUser(userId);

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
                border: Border.all(color: context.semantic.onMarker, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  isMe ? Icons.person : Icons.navigation,
                  size: 16,
                  color: context.semantic.onMarker,
                ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flag, color: context.semantic.destinationPin, size: 36),
              Icon(Icons.location_on_outlined, color: context.semantic.destinationPin, size: 12),
            ],
          ),
        ),
      );
    }).toList();

    final allMarkers = [...userMarkers, ...destinationMarkers];

    return Scaffold(
      appBar: AppBar(
        title: Text(_tripDetails?['title'] ?? 'Live trip'),
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
                polylines: liveMarkerMap.trails.entries
                    .where((entry) => entry.value.length >= 2)
                    .map((entry) => Polyline(
                          points: entry.value,
                          color: _trailColorForUser(entry.key),
                          strokeWidth: 4.0,
                        ))
                    .toList(),
              ),
              MarkerLayer(markers: allMarkers),
            ],
          ),
          if (!_isLoadingDetails && _members.isNotEmpty)
            Positioned(
              top: AppSpace.md,
              left: AppSpace.md,
              right: AppSpace.md,
              child: GlassPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.sm,
                  vertical: AppSpace.xs,
                ),
                child: SizedBox(
                  height: 44,
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
                        padding: const EdgeInsets.only(right: AppSpace.sm),
                        child: ActionChip(
                          avatar: CircleAvatar(
                            backgroundColor: color,
                            radius: 12,
                            child: Icon(
                              isMe ? Icons.person : Icons.navigation,
                              size: 10,
                              color: context.semantic.onMarker,
                            ),
                          ),
                          label: Text(
                            label,
                            style: monoData(
                              context,
                              size: 12,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          side: BorderSide(
                            color: hasLocation
                                ? context.semantic.signalOnline
                                : context.semantic.hairline,
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
            ),
          Positioned(
            right: AppSpace.md,
            bottom: AppSpace.md,
            child: SafeArea(
              top: false,
              child: GlassPanel(
                padding: const EdgeInsets.all(AppSpace.xs),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.sync),
                      tooltip: 'Sync offline points',
                      onPressed: _syncNow,
                    ),
                    IconButton(
                      icon: const Icon(Icons.my_location),
                      tooltip: 'Recenter on me',
                      onPressed: _recenterOnSelf,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
