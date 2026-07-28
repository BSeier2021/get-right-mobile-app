import 'package:get_right/repo/workout_repo.dart';

enum PlannerReuseKind { warmup, workout, plannedRoute, savedActivity }

class PlannerReuseOption {
  const PlannerReuseOption({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.journalId,
    this.routeId,
    this.runningLogId,
  });

  final PlannerReuseKind kind;
  final String title;
  final String subtitle;
  final String? journalId;
  final String? routeId;
  final String? runningLogId;
}

/// Parses calendar day data into entries the user can reuse when adding more content.
class PlannerDayReuse {
  PlannerDayReuse._();

  static List<PlannerReuseOption> optionsFromDayData(Map<String, dynamic>? dayData) {
    if (dayData == null) return const [];

    final options = <PlannerReuseOption>[];
    _addWorkoutOptions(options, dayData['workout']);
    _addRunOptionsFromList(options, dayData['runs']);
    if (options.where((option) => option.kind == PlannerReuseKind.savedActivity || option.kind == PlannerReuseKind.plannedRoute).isEmpty) {
      _addRunOptions(options, dayData['run']);
    }
    return options;
  }

  static bool hasReusableEntries(Map<String, dynamic>? dayData) => optionsFromDayData(dayData).isNotEmpty;

  static void _addWorkoutOptions(List<PlannerReuseOption> options, dynamic workoutRaw) {
    if (workoutRaw is! Map) return;
    final workout = Map<String, dynamic>.from(workoutRaw);
    final journalId = WorkoutRepository.isValidMongoId(workout['journalId']?.toString()) ? workout['journalId'].toString().trim() : null;
    final workouts = workout['workouts'];

    if (workouts is List && workouts.isNotEmpty) {
      options.add(
        PlannerReuseOption(
          kind: PlannerReuseKind.workout,
          title: 'Workout',
          subtitle: _exerciseCountLabel(workouts.length),
          journalId: journalId,
        ),
      );
      return;
    }

    final exerciseCount = workout['exercises'];
    final count = exerciseCount is num ? exerciseCount.toInt() : int.tryParse(exerciseCount?.toString() ?? '') ?? 0;
    if (count > 0 || journalId != null) {
      options.add(
        PlannerReuseOption(
          kind: PlannerReuseKind.workout,
          title: 'Workout',
          subtitle: count > 0 ? _exerciseCountLabel(count) : 'Logged session',
          journalId: journalId,
        ),
      );
    }
  }

  static void _addRunOptionsFromList(List<PlannerReuseOption> options, dynamic runsRaw) {
    if (runsRaw is! List) return;
    for (final item in runsRaw) {
      if (item is Map) {
        _addRunOptions(options, item);
      }
    }
  }

  static void _addRunOptions(List<PlannerReuseOption> options, dynamic runRaw) {
    if (runRaw is! Map) return;
    final run = Map<String, dynamic>.from(runRaw);
    final routeId = WorkoutRepository.isValidMongoId(run['routeId']?.toString()) ? run['routeId'].toString().trim() : null;
    final runId = WorkoutRepository.isValidMongoId(run['id']?.toString()) ? run['id'].toString().trim() : null;
    final distance = run['distance']?.toString().trim() ?? '';
    final time = run['time']?.toString().trim() ?? '';
    final isPlannedRoute = run['isPlannedRoute'] == true;

    if (isPlannedRoute && routeId != null) {
      options.add(
        PlannerReuseOption(
          kind: PlannerReuseKind.plannedRoute,
          title: 'Planned route',
          subtitle: distance.isNotEmpty ? distance : 'Saved route',
          routeId: routeId,
        ),
      );
      return;
    }

    if (runId != null) {
      final parts = <String>[];
      if (distance.isNotEmpty) parts.add(distance);
      if (time.isNotEmpty && time != '0:00') parts.add(time);
      options.add(
        PlannerReuseOption(
          kind: PlannerReuseKind.savedActivity,
          title: run['activityType']?.toString().trim().isNotEmpty == true ? run['activityType'].toString() : 'Saved activity',
          subtitle: parts.isNotEmpty ? parts.join(' · ') : 'Logged activity',
          runningLogId: runId,
          routeId: routeId,
        ),
      );
    } else if (routeId != null) {
      options.add(
        PlannerReuseOption(
          kind: PlannerReuseKind.plannedRoute,
          title: 'Planned route',
          subtitle: distance.isNotEmpty ? distance : 'Saved route',
          routeId: routeId,
        ),
      );
    }
  }

  static String _exerciseCountLabel(int count) => '$count exercise${count == 1 ? '' : 's'}';
}
