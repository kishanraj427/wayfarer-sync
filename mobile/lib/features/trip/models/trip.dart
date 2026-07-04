import 'destination.dart';
import 'trip_member.dart';

class Trip {
  final String id;
  final String title;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<Destination> destinations;
  final List<TripMember> members;
  final int memberCount;

  const Trip({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.endedAt,
    required this.destinations,
    required this.members,
    required this.memberCount,
  });

  bool get isActive => endedAt == null;
  Destination? get primaryDestination =>
      destinations.isEmpty ? null : destinations.first;

  factory Trip.fromJson(Map<String, dynamic> json) {
    final destinations = (json['destinations'] as List<dynamic>? ?? [])
        .map((dest) => Destination.fromJson(dest as Map<String, dynamic>))
        .toList();
    final members = (json['members'] as List<dynamic>? ?? [])
        .map((member) => TripMember.fromJson(member as Map<String, dynamic>))
        .toList();
    final count = (json['_count'] as Map<String, dynamic>?)?['members'] as num?;

    return Trip(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Unnamed trip',
      startedAt: _parseDate(json['startedAt']),
      endedAt: _parseDate(json['endedAt']),
      destinations: destinations,
      members: members,
      memberCount: count?.toInt() ?? members.length,
    );
  }
}

DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value as String);
