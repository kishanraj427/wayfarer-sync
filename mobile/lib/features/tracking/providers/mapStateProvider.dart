import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/appConstants.dart';

/// Maximum number of coordinates retained per user trail to bound memory.
const int maxTrailPoints = AppConstants.maxTrailPoints;

/// Splits a trail into continuous segments, starting a new segment wherever two
/// consecutive points are farther than [AppConstants.maxTrailSegmentMeters]
/// apart. This stops a stale or out-of-order fix (e.g. a leftover emulator
/// location in another country) from being drawn as a straight "teleport" line
/// across the map; such an outlier ends up in its own tiny segment that is
/// dropped by the caller's minimum-length check.
List<List<LatLng>> listTrailSegments(List<LatLng> trail) {
  if (trail.length < 2) return [trail];

  const distance = Distance();
  final segmentList = <List<LatLng>>[];
  var currentSegment = <LatLng>[trail.first];

  for (var index = 1; index < trail.length; index++) {
    final previousPoint = trail[index - 1];
    final point = trail[index];
    if (distance(previousPoint, point) > AppConstants.maxTrailSegmentMeters) {
      segmentList.add(currentSegment);
      currentSegment = <LatLng>[point];
    } else {
      currentSegment.add(point);
    }
  }
  segmentList.add(currentSegment);
  return segmentList;
}

/// Latest coordinate per user (for markers/centering) plus an ordered
/// coordinate history per user (for polylines).
class UserLiveMarkerState {
  final Map<String, LatLng> positions;
  final Map<String, List<LatLng>> trails;
  UserLiveMarkerState(this.positions, this.trails);
}

class MapStateNotifier extends StateNotifier<UserLiveMarkerState> {
  MapStateNotifier() : super(UserLiveMarkerState({}, {}));

  /// Records a fresh coordinate: updates the user's latest position and
  /// appends it to their ordered trail, dropping the oldest beyond the cap.
  void updateMemberPosition(String userId, LatLng position) {
    final updatedPositions = Map<String, LatLng>.from(state.positions);
    updatedPositions[userId] = position;

    final updatedTrails = Map<String, List<LatLng>>.from(state.trails);
    final existingTrail = updatedTrails[userId] ?? const <LatLng>[];
    final nextTrail = [...existingTrail, position];
    if (nextTrail.length > maxTrailPoints) {
      nextTrail.removeRange(0, nextTrail.length - maxTrailPoints);
    }
    updatedTrails[userId] = nextTrail;

    state = UserLiveMarkerState(updatedPositions, updatedTrails);
  }

  /// Seeds movement history fetched from the backend when the map opens.
  /// Only trails (the drawn path) are seeded — never positions — so the live
  /// marker and the "live members" top bar stay driven purely by fresh frames,
  /// while a member's earlier route is still visible. Skips any user whose
  /// trail live updates have already begun filling.
  void hydrateHistory(Map<String, List<LatLng>> historyByUser) {
    final updatedTrails = Map<String, List<LatLng>>.from(state.trails);

    historyByUser.forEach((userId, points) {
      if (points.isEmpty || updatedTrails.containsKey(userId)) return;

      final cappedTrail = points.length > maxTrailPoints
          ? points.sublist(points.length - maxTrailPoints)
          : List<LatLng>.from(points);
      updatedTrails[userId] = cappedTrail;
    });

    state = UserLiveMarkerState(state.positions, updatedTrails);
  }
}

final mapStateProvider = StateNotifierProvider<MapStateNotifier, UserLiveMarkerState>((ref) {
  return MapStateNotifier();
});
