import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/appConstants.dart';
import '../constants/appStrings.dart';
import 'apiUrl.dart';
import 'authSession.dart';
import 'authTokenProvider.dart';
import 'jwtClaims.dart';
import 'refreshCoordinator.dart';

/// Injectable so tests can supply a MockClient instead of real sockets.
final httpClientProvider = Provider<http.Client>((ref) => http.Client());

/// Header and body field names. Named so a rename is a compile error rather
/// than a silent contract break with the backend.
const String _contentTypeHeader = 'Content-Type';
const String _authorizationHeader = 'Authorization';
const String _clientVersionHeader = 'X-Client-Version';
const String _jsonContentType = 'application/json';
const String _bearerPrefix = 'Bearer ';
const String _successField = 'success';
const String _dataField = 'data';
const String _errorField = 'error';
const String _messageField = 'message';

const String _methodGet = 'GET';
const String _methodPost = 'POST';

const int _httpOk = 200;
const int _httpMultipleChoices = 300;
const int _httpUnauthorized = 401;
const int _httpTooManyRequests = 429;
const int _httpServerError = 500;

class ApiClient {
  final Ref _ref;
  final String baseUrl = ApiUrl.baseUrl;

  ApiClient(this._ref);

  http.Client get _client => _ref.read(httpClientProvider);

  Map<String, String> _headers() {
    final token = _ref.read(authSessionProvider).accessToken;
    return {
      _contentTypeHeader: _jsonContentType,
      _clientVersionHeader: AppConstants.clientVersion,
      if (token != null) _authorizationHeader: '$_bearerPrefix$token',
    };
  }

  /// Refreshes ahead of expiry so most requests never see a 401. Any outcome but
  /// success is swallowed — must never block the caller's request or end the session (R1).
  Future<void> _refreshIfNearExpiry() async {
    final session = _ref.read(authSessionProvider);

    // An install upgraded in place from the deployed release holds an access
    // token but no refresh token. Exchange it rather than logging them out.
    if (session.needsExchange) {
      await _ref.read(refreshCoordinatorProvider).exchange();
      return;
    }

    final token = session.accessToken;
    if (token == null) return;
    if (isExpiringWithin(token, AppConstants.proactiveRefreshWindow)) {
      await _ref.read(refreshCoordinatorProvider).refresh();
    }
  }

  Future<dynamic> get(String endpoint) => _send(_methodGet, endpoint, null);

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) =>
      _send(_methodPost, endpoint, body);

  Future<dynamic> _send(
    String method,
    String endpoint,
    Map<String, dynamic>? body,
  ) async {
    await _refreshIfNearExpiry();

    var response = await _raw(method, endpoint, body);

    // Retry at most once, never for /refresh itself (would recurse); only a
    // successful refresh justifies retrying.
    if (response.statusCode == _httpUnauthorized && endpoint != ApiUrl.refresh) {
      final outcome = await _ref.read(refreshCoordinatorProvider).refresh();
      if (outcome == RefreshOutcome.success) {
        response = await _raw(method, endpoint, body);
      }
    }

    return _handleResponse(response);
  }

  Future<http.Response> _raw(
    String method,
    String endpoint,
    Map<String, dynamic>? body,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final future = method == _methodGet
          ? _client.get(uri, headers: _headers())
          : _client.post(
              uri,
              headers: _headers(),
              body: jsonEncode(body ?? const <String, dynamic>{}),
            );
      return await future.timeout(AppConstants.requestTimeout);
    } catch (error) {
      throw _asFriendlyException(error);
    }
  }

  /// Auth responses are FLAT and rely on the `data`-absent fallback below —
  /// must never gain a top-level `data` key.
  dynamic _handleResponse(http.Response response) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      // Body isn't JSON — typically an HTML gateway/error page from the host.
      throw ApiException(
        response.statusCode >= _httpServerError
            ? AppStrings.serverError
            : AppStrings.unknownError,
        response.statusCode,
      );
    }

    final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode >= _httpOk &&
        response.statusCode < _httpMultipleChoices) {
      if (body[_successField] == true) {
        return body.containsKey(_dataField) ? body[_dataField] : body;
      }
    }

    // The server's `error` text is developer-facing, so it is kept for logs
    // only and never shown. The user sees copy chosen by status code (R4).
    throw ApiException(
      AppStrings.messageForStatus(response.statusCode),
      response.statusCode,
      debugMessage: body[_errorField] as String? ?? body[_messageField] as String?,
    );
  }

  /// Maps transport-level failures to a user-facing [ApiException] so screens
  /// never surface raw SocketException / ClientException dumps (R4).
  ApiException _asFriendlyException(Object error) {
    if (error is ApiException) return error;
    if (error is SocketException || error is http.ClientException) {
      return ApiException(AppStrings.networkError, AppConstants.noResponseStatus);
    }
    if (error is TimeoutException) {
      return ApiException(AppStrings.timeoutError, AppConstants.noResponseStatus);
    }
    return ApiException(AppStrings.unknownError, AppConstants.noResponseStatus);
  }
}

/// [message] is always user-ready copy from [AppStrings]. [debugMessage] holds
/// the server's raw text for logs — never render it, or `toString()`, to a user.
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? debugMessage;

  ApiException(this.message, this.statusCode, {this.debugMessage});

  @override
  String toString() =>
      'ApiException ($statusCode): $message${debugMessage == null ? '' : ' [$debugMessage]'}';
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref));
