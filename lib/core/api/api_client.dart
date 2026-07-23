// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../security/session_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required SessionStorage sessionStorage,
    http.Client? httpClient,
    String? baseUrl,
  }) : _sessionStorage = sessionStorage,
       _httpClient = httpClient ?? http.Client(),
       _baseUrl = Uri.parse(baseUrl ?? AppConfig.apiBaseUrl);

  final SessionStorage _sessionStorage;
  final http.Client _httpClient;
  final Uri _baseUrl;
  bool _refreshing = false;
  static const _timeout = Duration(seconds: 20);
  static const _connectionMessage =
      'Die Verbindung zum Server konnte nicht hergestellt werden. '
      'Prüfe deine Internetverbindung und versuche es erneut.';

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

  Future<dynamic> uploadFile(
    String path, {
    required String field,
    required String fileName,
    required Uint8List bytes,
  }) {
    return _uploadFile(path, field: field, fileName: fileName, bytes: bytes);
  }

  Future<Uint8List> getBytes(String path) => _getBytes(path);

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool retryOnUnauthorized = true,
  }) async {
    try {
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

      final streamed = await _httpClient.send(request).timeout(_timeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(_timeout);

      if (response.statusCode == 401 &&
          retryOnUnauthorized &&
          await _refreshAccessToken()) {
        return _send(
          method,
          path,
          body: body,
          query: query,
          retryOnUnauthorized: false,
        );
      }
      return _decodeJsonResponse(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(_connectionMessage);
    }
  }

  Future<dynamic> _uploadFile(
    String path, {
    required String field,
    required String fileName,
    required Uint8List bytes,
    bool retryOnUnauthorized = true,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      final accessToken = await _sessionStorage.accessToken();
      request.headers.addAll({
        'Accept': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      });
      request.files.add(
        http.MultipartFile.fromBytes(field, bytes, filename: fileName),
      );
      final response = await http.Response.fromStream(
        await _httpClient.send(request).timeout(_timeout),
      ).timeout(_timeout);
      if (response.statusCode == 401 &&
          retryOnUnauthorized &&
          await _refreshAccessToken()) {
        return _uploadFile(
          path,
          field: field,
          fileName: fileName,
          bytes: bytes,
          retryOnUnauthorized: false,
        );
      }
      return _decodeJsonResponse(response);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(_connectionMessage);
    }
  }

  Future<Uint8List> _getBytes(
    String path, {
    bool retryOnUnauthorized = true,
  }) async {
    try {
      final accessToken = await _sessionStorage.accessToken();
      final response = await _httpClient
          .get(
            _uri(path),
            headers: {
              'Accept': '*/*',
              if (accessToken != null) 'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(_timeout);
      if (response.statusCode == 401 &&
          retryOnUnauthorized &&
          await _refreshAccessToken()) {
        return _getBytes(path, retryOnUnauthorized: false);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _decodeJsonResponse(response);
      }
      return response.bodyBytes;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(_connectionMessage);
    }
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    return _baseUrl.replace(
      path: '${_baseUrl.path.replaceAll(RegExp(r'/$'), '')}/$path',
      queryParameters: query,
    );
  }

  dynamic _decodeJsonResponse(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final candidate = decoded is Map<String, dynamic>
          ? decoded['message'] ?? decoded['error']
          : null;
      final message = candidate is String && candidate.trim().isNotEmpty
          ? candidate
          : 'Die Anfrage konnte nicht verarbeitet werden.';
      throw ApiException(message, statusCode: response.statusCode);
    }
    if (response.body.isNotEmpty && decoded == null) {
      throw ApiException(
        'Der Dienst hat eine ungültige Antwort gesendet.',
        statusCode: response.statusCode,
      );
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
      final uri = _baseUrl.replace(
        path: '${_baseUrl.path.replaceAll(RegExp(r'/$'), '')}/auth/refresh',
      );
      final response = await _httpClient
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(_timeout);
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
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }
}
