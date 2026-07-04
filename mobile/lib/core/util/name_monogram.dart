/// Derives a 1–2 char avatar label. The backend stores no profile picture, so
/// avatars are always a monogram: first + last initials, with an email fallback
/// for legacy accounts created before names existed.
String nameMonogram({String? firstName, String? lastName, required String email}) {
  final first = (firstName ?? '').trim();
  final last = (lastName ?? '').trim();
  if (first.isNotEmpty && last.isNotEmpty) {
    return (first[0] + last[0]).toUpperCase();
  }
  if (first.isNotEmpty) return first[0].toUpperCase();
  if (last.isNotEmpty) return last[0].toUpperCase();
  return _emailMonogram(email);
}

String _emailMonogram(String email) {
  final local = email.split('@').first.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (local.isEmpty) return '?';
  if (local.length == 1) return local.toUpperCase();
  return (local[0] + local[local.length ~/ 2]).toUpperCase();
}
