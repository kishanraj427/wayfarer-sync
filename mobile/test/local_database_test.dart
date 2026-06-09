import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:wayfarer_sync_mobile/core/storage/localDatabase.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('Drift SQLite Local Database Tests', () {
    test('Can insert and retrieve unsynced path points for a specific trip', () async {
      final now = DateTime.now();

      // Insert unsynced point for trip 1
      await database.into(database.localPathPoints).insert(
        LocalPathPointsCompanion(
          id: const Value('pt-1'),
          tripId: const Value('trip-1'),
          userId: const Value('user-1'),
          latitude: const Value(37.7749),
          longitude: const Value(-122.4194),
          timestamp: Value(now),
          accuracy: const Value(5.0),
          isSynced: const Value(false),
        ),
      );

      // Insert synced point for trip 1
      await database.into(database.localPathPoints).insert(
        LocalPathPointsCompanion(
          id: const Value('pt-2'),
          tripId: const Value('trip-1'),
          userId: const Value('user-1'),
          latitude: const Value(37.7750),
          longitude: const Value(-122.4195),
          timestamp: Value(now),
          accuracy: const Value(4.0),
          isSynced: const Value(true),
        ),
      );

      // Insert unsynced point for a different trip (trip 2)
      await database.into(database.localPathPoints).insert(
        LocalPathPointsCompanion(
          id: const Value('pt-3'),
          tripId: const Value('trip-2'),
          userId: const Value('user-1'),
          latitude: const Value(34.0522),
          longitude: const Value(-118.2437),
          timestamp: Value(now),
          accuracy: const Value(3.0),
          isSynced: const Value(false),
        ),
      );

      // Verify we only get unsynced points for trip-1
      final unsyncedTrip1 = await database.getUnsyncedPoints('trip-1');
      expect(unsyncedTrip1.length, 1);
      expect(unsyncedTrip1.first.id, 'pt-1');
      expect(unsyncedTrip1.first.isSynced, false);

      // Verify we get unsynced points for trip-2
      final unsyncedTrip2 = await database.getUnsyncedPoints('trip-2');
      expect(unsyncedTrip2.length, 1);
      expect(unsyncedTrip2.first.id, 'pt-3');
    });

    test('Can mark points as synced', () async {
      final now = DateTime.now();

      await database.into(database.localPathPoints).insert(
        LocalPathPointsCompanion(
          id: const Value('pt-4'),
          tripId: const Value('trip-1'),
          userId: const Value('user-1'),
          latitude: const Value(37.7749),
          longitude: const Value(-122.4194),
          timestamp: Value(now),
          accuracy: const Value(5.0),
          isSynced: const Value(false),
        ),
      );

      // Verify it is unsynced initially
      var unsynced = await database.getUnsyncedPoints('trip-1');
      expect(unsynced.length, 1);
      expect(unsynced.first.id, 'pt-4');

      // Mark it as synced
      await database.markPointsAsSynced(['pt-4']);

      // Verify it is no longer returned as unsynced
      unsynced = await database.getUnsyncedPoints('trip-1');
      expect(unsynced.isEmpty, true);

      // Verify the status in the database is indeed synced
      final allPoints = await database.select(database.localPathPoints).get();
      expect(allPoints.first.id, 'pt-4');
      expect(allPoints.first.isSynced, true);
    });
  });
}
