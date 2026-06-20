import 'dart:convert';
import '../models/exercise.dart';
import '../models/workout_session.dart';
import 'api_client.dart';

class WorkoutService {
  static Future<List<Exercise>> getExercises({String? category, String? level}) async {
    try {
      String query = '';
      if (category != null && level != null) {
        query = '?category=$category&level=$level';
      } else if (category != null) {
        query = '?category=$category';
      } else if (level != null) {
        query = '?level=$level';
      }

      final response = await ApiClient.get('/exercises$query');
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        final List<dynamic> list = data['data'];
        final parsed = list.map((e) => Exercise.fromJson(e)).toList();
        parsed.removeWhere((exercise) => exercise.name.toLowerCase().contains("push up"));
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    } catch (_) {}
    
    
    return [
      Exercise(
        id: 2,
        name: "Squats",
        category: "STRENGTH",
        difficultyLevel: "BEGINNER",
        metValue: 5.0,
        description: "An essential lower body movement focusing on quadriceps, hamstrings, and glutes. Great for functional strength, flexibility, and power.",
        muscleGroups: "quadriceps, hamstrings, glutes, core",
        instructions: ["Stand with feet shoulder-width apart, toes slightly outward", "Lower hips back and down as if sitting in a chair", "Keep your chest high and knees behind your toes", "Drive through your heels to return to standing position"],
        defaultSets: 4,
        defaultReps: 12,
      ),
      Exercise(
        id: 3,
        name: "Barbell Biceps Curl",
        category: "STRENGTH",
        difficultyLevel: "INTERMEDIATE",
        metValue: 4.5,
        description: "An isolated upper body exercise focusing specifically on the biceps brachii, helping build arm strength, muscle mass, and grip strength.",
        muscleGroups: "biceps, forearms, shoulders",
        instructions: ["Stand up straight holding a barbell with shoulder-width grip", "Keep elbows close to your torso, curl weights while contracting biceps", "Raise the bar until shoulder level, squeeze biceps at the top", "Slowly lower the barbell back to the starting position"],
        defaultSets: 3,
        defaultReps: 12,
      ),
      Exercise(
        id: 4,
        name: "Shoulder Press",
        category: "STRENGTH",
        difficultyLevel: "INTERMEDIATE",
        metValue: 5.0,
        description: "A powerhouse overhead pressing movement targeting the deltoids, triceps, and upper chest, essential for building shoulder strength and stability.",
        muscleGroups: "shoulders, triceps, upper chest, core",
        instructions: ["Hold the barbell or dumbbells at shoulder height with palms facing forward", "Keep your core tight and press the weight straight overhead", "Extend arms fully without locking elbows at the top", "Slowly lower the weight back to shoulder level under control"],
        defaultSets: 3,
        defaultReps: 12,
      ),
    ];
  }

  static Future<int?> startSession(int exerciseId) async {
    try {
      final response = await ApiClient.post('/workouts/start', {
        'exerciseId': exerciseId,
      });
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        return data['data']['id'];
      }
    } catch (_) {}
    return null;
  }

  static Future<WorkoutSession?> completeSession({
    required int sessionId,
    required int totalReps,
    required int totalSets,
    required int durationSeconds,
    required double avgPostureScore,
    String? aiFeedback,
    double? caloriesBurned,
  }) async {
    try {
      final response = await ApiClient.put('/workouts/$sessionId/complete', {
        'totalReps': totalReps,
        'totalSets': totalSets,
        'durationSeconds': durationSeconds,
        'avgPostureScore': avgPostureScore,
        'aiFeedback': aiFeedback ?? '',
        'caloriesBurned': caloriesBurned,
      });
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        return WorkoutSession.fromJson(data['data']);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<WorkoutSession>> getHistory({int page = 0, int size = 10}) async {
    try {
      final response = await ApiClient.get('/workouts/history?page=$page&size=$size');
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        final List<dynamic> list = data['data']['content'];
        return list.map((e) => WorkoutSession.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<dynamic>> getPersonalRecords() async {
    try {
      final response = await ApiClient.get('/workouts/records');
      final Map<String, dynamic> data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 1000) {
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }
}
