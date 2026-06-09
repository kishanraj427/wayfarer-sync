import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../../core/storage/localDatabase.dart';
import '../../../core/storage/storageProviders.dart';
import 'locationPermissionHandler.dart';
import 'trackingSocketService.dart';
import 'package:latlong2/latlong.dart';
import '../providers/mapStateProvider.dart';

class LocationTrackingService {
  final Ref _ref;
  StreamSubscription<Position>? _positionStreamSubscription;
  final _uuid = const Uuid();

  LocationTrackingService(this._ref);

  /// Starts listening to the hardware GPS sensor and streaming updates
  Future<void> startTracking(String tripId, String userId) async {
    // 1. Verify permissions before touching hardware
    final hasPermission = await LocationPermissionHandler.requestPermission();
    if (!hasPermission) {
      print("Location tracking aborted: Permissions missing.");
      return;
    }

    // 2. Configure hardware sensor tracking criteria
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, // Use high accuracy for real-time tracking
      distanceFilter: 10,              // Trigger an update only after moving 10 meters
    );

    // 3. Open the continuous hardware position wire
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      await _handleIncomingPosition(tripId, userId, position);
    });
  }

  /// Directs a fresh GPS point into both the local SQLite cache and the network pipe
  Future<void> _handleIncomingPosition(String tripId, String userId, Position position) async {
    final pointId = _uuid.v4();
    final timestamp = DateTime.now();

    // -- TARGET A: Write to local Drift SQLite Database --
    final db = _ref.read(databaseProvider);
    await db.into(db.localPathPoints).insert(
      LocalPathPointsCompanion(
        id: Value(pointId),
        tripId: Value(tripId),
        userId: Value(userId),
        latitude: Value(position.latitude),
        longitude: Value(position.longitude),
        timestamp: Value(timestamp),
        accuracy: Value(position.accuracy),
        isSynced: const Value(false), // Defaults to false, SyncService updates this later
      ),
    );

    // -- TARGET B: Pipe through Live WebSocket (If connected) --
    _ref.read(trackingSocketServiceProvider).sendLocationUpdate(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );

    // -- TARGET C: Update Local Map Render State --
    _ref.read(mapStateProvider.notifier).updateMemberPosition(
          userId,
          LatLng(position.latitude, position.longitude),
        );

    print('GPS breadcrumb captured local & socket: ${position.latitude}, ${position.longitude}');
  }

  /// Turn off hardware tracking to conserve battery when the run finishes
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }
}

final locationTrackingServiceProvider = Provider<LocationTrackingService>((ref) {
  return LocationTrackingService(ref);
});