import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wayfarer_sync_mobile/core/network/authTokenProvider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthTokenNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initializes with initialToken and state is set', () {
      final notifier = AuthTokenNotifier('initial-test-token');
      expect(notifier.state, 'initial-test-token');
      expect(notifier.isAuthenticated, true);
    });

    test('initializes with null and state is null', () {
      final notifier = AuthTokenNotifier(null);
      expect(notifier.state, null);
      expect(notifier.isAuthenticated, false);
    });

    test('setToken updates state and saves to SharedPreferences', () async {
      final notifier = AuthTokenNotifier(null);
      await notifier.setToken('new-token');
      expect(notifier.state, 'new-token');
      expect(notifier.isAuthenticated, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AuthTokenNotifier.tokenKey), 'new-token');
    });

    test('clearToken clears state and removes from SharedPreferences', () async {
      // Set initial values in SharedPreferences mock directly
      SharedPreferences.setMockInitialValues({AuthTokenNotifier.tokenKey: 'some-token'});
      
      final notifier = AuthTokenNotifier('some-token');
      await notifier.clearToken();
      expect(notifier.state, null);
      expect(notifier.isAuthenticated, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(AuthTokenNotifier.tokenKey), false);
    });
  });
}
