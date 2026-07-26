import 'dart:convert';

/// Number of dot-separated segments in a JWT (header.payload.signature).
const int _jwtSegmentCount = 3;

/// Claim key holding the subject's user id.
const String _claimUserId = 'userId';

/// Claim key holding the expiry timestamp (seconds since epoch).
const String _claimExp = 'exp';

/// Decodes a JWT payload WITHOUT verifying its signature; for local scheduling
/// decisions only. The server is the sole authority on validity.
Map<String, dynamic>? decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != _jwtSegmentCount) return null;
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final payload = jsonDecode(decoded);
    return payload is Map<String, dynamic> ? payload : null;
  } catch (_) {
    return null;
  }
}

String? userIdFromToken(String token) => decodeJwtPayload(token)?[_claimUserId] as String?;

DateTime? expiryOf(String token) {
  final exp = decodeJwtPayload(token)?[_claimExp];
  if (exp is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
}

/// A token with no readable `exp` is treated as already expiring, so the
/// caller refreshes rather than assuming validity.
bool isExpiringWithin(String token, Duration window) {
  final expiry = expiryOf(token);
  if (expiry == null) return true;
  return expiry.isBefore(DateTime.now().add(window));
}
