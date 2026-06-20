import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiClient {
  static String get baseUrl =>
      AppConfig.apiBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  static const Duration _timeout = Duration(seconds: 20);

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'auth_token';

  static Future<String?> getToken() async {
    try {
      final token = (await _storage.read(key: _tokenKey))?.trim();
      if (token == null || token.isEmpty) {
        return null;
      }
      return token;
    } catch (_) {
      await clearToken();
      return null;
    }
  }

  static Future<void> saveToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw ArgumentError('Cannot persist an empty auth token.');
    }
    await _storage.write(key: _tokenKey, value: normalizedToken);
  }

  static Future<void> clearToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.Response> get(String path) async {
    final url = _buildUri(path);
    final headers = await _headers();
    return http.get(url, headers: headers).timeout(_timeout);
  }

  static Future<http.Response> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = _buildUri(path);
    final headers = await _headers();
    return http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
  }

  static Future<http.Response> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = _buildUri(path);
    final headers = await _headers();
    return http
        .put(url, headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
  }

  static Future<http.Response> delete(String path) async {
    final url = _buildUri(path);
    final headers = await _headers();
    return http.delete(url, headers: headers).timeout(_timeout);
  }

  static Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath');
  }
}
