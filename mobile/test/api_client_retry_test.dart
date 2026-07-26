import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer_sync_mobile/core/network/apiClient.dart';
import 'package:wayfarer_sync_mobile/core/network/authSession.dart';
import 'package:wayfarer_sync_mobile/core/network/authTokenProvider.dart';
import 'package:wayfarer_sync_mobile/core/network/refreshCoordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Separate transports for API calls vs. refresh, so a test can assert an exact API call count.
  ProviderContainer containerWith(
    http.Client apiTransport,
    http.Client refreshTransport,
  ) {
    return ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(
          (ref) => AuthSessionNotifier(
            const AuthSession(accessToken: 'a1', refreshToken: 'r1'),
          ),
        ),
        refreshCoordinatorProvider.overrideWith(
          (ref) => RefreshCoordinator(
            refreshTransport,
            'http://test',
            ref.read(authSessionProvider.notifier),
          ),
        ),
        httpClientProvider.overrideWithValue(apiTransport),
      ],
    );
  }

  test('a 401 triggers one refresh then one retry, and succeeds', () async {
    var apiCalls = 0;
    final api = MockClient((req) async {
      apiCalls++;
      if (apiCalls == 1) {
        return http.Response(jsonEncode({'error': 'expired'}), 401);
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'ok': true},
        }),
        200,
      );
    });
    final refresh = MockClient(
      (_) async => http.Response(
        jsonEncode({'accessToken': 'a2', 'refreshToken': 'r2'}),
        200,
      ),
    );

    final container = containerWith(api, refresh);
    addTearDown(container.dispose);
    final result = await container.read(apiClientProvider).get('/thing');

    expect(apiCalls, 2);
    expect(result['ok'], isTrue);
  });

  test('retries AT MOST once — a persistently 401ing endpoint does not loop',
      () async {
    var apiCalls = 0;
    final api = MockClient((_) async {
      apiCalls++;
      return http.Response(jsonEncode({'error': 'expired'}), 401);
    });
    final refresh = MockClient(
      (_) async => http.Response(
        jsonEncode({'accessToken': 'a2', 'refreshToken': 'r2'}),
        200,
      ),
    );

    final container = containerWith(api, refresh);
    addTearDown(container.dispose);
    await expectLater(
      container.read(apiClientProvider).get('/thing'),
      throwsA(isA<ApiException>()),
    );
    expect(apiCalls, 2);
  });

  test('a 401 whose refresh fails throws but KEEPS the session (R1)', () async {
    final api = MockClient(
      (_) async => http.Response(jsonEncode({'error': 'expired'}), 401),
    );
    // 500 on refresh is retryLater, never sessionDead.
    final refresh = MockClient((_) async => http.Response('{}', 500));

    final container = containerWith(api, refresh);
    addTearDown(container.dispose);
    await expectLater(
      container.read(apiClientProvider).get('/thing'),
      throwsA(isA<ApiException>()),
    );
    expect(container.read(authSessionProvider).isAuthenticated, isTrue);
  });

  test('sends the X-Client-Version header', () async {
    String? seen;
    final api = MockClient((req) async {
      seen = req.headers['X-Client-Version'];
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });
    final container = containerWith(
      api,
      MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(container.dispose);
    await container.read(apiClientProvider).get('/thing');

    expect(seen, isNotNull);
    expect(seen, isNotEmpty);
  });

  test('a 429 surfaces the friendly rate-limit copy, not a raw status', () async {
    final api = MockClient(
      (_) async => http.Response(jsonEncode({'error': 'slow down'}), 429),
    );
    final container = containerWith(
      api,
      MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(apiClientProvider).get('/thing'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('Too many'),
        ),
      ),
    );
  });
}
