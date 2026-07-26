import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../constants/appConstants.dart';
import 'apiUrl.dart';
import 'authSession.dart';
import 'authTokenProvider.dart';

/// Wire-contract constants for /auth/refresh and /auth/exchange. These are
/// NOT app-internal choices — they must match the backend byte-for-byte.
class _RefreshWire {
  _RefreshWire._();

  static const String contentTypeHeader = 'Content-Type';
  static const String contentTypeJson = 'application/json';
  static const String authorizationHeader = 'Authorization';
  static const String bearerPrefix = 'Bearer ';

  static const String refreshTokenField = 'refreshToken';
  static const String accessTokenField = 'accessToken';
  static const String codeField = 'code';

  /// The one string that may end a session (R1). A wire contract with the
  /// backend — never change the value, only ever reference this constant.
  static const String invalidRefreshCode = 'INVALID_REFRESH';
}

/// Owns token renewal. R1: only an explicit server "refresh token invalid" ends
/// a session — everything else keeps the user logged in.
class RefreshCoordinator {
  final http.Client _client;
  final String _baseUrl;
  final AuthSessionNotifier _session;

  RefreshCoordinator(this._client, this._baseUrl, this._session);

  Future<RefreshOutcome>? _inFlight;

  /// Single-flight: concurrent callers share one request and one rotation.
  Future<RefreshOutcome> refresh() {
    return _inFlight ??= _perform().whenComplete(() => _inFlight = null);
  }

  Future<RefreshOutcome> _perform() async {
    final session = _session.session;

    if (session.refreshToken == null) {
      // An in-place upgrade from v1.0.4+5 lands here. Logging out would
      // violate R1 for the entire installed base.
      if (session.accessToken != null) return RefreshOutcome.needsExchange;

      // Nothing to clear — and clearing here would overwrite a pending
      // logout reason with sessionExpired, misleading a deliberate sign-out (R4).
      return RefreshOutcome.sessionDead;
    }

    return _post(
      ApiUrl.refresh,
      body: {_RefreshWire.refreshTokenField: session.refreshToken},
    );
  }

  /// One-shot upgrade for installs holding only a legacy access token.
  Future<RefreshOutcome> exchange() {
    final access = _session.session.accessToken;
    if (access == null) return Future.value(RefreshOutcome.sessionDead);
    return _post(
      ApiUrl.exchange,
      headers: {
        _RefreshWire.authorizationHeader: '${_RefreshWire.bearerPrefix}$access',
      },
    );
  }

  Future<RefreshOutcome> _post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: {
              _RefreshWire.contentTypeHeader: _RefreshWire.contentTypeJson,
              ...?headers,
            },
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(AppConstants.requestTimeout);
    } on SocketException {
      return RefreshOutcome.retryLater; // offline — never a logout
    } on TimeoutException {
      return RefreshOutcome.retryLater;
    } on http.ClientException {
      return RefreshOutcome.retryLater;
    } catch (_) {
      return RefreshOutcome.retryLater;
    }

    Map<String, dynamic> parsed = const {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) parsed = decoded;
    } catch (_) {
      // HTML gateway page or truncated body — transient, not an auth verdict.
    }

    if (response.statusCode == 200) {
      final access = parsed[_RefreshWire.accessTokenField] as String?;
      final refresh = parsed[_RefreshWire.refreshTokenField] as String?;
      if (access == null || refresh == null) return RefreshOutcome.retryLater;
      await _session.setTokens(accessToken: access, refreshToken: refresh);
      return RefreshOutcome.success;
    }

    // The ONLY session-ending condition. A bare 401 from a proxy or a
    // misconfigured gateway must never mass-log-out users.
    if (response.statusCode == 401 &&
        parsed[_RefreshWire.codeField] == _RefreshWire.invalidRefreshCode) {
      await _session.clear(reason: LogoutReason.sessionExpired);
      return RefreshOutcome.sessionDead;
    }

    return RefreshOutcome.retryLater;
  }
}

final refreshCoordinatorProvider = Provider<RefreshCoordinator>((ref) {
  return RefreshCoordinator(
    http.Client(),
    ApiUrl.baseUrl,
    ref.read(authSessionProvider.notifier),
  );
});
