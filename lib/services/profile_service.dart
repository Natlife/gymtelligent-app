import 'dart:convert';
import 'api_client.dart';

class ProfileService {
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final response = await ApiClient.get('/users/me/profile');
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        return data['data'];
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> updateProfile({
    double? weightKg,
    double? heightCm,
    int? age,
    String? gender,
    String? fitnessGoal,
    String? fitnessLevel,
    String? avatarUrl,
  }) async {
    try {
      final Map<String, dynamic> body = {};
      if (weightKg != null) body['weightKg'] = weightKg;
      if (heightCm != null) body['heightCm'] = heightCm;
      if (age != null) body['age'] = age;
      if (gender != null) body['gender'] = gender.toUpperCase();
      if (fitnessGoal != null) body['fitnessGoal'] = fitnessGoal.toUpperCase();
      if (fitnessLevel != null) body['fitnessLevel'] = fitnessLevel.toUpperCase();
      if (avatarUrl != null) body['avatarUrl'] = avatarUrl;

      final response = await ApiClient.put('/users/me/profile', body);
      final Map<String, dynamic> data = jsonDecode(response.body);
      return response.statusCode == 200 && data['code'] == 1000;
    } catch (_) {}
    return false;
  }
}
