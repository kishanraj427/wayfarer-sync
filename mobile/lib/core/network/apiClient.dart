import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'authTokenProvider.dart';

class ApiClient {
  final Ref _ref;
  final String baseUrl = 'http://localhost:3000/api';

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
    final Map<String, dynamic> body = jsonDecode(response.body);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['success'] == true) {
        return body.containsKey('data') ? body['data'] : body;
      }
    }
    
    // Fallback error generation matching backend patterns
    final errorMessage = body['error'] ?? body['message'] ?? 'An unknown network error occurred';
    throw ApiException(errorMessage, response.statusCode);
  }

  Future<dynamic> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
      );
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _getHeaders(),
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } catch (e) {
      rethrow;
    }
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