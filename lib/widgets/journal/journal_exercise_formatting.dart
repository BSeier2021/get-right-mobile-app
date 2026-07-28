import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/models/workout_exercise_model.dart';

/// Shared summary and set-value formatting for journal exercise cards.
class JournalExerciseFormatting {
  JournalExerciseFormatting._();

  static String summaryFor(WorkoutExerciseModel exercise) {
    final setCount = exercise.sets.length;
    final setLabel = setCount == 1 ? '1 set' : '$setCount sets';

    if (setCount == 0) return '$setLabel · not configured';

    final first = exercise.sets.first;
    final detail = _firstSetDetail(first, exercise);

    if (detail == null) return '$setLabel · not configured';
    return '$setLabel · $detail';
  }

  static String mainSetValue(ExerciseSetModel set) {
    if (set.isTimed && set.timeSeconds != null) {
      final seconds = set.timeSeconds!;
      if (seconds >= 60 && seconds % 60 == 0) return '${seconds ~/ 60} min';
      return '$seconds sec';
    }
    if (set.isAMRAP) return 'AMRAP';
    if (set.isFAILURE) return 'Failure';
    if (set.reps != null && set.reps! > 0) return '${set.reps} reps';
    return '—';
  }

  static String secondarySetValue(ExerciseSetModel set, WorkoutExerciseModel exercise) {
    if (exercise.hasDistanceSets) {
      if (set.isDistanceBased && set.distance != null && set.distance! > 0) {
        return formatDistance(set);
      }
      return '—';
    }
    if (set.isBodyweight) return 'Bodyweight';
    if (set.weight != null && set.weight! > 0) {
      return set.weight! % 1 == 0 ? '${set.weight!.toInt()} lbs' : '${set.weight} lbs';
    }
    return '—';
  }

  static String mainColumnLabel(WorkoutExerciseModel exercise) {
    if (exercise.hasTimedSets) return 'Time';
    return 'Reps';
  }

  static String secondaryColumnLabel(WorkoutExerciseModel exercise) {
    if (exercise.hasDistanceSets) return 'Distance';
    return 'Weight';
  }

  /// Compact cell value for table rows (header carries the unit label).
  static String mainCellValue(ExerciseSetModel set) {
    if (set.isTimed && set.timeSeconds != null && set.timeSeconds! > 0) {
      final seconds = set.timeSeconds!;
      if (seconds >= 60 && seconds % 60 == 0) return '${seconds ~/ 60}m';
      if (seconds >= 60) {
        final m = seconds ~/ 60;
        final s = seconds % 60;
        return s > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '${m}m';
      }
      return '${seconds}s';
    }
    if (set.isAMRAP) return 'AMRAP';
    if (set.isFAILURE) return 'Fail';
    if (set.reps != null && set.reps! > 0) return '${set.reps}';
    return '—';
  }

  static String secondaryCellValue(ExerciseSetModel set, WorkoutExerciseModel exercise) {
    if (exercise.hasDistanceSets) {
      if (set.isDistanceBased && set.distance != null && set.distance! > 0) {
        final value = set.distance!;
        final display = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
        final unit = set.distanceUnit?.toLowerCase().trim();
        final suffix = switch (unit) {
          'meters' || 'm' => 'm',
          'km' || 'kilometers' => 'km',
          _ => 'mi',
        };
        return '$display $suffix';
      }
      return '—';
    }
    if (set.isBodyweight) return 'BW';
    if (set.weight != null && set.weight! > 0) {
      return set.weight! % 1 == 0 ? '${set.weight!.toInt()}' : set.weight!.toStringAsFixed(1);
    }
    return '—';
  }

  static String formatDistance(ExerciseSetModel set) {
    final value = set.distance!;
    final display = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
    final unit = set.distanceUnit?.toLowerCase().trim();
    return switch (unit) {
      'meters' || 'm' => '$display m',
      'km' || 'kilometers' => '$display km',
      _ => '$display mi',
    };
  }

  static String? _firstSetDetail(ExerciseSetModel set, WorkoutExerciseModel exercise) {
    if (set.isTimed && set.timeSeconds != null && set.timeSeconds! > 0) {
      final seconds = set.timeSeconds!;
      if (seconds >= 60 && seconds % 60 == 0) return '${seconds ~/ 60} min';
      return '$seconds sec';
    }
    if (set.isAMRAP) return 'AMRAP';
    if (set.isFAILURE) return 'to failure';
    if (set.reps != null && set.reps! > 0) {
      return '${set.reps} reps';
    }
    if (set.isDistanceBased && set.distance != null && set.distance! > 0) {
      return formatDistance(set);
    }
    if (set.isBodyweight) return 'bodyweight';
    if (set.weight != null && set.weight! > 0) {
      return '${set.weight! % 1 == 0 ? set.weight!.toInt() : set.weight} lbs';
    }
    return null;
  }
}
