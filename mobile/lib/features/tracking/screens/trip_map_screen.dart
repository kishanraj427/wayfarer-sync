import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:wayfarer_sync_mobile/features/tracking/models/realtimeEvent.dart';
import '../../../core/constants/appMotion.dart';
import '../../../core/constants/appStrings.dart';
import '../../../core/constants/appConstants.dart';
import '../../../core/constants/appRoutes.dart';
import '../../../core/motion/motion.dart';
import '../../../core/network/apiUrl.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/theme/appSemanticColors.dart';
import '../../../core/theme/appTheme.dart';
import '../../../core/theme/appTokens.dart';
import '../../../core/widgets/glassPanel.dart';
import '../../trip/providers/trips_provider.dart';
import '../../trip/services/tripShare.dart';
import '../providers/connectivityProvider.dart';
import '../providers/liveTrackingProviders.dart';
import '../providers/mapStateProvider.dart';
import '../repositories/pathRepository.dart';
import '../services/locationPermissionHandler.dart';
import '../widgets/locationAccessWatcher.dart';
import '../services/locationTrackingService.dart';
import '../services/osrmRoutingService.dart';
import '../services/syncService.dart';

class TripMapScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String tripTitle;
  final String currentUserId;

  const TripMapScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
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

  // Saved during initState so dispose() can call stopTracking() without
  // touching `ref` (which is illegal during dispose in Riverpod).
  late final LocationTrackingService _trackingService;
  late final OsrmRoutingService _routingService;

  // Rendered route lines, updated by the service after each fetch.
  Map<String, List<LatLng>> _routesToDestination = {};

  // Durable subscription to other members' live location frames. Registered
  // via listenManual (not ref.listen, which only works inside build) so the
  // underlying autoDispose stream provider stays alive and the socket keeps
  // draining while this screen is open. Closed in dispose().
  ProviderSubscription<AsyncValue<MemberLocationUpdate>>?
  _liveLocationSubscription;

  // Re-checks location access whenever the app comes back to the foreground,
  // so turning GPS off mid-trip — or returning from the settings screen after
  // turning it on — is noticed instead of ignored until the next cold start.
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Save direct references before any async work so dispose() and
      // callbacks can use them without touching ref.
      _trackingService = ref.read(locationTrackingServiceProvider);
      _routingService = ref.read(osrmRoutingServiceProvider);
      _beginTracking();
      _lifecycle = AppLifecycleListener(onResume: _beginTracking);
      _fetchTripDetails();
      _loadHistoricalPaths();

      // Subscribe to other members' live locations for the lifetime of this
      // screen. listenManual — not ref.listen, which only works during build —
      // returns a durable subscription (closed in dispose) and keeps the
      // autoDispose stream provider, and therefore the socket, alive. This is
      // the only path that feeds remote members into the map, so if it fails to
      // subscribe no one but yourself ever appears.
      _liveLocationSubscription =
          ref.listenManual<AsyncValue<MemberLocationUpdate>>(
            liveLocationStreamProvider(widget.tripId),
            (previous, next) {
              // AsyncValue.value is nullable in Riverpod 3: null while loading
              // or on error, the data otherwise.
              final update = next.value;
              if (update == null) return;
              ref
                  .read(mapStateProvider.notifier)
                  .updateMemberPosition(
                    update.userId,
                    LatLng(update.latitude, update.longitude),
                  );
            },
            onError: (error, stackTrace) {
              // reason: a swallowed socket/parse error previously hid that
              // remote updates had stopped arriving — surface it instead.
              debugPrint('Live location stream error: $error');
            },
          );
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

  /// Loads every member's recorded path once on open and seeds the map, so a
  /// member's earlier movement is visible immediately instead of only after
  /// they emit a fresh live frame.
  Future<void> _loadHistoricalPaths() async {
    try {
      final pathRepository = ref.read(pathRepositoryProvider);
      final historyByUser = await pathRepository.getTripPaths(widget.tripId);
      if (!mounted) return;
      ref.read(mapStateProvider.notifier).hydrateHistory(historyByUser);
    } catch (error) {
      // reason: history is a best-effort enhancement; live tracking still works
      // without it, so a fetch failure must not break opening the map.
      debugPrint('Failed to load historical paths: $error');
    }
  }

  // ── OSRM route refresh ────────────────────────────────────────────────

  /// Asks the service to refresh any stale routes, then flushes the new
  /// route map into local state so the map layer repaints.
  Future<void> _refreshRoutes(Map<String, LatLng> positions) async {
    if (_destinations.isEmpty) return;
    final dest = _destinations.first;
    final destLat = (dest['latitude'] as num).toDouble();
    final destLng = (dest['longitude'] as num).toDouble();

    final updated = await _routingService.fetchRoutesToDestination(
      destination: LatLng(destLat, destLng),
      positions: positions,
    );

    if (updated && mounted) {
      setState(() {
        _routesToDestination = Map.of(_routingService.routes);
      });
    }
  }

  /// Starts tracking, and tells the user if it could not start.
  ///
  /// Safe to call repeatedly — it runs on every resume, and re-checking is the
  /// whole point: location can be switched off long after the first launch.
  Future<void> _beginTracking() async {
    // Always re-check, even while tracking. An open position stream does NOT
    // prove location is still available: the user can switch GPS off while the
    // app is backgrounded, and the subscription stays alive but silent.
    final access = await LocationPermissionHandler.check();

    if (access == LocationAccess.granted) {
      if (!_trackingService.isTracking) {
        await _trackingService.startTracking(
          widget.tripId,
          widget.currentUserId,
        );
      }
      return;
    }

    // Access was lost — drop the stale stream so isTracking reflects reality.
    _trackingService.stopTracking();
    if (!mounted) return;
    await showLocationAccessDialog(context, access);
  }

  @override
  void dispose() {
    // Use the pre-saved service reference — never call ref.read() here.
    _lifecycle?.dispose();
    _liveLocationSubscription?.close();
    _trackingService.stopTracking();
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
    // Prefer the colour assigned to this member in the trip, so a traveler's
    // own path is drawn in their trip colour (not a generic self colour).
    final member = _members.firstWhere(
      (member) => member['userId'] == userId,
      orElse: () => null,
    );
    final hexColor = member?['color'] as String?;
    if (hexColor != null) return _getMemberColor(hexColor);
    return userId == widget.currentUserId
        ? context.semantic.selfMarker
        : context.semantic.peerFallback;
  }

  Future<void> _syncNow() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.startingSync),
        duration: AppConstants.snackBarShort,
      ),
    );
    try {
      await ref.read(syncServiceProvider).synchronizeTripPaths(widget.tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.syncComplete)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.syncFailed(
            e is ApiException ? e.message : AppStrings.unknownError))));
      }
    }
  }

  // ── App bar actions ───────────────────────────────────────────────

  void _shareTrip() {
    shareTrip(tripId: widget.tripId, title: widget.tripTitle);
  }

  Future<void> _confirmEndTrip() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.endTripDialogTitle),
        content: const Text(AppStrings.endTripDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.endTrip),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(tripsProvider.notifier).endTrip(widget.tripId);
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text(AppStrings.tripEnded)));
        router.go(AppRoutes.trips);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.failedToEndTrip(
              e is ApiException ? e.message : AppStrings.unknownError))),
        );
      }
    }
  }

  void _recenterOnSelf() {
    final userPosition = ref
        .read(mapStateProvider)
        .positions[widget.currentUserId];
    if (userPosition != null) {
      _mapController.move(userPosition, AppConstants.mapFocusZoom);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.currentLocationUnavailable)),
      );
    }
  }

  static const double _minZoom = AppConstants.mapMinZoom;
  static const double _maxZoom = AppConstants.mapMaxZoom;
  static const double _zoomStep = AppConstants.mapZoomStep;

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    final nextZoom = (camera.zoom + delta).clamp(_minZoom, _maxZoom).toDouble();
    _mapController.move(camera.center, nextZoom);
  }

  @override
  Widget build(BuildContext context) {
    final liveMarkerMap = ref.watch(mapStateProvider);

    // Top bar shows only live members: the current user (always live while
    // viewing their own map) plus anyone we're currently receiving locations
    // for. A member in the roster who has never shared a location is omitted.
    final liveMembers = _members.where((member) {
      final userId = member['userId'] as String?;
      if (userId == null) return false;
      return userId == widget.currentUserId ||
          liveMarkerMap.positions.containsKey(userId);
    }).toList();

    // Display-only: drives the "Syncing…" indicator dot in the bottom info
    // panel. Reuses the existing app-wide connectivity stream; does not
    // trigger sync itself (that's owned by connectivitySyncListenerProvider).
    final connectivityAsync = ref.watch(connectivityStreamProvider);
    final isOnline = connectivityAsync.maybeWhen(
      data: (resultList) => resultList.any(
        (result) =>
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.ethernet ||
            result == ConnectivityResult.vpn,
      ),
      orElse: () => false,
    );

    final userPosition = liveMarkerMap.positions[widget.currentUserId];
    if (!_hasCentered && userPosition != null) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(userPosition, AppConstants.mapFocusZoom);
      });
    }

    // Refresh OSRM routes whenever positions change (post-frame so we
    // don't trigger setState during a build).
    if (liveMarkerMap.positions.isNotEmpty && _destinations.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshRoutes(liveMarkerMap.positions);
      });
    }

    // NOTE: ref.listen was moved to initState so it is only registered once.

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
        ).appPopIn(context),
      );
    }).toList();

    // Generate destinations static markers
    final destinationMarkers = _destinations.map((dest) {
      final lat = (dest['latitude'] as num).toDouble();
      final lon = (dest['longitude'] as num).toDouble();
      final name = dest['name'] as String? ?? AppStrings.destinationFallback;

      return Marker(
        point: LatLng(lat, lon),
        width: 60,
        height: 60,
        child: GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(AppStrings.destinationSnack(name))));
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_on,
                color: context.semantic.destinationPin,
                size: 36,
              ),
            ],
          ),
        ).appPopIn(context),
      );
    }).toList();

    final allMarkers = [...userMarkers, ...destinationMarkers];

    // Shared chrome for the circular zoom/recenter/sync buttons — appearance
    // only, applied via IconButton's existing `style` slot.
    final circularButtonStyle = IconButton.styleFrom(
      backgroundColor: Theme.of(context).colorScheme.surface,
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      shape: CircleBorder(side: BorderSide(color: context.semantic.hairline)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.tripTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == AppConstants.menuActionShare) _shareTrip();
              if (value == AppConstants.menuActionEnd) _confirmEndTrip();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: AppConstants.menuActionShare,
                child: ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: Text(AppStrings.share),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: AppConstants.menuActionEnd,
                child: ListTile(
                  leading: Icon(Icons.stop_circle_outlined),
                  title: Text(AppStrings.endTrip),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(0.0, 0.0),
              initialZoom: AppConstants.mapInitialZoom,
            ),
            children: [
              TileLayer(
                urlTemplate: AppConstants.osmTileUrlTemplate,
                userAgentPackageName: 'com.wayfarersync.mobile',
              ),
              // ── OSRM road routes (member → destination) ───────────────
              // Casing layer: SOLID continuous black border drawn first.
              // Sits behind the dash gaps of the route layer so the colored
              // line is readable against any OSM tile color.
              PolylineLayer(
                polylines: _routesToDestination.entries
                    .where((e) => e.value.length >= 2)
                    .map(
                      (e) => Polyline(
                        points: e.value,
                        color: Colors.black.withValues(alpha: .85),
                        strokeWidth: 5.0,
                      ),
                    )
                    .toList(),
              ),
              // Route layer: member color, dashed, drawn on top of casing.
              PolylineLayer(
                polylines: _routesToDestination.entries
                    .where((e) => e.value.length >= 2)
                    .map(
                      (e) => Polyline(
                        points: e.value,
                        color: _trailColorForUser(e.key),
                        strokeWidth: 3.0,
                        pattern: StrokePattern.dashed(segments: [12.0, 6.0]),
                      ),
                    )
                    .toList(),
              ),
              // ── GPS breadcrumb trails (movement history) ──────────────
              // Each trail is split into segments so a stale/out-of-order fix
              // never draws a straight "teleport" line across the map.
              PolylineLayer(
                polylines: liveMarkerMap.trails.entries
                    .expand(
                      (entry) => listTrailSegments(entry.value)
                          .where((segment) => segment.length >= 2)
                          .map(
                            (segment) => Polyline(
                              points: segment,
                              color: _trailColorForUser(entry.key),
                              strokeWidth: 4.0,
                            ),
                          ),
                    )
                    .toList(),
              ),
              MarkerLayer(markers: allMarkers),
            ],
          ),
          if (!_isLoadingDetails &&
              (_members.isNotEmpty || _destinations.isNotEmpty))
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
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // ── Destination chips (shown first) ───────────────────
                      ..._destinations.map((dest) {
                        final lat = (dest['latitude'] as num).toDouble();
                        final lon = (dest['longitude'] as num).toDouble();
                        final name = dest['name'] as String? ?? AppStrings.destinationFallback;

                        return Padding(
                          padding: const EdgeInsets.only(),
                          child: Tooltip(
                            message: name,
                            preferBelow: false,
                            child: ActionChip(
                              label: CircleAvatar(
                                backgroundColor:
                                    context.semantic.destinationPin,
                                radius: 12,
                                child: Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: context.semantic.onMarker,
                                ),
                              ),
                              side: BorderSide(
                                color: context.semantic.destinationPin,
                                width: 1.5,
                              ),
                              onPressed: () {
                                _mapController.move(LatLng(lat, lon), AppConstants.mapFocusZoom);
                              },
                            ),
                          ),
                        );
                      }),

                      // ── Divider between destinations and members ──────────
                      if (_destinations.isNotEmpty && liveMembers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.sm,
                            vertical: AppSpace.xs,
                          ),
                          child: VerticalDivider(
                            width: 1,
                            thickness: 1,
                            color: context.semantic.hairline,
                          ),
                        ),

                      // ── Member chips (live members only) ──────────────────
                      ...liveMembers.map((member) {
                        final userId = member['userId'] as String;
                        final userEmail =
                            member['user']?['email'] as String? ?? AppStrings.memberFallback;
                        final isMe = userId == widget.currentUserId;
                        final label = isMe ? AppStrings.meLabel : _getEmailPrefix(userEmail);
                        final hexColor =
                            member['color'] as String? ?? AppConstants.defaultMemberColorHex;
                        final color = _getMemberColor(hexColor);
                        final hasLocation = liveMarkerMap.positions.containsKey(
                          userId,
                        );
                        // "Selected" chip = the current user's own chip — the
                        // only selection concept already present (`isMe`).
                        final isSelected = isMe;

                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpace.sm),
                          child: ActionChip(
                            backgroundColor: isSelected
                                ? context.semantic.activeContainer
                                : Theme.of(context).colorScheme.surface,
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
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: isSelected
                                        ? context.semantic.onActiveContainer
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
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
                                _mapController.move(pos, AppConstants.mapFocusZoom);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppStrings.noLocationUpdates(label),
                                    ),
                                    duration: AppConstants.snackBarNormal,
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          if (!_isLoadingDetails)
            Positioned(
              left: AppSpace.md,
              bottom: AppSpace.md,
              child: SafeArea(
                top: false,
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.tripIdInfoLabel,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(widget.tripId, style: monoData(context)),
                      const SizedBox(height: AppSpace.xs),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isOnline
                                  ? context.semantic.signalOnline
                                  : context.semantic.hairline,
                            ),
                          ),
                          const SizedBox(width: AppSpace.xs),
                          AnimatedSwitcher(
                            duration: AppMotion.fast,
                            child: Text(
                              isOnline ? AppStrings.statusSyncing : AppStrings.statusOffline,
                              key: ValueKey<bool>(isOnline),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      style: circularButtonStyle,
                      icon: const Icon(Icons.add),
                      tooltip: AppStrings.zoomInTooltip,
                      onPressed: () => _zoomBy(_zoomStep),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    IconButton(
                      style: circularButtonStyle,
                      icon: const Icon(Icons.remove),
                      tooltip: AppStrings.zoomOutTooltip,
                      onPressed: () => _zoomBy(-_zoomStep),
                    ),
                    Divider(
                      height: AppSpace.sm,
                      color: context.semantic.hairline,
                    ),
                    IconButton(
                      style: circularButtonStyle,
                      icon: const Icon(Icons.my_location),
                      tooltip: AppStrings.recenterTooltip,
                      onPressed: _recenterOnSelf,
                    ),
                    const SizedBox(height: AppSpace.xs),
                    IconButton(
                      style: circularButtonStyle,
                      icon: const Icon(Icons.sync),
                      tooltip: AppStrings.syncOfflineTooltip,
                      onPressed: _syncNow,
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
