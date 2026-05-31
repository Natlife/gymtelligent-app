import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class ApiClient {
  // Production Server URL - Change this to your deployed domain (e.g. https://api.gymtelligent.com/api/v1)
  static const String prodUrl = 'https://gymtelligent-api.example.com/api/v1';

  static String get baseUrl {
    if (kReleaseMode) {
      return prodUrl;
    }
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:5001/api/v1';
      }
    } catch (_) {}
    return 'http://localhost:5001/api/v1';
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.Response> get(String path) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    return http.get(url, headers: headers);
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    return http.post(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> put(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    return http.put(url, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> delete(String path) async {
    final url = Uri.parse('$baseUrl$path');
    final headers = await _headers();
    return http.delete(url, headers: headers);
  }
}
