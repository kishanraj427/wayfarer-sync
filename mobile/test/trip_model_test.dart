import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/features/trip/models/trip.dart';
import 'package:wayfarer_sync_mobile/features/trip/models/join_result.dart';

void main() {
  test('Trip.fromJson parses nested data and derives active state', () {
    final trip = Trip.fromJson({
      'id': 't1',
      'title': 'Alpine',
      'startedAt': '2026-06-14T00:00:00.000Z',
      'endedAt': null,
      'destinations': [
        {'id': 'd1', 'name': 'Zermatt', 'latitude': 46, 'longitude': 7.7, 'order': 0},
      ],
      'members': [
        {'id': 'm1', 'userId': 'u1', 'color': '#ff0000', 'user': {'id': 'u1', 'email': 'alex@x.com'}},
      ],
      '_count': {'members': 3},
    });

    expect(trip.id, 't1');
    expect(trip.isActive, true);
    expect(trip.primaryDestination!.name, 'Zermatt');
    expect(trip.primaryDestination!.latitude, 46.0); // int coerced to double
    expect(trip.members.first.email, 'alex@x.com');
    expect(trip.memberCount, 3);
  });

  test('Trip.fromJson falls back memberCount and marks ended', () {
    final trip = Trip.fromJson({
      'id': 't2',
      'title': 'X',
      'endedAt': '2026-06-20T00:00:00.000Z',
      'destinations': [],
      'members': [
        {'id': 'm1', 'userId': 'u1', 'color': '#00ff00'},
      ],
    });

    expect(trip.isActive, false);
    expect(trip.memberCount, 1);
    expect(trip.primaryDestination, isNull);
    expect(trip.members.first.email, isNull);
  });

  test('JoinResult.fromJson reads the flag and nested member', () {
    final result = JoinResult.fromJson({
      'alreadyMember': true,
      'member': {'id': 'm1', 'userId': 'u1', 'color': '#123456'},
    });
    expect(result.alreadyMember, true);
    expect(result.member!.userId, 'u1');
  });
}
