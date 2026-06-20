class DailyStats {
  final String date;
  final double totalCalories;
  final int totalDurationSeconds;
  final int totalReps;
  final int workoutCount;
  final double avgPostureScore;

  DailyStats({
    required this.date,
    required this.totalCalories,
    required this.totalDurationSeconds,
    required this.totalReps,
    required this.workoutCount,
    required this.avgPostureScore,
  });

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      date: json['date'] ?? '',
      totalCalories: (json['totalCalories'] ?? 0.0).toDouble(),
      totalDurationSeconds: json['totalDurationSeconds'] ?? 0,
      totalReps: json['totalReps'] ?? 0,
      workoutCount: json['workoutCount'] ?? 0,
      avgPostureScore: (json['avgPostureScore'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'totalCalories': totalCalories,
      'totalDurationSeconds': totalDurationSeconds,
      'totalReps': totalReps,
      'workoutCount': workoutCount,
      'avgPostureScore': avgPostureScore,
    };
  }
}
