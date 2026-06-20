import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'api_client.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      final response = await ApiClient.post('/auth/login', {
        'username': username,
        'password': password,
      });

      final data = _decodeApiResponse(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        final token = data['data']['token'];
        await ApiClient.saveToken(token);
        return {'success': true, 'message': 'Success'};
      }

      
      if (data['data'] is Map) {
        final Map<String, dynamic> errors = data['data'];
        if (errors.isNotEmpty) {
          final List<String> errorList = [];
          errors.forEach((key, val) {
            errorList.add('$val');
          });
          return {'success': false, 'message': errorList.join('\n')};
        }
      }

      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      debugPrint('AuthService.login error: $e');
      return {'success': false, 'message': _formatAuthError(e)};
    }
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String email,
    required String fullName,
    double? weightKg,
    double? heightCm,
    int? age,
    String? gender,
    String? fitnessGoal,
    String? fitnessLevel,
  }) async {
    try {
      final response = await ApiClient.post('/auth/register', {
        'username': username,
        'password': password,
        'email': email,
        'fullName': fullName,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'age': age,
        'gender': gender,
        'fitnessGoal': fitnessGoal,
        'fitnessLevel': fitnessLevel,
      });
      final data = _decodeApiResponse(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        final token = data['data']['token'];
        await ApiClient.saveToken(token);
        return {'success': true, 'message': 'Registration successful'};
      }

      
      if (data['data'] is Map) {
        final Map<String, dynamic> errors = data['data'];
        if (errors.isNotEmpty) {
          final List<String> errorList = [];
          errors.forEach((key, val) {
            errorList.add('$val');
          });
          return {'success': false, 'message': errorList.join('\n')};
        }
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed',
      };
    } catch (e) {
      debugPrint('AuthService.register error: $e');
      return {'success': false, 'message': _formatAuthError(e)};
    }
  }

  static Future<void> logout() async {
    await ApiClient.clearToken();
  }

  static Map<String, dynamic> _decodeApiResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('API response is not a JSON object');
  }

  static String _formatAuthError(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return 'Connection failed. Please check your internet and try again.';
    }

    if (error is FormatException) {
      return 'Server returned an invalid response. Please try again.';
    }

    return 'Something went wrong. Please try again.';
  }
}
