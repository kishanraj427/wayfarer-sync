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

  static const String _idField = 'id';
  static const String _emailField = 'email';
  static const String _firstNameField = 'firstName';
  static const String _lastNameField = 'lastName';

  /// Defensive by construction (L1): every field is server-controlled, so a
  /// non-nullable cast (`json['id'] as String`) would throw the moment the
  /// backend adds, removes, or retypes a field. Missing/mistyped data
  /// degrades to an empty string / null instead of crashing the screen.
  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json[_idField] is String ? json[_idField] as String : '',
        email: json[_emailField] is String ? json[_emailField] as String : '',
        firstName: json[_firstNameField] is String ? json[_firstNameField] as String : null,
        lastName: json[_lastNameField] is String ? json[_lastNameField] as String : null,
      );

  Map<String, dynamic> toJson() => {
        _idField: id,
        _emailField: email,
        _firstNameField: firstName,
        _lastNameField: lastName,
      };
}
