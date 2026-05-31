import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/daily_stats.dart';
import '../models/stats_summary.dart';
import 'api_client.dart';

class StatsService {
  static Future<StatsSummary?> getSummary() async {
    try {
      final response = await ApiClient.get('/stats/summary');
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        return StatsSummary.fromJson(data['data']);
      }
    } catch (_) {}
    return null;
  }

  static Future<DailyStats?> getDailyStats(DateTime date) async {
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(date);
      final response = await ApiClient.get('/stats/daily?date=$formattedDate');
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        return DailyStats.fromJson(data['data']);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<DailyStats>> getWeeklyStats(DateTime weekStart) async {
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(weekStart);
      final response = await ApiClient.get('/stats/weekly?weekStart=$formattedDate');
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        final List<dynamic> list = data['data'];
        return list.map((e) => DailyStats.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }
}
