import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/core/constants/appStrings.dart';
import 'package:wayfarer_sync_mobile/core/network/apiClient.dart';
import 'package:wayfarer_sync_mobile/features/auth/models/current_user.dart';

void main() {
  group('R4: no raw exception text ever reaches the user', () {
    test('failedToX helpers accept a message string and never leak a class name', () {
      final ex = ApiException(AppStrings.networkError, 0);
      final rendered = [
        AppStrings.failedToEndTrip(ex.message),
        AppStrings.failedToJoinTrip(ex.message),
        AppStrings.failedToStartTrip(ex.message),
        AppStrings.syncFailed(ex.message),
        AppStrings.couldNotGetLocation(ex.message),
      ];

      for (final text in rendered) {
        expect(text.contains('ApiException'), isFalse, reason: text);
        expect(text.contains('Exception'), isFalse, reason: text);
        expect(text.contains('(0)'), isFalse, reason: text);
      }
    });

    test('session and credential copy is present and distinct', () {
      expect(AppStrings.sessionExpiredBanner, isNotEmpty);
      expect(AppStrings.invalidCredentials, isNotEmpty);
      expect(AppStrings.sessionExpiredBanner, isNot(AppStrings.invalidCredentials));
    });
  });

  group('R4: the server never speaks to the user', () {
    // Every error string the backend can emit, harvested from backend/src.
    // None of these may ever appear on screen.
    const backendStrings = [
      'Invalid or expired refresh token',
      'Invalid or expired credentials',
      'Invalid token',
      'No token provided',
      'Not authenticated',
      'Invalid credentials',
      'tripId must be a valid UUID',
      'Trip ID must be a valid UUID',
      'Trip not found',
      'User not found',
      'Validation failed',
      'Internal server error',
      'Already exists',
      'Not found',
    ];

    test('messageForStatus never returns backend wording', () {
      const statuses = [0, 400, 401, 403, 404, 409, 422, 429, 500, 502, 503, 418];
      for (final status in statuses) {
        final copy = AppStrings.messageForStatus(status);
        expect(copy, isNotEmpty, reason: 'status $status');
        for (final raw in backendStrings) {
          expect(copy.contains(raw), isFalse, reason: '$status leaked "$raw"');
        }
      }
    });

    test('every mapped status produces copy that reads like a sentence', () {
      for (final status in [400, 401, 403, 404, 409, 429, 500]) {
        final copy = AppStrings.messageForStatus(status);
        // A real sentence, not a code or a field name.
        expect(copy.endsWith('.'), isTrue, reason: 'status $status: "$copy"');
        expect(copy.contains('_'), isFalse, reason: 'status $status: "$copy"');
        expect(RegExp(r'[A-Z]{3,}').hasMatch(copy), isFalse,
            reason: 'status $status looks like a code: "$copy"');
      }
    });

    test('ApiException keeps server text in debugMessage, out of message', () {
      final e = ApiException(
        AppStrings.messageForStatus(404),
        404,
        debugMessage: 'Trip not found',
      );
      expect(e.message, AppStrings.notFound);
      expect(e.message.contains('Trip not found'), isFalse);
      expect(e.debugMessage, 'Trip not found');
    });
  });

  group('L1: defensive parsing of server-controlled fields', () {
    test('CurrentUser.fromJson tolerates missing id and email', () {
      final user = CurrentUser.fromJson(const {});
      expect(user.id, '');
      expect(user.email, '');
    });

    test('CurrentUser.fromJson tolerates wrong types instead of throwing', () {
      final user = CurrentUser.fromJson(const {'id': 42, 'email': null});
      expect(user.id, '');
      expect(user.email, '');
    });

    test('CurrentUser.fromJson ignores unknown fields', () {
      final user = CurrentUser.fromJson(const {'id': 'u1', 'email': 'a@b.c', 'brandNew': 1});
      expect(user.id, 'u1');
    });
  });
}
