import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/appConstants.dart';
import '../constants/appStrings.dart';
import 'authTokenProvider.dart';
import 'apiUrl.dart';

class ApiClient {
  final Ref _ref;
  final String baseUrl = ApiUrl.baseUrl;

  ApiClient(this._ref);

  /// Helper to generate headers automatically injected with JWT tokens
  Map<String, String> _getHeaders() {
    final token = _ref.read(authTokenProvider);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Handles payload unpacking and throws human-readable exceptions matching your apiErrorSchema
  dynamic _handleResponse(http.Response response) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      // Body isn't JSON — typically an HTML gateway/error page from the host.
      throw ApiException(
        response.statusCode >= 500 ? AppStrings.serverError : AppStrings.unknownError,
        response.statusCode,
      );
    }

    final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['success'] == true) {
        return body.containsKey('data') ? body['data'] : body;
      }
    }

    // Fallback error generation matching backend patterns
    final errorMessage = body['error'] ?? body['message'] ?? AppStrings.unknownError;
    throw ApiException(errorMessage, response.statusCode);
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$endpoint'), headers: _getHeaders())
          .timeout(AppConstants.requestTimeout);
      return _handleResponse(response);
    } catch (error) {
      throw _asFriendlyException(error);
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(AppConstants.requestTimeout);
      return _handleResponse(response);
    } catch (error) {
      throw _asFriendlyException(error);
    }
  }

  /// Maps transport-level failures to a user-facing [ApiException] so screens
  /// never surface raw SocketException / ClientException dumps.
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

/// Custom Exception wrapper to transport error context cleanly to UI layers
class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException ($statusCode): $message';
}

// Global provider exposure logic
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref);
});
