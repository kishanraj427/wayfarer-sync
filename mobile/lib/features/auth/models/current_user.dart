class CurrentUser {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;

  const CurrentUser({required this.id, required this.email, this.firstName, this.lastName});

  String get displayName {
    final full = [firstName, lastName].where((part) => (part ?? '').trim().isNotEmpty).join(' ').trim();
    return full.isEmpty ? email : full;
  }

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as String,
        email: json['email'] as String,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'email': email, 'firstName': firstName, 'lastName': lastName};
}
