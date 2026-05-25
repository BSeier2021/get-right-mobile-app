import 'package:get_right/models/exercise_set_model.dart';

/// Workout Exercise Model
/// Represents a single exercise in a workout (can be part of a superset)
class WorkoutExerciseModel {
  final String id;
  final String exerciseName;
  final String exerciseId; // Reference to exercise library
  final String? iconUrl; // Exercise icon from library / API
  final List<ExerciseSetModel> sets;
  final String? notes; // Exercise-level notes
  final bool isSuperset; // If true, this is part of a superset
  final String? supersetId; // ID of the superset group
  final int? supersetOrder; // Order within superset (0 or 1)
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;

  WorkoutExerciseModel({
    required this.id,
    required this.exerciseName,
    required this.exerciseId,
    this.iconUrl,
    required this.sets,
    this.notes,
    this.isSuperset = false,
    this.supersetId,
    this.supersetOrder,
    required this.date,
    required this.createdAt,
    this.updatedAt,
  });

  factory WorkoutExerciseModel.fromJson(Map<String, dynamic> json) {
    return WorkoutExerciseModel(
      id: json['id'] ?? '',
      exerciseName: json['exerciseName'] ?? '',
      exerciseId: json['exerciseId'] ?? '',
      iconUrl: json['iconUrl'],
      sets: (json['sets'] as List<dynamic>?)
              ?.map((set) => ExerciseSetModel.fromJson(set as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'],
      isSuperset: json['isSuperset'] ?? false,
      supersetId: json['supersetId'],
      supersetOrder: json['supersetOrder']?.toInt(),
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'exerciseId': exerciseId,
      'iconUrl': iconUrl,
      'sets': sets.map((set) => set.toJson()).toList(),
      'notes': notes,
      'isSuperset': isSuperset,
      'supersetId': supersetId,
      'supersetOrder': supersetOrder,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  WorkoutExerciseModel copyWith({
    String? id,
    String? exerciseName,
    String? exerciseId,
    String? iconUrl,
    List<ExerciseSetModel>? sets,
    String? notes,
    bool? isSuperset,
    String? supersetId,
    int? supersetOrder,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutExerciseModel(
      id: id ?? this.id,
      exerciseName: exerciseName ?? this.exerciseName,
      exerciseId: exerciseId ?? this.exerciseId,
      iconUrl: iconUrl ?? this.iconUrl,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
      isSuperset: isSuperset ?? this.isSuperset,
      supersetId: supersetId ?? this.supersetId,
      supersetOrder: supersetOrder ?? this.supersetOrder,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if this exercise has timed sets
  bool get hasTimedSets => sets.any((set) => set.isTimed);

  /// Get all timed sets
  List<ExerciseSetModel> get timedSets => sets.where((set) => set.isTimed).toList();

  /// Check if this exercise has distance-based sets
  bool get hasDistanceSets => sets.any((set) => set.isDistanceBased);
}

