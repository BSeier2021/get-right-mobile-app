import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get_right/data/gr_exercise_assets.dart';
import 'package:get_right/models/exercise_library_category.dart';
import 'package:get_right/models/gr_exercise_entry.dart';

/// Loads and queries the bundled Get Right exercise catalog (`ExerciseList.json`).
class GrExerciseCatalog {
  GrExerciseCatalog._();

  static final GrExerciseCatalog instance = GrExerciseCatalog._();

  static const Map<String, String> _muscleGroupLabels = {
    'chest': 'Chest',
    'back': 'Back',
    'legs': 'Legs',
    'arms': 'Arms',
    'core': 'Core',
  };

  static const List<String> _muscleGroupOrder = ['chest', 'back', 'legs', 'arms', 'core'];

  bool _loaded = false;
  List<GrExerciseEntry> _allExercises = const [];
  final Map<String, List<GrExerciseEntry>> _byMuscleGroup = {};

  Future<void> ensureLoaded() async {
    if (_loaded) return;

    final raw = await rootBundle.loadString('assets/gr_json/ExerciseList.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('ExerciseList.json must be a JSON object');
    }

    final muscleGroups = decoded['muscleGroups'];
    if (muscleGroups is! Map) {
      throw StateError('ExerciseList.json is missing muscleGroups');
    }

    final all = <GrExerciseEntry>[];
    final byGroup = <String, List<GrExerciseEntry>>{};

    for (final entry in _muscleGroupOrder) {
      final groupData = muscleGroups[entry];
      if (groupData is! Map) continue;

      final exercisesRaw = groupData['exercises'];
      if (exercisesRaw is! List) continue;

      final parsed = <GrExerciseEntry>[];
      for (final item in exercisesRaw) {
        if (item is! Map) continue;
        final exercise = GrExerciseEntry.fromJson(Map<String, dynamic>.from(item), muscleGroupKey: entry);
        if (exercise.id.isEmpty || exercise.name.isEmpty) continue;
        parsed.add(exercise);
        all.add(exercise);
      }
      byGroup[entry] = parsed;
    }

    _allExercises = all;
    _byMuscleGroup
      ..clear()
      ..addAll(byGroup);
    _loaded = true;
  }

  List<GrExerciseEntry> get allExercises => List.unmodifiable(_allExercises);

  List<GrExerciseEntry> exercisesForMuscleGroup(String key) {
    final normalized = key.trim().toLowerCase();
    return List.unmodifiable(_byMuscleGroup[normalized] ?? const []);
  }

  List<ExerciseLibraryCategory> getMuscleGroupCategories() {
    final categories = <ExerciseLibraryCategory>[];
    for (final key in _muscleGroupOrder) {
      final label = _muscleGroupLabels[key];
      if (label == null) continue;
      final exercises = _byMuscleGroup[key] ?? const [];
      categories.add(
        ExerciseLibraryCategory(
          id: key,
          name: label,
          iconUrl: GrExerciseAssets.muscleGroupImage(key),
          totalExercises: exercises.length,
        ),
      );
    }
    return categories;
  }

  List<GrExerciseEntry> searchExercises(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return allExercises;
    return allExercises.where((e) {
      if (e.name.toLowerCase().contains(q)) return true;
      if (e.primaryMuscleLabel.toLowerCase().contains(q)) return true;
      if (e.tags.any((tag) => tag.toLowerCase().contains(q))) return true;
      if (e.equipment.any((item) => item.toLowerCase().contains(q))) return true;
      return false;
    }).toList();
  }
}
