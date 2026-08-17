import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get_right/models/workout_journal_model.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/models/journal_exercise_type.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/services/share_to_chat_service.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/journal/exercise_card.dart';
import 'package:get_right/widgets/journal/superset_card.dart';
import 'package:get_right/views/journal/workout_celebration_screen.dart';
import 'package:get_right/views/home/dashboard_screen.dart';

class WorkoutJournalScreen extends StatefulWidget {
  final bool isEmbedded;
  const WorkoutJournalScreen({super.key, this.isEmbedded = false});

  @override
  State<WorkoutJournalScreen> createState() => _WorkoutJournalScreenState();
}

class _WorkoutJournalScreenState extends State<WorkoutJournalScreen> {
  static const _exerciseSectionPrefsPrefix = 'workout_journal_exercise_sections_v1';

  WorkoutJournalModel? _workout;
  List<WorkoutJournalModel> _journalEntries = [];
  Map<String, String> _workoutJournalByExerciseId = {};
  Map<String, JournalExerciseType> _exerciseSectionById = {};
  String? _workoutJournalId;
  bool _isLoading = true;
  bool _isSavingJournal = false;
  String? _loadError;
  final WorkoutRepository _workoutRepo = WorkoutRepository();
  final CalendarRepository _calendarRepo = CalendarRepository();
  bool _isStarted = false;
  bool _isPaused = false;
  // Dialog is now used instead of inline add-exercise content
  Timer? _timer;
  int _seconds = 0;
  int _calories = 0;
  DateTime? _startTime;
  Worker? _plannerReloadWorker;
  Worker? _journalRefreshWorker;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<HomeNavigationController>()) {
      final nav = Get.find<HomeNavigationController>();
      _plannerReloadWorker = ever<int>(nav.journalPlannerReloadNonce, (_) {
        if (!mounted || nav.journalAnchorDate.value == null) return;
        _loadWorkoutJournal();
      });
      _journalRefreshWorker = ever<int>(nav.workoutJournalRefreshNonce, (_) {
        if (!mounted) return;
        _loadWorkoutJournal();
      });
    }
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _plannerReloadWorker?.dispose();
    _journalRefreshWorker?.dispose();
    super.dispose();
  }

  void _load() {
    _loadWorkoutJournal();
  }

  Future<void> _loadWorkoutJournal() async {
    await _loadExerciseSections();
    await _refreshWorkoutJournalFromApi(showLoading: true);
  }

  Future<String> _exerciseSectionPrefsKey() async {
    final storage = await StorageService.getInstance();
    final userId = storage.getUserId()?.trim();
    if (userId != null && userId.isNotEmpty) {
      return '${_exerciseSectionPrefsPrefix}_$userId';
    }
    return _exerciseSectionPrefsPrefix;
  }

  Future<void> _loadExerciseSections() async {
    final storage = await StorageService.getInstance();
    final raw = storage.getString(await _exerciseSectionPrefsKey());
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final next = <String, JournalExerciseType>{};
      decoded.forEach((key, value) {
        final id = key.toString();
        if (!WorkoutRepository.isValidMongoId(id)) return;
        next[id] = JournalExerciseType.fromApi(value?.toString()) ?? JournalExerciseType.workout;
      });
      _exerciseSectionById = next;
    } catch (_) {
      /* ignore corrupt prefs */
    }
  }

  Future<void> _persistExerciseSections() async {
    final storage = await StorageService.getInstance();
    final payload = _exerciseSectionById.map((id, type) => MapEntry(id, type.apiValue));
    await storage.saveString(await _exerciseSectionPrefsKey(), jsonEncode(payload));
  }

  Future<void> _rememberExerciseSections(Iterable<WorkoutExerciseModel> exercises, JournalExerciseType type) async {
    var changed = false;
    for (final ex in exercises) {
      if (!WorkoutRepository.isValidMongoId(ex.id)) continue;
      _exerciseSectionById[ex.id] = type;
      changed = true;
    }
    if (changed) await _persistExerciseSections();
  }

  Future<void> _forgetExerciseSection(String exerciseId) async {
    if (_exerciseSectionById.remove(exerciseId) != null) {
      await _persistExerciseSections();
    }
  }

  WorkoutJournalModel _emptyWorkoutShell() {
    final day = HomeNavigationController.journalDayOrNow();
    return WorkoutJournalModel(id: '', userId: 'user_1', date: day, warmupExercises: [], workoutExercises: [], createdAt: day);
  }

  DateTime get _journalDay => HomeNavigationController.journalDayOrNow();

  HomeNavigationController? get _navController => Get.isRegistered<HomeNavigationController>() ? Get.find<HomeNavigationController>() : null;

  bool get _isWorkoutCompleted =>
      _workout?.isCompleted == true || _journalEntries.any((entry) => entry.isCompleted);

  WorkoutJournalModel _normalizeJournalExercises(WorkoutJournalModel fromApi) {
    final seen = <String>{};
    final unified = <WorkoutExerciseModel>[];

    for (final ex in fromApi.allExercises) {
      if (!seen.add(ex.id)) continue;
      unified.add(ex.copyWith(exerciseType: JournalExerciseType.workout));
    }

    return fromApi.copyWith(warmupExercises: const [], workoutExercises: unified);
  }

  Future<void> _refreshWorkoutJournalFromApi({bool showLoading = false}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final day = _journalDay;
      final fromPlanner = _navController?.journalAnchorDate.value != null;
      final strictDay = fromPlanner;
      var page = await _workoutRepo.fetchWorkoutJournalEntries(dateFrom: day, dateTo: day);
      var rawEntries = WorkoutRepository.entriesForDay(page, day: day, strict: strictDay);

      if (rawEntries.length > 1) {
        final canonicalId = WorkoutRepository.primaryJournalIdForDay(rawEntries, day: day, strict: strictDay);
        if (canonicalId != null) {
          try {
            await _workoutRepo.consolidateDayJournal(preferredJournalId: canonicalId, date: day);
            page = await _workoutRepo.fetchWorkoutJournalEntries(dateFrom: day, dateTo: day);
            rawEntries = WorkoutRepository.entriesForDay(page, day: day, strict: strictDay);
          } catch (_) {
            /* keep merged UI view if consolidate fails */
          }
        }
      }

      final detailJournalId =
          WorkoutRepository.primaryJournalIdForDay(rawEntries, day: day, strict: strictDay) ??
          (WorkoutRepository.isValidMongoId(_workoutJournalId) ? _workoutJournalId : null);
      if (WorkoutRepository.isValidMongoId(detailJournalId)) {
        try {
          final detail = await _workoutRepo.fetchWorkoutJournalById(detailJournalId!);
          if (detail != null) {
            rawEntries = WorkoutRepository.entriesWithDetailReplacing(rawEntries, detail);
          }
        } catch (_) {
          /* list response is still usable */
        }
      }

      final nav = _navController;
      final hasJournalForDay = rawEntries.isNotEmpty;
      if (hasJournalForDay && nav != null) {
        nav.startFreshJournal.value = false;
      }
      final startFresh = !hasJournalForDay && nav?.startFreshJournal.value == true;
      final preferredId = nav?.preferredJournalId.value;
      final today = startFresh ? null : WorkoutRepository.todayEntryFrom(page, day: day, strict: strictDay);
      if (!mounted) return;

      final previousWorkout = _workout;
      setState(() {
        _journalEntries = rawEntries;
        _workoutJournalByExerciseId = WorkoutRepository.exerciseJournalMapFrom(rawEntries);
        _workoutJournalId =
            WorkoutRepository.primaryJournalIdForDay(rawEntries, day: day, strict: strictDay) ??
            (WorkoutRepository.isValidMongoId(preferredId) ? preferredId : null) ??
            _workoutJournalId;
        if (today != null && today.id.isNotEmpty) {
          _workout = _normalizeJournalExercises(
            today.copyWith(
              startedAt: _isStarted && !today.isCompleted ? (previousWorkout?.startedAt ?? today.startedAt) : today.startedAt,
              completedAt: today.completedAt ?? (today.isCompleted ? today.updatedAt : previousWorkout?.completedAt),
              durationSeconds: _isStarted && !today.isCompleted
                  ? (previousWorkout?.durationSeconds ?? today.durationSeconds)
                  : (today.durationSeconds ?? previousWorkout?.durationSeconds),
              caloriesBurned: today.caloriesBurned ?? previousWorkout?.caloriesBurned,
              status: today.status ?? previousWorkout?.status,
            ),
          );
        } else if (_workout == null || startFresh) {
          _workoutJournalId = null;
          _workout = _emptyWorkoutShell();
        }
        _isLoading = false;
        _loadError = null;
      });

      if (page.syncFailed && mounted) {
        Get.snackbar(
          'Sync unavailable',
          'Workout list could not be loaded from the server. You can still add exercises.',
          backgroundColor: AppColors.primaryGrayDark,
          colorText: AppColors.onSurface,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_workout == null) _workout = _emptyWorkoutShell();
        _loadError = null;
      });
      Get.snackbar('Sync unavailable', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
    }
  }

  WorkoutJournalModel? _journalEntryForExercise(String exerciseId) {
    final journalId = _workoutJournalByExerciseId[exerciseId];
    if (journalId == null) return null;
    return WorkoutRepository.journalEntryById(_journalEntries, journalId);
  }

  Future<bool> _persistJournalEntry({required String journalId, required List<String> workoutIds, int? duration, String? notes}) async {
    final entry = WorkoutRepository.journalEntryById(_journalEntries, journalId);
    if (entry == null) return false;

    setState(() => _isSavingJournal = true);
    try {
      await _workoutRepo.updateWorkoutJournal(
        journalId: journalId,
        workoutIds: workoutIds,
        duration: duration ?? entry.durationSeconds ?? 0,
        notes: notes ?? '',
      );
      await _refreshWorkoutJournalFromApi();
      return true;
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSavingJournal = false);
    }
  }

  Future<void> _deleteExercise(WorkoutExerciseModel ex) async {
    final journalId = _workoutJournalByExerciseId[ex.id];
    if (journalId == null || !WorkoutRepository.isValidMongoId(journalId)) {
      setState(() {
        _workout = _workout!.copyWith(workoutExercises: _workout!.workoutExercises.where((e) => e.id != ex.id).toList());
      });
      return;
    }

    final entry = WorkoutRepository.journalEntryById(_journalEntries, journalId);
    if (entry == null) return;

    final remainingIds = WorkoutRepository.workoutIdsFrom(entry).where((id) => id != ex.id).toList();
    await _forgetExerciseSection(ex.id);
    await _persistJournalEntry(journalId: journalId, workoutIds: remainingIds);
  }

  Future<void> _reorderExercises(List<WorkoutExerciseModel> reordered) async {
    final idsByJournal = <String, List<String>>{};
    for (final ex in reordered) {
      final journalId = _workoutJournalByExerciseId[ex.id];
      if (journalId == null || !WorkoutRepository.isValidMongoId(ex.id)) continue;
      idsByJournal.putIfAbsent(journalId, () => []).add(ex.id);
    }

    if (idsByJournal.isEmpty) {
      setState(() {
        _workout = _workout!.copyWith(workoutExercises: reordered);
      });
      return;
    }

    setState(() => _isSavingJournal = true);
    try {
      for (final journalId in idsByJournal.keys) {
        final entry = WorkoutRepository.journalEntryById(_journalEntries, journalId);
        if (entry == null) continue;
        await _workoutRepo.updateWorkoutJournal(journalId: journalId, workoutIds: idsByJournal[journalId]!, duration: entry.durationSeconds ?? 0, notes: '');
      }
      await _refreshWorkoutJournalFromApi();
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      }
    } finally {
      if (mounted) setState(() => _isSavingJournal = false);
    }
  }

  List<WorkoutExerciseModel> _applyExerciseNotes(List<WorkoutExerciseModel> exercises, String targetExerciseId, String notes) {
    final trimmed = notes.trim();
    return exercises.map((e) => e.id == targetExerciseId ? e.copyWith(notes: trimmed.isEmpty ? null : trimmed) : e).toList();
  }

  Future<void> _saveJournalNotes(WorkoutExerciseModel ex, String notes) async {
    setState(() {
      if (_workout == null) return;
      _workout = _workout!.copyWith(
        workoutExercises: _applyExerciseNotes(_workout!.workoutExercises, ex.id, notes),
      );
    });

    if (!WorkoutRepository.isValidMongoId(ex.id)) return;

    setState(() => _isSavingJournal = true);
    try {
      await _workoutRepo.updateWorkout(
        ex.id,
        WorkoutRepository.updateWorkoutBody(name: ex.exerciseName, exercise: WorkoutRepository.exerciseSetsToApi(ex.sets), notes: notes.trim()),
      );
      await _refreshWorkoutJournalFromApi();
    } catch (e) {
      if (mounted) {
        Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      }
    } finally {
      if (mounted) setState(() => _isSavingJournal = false);
    }
  }

  void _startWorkout() {
    if (_isWorkoutCompleted) {
      Get.snackbar('Workout completed', 'This workout is already completed.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    setState(() {
      _isStarted = true;
      _isPaused = false;
      _startTime = DateTime.now();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused) {
        setState(() {
          _seconds++;
          _calories = (_seconds / 60 * 5).round();
        });
      }
    });
  }

  void _pauseWorkout() {
    setState(() => _isPaused = true);
  }

  void _resumeWorkout() {
    setState(() => _isPaused = false);
  }

  void _stopWorkout() async {
    _timer?.cancel();

    if (_workout != null && _startTime != null) {
      _workout = _workout!.copyWith(
        startedAt: _startTime,
        completedAt: DateTime.now(),
        durationSeconds: _seconds,
        caloriesBurned: _calories,
        status: 'Completed',
      );
    }

    setState(() {
      _isStarted = false;
      _isPaused = false;
    });

    final celebrationCalories = _workout?.caloriesBurned ?? _calories;
    final prepareFuture = _finalizeWorkoutJournal();

    Get.to(
      () => WorkoutCelebrationScreen(
        duration: _formatTime(_seconds),
        calories: celebrationCalories,
        workoutName: _getWorkoutName(),
        workoutJournalId: _workoutJournalId,
        prepareFuture: prepareFuture,
      ),
      transition: Transition.zoom,
      duration: const Duration(milliseconds: 500),
    )?.then((_) {
      if (!mounted) return;
      setState(() {
        _seconds = 0;
        _calories = 0;
        _startTime = null;
      });
    });
  }

  Future<int?> _finalizeWorkoutJournal() async {
    if (_workout == null) return null;

    final workoutIds = _workout!.allExercises.where((e) => WorkoutRepository.isValidMongoId(e.id)).map((e) => e.id).toList();
    if (workoutIds.isEmpty) {
      if (WorkoutRepository.isValidMongoId(_workoutJournalId) && _seconds >= 1) {
        try {
          await _workoutRepo.completeWorkoutJournal(journalId: _workoutJournalId!, duration: _seconds);
        } catch (e) {
          if (!mounted) return _workout?.caloriesBurned;
          Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
        }
      }
      await _refreshWorkoutJournalFromApi();
      return _workout?.caloriesBurned;
    }

    try {
      _workoutJournalId = await _workoutRepo.consolidateDayJournal(
        existingJournalWorkoutIds: workoutIds,
        preferredJournalId: _workoutJournalId,
        duration: _seconds,
        notes: '',
        date: _journalDay,
      );
      if (WorkoutRepository.isValidMongoId(_workoutJournalId) && _seconds >= 1) {
        await _workoutRepo.completeWorkoutJournal(journalId: _workoutJournalId!, duration: _seconds);
      }
      await _refreshWorkoutJournalFromApi();
      return _workout?.caloriesBurned;
    } catch (e) {
      if (!mounted) return _workout?.caloriesBurned;
      Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      return _workout?.caloriesBurned;
    }
  }

  String _getWorkoutName() {
    if (_workout == null) return 'Workout';
    final exerciseCount = _workout!.workoutExercises.length;
    return '$exerciseCount Exercise${exerciseCount != 1 ? 's' : ''}';
  }

  // ignore: unused_element
  Widget _buildStatBadge({required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 2),
          ),
          child: Icon(icon, color: AppColors.accent, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)),
      ],
    );
  }

  String _formatTime(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Future<void> _ensureWorkoutJournalId() async {
    _workoutJournalId = await _workoutRepo.findWorkoutJournalIdForToday(date: _journalDay) ?? _workoutJournalId;
  }

  Future<void> _linkJournalToPlannerCalendar(String journalId) async {
    final anchor = _navController?.journalAnchorDate.value;
    if (anchor == null || !WorkoutRepository.isValidMongoId(journalId)) return;
    try {
      await _calendarRepo.attachWorkoutJournalToCalendar(date: anchor, workoutJournalId: journalId);
    } catch (_) {
      /* non-blocking — exercises are saved even if calendar link fails */
    }
  }

  List<String> _currentJournalWorkoutIds() {
    if (_workout == null) return const [];
    return _workout!.allExercises.where((e) => WorkoutRepository.isValidMongoId(e.id)).map((e) => e.id).toList();
  }

  List<String> _currentAddedLibraryExerciseIds() {
    if (_workout == null) return const [];
    return _workout!.allExercises.map((e) => e.exerciseId).where((id) => id.isNotEmpty).toSet().toList();
  }

  Future<void> _openAddExerciseFlow() async {
    try {
      await _ensureWorkoutJournalId();
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    await Get.toNamed(
      AppRoutes.exerciseConfiguration,
      arguments: {
        'exerciseType': JournalExerciseType.workout,
        'workoutJournalId': _workoutJournalId,
        'journalWorkoutIds': _currentJournalWorkoutIds(),
        'addedExerciseIds': _currentAddedLibraryExerciseIds(),
        'journalDay': _journalDay,
      },
    )?.then((r) async {
      if (r is! Map || r['exercises'] == null) return;
      final returnedJournalId = r['workoutJournalId']?.toString();
      if (WorkoutRepository.isValidMongoId(returnedJournalId)) {
        _workoutJournalId = returnedJournalId;
        await _linkJournalToPlannerCalendar(returnedJournalId!);
      }
      final exercises = (r['exercises'] as List).whereType<WorkoutExerciseModel>();
      await _rememberExerciseSections(exercises, JournalExerciseType.workout);
      await _refreshWorkoutJournalFromApi();
    });
  }

  Future<void> _openSupersetPartnerFlow(WorkoutExerciseModel existing) async {
    if (_isWorkoutCompleted) {
      Get.snackbar('Workout completed', 'You cannot add exercises to a completed workout.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (!WorkoutRepository.isValidMongoId(existing.id)) {
      Get.snackbar('Cannot add superset', 'Save this exercise first.', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    try {
      await _ensureWorkoutJournalId();
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    await Get.toNamed(
      AppRoutes.exerciseConfiguration,
      arguments: {
        'exerciseType': JournalExerciseType.workout,
        'workoutJournalId': _workoutJournalId,
        'journalWorkoutIds': _currentJournalWorkoutIds(),
        'addedExerciseIds': _currentAddedLibraryExerciseIds(),
        'journalDay': _journalDay,
        'supersetPartnerOf': existing,
      },
    )?.then((r) async {
      if (r is! Map || r['exercises'] == null) return;
      final returnedJournalId = r['workoutJournalId']?.toString();
      if (WorkoutRepository.isValidMongoId(returnedJournalId)) {
        _workoutJournalId = returnedJournalId;
        await _linkJournalToPlannerCalendar(returnedJournalId!);
      }
      final exercises = (r['exercises'] as List).whereType<WorkoutExerciseModel>();
      await _rememberExerciseSections(exercises, JournalExerciseType.workout);
      await _refreshWorkoutJournalFromApi();
    });
  }

  // ignore: unused_element
  void _showQuickAddDialog({required bool isTimer}) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController setsController = TextEditingController(text: '3');
    final TextEditingController repsController = TextEditingController(text: '10');
    final TextEditingController timeController = TextEditingController(text: '60');

    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.backgroundColor, borderRadius: BorderRadius.circular(20)),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isTimer ? 'Quick Add Timer Exercise' : 'Quick Add Exercise',
                          style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.primaryGray),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Exercise Name',
                        hintText: 'Enter exercise name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.fitness_center, color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isTimer) ...[
                      TextField(
                        controller: setsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Number of Sets',
                          hintText: '3',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.repeat, color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: timeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Time per Set (seconds)',
                          hintText: '60',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.timer, color: AppColors.accent),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: setsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Number of Sets',
                          hintText: '3',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.repeat, color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: repsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Reps per Set',
                          hintText: '10',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.numbers, color: AppColors.accent),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              nameController.dispose();
                              setsController.dispose();
                              repsController.dispose();
                              timeController.dispose();
                              Get.back();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: AppColors.primaryGray),
                            ),
                            child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.primaryGray)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final name = nameController.text.trim();
                              if (name.isEmpty) {
                                Get.snackbar('Error', 'Please enter exercise name', backgroundColor: AppColors.error, colorText: Colors.white);
                                return;
                              }

                              final sets = int.tryParse(setsController.text) ?? 3;
                              final now = DateTime.now();
                              final List<ExerciseSetModel> exerciseSets = [];

                              for (int i = 0; i < sets; i++) {
                                exerciseSets.add(
                                  ExerciseSetModel(
                                    id: 'set_${i + 1}_${now.millisecondsSinceEpoch}',
                                    setNumber: i + 1,
                                    reps: isTimer ? null : (int.tryParse(repsController.text) ?? 10),
                                    repsType: isTimer ? null : 'standard',
                                    timeSeconds: isTimer ? (int.tryParse(timeController.text) ?? 60) : null,
                                  ),
                                );
                              }

                              final exercise = WorkoutExerciseModel(
                                id: 'ex_${now.millisecondsSinceEpoch}',
                                exerciseName: name,
                                exerciseId: 'quick_${now.millisecondsSinceEpoch}',
                                sets: exerciseSets,
                                date: now,
                                createdAt: now,
                              );

                              setState(() {
                                _workout = _workout!.copyWith(workoutExercises: [..._workout!.workoutExercises, exercise]);
                              });

                              nameController.dispose();
                              setsController.dispose();
                              repsController.dispose();
                              timeController.dispose();
                              Get.back();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.onAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Add Exercise', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      // When embedded in combined screen, no AppBar or Scaffold needed
      return Container(
        color: AppColors.backgroundColor,

        child: Column(
          children: [
            // Actions bar
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                  : _loadError != null
                  ? _buildLoadError()
                  : _workout == null || _workout!.isEmpty
                  ? _buildEmpty()
                  : _buildContent(),
            ),
          ],
        ),
      );
    }

    // Standalone screen with full scaffold
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: AppColors.accent),
          onPressed: () {},
        ),
        title: Text(
          'Workout Journal',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: AppColors.accent),
            onPressed: () => Get.toNamed(AppRoutes.calendar),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: AppColors.onAccent, size: 20),
            ),
            onPressed: _isWorkoutCompleted ? null : _showAddExerciseDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _loadError != null
          ? _buildLoadError()
          : _workout == null || _workout!.isEmpty
          ? _buildEmpty()
          : _buildContent(),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Could not load workout journal',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadWorkoutJournal, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // GR Logo with drop shadow
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 15, offset: Offset(2, 10))],
                  ),
                  child: Image.asset('assets/images/logo-04.png', width: 130, height: 130, fit: BoxFit.contain),
                ),
              ),
              // Instructional text
              Text(
                'Build workout with + button',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark, fontSize: 16.sp),
              ),
            ],
          ),
        ),
        // Glass / Frosted Plus Button at bottom center with 3D effect
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isWorkoutCompleted ? null : _showAddExerciseDialog,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color.fromARGB(255, 240, 250, 219).withValues(alpha: 0.7), // Light grey frosted
                  boxShadow: [
                    // Soft diffused shadow beneath and slightly to the right
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(2, 6), spreadRadius: 0),
                    // Very subtle ambient shadow
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(1, 3), spreadRadius: 0),
                  ],
                  border: Border.all(
                    color: AppColors.accent,
                    width: 0.8, // Very thin border
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.5,
                      colors: [
                        Colors.white.withValues(alpha: 0.4), // Subtle highlight at top-left
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Center(child: Icon(Icons.add, size: 40, color: Colors.black87)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openNewWorkoutScreen() async {
    if (_isWorkoutCompleted) {
      Get.snackbar('Workout completed', 'You cannot add more exercises to a completed workout.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      await _ensureWorkoutJournalId();
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Error', e.toString().replaceFirst('Exception: ', ''), backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    await Get.toNamed(
      AppRoutes.newWorkout,
      arguments: {
        'workoutJournalId': _workoutJournalId,
        'journalWorkoutIds': _currentJournalWorkoutIds(),
        'addedExerciseIds': _currentAddedLibraryExerciseIds(),
        'journalDay': _journalDay,
      },
    )?.then((r) async {
      if (r is! Map || r['exercises'] == null) return;
      final returnedJournalId = r['workoutJournalId']?.toString();
      if (WorkoutRepository.isValidMongoId(returnedJournalId)) {
        _workoutJournalId = returnedJournalId;
        await _linkJournalToPlannerCalendar(returnedJournalId!);
      }
      final exercises = (r['exercises'] as List).whereType<WorkoutExerciseModel>();
      await _rememberExerciseSections(exercises, JournalExerciseType.workout);
      await _refreshWorkoutJournalFromApi();
    });
  }

  void _showAddExerciseDialog() {
    _openNewWorkoutScreen();
  }

  void _shareVia(String method) {
    if (Get.isDialogOpen == true) Get.back();
    switch (method) {
      case 'message':
        final journalId = _workoutJournalId?.trim();
        if (!WorkoutRepository.isValidMongoId(journalId)) {
          Get.snackbar('Cannot share', 'Save at least one exercise first', backgroundColor: AppColors.error, colorText: AppColors.onError);
          return;
        }
        ShareToChatService.share(context: context, type: SharedContentType.workoutJournal, contentId: journalId!);
        break;
      case 'copy':
        Get.snackbar('Link Copied', 'Workout link copied to clipboard', backgroundColor: AppColors.completed, colorText: AppColors.onError);
        break;
      default:
        Get.snackbar('Share', 'Opening system share sheet', backgroundColor: AppColors.accentVariant, colorText: Colors.white);
    }
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isStarted) _buildMetrics(),

                if (_workout!.workoutExercises.isNotEmpty) ...[
                  _buildExerciseSummaryHeader(),
                  ..._buildExercisesList(_workout!.workoutExercises),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        /// Bottom Buttons
        if (!_isStarted && !_workout!.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isWorkoutCompleted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.completed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.completed.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, color: AppColors.completed, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Workout completed',
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.completed, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(33, 33, 78, 49),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: AppColors.accentVariant.withValues(alpha: 0.25), width: 2),
                        ),
                        child: SvgPicture.asset(
                          'assets/icons/share.svg',
                          width: 22,
                          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                        ).paddingAll(5),
                      ),
                      onPressed: () => _shareVia('message'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isWorkoutCompleted ? null : _startWorkout,
                      icon: Icon(Icons.play_arrow, color: AppColors.white, size: 25),

                      label: Text('Start Workout', style: AppTextStyles.buttonMedium),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        disabledBackgroundColor: AppColors.primaryGrayLight,
                        disabledForegroundColor: AppColors.primaryGray,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        elevation: 2,
                      ),
                    ),

                    if (_workout != null && !_workout!.isEmpty)
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(33, 33, 78, 49),
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(color: AppColors.accentVariant.withValues(alpha: 0.25), width: 2),
                          ),
                          child: Icon(
                            Icons.add,
                            color: _isWorkoutCompleted ? AppColors.primaryGray : AppColors.accentVariant,
                            size: 30.sp,
                          ),
                        ),
                        onPressed: _isWorkoutCompleted ? null : _showAddExerciseDialog,
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMetrics() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.backgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          GestureDetector(
            onTap: _stopWorkout,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: Icon(Icons.stop, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isPaused ? _resumeWorkout : _pauseWorkout,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: _isPaused ? AppColors.accent : Colors.orange, shape: BoxShape.circle),
              child: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.primaryGrayLight.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timer_outlined, color: AppColors.accent, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(_seconds),
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSummaryHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          '${_workout!.workoutExercises.length} ${_workout!.workoutExercises.length == 1 ? 'Exercise' : 'Exercises'}',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
        ),
      );

  WorkoutExerciseModel _exerciseWithJournalNotes(WorkoutExerciseModel ex) => ex;

  String? _supersetGroupKey(WorkoutExerciseModel ex) {
    final raw = ex.supersetIdentifier?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return ex.supersetId;
  }

  bool _inSameSupersetGroup(WorkoutExerciseModel a, WorkoutExerciseModel b) {
    if (!a.isSuperset || !b.isSuperset || a.id == b.id) return false;
    final rawA = a.supersetIdentifier?.trim();
    final rawB = b.supersetIdentifier?.trim();
    if (rawA != null && rawA.isNotEmpty && rawB != null && rawB.isNotEmpty) {
      return rawA == rawB;
    }
    final keyA = _supersetGroupKey(a);
    final keyB = _supersetGroupKey(b);
    return keyA != null && keyA == keyB;
  }

  (WorkoutExerciseModel, WorkoutExerciseModel) _orderedSupersetPair(
    WorkoutExerciseModel a,
    WorkoutExerciseModel b,
    List<WorkoutExerciseModel> exercises,
  ) {
    if (a.supersetOrder != null && b.supersetOrder != null && a.supersetOrder != b.supersetOrder) {
      return a.supersetOrder! <= b.supersetOrder! ? (a, b) : (b, a);
    }
    final indexA = exercises.indexWhere((e) => e.id == a.id);
    final indexB = exercises.indexWhere((e) => e.id == b.id);
    if (indexA >= 0 && indexB >= 0 && indexA != indexB) {
      return indexA <= indexB ? (a, b) : (b, a);
    }
    return (a, b);
  }

  /// Build exercises list with superset grouping support
  List<Widget> _buildExercisesList(List<WorkoutExerciseModel> exercises) {
    final List<Widget> widgets = [];
    final Set<String> processedSupersets = {};

    for (int i = 0; i < exercises.length; i++) {
      final exercise = _exerciseWithJournalNotes(exercises[i]);

      // Check if this exercise is part of a superset
      if (exercise.isSuperset && _supersetGroupKey(exercise) != null) {
        final groupKey = _supersetGroupKey(exercise)!;
        // Skip if we've already processed this superset group
        if (processedSupersets.contains(groupKey)) {
          continue;
        }

        // Find the partner exercise in the same superset group
        final otherRaw = exercises.firstWhereOrNull((e) => _inSameSupersetGroup(exercise, e));
        final otherExercise = otherRaw != null ? _exerciseWithJournalNotes(otherRaw) : null;

        if (otherExercise != null) {
          final pair = _orderedSupersetPair(exercise, otherExercise, exercises);
          final ex1 = pair.$1;
          final ex2 = pair.$2;
          // Add superset card
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SupersetCard(
                exercise1: ex1,
                exercise2: ex2,
                onMenuTap1: () => _showMenu(ex1),
                onMenuTap2: () => _showMenu(ex2),
                onTimerTap1: () {
                  if (ex1.hasTimedSets) {
                    Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': ex1});
                  }
                },
                onTimerTap2: () {
                  if (ex2.hasTimedSets) {
                    Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': ex2});
                  }
                },
              ),
            ),
          );
          processedSupersets.add(groupKey);
        } else {
          // Superset partner not found, display as regular exercise
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ExerciseCard(
                exercise: exercise,
                onMenuTap: () => _showMenu(exercise),
                onTimerTap: () {
                  if (exercise.hasTimedSets) {
                    Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': exercise});
                  }
                },
              ),
            ),
          );
        }
      } else {
        // Regular exercise (not a superset)
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ExerciseCard(
              exercise: exercise,
              onMenuTap: () => _showMenu(exercise),
              onTimerTap: () {
                if (exercise.hasTimedSets) {
                  Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': exercise});
                }
              },
            ),
          ),
        );
      }
    }

    return widgets;
  }

  void _showMenu(WorkoutExerciseModel ex) {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(color: AppColors.primaryGray, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              ListTile(
                onTap: () {
                  Get.back();
                  Get.toNamed(
                    AppRoutes.exerciseConfiguration,
                    arguments: {'isEditing': true, 'existingExercise': ex, 'exerciseType': JournalExerciseType.workout},
                  )?.then((r) async {
                    if (r != null) await _refreshWorkoutJournalFromApi();
                  });
                },
                title: Center(
                  child: Text(
                    'Edit',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              if (!_isWorkoutCompleted && !ex.isSuperset && WorkoutRepository.isValidMongoId(ex.id))
                ListTile(
                  onTap: _isSavingJournal
                      ? null
                      : () {
                          Get.back();
                          _openSupersetPartnerFlow(ex);
                        },
                  title: Center(
                    child: Text(
                      'Add Superset Partner',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ListTile(
                onTap: () {
                  Get.back();
                  final displayEx = _exerciseWithJournalNotes(ex);
                  Get.toNamed(
                    AppRoutes.videoWalkthrough,
                    arguments: {
                      'exerciseName': displayEx.exerciseName,
                      'exerciseId': displayEx.exerciseId,
                      'videoUrl': displayEx.videoUrl,
                      'videoThumbnailUrl': displayEx.videoThumbnailUrl ?? displayEx.iconUrl,
                    },
                  );
                },
                title: Center(
                  child: Text(
                    'Video Walkthrough',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              ListTile(
                onTap: _isSavingJournal
                    ? null
                    : () {
                        Get.back();
                        _deleteExercise(ex);
                      },
                title: Center(
                  child: Text(
                    'Delete',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.red, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              ListTile(
                onTap: _isSavingJournal
                    ? null
                    : () {
                        Get.back();
                        Get.toNamed(
                          AppRoutes.reorderExercises,
                          arguments: {'exercises': _workout!.workoutExercises},
                        )?.then((r) {
                          if (r != null && r['exercises'] != null) {
                            _reorderExercises(r['exercises'] as List<WorkoutExerciseModel>);
                          }
                        });
                      },
                title: Center(
                  child: Text(
                    'Move/Reorder',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              ListTile(
                onTap: _isSavingJournal
                    ? null
                    : () {
                        Get.back();
                        Get.toNamed(AppRoutes.addNotes, arguments: {'exerciseName': ex.exerciseName, 'existingNotes': ex.notes ?? ''})?.then((r) {
                          if (r != null && r['notes'] != null) {
                            _saveJournalNotes(ex, r['notes'] as String);
                          }
                        });
                      },
                title: Center(
                  child: Text(
                    'Add Notes',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Get.back(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentVariant,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel', style: AppTextStyles.buttonMedium),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }
}
