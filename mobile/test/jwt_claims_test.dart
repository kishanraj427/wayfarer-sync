import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/core/network/jwtClaims.dart';

String makeJwt(Map<String, dynamic> payload) {
  String seg(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg(payload)}.signature';
}

void main() {
  group('decodeJwtPayload', () {
    test('reads userId from a well-formed token', () {
      expect(userIdFromToken(makeJwt({'userId': 'u-1'})), 'u-1');
    });

    test('returns null for a malformed token instead of throwing', () {
      expect(decodeJwtPayload('not-a-jwt'), isNull);
      expect(decodeJwtPayload(''), isNull);
      expect(userIdFromToken('a.b'), isNull);
    });

    test('returns null when the payload is not valid base64/JSON', () {
      expect(decodeJwtPayload('aaa.!!!not-base64!!!.ccc'), isNull);
    });
  });

  group('expiry', () {
    test('expiryOf reads the exp claim as seconds since epoch', () {
      final exp = DateTime.now().add(const Duration(minutes: 30));
      final token = makeJwt({'userId': 'u', 'exp': exp.millisecondsSinceEpoch ~/ 1000});
      expect(expiryOf(token)!.difference(exp).inSeconds.abs(), lessThan(2));
    });

    test('isExpiringWithin is true when expiry is inside the window', () {
      final soon = DateTime.now().add(const Duration(minutes: 2));
      final token = makeJwt({'exp': soon.millisecondsSinceEpoch ~/ 1000});
      expect(isExpiringWithin(token, const Duration(minutes: 3)), isTrue);
    });

    test('isExpiringWithin is false when expiry is beyond the window', () {
      final later = DateTime.now().add(const Duration(minutes: 30));
      final token = makeJwt({'exp': later.millisecondsSinceEpoch ~/ 1000});
      expect(isExpiringWithin(token, const Duration(minutes: 3)), isFalse);
    });

    test('a token with no exp claim is treated as expiring (refresh it)', () {
      expect(isExpiringWithin(makeJwt({'userId': 'u'}), const Duration(minutes: 3)), isTrue);
    });
  });
}
