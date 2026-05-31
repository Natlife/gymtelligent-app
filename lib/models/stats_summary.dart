class StatsSummary {
  final int totalWorkouts;
  final double totalCalories;
  final int currentStreak;
  final int longestStreak;

  StatsSummary({
    required this.totalWorkouts,
    required this.totalCalories,
    required this.currentStreak,
    required this.longestStreak,
  });

  factory StatsSummary.fromJson(Map<String, dynamic> json) {
    return StatsSummary(
      totalWorkouts: json['totalWorkouts'] ?? 0,
      totalCalories: (json['totalCalories'] ?? 0.0).toDouble(),
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
    );
  }
}
