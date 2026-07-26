import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/core/constants/appStrings.dart';
import 'package:wayfarer_sync_mobile/features/tracking/services/locationPermissionHandler.dart';

void main() {
  group('location access is explained, not silent', () {
    const failures = [
      LocationAccess.serviceDisabled,
      LocationAccess.denied,
      LocationAccess.deniedForever,
    ];

    test('every failure has its own message', () {
      final messages = failures.map((a) => a.message).toList();
      for (final m in messages) {
        expect(m, isNotEmpty);
        expect(m.endsWith('.'), isTrue, reason: m);
      }
      // Distinct copy per cause — "location is off" and "permission blocked"
      // need different fixes, so they must not read the same.
      expect(messages.toSet().length, messages.length);
    });

    test('a disabled service opens location settings, a block opens app settings', () {
      expect(
        LocationAccess.serviceDisabled.actionLabel,
        AppStrings.turnOnLocation,
      );
      expect(LocationAccess.denied.actionLabel, AppStrings.openSettings);
      expect(LocationAccess.deniedForever.actionLabel, AppStrings.openSettings);
    });

    test('messages never leak API or enum wording', () {
      for (final access in failures) {
        final m = access.message;
        for (final leak in [
          'LocationPermission',
          'deniedForever',
          'Geolocator',
          'null',
        ]) {
          expect(m.contains(leak), isFalse, reason: '$access leaked "$leak"');
        }
      }
    });

    test('granted has no message to show', () {
      expect(LocationAccess.granted.message, isEmpty);
    });
  });
}
