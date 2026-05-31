import 'dart:convert';

class Exercise {
  final int id;
  final String name;
  final String category;
  final String difficultyLevel;
  final double metValue;
  final String description;
  final String muscleGroups;
  final String? imageUrl;
  final List<String> instructions;
  final int defaultSets;
  final int defaultReps;

  Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.difficultyLevel,
    required this.metValue,
    required this.description,
    required this.muscleGroups,
    this.imageUrl,
    required this.instructions,
    required this.defaultSets,
    required this.defaultReps,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    List<String> parsedInstructions = [];
    if (json['instructions'] != null) {
      try {
        final decoded = jsonDecode(json['instructions']);
        if (decoded is List) {
          parsedInstructions = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedInstructions = [json['instructions'].toString()];
      }
    }
    return Exercise(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      category: json['category'] ?? 'STRENGTH',
      difficultyLevel: json['difficultyLevel'] ?? 'BEGINNER',
      metValue: (json['metValue'] ?? 3.5).toDouble(),
      description: json['description'] ?? '',
      muscleGroups: json['muscleGroups'] ?? '',
      imageUrl: json['imageUrl'],
      instructions: parsedInstructions,
      defaultSets: json['defaultSets'] ?? 3,
      defaultReps: json['defaultReps'] ?? 12,
    );
  }
}
