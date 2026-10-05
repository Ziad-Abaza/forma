import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../storage/token_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final dynamic details;

  ApiException({
    required this.statusCode,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({super.message = 'Session expired or unauthorized'})
      : super(statusCode: 401);
}

class ApiClient {
  final String Function() getBaseUrl;
  final TokenStorage tokenStorage;
  final http.Client _httpClient;
  final void Function()? onSessionExpired;

  bool _isRefreshing = false;
  final List<Completer<String?>> _refreshQueue = [];

  ApiClient({
    required this.getBaseUrl,
    required this.tokenStorage,
    http.Client? httpClient,
    this.onSessionExpired,
  }) : _httpClient = httpClient ?? http.Client();

  String get baseUrl => getBaseUrl();

  Future<Map<String, String>> _buildHeaders({bool includeAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (includeAuth) {
      final token = await tokenStorage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters, bool requireAuth = true}) async {
    return _sendWithRetry(() async {
      final uri = _buildUri(path, queryParameters);
      final headers = await _buildHeaders(includeAuth: requireAuth);
      return await _httpClient.get(uri, headers: headers);
    }, requireAuth: requireAuth);
  }

  Future<dynamic> post(String path, {dynamic body, bool requireAuth = true}) async {
    return _sendWithRetry(() async {
      final uri = _buildUri(path);
      final headers = await _buildHeaders(includeAuth: requireAuth);
      final encoded = body != null ? jsonEncode(body) : null;
      return await _httpClient.post(uri, headers: headers, body: encoded);
    }, requireAuth: requireAuth);
  }

  Future<dynamic> put(String path, {dynamic body, bool requireAuth = true}) async {
    return _sendWithRetry(() async {
      final uri = _buildUri(path);
      final headers = await _buildHeaders(includeAuth: requireAuth);
      final encoded = body != null ? jsonEncode(body) : null;
      return await _httpClient.put(uri, headers: headers, body: encoded);
    }, requireAuth: requireAuth);
  }

  Future<dynamic> patch(String path, {dynamic body, bool requireAuth = true}) async {
    return _sendWithRetry(() async {
      final uri = _buildUri(path);
      final headers = await _buildHeaders(includeAuth: requireAuth);
      final encoded = body != null ? jsonEncode(body) : null;
      return await _httpClient.patch(uri, headers: headers, body: encoded);
    }, requireAuth: requireAuth);
  }

  Future<dynamic> delete(String path, {bool requireAuth = true}) async {
    return _sendWithRetry(() async {
      final uri = _buildUri(path);
      final headers = await _buildHeaders(includeAuth: requireAuth);
      return await _httpClient.delete(uri, headers: headers);
    }, requireAuth: requireAuth);
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final fullUrl = '$cleanBase$cleanPath';

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final stringParams = queryParameters.map((k, v) => MapEntry(k, v.toString()));
      return Uri.parse(fullUrl).replace(queryParameters: stringParams);
    }
    return Uri.parse(fullUrl);
  }

  Future<dynamic> _sendWithRetry(
    Future<http.Response> Function() requestFn, {
    required bool requireAuth,
  }) async {
    http.Response response;
    try {
      response = await requestFn().timeout(const Duration(seconds: 15));
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 0, message: 'Network connection failed: $e');
    }

    // Automatic token refresh on 401
    if (response.statusCode == 401 && requireAuth) {
      final refreshedToken = await _attemptTokenRefresh();
      if (refreshedToken != null) {
        // Retry the original request with refreshed token
        try {
          response = await requestFn().timeout(const Duration(seconds: 15));
        } catch (e) {
          throw ApiException(statusCode: 0, message: 'Network connection failed on retry: $e');
        }
      } else {
        await tokenStorage.clearAll();
        onSessionExpired?.call();
        throw UnauthorizedException();
      }
    }

    return _handleResponse(response);
  }

  Future<String?> _attemptTokenRefresh() async {
    if (_isRefreshing) {
      final completer = Completer<String?>();
      _refreshQueue.add(completer);
      return completer.future;
    }

    _isRefreshing = true;
    try {
      final refreshToken = await tokenStorage.getRefreshToken();
      if (refreshToken == null) {
        _notifyQueue(null);
        return null;
      }

      final uri = _buildUri('/api/v1/auth/refresh');
      final resp = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final newAccess = data['tokens']['accessToken'] as String;
        final newRefresh = data['tokens']['refreshToken'] as String;
        final userId = data['user']?['id'] as String?;
        final email = data['user']?['email'] as String?;

        await tokenStorage.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
          userId: userId,
          email: email,
        );

        _notifyQueue(newAccess);
        return newAccess;
      } else {
        _notifyQueue(null);
        return null;
      }
    } catch (err) {
      debugPrint('[ApiClient] Token refresh failed: $err');
      _notifyQueue(null);
      return null;
    } finally {
      _isRefreshing = false;
    }
  }

  void _notifyQueue(String? token) {
    for (final completer in _refreshQueue) {
      if (!completer.isCompleted) completer.complete(token);
    }
    _refreshQueue.clear();
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = (decoded is Map && decoded['error'] != null)
        ? decoded['error'].toString()
        : 'HTTP Error ${response.statusCode}';

    if (response.statusCode == 401) {
      throw UnauthorizedException(message: message);
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
      details: decoded,
    );
  }
}
