import 'package:flutter_riverpod/legacy.dart';
import 'package:latlong2/latlong.dart';

/// Tracks the absolute latest coordinate received for each user map key
class UserLiveMarkerState {
  final Map<String, LatLng> positions;
  UserLiveMarkerState(this.positions);
}

class MapStateNotifier extends StateNotifier<UserLiveMarkerState> {
  MapStateNotifier() : super(UserLiveMarkerState({}));

  /// Drops a fresh coordinate point into our active render state matrix
  void updateMemberPosition(String userId, LatLng position) {
    final updatedMap = Map<String, LatLng>.from(state.positions);
    updatedMap[userId] = position;
    state = UserLiveMarkerState(updatedMap);
  }
}

final mapStateProvider = StateNotifierProvider<MapStateNotifier, UserLiveMarkerState>((ref) {
  return MapStateNotifier();
});