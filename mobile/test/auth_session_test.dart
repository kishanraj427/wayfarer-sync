import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer_sync_mobile/core/network/authSession.dart';
import 'package:wayfarer_sync_mobile/core/network/authTokenProvider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AuthSessionNotifier', () {
    test('persists both tokens under their own keys', () async {
      final n = AuthSessionNotifier(AuthSession.empty);
      await n.setTokens(accessToken: 'a1', refreshToken: 'r1');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AuthSessionNotifier.accessTokenKey), 'a1');
      expect(prefs.getString(AuthSessionNotifier.refreshTokenKey), 'r1');
      expect(n.state.isAuthenticated, isTrue);
    });

    test('an access token alone still counts as authenticated (offline cold start)', () {
      final n = AuthSessionNotifier(const AuthSession(accessToken: 'a1'));
      expect(n.state.isAuthenticated, isTrue);
      expect(n.state.needsExchange, isTrue);
    });

    test('clear removes both tokens and the cached user', () async {
      SharedPreferences.setMockInitialValues({
        AuthSessionNotifier.accessTokenKey: 'a1',
        AuthSessionNotifier.refreshTokenKey: 'r1',
        AuthSessionNotifier.currentUserPrefsKey: '{}',
      });
      final n = AuthSessionNotifier(const AuthSession(accessToken: 'a1', refreshToken: 'r1'));
      await n.clear(reason: LogoutReason.userInitiated);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AuthSessionNotifier.accessTokenKey), isNull);
      expect(prefs.getString(AuthSessionNotifier.refreshTokenKey), isNull);
      expect(prefs.getString(AuthSessionNotifier.currentUserPrefsKey), isNull);
      expect(n.state.isAuthenticated, isFalse);
    });

    test('logout reason is readable once, then cleared (banner shows a single time)', () async {
      final n = AuthSessionNotifier(const AuthSession(accessToken: 'a1'));
      await n.clear(reason: LogoutReason.sessionExpired);

      expect(n.consumeLogoutReason(), LogoutReason.sessionExpired);
      expect(n.consumeLogoutReason(), isNull);
    });

    test('setAccessToken updates only the access token', () async {
      final n = AuthSessionNotifier(const AuthSession(accessToken: 'a1', refreshToken: 'r1'));
      await n.setAccessToken('a2');
      expect(n.state.accessToken, 'a2');
      expect(n.state.refreshToken, 'r1');
    });
  });
}
