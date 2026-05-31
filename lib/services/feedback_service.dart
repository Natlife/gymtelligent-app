import 'dart:convert';
import 'api_client.dart';

class FeedbackService {
  static Future<bool> submitFeedback({
    required String title,
    required String content,
  }) async {
    try {
      final response = await ApiClient.post('/feedbacks', {
        'title': title,
        'content': content,
      });
      final Map<String, dynamic> data = jsonDecode(response.body);
      return response.statusCode == 200 && data['code'] == 1000;
    } catch (_) {}
    return false;
  }

  static Future<List<Map<String, dynamic>>?> getAllFeedbacks() async {
    try {
      final response = await ApiClient.get('/feedbacks');
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        final List<dynamic> list = data['data'];
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (_) {}
    return null;
  }
}
