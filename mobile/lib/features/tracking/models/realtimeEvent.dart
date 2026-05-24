class MemberLocationUpdate {
  final String userId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;

  MemberLocationUpdate({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
  });

  factory MemberLocationUpdate.fromJson(Map<String, dynamic> json) {
    return MemberLocationUpdate(
      userId: json['userId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
    );
  }
}