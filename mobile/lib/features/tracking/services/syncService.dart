import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wayfarer_sync_mobile/core/storage/storageProviders.dart';
import 'package:wayfarer_sync_mobile/features/tracking/repositories/pathRepository.dart';
import '../../../core/storage/localDatabase.dart';

class SyncService {
  final AppDatabase _db;
  final PathRepository _pathRepository;

  SyncService(this._db, this._pathRepository);

  /// Pulls pending local breadcrumbs and streams them straight up to your backend
  Future<void> synchronizeTripPaths(String tripId) async {
    try {
      // 1. Gather all local unsynced data points from SQLite
      final unsyncedPoints = await _db.getUnsyncedPoints(tripId);
      if (unsyncedPoints.isEmpty) return;

      // 2. Dispatch the array payload over HTTP to your Express batch route
      await _pathRepository.uploadOfflineBatch(tripId, unsyncedPoints);

      // 3. Flip the local status flags to true so your offline cache is now clean
      final pointIds = unsyncedPoints.map((pt) => pt.id).toList();
      await _db.markPointsAsSynced(pointIds);

      // ignore: avoid_print
      print('Sync successful: ${pointIds.length} points updated.');
    } catch (e) {
      // Log errors safely (e.g. if the user is still in a dead zone, it retries later)
      // ignore: avoid_print
      print('Sync cycle deferred: $e');
    }
  }

  /// Finds all unsynced points across all trips and synchronizes them
  Future<void> synchronizeAll() async {
    try {
      final unsyncedPoints = await (_db.select(_db.localPathPoints)
            ..where((t) => t.isSynced.equals(false)))
          .get();
      if (unsyncedPoints.isEmpty) return;

      final tripIds = unsyncedPoints.map((pt) => pt.tripId).toSet();
      for (final tripId in tripIds) {
        await synchronizeTripPaths(tripId);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Sync all deferral: $e');
    }
  }
}

// Global provider mapping for the service layer
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.read(databaseProvider);
  final pathRepo = ref.read(pathRepositoryProvider);
  return SyncService(db, pathRepo);
});
