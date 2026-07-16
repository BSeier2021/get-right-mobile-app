import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/models/journal_exercise_type.dart';

/// Workout Exercise Model
/// Represents a single exercise in a workout (can be part of a superset)
class WorkoutExerciseModel {
  final String id;
  final String exerciseName;
  final String exerciseId; // Reference to exercise library
  final String? iconUrl; // Exercise icon from library / API
  final String? videoUrl;
  final String? videoThumbnailUrl;
  final List<ExerciseSetModel> sets;
  final String? notes; // Exercise-level notes
  final bool isSuperset; // If true, this is part of a superset
  final String? supersetIdentifier; // Raw API value — partners share the same string
  final String? supersetId; // Parsed group id for UI grouping
  final int? supersetOrder; // Order within superset (0 or 1)
  final DateTime date;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final JournalExerciseType? exerciseType;

  /// Parses API/local identifiers like `A1`, `A2` → group `A` with order 0, 1.
  static ({String groupId, int order})? parseSupersetIdentifier(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'^([A-Za-z]+)(\d+)$').firstMatch(value);
    if (match != null) {
      final groupId = match.group(1)!.toUpperCase();
      final order = (int.tryParse(match.group(2)!) ?? 1) - 1;
      return (groupId: groupId, order: order < 0 ? 0 : order);
    }
    return (groupId: value.toUpperCase(), order: 0);
  }

  WorkoutExerciseModel({
    required this.id,
    required this.exerciseName,
    required this.exerciseId,
    this.iconUrl,
    this.videoUrl,
    this.videoThumbnailUrl,
    required this.sets,
    this.notes,
    this.isSuperset = false,
    this.supersetIdentifier,
    this.supersetId,
    this.supersetOrder,
    required this.date,
    required this.createdAt,
    this.updatedAt,
    this.exerciseType,
  });

  factory WorkoutExerciseModel.fromJson(Map<String, dynamic> json) {
    return WorkoutExerciseModel(
      id: json['id'] ?? '',
      exerciseName: json['exerciseName'] ?? '',
      exerciseId: json['exerciseId'] ?? '',
      iconUrl: json['iconUrl'],
      videoUrl: json['videoUrl'],
      videoThumbnailUrl: json['videoThumbnailUrl'],
      sets: (json['sets'] as List<dynamic>?)
              ?.map((set) => ExerciseSetModel.fromJson(set as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes'],
      isSuperset: json['isSuperset'] ?? false,
      supersetIdentifier: json['supersetIdentifier'],
      supersetId: json['supersetId'],
      supersetOrder: json['supersetOrder']?.toInt(),
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      exerciseType: JournalExerciseType.fromApi(json['exerciseType']?.toString()) ?? JournalExerciseType.fromApi(json['type']?.toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseName': exerciseName,
      'exerciseId': exerciseId,
      'iconUrl': iconUrl,
      'videoUrl': videoUrl,
      'videoThumbnailUrl': videoThumbnailUrl,
      'sets': sets.map((set) => set.toJson()).toList(),
      'notes': notes,
      'isSuperset': isSuperset,
      if (supersetIdentifier != null) 'supersetIdentifier': supersetIdentifier,
      'supersetId': supersetId,
      'supersetOrder': supersetOrder,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      if (exerciseType != null) 'exerciseType': exerciseType!.apiValue,
    };
  }

  WorkoutExerciseModel copyWith({
    String? id,
    String? exerciseName,
    String? exerciseId,
    String? iconUrl,
    String? videoUrl,
    String? videoThumbnailUrl,
    List<ExerciseSetModel>? sets,
    String? notes,
    bool? isSuperset,
    String? supersetIdentifier,
    String? supersetId,
    int? supersetOrder,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    JournalExerciseType? exerciseType,
  }) {
    return WorkoutExerciseModel(
      id: id ?? this.id,
      exerciseName: exerciseName ?? this.exerciseName,
      exerciseId: exerciseId ?? this.exerciseId,
      iconUrl: iconUrl ?? this.iconUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      videoThumbnailUrl: videoThumbnailUrl ?? this.videoThumbnailUrl,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
      isSuperset: isSuperset ?? this.isSuperset,
      supersetIdentifier: supersetIdentifier ?? this.supersetIdentifier,
      supersetId: supersetId ?? this.supersetId,
      supersetOrder: supersetOrder ?? this.supersetOrder,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      exerciseType: exerciseType ?? this.exerciseType,
    );
  }

  /// Check if this exercise has timed sets
  bool get hasTimedSets => sets.any((set) => set.isTimed);

  /// Get all timed sets
  List<ExerciseSetModel> get timedSets => sets.where((set) => set.isTimed).toList();

  /// Check if this exercise has distance-based sets
  bool get hasDistanceSets => sets.any((set) => set.isDistanceBased);
}

