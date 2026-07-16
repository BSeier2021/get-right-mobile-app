import 'package:get_right/models/workout_exercise_model.dart';

/// Workout Journal Model
/// Represents a complete workout session with warmup and main workout sections
class WorkoutJournalModel {
  final String id;
  final String userId;
  final DateTime date;
  final List<WorkoutExerciseModel> warmupExercises;
  final List<WorkoutExerciseModel> workoutExercises;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? durationSeconds; // Total workout duration
  final int? caloriesBurned; // From smartwatch
  final String? notes; // Daily workout notes
  final String? status; // API journal status e.g. Completed, Incomplete

  WorkoutJournalModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.warmupExercises,
    required this.workoutExercises,
    required this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.completedAt,
    this.durationSeconds,
    this.caloriesBurned,
    this.notes,
    this.status,
  });

  factory WorkoutJournalModel.fromJson(Map<String, dynamic> json) {
    return WorkoutJournalModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      warmupExercises: (json['warmupExercises'] as List<dynamic>?)?.map((ex) => WorkoutExerciseModel.fromJson(ex as Map<String, dynamic>)).toList() ?? [],
      workoutExercises: (json['workoutExercises'] as List<dynamic>?)?.map((ex) => WorkoutExerciseModel.fromJson(ex as Map<String, dynamic>)).toList() ?? [],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt']) : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      durationSeconds: json['durationSeconds']?.toInt(),
      caloriesBurned: json['caloriesBurned']?.toInt(),
      notes: json['notes'],
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'warmupExercises': warmupExercises.map((ex) => ex.toJson()).toList(),
      'workoutExercises': workoutExercises.map((ex) => ex.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'caloriesBurned': caloriesBurned,
      'notes': notes,
      if (status != null) 'status': status,
    };
  }

  WorkoutJournalModel copyWith({
    String? id,
    String? userId,
    DateTime? date,
    List<WorkoutExerciseModel>? warmupExercises,
    List<WorkoutExerciseModel>? workoutExercises,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    int? durationSeconds,
    int? caloriesBurned,
    String? notes,
    String? status,
  }) {
    return WorkoutJournalModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      warmupExercises: warmupExercises ?? this.warmupExercises,
      workoutExercises: workoutExercises ?? this.workoutExercises,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }

  static bool isCompletedStatus(String? raw) => raw?.trim().toLowerCase() == 'completed';

  /// Check if workout is completed
  bool get isCompleted => completedAt != null || isCompletedStatus(status);

  /// Check if workout is empty
  bool get isEmpty => warmupExercises.isEmpty && workoutExercises.isEmpty;

  /// Get all exercises (warmup + workout)
  List<WorkoutExerciseModel> get allExercises => [...warmupExercises, ...workoutExercises];

  /// Get all exercises grouped by supersets
  List<dynamic> get groupedExercises {
    final List<dynamic> grouped = [];
    final Set<String> processedSupersets = {};

    for (final exercise in allExercises) {
      if (exercise.isSuperset && exercise.supersetId != null) {
        if (!processedSupersets.contains(exercise.supersetId)) {
          final otherExercise = allExercises.firstWhere(
            (ex) => ex.isSuperset && ex.supersetId == exercise.supersetId && ex.id != exercise.id,
            orElse: () => exercise,
          );
          final ordered = (exercise.supersetOrder != null && otherExercise.supersetOrder != null && exercise.supersetOrder! > otherExercise.supersetOrder!)
              ? [otherExercise, exercise]
              : [exercise, otherExercise];
          grouped.add({
            'type': 'superset',
            'exercises': ordered,
            'supersetId': exercise.supersetId,
          });
          processedSupersets.add(exercise.supersetId!);
        }
      } else if (!exercise.isSuperset) {
        grouped.add({'type': 'exercise', 'exercise': exercise});
      }
    }

    return grouped;
  }
}
