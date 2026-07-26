import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer_sync_mobile/core/network/authSession.dart';
import 'package:wayfarer_sync_mobile/core/network/authTokenProvider.dart';
import 'package:wayfarer_sync_mobile/core/network/refreshCoordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AuthSessionNotifier seeded() =>
      AuthSessionNotifier(const AuthSession(accessToken: 'a1', refreshToken: 'r1'));

  RefreshCoordinator build(http.Client client, AuthSessionNotifier session) =>
      RefreshCoordinator(client, 'http://test', session);

  group('failure triage — only an explicit rejection ends a session (R1)', () {
    test('200 with tokens -> success, session renewed', () async {
      final session = seeded();
      final c = build(MockClient((_) async => http.Response(
          jsonEncode({'accessToken': 'a2', 'refreshToken': 'r2', 'success': true}), 200)), session);

      expect(await c.refresh(), RefreshOutcome.success);
      expect(session.state.accessToken, 'a2');
      expect(session.state.refreshToken, 'r2');
    });

    test('401 WITH code INVALID_REFRESH -> sessionDead, session cleared', () async {
      final session = seeded();
      final c = build(MockClient((_) async => http.Response(
          jsonEncode({'error': 'nope', 'code': 'INVALID_REFRESH'}), 401)), session);

      expect(await c.refresh(), RefreshOutcome.sessionDead);
      expect(session.state.isAuthenticated, isFalse);
      expect(session.consumeLogoutReason(), LogoutReason.sessionExpired);
    });

    test('401 WITHOUT the code -> retryLater, session KEPT', () async {
      final session = seeded();
      final c = build(MockClient((_) async => http.Response(jsonEncode({'error': 'nope'}), 401)), session);

      expect(await c.refresh(), RefreshOutcome.retryLater);
      expect(session.state.isAuthenticated, isTrue);
    });

    test('500 -> retryLater, session KEPT', () async {
      final session = seeded();
      final c = build(MockClient((_) async => http.Response('{}', 500)), session);
      expect(await c.refresh(), RefreshOutcome.retryLater);
      expect(session.state.isAuthenticated, isTrue);
    });

    test('404 (rolled-back backend) -> retryLater, session KEPT', () async {
      final session = seeded();
      final c = build(MockClient((_) async => http.Response('not found', 404)), session);
      expect(await c.refresh(), RefreshOutcome.retryLater);
      expect(session.state.isAuthenticated, isTrue);
    });

    test('ACCEPTANCE TEST: offline SocketException -> retryLater, still logged in', () async {
      final session = seeded();
      final c = build(MockClient((_) async => throw const SocketException('no network')), session);

      expect(await c.refresh(), RefreshOutcome.retryLater);
      expect(session.state.isAuthenticated, isTrue);
      expect(session.consumeLogoutReason(), isNull);
    });

    test('HTML gateway page -> retryLater, session KEPT', () async {
      final session = seeded();
      final c = build(MockClient((_) async => http.Response('<html>502</html>', 502)), session);
      expect(await c.refresh(), RefreshOutcome.retryLater);
      expect(session.state.isAuthenticated, isTrue);
    });

    test('no refresh token but an access token exists -> needsExchange, NOT sessionDead', () async {
      final session = AuthSessionNotifier(const AuthSession(accessToken: 'a1'));
      final c = build(MockClient((_) async => http.Response('{}', 200)), session);

      expect(await c.refresh(), RefreshOutcome.needsExchange);
      expect(session.state.isAuthenticated, isTrue);
    });

    test('no tokens at all -> sessionDead', () async {
      final session = AuthSessionNotifier(AuthSession.empty);
      final c = build(MockClient((_) async => http.Response('{}', 200)), session);
      expect(await c.refresh(), RefreshOutcome.sessionDead);
    });
  });

  group('single flight', () {
    test('5 concurrent refresh() calls make exactly ONE http request', () async {
      var calls = 0;
      final session = seeded();
      final c = build(MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response(jsonEncode({'accessToken': 'a2', 'refreshToken': 'r2'}), 200);
      }), session);

      final results = await Future.wait(List.generate(5, (_) => c.refresh()));
      expect(calls, 1);
      expect(results.every((r) => r == RefreshOutcome.success), isTrue);
    });

    test('a second refresh AFTER the first completes issues a new request', () async {
      var calls = 0;
      final session = seeded();
      final c = build(MockClient((_) async {
        calls++;
        return http.Response(jsonEncode({'accessToken': 'a2', 'refreshToken': 'r2'}), 200);
      }), session);

      await c.refresh();
      await c.refresh();
      expect(calls, 2);
    });
  });

  group('exchange', () {
    test('stores the new pair on success', () async {
      final session = AuthSessionNotifier(const AuthSession(accessToken: 'legacy'));
      final c = build(MockClient((_) async => http.Response(
          jsonEncode({'accessToken': 'a2', 'refreshToken': 'r2'}), 200)), session);

      expect(await c.exchange(), RefreshOutcome.success);
      expect(session.state.refreshToken, 'r2');
    });

    test('401 INVALID_REFRESH -> sessionDead, with a reason to show the user', () async {
      // The legacy token is this install's only credential, so a rejection means the session is truly over.
      final session = AuthSessionNotifier(const AuthSession(accessToken: 'legacy'));
      final c = build(
        MockClient((_) async => http.Response(
              jsonEncode({'error': 'nope', 'code': 'INVALID_REFRESH'}),
              401,
            )),
        session,
      );

      expect(await c.exchange(), RefreshOutcome.sessionDead);
      expect(session.state.isAuthenticated, isFalse);
      expect(session.consumeLogoutReason(), LogoutReason.sessionExpired);
    });

    test('401 WITHOUT the code -> retryLater, session KEPT', () async {
      final session = AuthSessionNotifier(const AuthSession(accessToken: 'legacy'));
      final c = build(
        MockClient((_) async => http.Response(jsonEncode({'error': 'nope'}), 401)),
        session,
      );

      expect(await c.exchange(), RefreshOutcome.retryLater);
      expect(session.state.isAuthenticated, isTrue);
    });

    test('offline exchange -> retryLater, session KEPT (R1)', () async {
      final session = AuthSessionNotifier(const AuthSession(accessToken: 'legacy'));
      final c = build(MockClient((_) async => throw const SocketException('offline')), session);

      expect(await c.exchange(), RefreshOutcome.retryLater);
      expect(session.state.isAuthenticated, isTrue);
    });
  });
}
