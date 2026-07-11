import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  final http.Client _client = http.Client();
  String? _authToken;

  // Callback for handling 401 unauthorized responses (session expired)
  VoidCallback? _onUnauthorized;

  // Initialize auth token from storage
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _authToken = prefs.getString('auth_token');
    } catch (e) {
      debugPrint('Error initializing HttpService: $e');
    }
  }

  // Set auth token and store login timestamp
  Future<void> setAuthToken(String? token) async {
    _authToken = token;
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      // Store login timestamp for session expiration tracking (7 days)
      await prefs.setInt(
        'auth_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_timestamp');
    }
  }

  // Get auth token
  String? get authToken => _authToken;

  // Set callback for 401 unauthorized (auto-logout)
  void setOnUnauthorized(VoidCallback? callback) {
    _onUnauthorized = callback;
  }

  // Check response for 401 and handle auto-logout
  http.Response _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      debugPrint(
        '🔒 401 Unauthorized - Session expired, triggering auto-logout',
      );
      // Clear token immediately
      _authToken = null;
      // Trigger the unauthorized callback (will navigate to login)
      if (_onUnauthorized != null) {
        debugPrint('🔒 Calling onUnauthorized callback');
        _onUnauthorized!.call();
      } else {
        debugPrint('🔒 WARNING: onUnauthorized callback is null!');
      }
    }
    return response;
  }

  // Build headers
  Map<String, String> _buildHeaders({Map<String, String>? additionalHeaders}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    return headers;
  }

  // Build full URL
  String _buildUrl(String endpoint, {Map<String, String>? queryParams}) {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams).toString();
    }
    return uri.toString();
  }

  // GET request
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    try {
      final url = _buildUrl(endpoint, queryParams: queryParams);
      final response = await _client.get(
        Uri.parse(url),
        headers: _buildHeaders(additionalHeaders: headers),
      );

      if (kDebugMode) {
        debugPrint('GET $url');
        debugPrint('Status: ${response.statusCode}');
      }

      return _handleResponse(response);
    } catch (e) {
      debugPrint('GET request error: $e');
      rethrow;
    }
  }

  // POST request
  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    try {
      final url = _buildUrl(endpoint, queryParams: queryParams);
      final response = await _client.post(
        Uri.parse(url),
        headers: _buildHeaders(additionalHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      );

      if (kDebugMode) {
        debugPrint('POST $url');
        debugPrint('Status: ${response.statusCode}');
      }

      return _handleResponse(response);
    } catch (e) {
      debugPrint('POST request error: $e');
      rethrow;
    }
  }

  // PUT request
  Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    try {
      final url = _buildUrl(endpoint, queryParams: queryParams);
      final response = await _client.put(
        Uri.parse(url),
        headers: _buildHeaders(additionalHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      );

      if (kDebugMode) {
        debugPrint('PUT $url');
        debugPrint('Status: ${response.statusCode}');
      }

      return _handleResponse(response);
    } catch (e) {
      debugPrint('PUT request error: $e');
      rethrow;
    }
  }

  // PATCH request
  Future<http.Response> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    try {
      final url = _buildUrl(endpoint, queryParams: queryParams);
      final response = await _client.patch(
        Uri.parse(url),
        headers: _buildHeaders(additionalHeaders: headers),
        body: body != null ? jsonEncode(body) : null,
      );

      if (kDebugMode) {
        debugPrint('PATCH $url');
        debugPrint('Status: ${response.statusCode}');
      }

      return _handleResponse(response);
    } catch (e) {
      debugPrint('PATCH request error: $e');
      rethrow;
    }
  }

  // DELETE request
  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
  }) async {
    try {
      final url = _buildUrl(endpoint, queryParams: queryParams);
      final response = await _client.delete(
        Uri.parse(url),
        headers: _buildHeaders(additionalHeaders: headers),
      );

      if (kDebugMode) {
        debugPrint('DELETE $url');
        debugPrint('Status: ${response.statusCode}');
      }

      return _handleResponse(response);
    } catch (e) {
      debugPrint('DELETE request error: $e');
      rethrow;
    }
  }

  // Dispose
  void dispose() {
    _client.close();
  }
}
