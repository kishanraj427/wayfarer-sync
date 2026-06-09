import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'localDatabase.g.dart';

// --- 1. Your Table Layouts ---

class LocalTrips extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalTripMembers extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get userId => text()();
  TextColumn get email => text()();
  TextColumn get color => text().withDefault(const Constant('#3388ff'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalPathPoints extends Table {
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get userId => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get accuracy => real().nullable()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// --- 2. Your Main Database Class ---
@DriftDatabase(tables: [LocalTrips, LocalTripMembers, LocalPathPoints])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection()); 

  @override
  int get schemaVersion => 1;

  Future<List<LocalPathPoint>> getUnsyncedPoints(String tripId) {
    return (select(localPathPoints)
          ..where((t) => t.tripId.equals(tripId) & t.isSynced.equals(false)))
        .get();
  }

  Future<void> markPointsAsSynced(List<String> pointIds) async {
    await (update(localPathPoints)..where((t) => t.id.isIn(pointIds)))
        .write(const LocalPathPointsCompanion(isSynced: Value(true)));
  }
}

// --- 3. The Global Connection Opener (MUST BE OUTSIDE THE CLASS) ---
QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    // Finds the safe app sandbox documents folder on iOS or Android
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'wayfarer_sync.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}