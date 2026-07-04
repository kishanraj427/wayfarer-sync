import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/network/apiUrl.dart';
import '../models/join_result.dart';
import '../models/trip.dart';

class TripRepository {
  final ApiClient _apiClient;
  TripRepository(this._apiClient);

  Future<List<Trip>> listMyTrips() async {
    final response = await _apiClient.get(ApiUrl.trips);
    final list = response as List<dynamic>;
    return list
        .map((trip) => Trip.fromJson(trip as Map<String, dynamic>))
        .toList();
  }

  Future<Trip> getTrip(String id) async {
    final response = await _apiClient.get(ApiUrl.tripDetails(id));
    return Trip.fromJson(response as Map<String, dynamic>);
  }

  Future<Trip> createTrip({
    required String title,
    required DateTime startedAt,
    required List<Map<String, dynamic>> destinations,
  }) async {
    final response = await _apiClient.post(ApiUrl.trips, {
      'title': title,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'destinations': destinations,
    });
    return Trip.fromJson(response as Map<String, dynamic>);
  }

  Future<JoinResult> joinTrip(String id) async {
    final response = await _apiClient.post(ApiUrl.joinTrip(id), {});
    return JoinResult.fromJson(response as Map<String, dynamic>);
  }

  Future<Trip> endTrip(String id) async {
    final response = await _apiClient.post(ApiUrl.endTrip(id), {});
    return Trip.fromJson(response as Map<String, dynamic>);
  }
}

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.read(apiClientProvider));
});
