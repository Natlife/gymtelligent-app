import 'dart:convert';
import 'api_client.dart';

class AuthService {
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await ApiClient.post('/auth/login', {
        'username': username,
        'password': password,
      });

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        final token = data['data']['token'];
        await ApiClient.saveToken(token);
        return {'success': true, 'message': 'Success'};
      }

      // Extract detailed validation error map if available
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
      return {'success': false, 'message': 'Network error: $e'};
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

      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        final token = data['data']['token'];
        await ApiClient.saveToken(token);
        return {'success': true, 'message': 'Registration successful'};
      }

      // Extract detailed validation error map if available
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

      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<void> logout() async {
    await ApiClient.clearToken();
  }
}
