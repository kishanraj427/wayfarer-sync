import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Fetches and caches road-based OSRM routes from each member's live
/// position to the trip destination.
///
/// The screen keeps a single [OsrmRoutingService] instance (via the
/// provider below) and calls [fetchRoutesToDestination] whenever it
/// detects that member positions have changed.
class OsrmRoutingService {
  static const String _osrmBase =
      'https://router.project-osrm.org/route/v1/driving/';

  // ── Internal state ──────────────────────────────────────────────────────

  /// Latest decoded route per userId (origin → destination).
  final Map<String, List<LatLng>> _routes = {};

  /// Last origin position for which a route was successfully fetched per user.
  /// Used to skip re-fetching when the member hasn't moved.
  final Map<String, LatLng> _lastFetchedOrigin = {};

  /// Guards against concurrent OSRM calls.
  bool _isFetching = false;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Read-only snapshot of all cached routes.
  Map<String, List<LatLng>> get routes => Map.unmodifiable(_routes);

  /// Fetches OSRM routes for every member in [positions] whose origin has
  /// changed since the last successful fetch.
  ///
  /// [destination] is the trip's primary destination [LatLng].
  /// Returns `true` if at least one route was updated so the caller knows
  /// it should call `setState`.
  Future<bool> fetchRoutesToDestination({
    required LatLng destination,
    required Map<String, LatLng> positions,
  }) async {
    if (_isFetching || positions.isEmpty) return false;

    // Only re-fetch members whose position has actually changed.
    final stale = positions.entries.where((e) {
      final prev = _lastFetchedOrigin[e.key];
      return prev == null ||
          prev.latitude != e.value.latitude ||
          prev.longitude != e.value.longitude;
    }).toList();

    if (stale.isEmpty) return false;

    _isFetching = true;
    bool anyUpdated = false;

    try {
      for (final entry in stale) {
        final userId = entry.key;
        final origin = entry.value;

        final route = await _fetchSingleRoute(origin, destination);
        if (route != null) {
          _routes[userId] = route;
          _lastFetchedOrigin[userId] = origin;
          anyUpdated = true;
        }
      }
    } finally {
      _isFetching = false;
    }

    return anyUpdated;
  }

  /// Clears all cached routes and origin history.
  /// Call this when the destination changes or when leaving the map screen.
  void clearRoutes() {
    _routes.clear();
    _lastFetchedOrigin.clear();
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  /// Calls the OSRM HTTP API for a single origin → destination pair.
  /// Returns `null` on any network/parse failure so callers can ignore it.
  Future<List<LatLng>?> _fetchSingleRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final uri = Uri.parse(
        '$_osrmBase'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=polyline',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routeList = data['routes'] as List<dynamic>?;
      if (routeList == null || routeList.isEmpty) return null;

      final geometry = routeList.first['geometry'] as String?;
      if (geometry == null) return null;

      return _decodePolyline(geometry);
    } catch (_) {
      // Silently swallow network errors, timeouts, parse exceptions.
      return null;
    }
  }

  /// Decodes a Google/OSRM precision-5 encoded polyline string into
  /// an ordered list of [LatLng] coordinates.
  List<LatLng> _decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, value = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        value |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (value & 1) != 0 ? ~(value >> 1) : (value >> 1);

      shift = 0;
      value = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        value |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (value & 1) != 0 ? ~(value >> 1) : (value >> 1);

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return result;
  }
}

// ── Provider ────────────────────────────────────────────────────────────────

/// Each map screen gets its own [OsrmRoutingService] instance.
/// Using [autoDispose] ensures routes are cleared when the screen exits.
final osrmRoutingServiceProvider =
    Provider.autoDispose<OsrmRoutingService>((ref) {
  final service = OsrmRoutingService();
  ref.onDispose(service.clearRoutes);
  return service;
});
