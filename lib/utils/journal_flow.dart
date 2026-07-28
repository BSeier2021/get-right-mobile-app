import 'package:get/get.dart';
import 'package:get_right/models/journal_exercise_type.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/views/home/dashboard_screen.dart';

/// Shared navigation + argument helpers for the workout journal add-exercise flow.
///
/// Flow (views/journal/):
/// ```
/// workout_journal_screen
///   └─ new_workout_screen          (empty journal only)
///        └─ journal_exercise_library_screen
///             ├─ add_to_workout_screen        (search / direct pick)
///             └─ exercise_selection_screen    (browse category)
///                  └─ add_to_workout_screen
///                       └─ exercise_configuration_screen  → saves & returns to journal
/// ```
///
/// Widgets (widgets/journal/): journal_exercise_card, workout_group_card, …
class JournalFlowContext {
  const JournalFlowContext({
    this.workoutJournalId,
    this.journalWorkoutIds = const [],
    this.addedExerciseIds = const [],
    this.journalDay,
    this.exerciseType = JournalExerciseType.workout,
  });

  final String? workoutJournalId;
  final List<String> journalWorkoutIds;
  final List<String> addedExerciseIds;
  final DateTime? journalDay;
  final JournalExerciseType exerciseType;

  factory JournalFlowContext.fromArgs(Map<String, dynamic>? args) {
    final map = args ?? const <String, dynamic>{};
    final rawJournalWorkoutIds = map['journalWorkoutIds'];
    final rawAddedExerciseIds = map['addedExerciseIds'];
    final rawJournalDay = map['journalDay'];

    DateTime? journalDay;
    if (rawJournalDay is DateTime) {
      journalDay = DateTime(rawJournalDay.year, rawJournalDay.month, rawJournalDay.day);
    } else if (rawJournalDay is String && rawJournalDay.isNotEmpty) {
      final parsed = DateTime.tryParse(rawJournalDay);
      if (parsed != null) {
        journalDay = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }

    return JournalFlowContext(
      workoutJournalId: map['workoutJournalId']?.toString() ?? map['workoutJournal']?.toString(),
      journalWorkoutIds: rawJournalWorkoutIds is List
          ? rawJournalWorkoutIds.map((e) => e.toString()).where(WorkoutRepository.isValidMongoId).toList()
          : const [],
      addedExerciseIds: rawAddedExerciseIds is List
          ? rawAddedExerciseIds.map((e) => e.toString()).where((id) => id.isNotEmpty).toList()
          : const [],
      journalDay: journalDay,
      exerciseType: JournalExerciseType.fromArgs(map) ?? JournalExerciseType.workout,
    );
  }

  /// Route arguments forwarded to each step in the journal add-exercise flow.
  Map<String, dynamic> toRouteArgs({bool journalFlow = true}) {
    return {
      'exerciseType': exerciseType,
      if (workoutJournalId != null) 'workoutJournalId': workoutJournalId,
      if (journalWorkoutIds.isNotEmpty) 'journalWorkoutIds': journalWorkoutIds,
      if (addedExerciseIds.isNotEmpty) 'addedExerciseIds': addedExerciseIds,
      if (journalDay != null) 'journalDay': journalDay,
      if (journalFlow) 'journalFlow': true,
    };
  }

  JournalFlowContext copyWith({
    String? workoutJournalId,
    List<String>? journalWorkoutIds,
    List<String>? addedExerciseIds,
    DateTime? journalDay,
    JournalExerciseType? exerciseType,
  }) {
    return JournalFlowContext(
      workoutJournalId: workoutJournalId ?? this.workoutJournalId,
      journalWorkoutIds: journalWorkoutIds ?? this.journalWorkoutIds,
      addedExerciseIds: addedExerciseIds ?? this.addedExerciseIds,
      journalDay: journalDay ?? this.journalDay,
      exerciseType: exerciseType ?? this.exerciseType,
    );
  }
}

/// Parsed result from [AppRoutes.exerciseConfiguration] after a successful save.
class JournalFlowSaveResult {
  const JournalFlowSaveResult({
    required this.exercises,
    required this.exerciseType,
    this.workoutJournalId,
  });

  final List<WorkoutExerciseModel> exercises;
  final JournalExerciseType exerciseType;
  final String? workoutJournalId;

  static JournalFlowSaveResult? tryParse(dynamic result) {
    if (result is! Map || result['exercises'] == null) return null;
    final map = Map<String, dynamic>.from(result);
    final exercises = (map['exercises'] as List).whereType<WorkoutExerciseModel>().toList();
    if (exercises.isEmpty) return null;

    final exerciseType = map['exerciseType'] is JournalExerciseType
        ? map['exerciseType'] as JournalExerciseType
        : JournalExerciseType.fromIsWarmup(map['isWarmup'] == true);

    final journalId = map['workoutJournalId']?.toString();
    return JournalFlowSaveResult(
      exercises: exercises,
      exerciseType: exerciseType,
      workoutJournalId: WorkoutRepository.isValidMongoId(journalId) ? journalId : null,
    );
  }
}

class JournalFlowNavigator {
  JournalFlowNavigator._();

  static const _flowRoutes = <String>{
    AppRoutes.exerciseConfiguration,
    AppRoutes.addToWorkout,
    AppRoutes.exerciseSelection,
    AppRoutes.journalExerciseLibrary,
    AppRoutes.newWorkout,
  };

  /// Opens the correct entry screen for adding exercises to today's journal.
  static Future<Map<String, dynamic>?> openAddExerciseFlow({
    required JournalFlowContext context,
    required bool workoutIsEmpty,
  }) {
    if (workoutIsEmpty) {
      return pushAndBubble(
        AppRoutes.newWorkout,
        arguments: context.toRouteArgs(journalFlow: false),
      );
    }
    return openExerciseLibrary(context);
  }

  static Future<Map<String, dynamic>?> openExerciseLibrary(JournalFlowContext context) {
    return pushAndBubble(
      AppRoutes.journalExerciseLibrary,
      arguments: context.toRouteArgs(),
    );
  }

  /// Pushes a child route and returns its result to the caller.
  static Future<Map<String, dynamic>?> pushAndBubble(
    String route, {
    required Map<String, dynamic> arguments,
  }) async {
    final result = await Get.toNamed(route, arguments: arguments);
    return _asResultMap(result);
  }

  /// Pushes a child route and forwards a non-null result up one level.
  static Future<void> pushChildAndBubble(
    String route, {
    required Map<String, dynamic> arguments,
  }) async {
    final result = await Get.toNamed(route, arguments: arguments);
    bubbleResult(result);
  }

  static void bubbleResult(dynamic result) {
    if (result != null) Get.back(result: result);
  }

  /// After configure-exercise saves in the journal flow, refresh the journal tab and exit the flow.
  static void completeAfterSave(
    Map<String, dynamic> result, {
    required bool journalFlow,
    required bool isEditing,
  }) {
    if (!journalFlow) {
      Get.back(result: result);
      return;
    }

    _refreshJournalTab();

    if (isEditing) {
      Get.back(result: result);
      return;
    }

    Get.until((route) {
      final name = route.settings.name;
      if (name == AppRoutes.newWorkout) return true;
      if (route.isFirst) return true;
      return name != null && !_flowRoutes.contains(name);
    });

    if (Get.currentRoute == AppRoutes.newWorkout) {
      Get.back(result: result);
    }
  }

  static void _refreshJournalTab() {
    if (Get.isRegistered<HomeNavigationController>()) {
      Get.find<HomeNavigationController>().refreshWorkoutJournal();
    }
  }

  static Map<String, dynamic>? _asResultMap(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }
}
