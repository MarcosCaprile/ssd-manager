// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../security/session_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required SessionStorage sessionStorage,
    http.Client? httpClient,
    String? baseUrl,
  })  : _sessionStorage = sessionStorage,
        _httpClient = httpClient ?? http.Client(),
        _baseUrl = Uri.parse(baseUrl ?? AppConfig.apiBaseUrl);

  final SessionStorage _sessionStorage;
  final http.Client _httpClient;
  final Uri _baseUrl;
  bool _refreshing = false;

  Future<dynamic> get(String path, {Map<String, String>? query}) {
    return _send('GET', path, query: query);
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) {
    return _send('POST', path, body: body);
  }

  Future<dynamic> patch(String path, {Map<String, dynamic>? body}) {
    return _send('PATCH', path, body: body);
  }

  Future<dynamic> delete(String path, {Map<String, dynamic>? body}) {
    return _send('DELETE', path, body: body);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool retryOnUnauthorized = true,
  }) async {
    final uri = _baseUrl.replace(
      path: '${_baseUrl.path.replaceAll(RegExp(r'/$'), '')}/$path',
      queryParameters: query,
    );
    final accessToken = await _sessionStorage.accessToken();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };

    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 401 && retryOnUnauthorized && await _refreshAccessToken()) {
      return _send(method, path, body: body, query: query, retryOnUnauthorized: false);
    }

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? (decoded['message'] ?? decoded['error'] ?? 'Die Anfrage konnte nicht verarbeitet werden.')
              as String
          : 'Die Anfrage konnte nicht verarbeitet werden.';
      throw ApiException(message, statusCode: response.statusCode);
    }

    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      return decoded['data'];
    }
    return decoded;
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final refreshToken = await _sessionStorage.refreshToken();
      if (refreshToken == null) return false;
      final uri = _baseUrl.replace(path: '${_baseUrl.path.replaceAll(RegExp(r'/$'), '')}/auth/refresh');
      final response = await _httpClient.post(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (response.statusCode != 200) return false;
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'] as Map<String, dynamic>;
      final session = await _sessionStorage.read();
      if (session == null) return false;
      await _sessionStorage.save(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        user: session.user,
      );
      return true;
    } finally {
      _refreshing = false;
    }
  }
}
