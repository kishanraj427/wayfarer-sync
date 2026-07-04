class TripMember {
  final String id;
  final String userId;
  final String color;
  final String? email;

  const TripMember({
    required this.id,
    required this.userId,
    required this.color,
    this.email,
  });

  factory TripMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return TripMember(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      color: json['color'] as String? ?? '#3388ff',
      email: user?['email'] as String?,
    );
  }
}
