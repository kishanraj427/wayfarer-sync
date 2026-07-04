import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/join_result.dart';
import '../models/trip.dart';
import '../repositories/trip_repository.dart';

class TripsNotifier extends AsyncNotifier<List<Trip>> {
  @override
  Future<List<Trip>> build() {
    return ref.read(tripRepositoryProvider).listMyTrips();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(tripRepositoryProvider).listMyTrips(),
    );
  }

  Future<JoinResult> join(String tripId) async {
    final result = await ref.read(tripRepositoryProvider).joinTrip(tripId);
    if (!result.alreadyMember) {
      await refresh();
    }
    return result;
  }

  Future<void> endTrip(String tripId) async {
    await ref.read(tripRepositoryProvider).endTrip(tripId);
    await refresh();
  }
}

final tripsProvider =
    AsyncNotifierProvider<TripsNotifier, List<Trip>>(TripsNotifier.new);
