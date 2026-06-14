import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/apiUrl.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/storage/localDatabase.dart';

class PathRepository {
  final ApiClient _apiClient;

  PathRepository(this._apiClient);

  /// Pushes an array of offline locations straight to the backend batch sync endpoint.
  /// Maps properties explicitly to match your precise back-end `pathPointBatchSchema`.
  Future<int> uploadOfflineBatch(String tripId, List<LocalPathPoint> offlinePoints) async {
    if (offlinePoints.isEmpty) return 0;

    final payload = {
      'points': offlinePoints.map((pt) => {
        'latitude': pt.latitude,
        'longitude': pt.longitude,
        'timestamp': pt.timestamp.toUtc().toIso8601String(),
        if (pt.accuracy != null) 'accuracy': pt.accuracy,
      }).toList(),
    };

    // Calls POST /api/trip/:id/paths/batch
    final responseData = await _apiClient.post(ApiUrl.uploadBatch(tripId), payload);
    
    // Returns the count integer parsed out of your backend batchSuccessDataSchema
    return responseData['count'] as int;
  }
}

final pathRepositoryProvider = Provider<PathRepository>((ref) {
  final apiClient = ref.read(apiClientProvider);
  return PathRepository(apiClient);
});