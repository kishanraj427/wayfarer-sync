import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';

/// Maximum number of coordinates retained per user trail to bound memory.
const int maxTrailPoints = 500;

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
}

final mapStateProvider = StateNotifierProvider<MapStateNotifier, UserLiveMarkerState>((ref) {
  return MapStateNotifier();
});
