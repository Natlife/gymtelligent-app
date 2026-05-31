import 'exercise.dart';

class WorkoutSession {
  final int id;
  final Exercise exercise;
  final String sessionDate;
  final String? startedAt;
  final String? endedAt;
  final int durationSeconds;
  final int totalReps;
  final int totalSets;
  final double caloriesBurned;
  final double avgPostureScore;
  final String? aiFeedback;

  WorkoutSession({
    required this.id,
    required this.exercise,
    required this.sessionDate,
    this.startedAt,
    this.endedAt,
    required this.durationSeconds,
    required this.totalReps,
    required this.totalSets,
    required this.caloriesBurned,
    required this.avgPostureScore,
    this.aiFeedback,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] ?? 0,
      exercise: Exercise.fromJson(json['exercise']),
      sessionDate: json['sessionDate'] ?? '',
      startedAt: json['startedAt'],
      endedAt: json['endedAt'],
      durationSeconds: json['durationSeconds'] ?? 0,
      totalReps: json['totalReps'] ?? 0,
      totalSets: json['totalSets'] ?? 0,
      caloriesBurned: (json['caloriesBurned'] ?? 0.0).toDouble(),
      avgPostureScore: (json['avgPostureScore'] ?? 0.0).toDouble(),
      aiFeedback: json['aiFeedback'],
    );
  }
}
