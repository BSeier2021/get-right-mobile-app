import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/models/workout_journal_model.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/models/journal_exercise_type.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/services/share_to_chat_service.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/models/workout_group_type.dart';
import 'package:get_right/widgets/journal/journal_exercise_card.dart';
import 'package:get_right/widgets/journal/workout_group_card.dart';
import 'package:get_right/views/journal/workout_celebration_screen.dart';
import 'package:get_right/utils/journal_flow.dart';
import 'package:get_right/views/home/dashboard_screen.dart';

const Color _kJournalLime = Color(0xFFCBE870);
const Color _kJournalActionCircle = Color(0xFFE1EAD8);

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
  // Journal add-exercise flow is handled by JournalFlowNavigator (see lib/utils/journal_flow.dart).
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

  WorkoutJournalModel _applyStoredExerciseSections(WorkoutJournalModel fromApi) {
    final warmup = <WorkoutExerciseModel>[];
    final workout = <WorkoutExerciseModel>[];
    final seen = <String>{};
    var sectionsChanged = false;

    for (final ex in fromApi.allExercises) {
      if (!seen.add(ex.id)) continue;

      final type = ex.exerciseType ?? _exerciseSectionById[ex.id] ?? JournalExerciseType.workout;
      if (ex.exerciseType != null && WorkoutRepository.isValidMongoId(ex.id)) {
        if (_exerciseSectionById[ex.id] != ex.exerciseType) {
          _exerciseSectionById[ex.id] = ex.exerciseType!;
          sectionsChanged = true;
        }
      }

      final typed = ex.exerciseType == null ? ex.copyWith(exerciseType: type) : ex;
      if (type.isWarmup) {
        warmup.add(typed);
      } else {
        workout.add(typed);
      }
    }

    if (sectionsChanged) {
      unawaited(_persistExerciseSections());
    }

    return fromApi.copyWith(warmupExercises: warmup, workoutExercises: workout);
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
          _workout = _applyStoredExerciseSections(
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

  Future<void> _deleteExercise(WorkoutExerciseModel ex, bool isWarmup) async {
    final journalId = _workoutJournalByExerciseId[ex.id];
    if (journalId == null || !WorkoutRepository.isValidMongoId(journalId)) {
      setState(() {
        if (isWarmup) {
          _workout = _workout!.copyWith(warmupExercises: _workout!.warmupExercises.where((e) => e.id != ex.id).toList());
        } else {
          _workout = _workout!.copyWith(workoutExercises: _workout!.workoutExercises.where((e) => e.id != ex.id).toList());
        }
      });
      return;
    }

    final entry = WorkoutRepository.journalEntryById(_journalEntries, journalId);
    if (entry == null) return;

    final remainingIds = WorkoutRepository.workoutIdsFrom(entry).where((id) => id != ex.id).toList();
    await _forgetExerciseSection(ex.id);
    await _persistJournalEntry(journalId: journalId, workoutIds: remainingIds);
  }

  Future<void> _reorderExercises(List<WorkoutExerciseModel> reordered, bool isWarmup) async {
    final idsByJournal = <String, List<String>>{};
    for (final ex in reordered) {
      final journalId = _workoutJournalByExerciseId[ex.id];
      if (journalId == null || !WorkoutRepository.isValidMongoId(ex.id)) continue;
      idsByJournal.putIfAbsent(journalId, () => []).add(ex.id);
    }

    if (idsByJournal.isEmpty) {
      setState(() {
        if (isWarmup) {
          _workout = _workout!.copyWith(warmupExercises: reordered);
        } else {
          _workout = _workout!.copyWith(workoutExercises: reordered);
        }
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
    final exerciseCount = _workout!.warmupExercises.length + _workout!.workoutExercises.length;
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
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 20.sp),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'WORKOUT JOURNAL',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            fontSize: 14.sp,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.event_available_outlined, color: AppColors.accent, size: 24.sp),
            onPressed: () => Get.toNamed(AppRoutes.calendar),
          ),
          SizedBox(width: 4.w),
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

  void _showAddExerciseDialog() => _openAddExerciseFlow();

  Future<void> _openAddExerciseFlow() async {
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

    final flowContext = JournalFlowContext(
      workoutJournalId: _workoutJournalId,
      journalWorkoutIds: _currentJournalWorkoutIds(),
      addedExerciseIds: _currentAddedLibraryExerciseIds(),
      journalDay: _journalDay,
    );

    final result = await JournalFlowNavigator.openAddExerciseFlow(
      context: flowContext,
      workoutIsEmpty: _workout == null || _workout!.isEmpty,
    );

    final parsed = JournalFlowSaveResult.tryParse(result);
    if (parsed == null) return;

    if (parsed.workoutJournalId != null) {
      _workoutJournalId = parsed.workoutJournalId;
      await _linkJournalToPlannerCalendar(parsed.workoutJournalId!);
    }
    await _rememberExerciseSections(parsed.exercises, parsed.exerciseType);
    await _refreshWorkoutJournalFromApi();
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
    final exercises = _workout!.allExercises;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isStarted) _buildMetrics(),
                _buildTodaySectionHeader(),
                SizedBox(height: 16.h),
                ..._buildExercisesList(exercises, false),
              ],
            ),
          ),
        ),
        if (!_isStarted && !_workout!.isEmpty) _buildBottomActions(),
      ],
    );
  }

  Widget _buildTodaySectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today_outlined, color: AppColors.accent, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              "Today's Workout",
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        Container(
          height: 2,
          width: 160.w,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isWorkoutCompleted)
              Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: AppColors.completed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.completed.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: AppColors.completed, size: 18.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Workout completed',
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.completed, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                _buildCircleActionButton(
                  icon: Icons.ios_share,
                  onPressed: () => _shareVia('message'),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: SizedBox(
                    height: 52.h,
                    child: ElevatedButton.icon(
                      onPressed: _isWorkoutCompleted ? null : _startWorkout,
                      icon: Icon(Icons.play_arrow_rounded, color: AppColors.onAccent, size: 24.sp),
                      label: Text(
                        'Start Workout',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.onAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        disabledBackgroundColor: AppColors.primaryGrayLight,
                        disabledForegroundColor: AppColors.primaryGray,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                _buildCircleActionButton(
                  icon: Icons.add,
                  onPressed: _isWorkoutCompleted ? null : _showAddExerciseDialog,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          width: 52.w,
          height: 52.w,
          decoration: BoxDecoration(
            color: enabled ? _kJournalActionCircle : AppColors.primaryGrayLight.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: enabled ? AppColors.accent : AppColors.primaryGray,
            size: 24.sp,
          ),
        ),
      ),
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

  /// Build exercises list with grouped superset/circuit support.
  List<Widget> _buildExercisesList(List<WorkoutExerciseModel> exercises, bool isWarmup) {
    final List<Widget> widgets = [];
    final Set<String> processedGroups = {};
    var displayIndex = 0;

    for (final raw in exercises) {
      final exercise = _exerciseWithJournalNotes(raw);
      final groupKey = _supersetGroupKey(exercise);

      if (exercise.isSuperset && groupKey != null) {
        if (processedGroups.contains(groupKey)) continue;

        final groupMembers = exercises
            .where((e) => _inSameSupersetGroup(exercise, e))
            .map(_exerciseWithJournalNotes)
            .toList()
          ..sort((a, b) {
            final orderA = a.supersetOrder ?? exercises.indexWhere((e) => e.id == a.id);
            final orderB = b.supersetOrder ?? exercises.indexWhere((e) => e.id == b.id);
            return orderA.compareTo(orderB);
          });

        if (groupMembers.length >= 2) {
          displayIndex++;
          final groupType = groupMembers.length >= 3 ? WorkoutGroupType.circuit : WorkoutGroupType.superset;
          widgets.add(
            Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: WorkoutGroupCard(
                exercises: groupMembers,
                groupType: groupType,
                onMenuTap: (ex) => _showMenu(ex, isWarmup),
                onTimerTap: (ex) {
                  if (ex.hasTimedSets) {
                    Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': ex});
                  }
                },
              ),
            ),
          );
          processedGroups.add(groupKey);
          continue;
        }
      }

      displayIndex++;
      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: JournalExerciseCard(
            exercise: exercise,
            index: displayIndex,
            onMenuTap: () => _showMenu(exercise, isWarmup),
            onTimerTap: () {
              if (exercise.hasTimedSets) {
                Get.toNamed(AppRoutes.workoutTimer, arguments: {'exercise': exercise});
              }
            },
          ),
        ),
      );
    }

    return widgets;
  }

  void _showMenu(WorkoutExerciseModel ex, bool isWarmup) {
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
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: AppColors.accent, size: 22.sp),
                title: Text('Edit', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                onTap: () {
                  Get.back();
                  Get.toNamed(
                    AppRoutes.exerciseConfiguration,
                    arguments: {
                      'isEditing': true,
                      'existingExercise': ex,
                      'journalFlow': true,
                      'exerciseType': JournalExerciseType.fromIsWarmup(isWarmup),
                      'workoutJournalId': _workoutJournalId,
                      'journalWorkoutIds': _currentJournalWorkoutIds(),
                      'journalDay': _journalDay,
                    },
                  )?.then((r) async {
                    if (r != null) await _refreshWorkoutJournalFromApi();
                  });
                },
              ),
              ListTile(
                leading: Icon(Icons.swap_vert, color: AppColors.accent, size: 22.sp),
                title: Text('Reorder', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                onTap: _isSavingJournal
                    ? null
                    : () {
                        Get.back();
                        Get.toNamed(
                          AppRoutes.reorderExercises,
                          arguments: {'exercises': _workout!.allExercises},
                        )?.then((r) {
                          if (r != null && r['exercises'] != null) {
                            _reorderExercises(r['exercises'] as List<WorkoutExerciseModel>, isWarmup);
                          }
                        });
                      },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                title: Text('Delete', style: AppTextStyles.bodyMedium.copyWith(color: Colors.red, fontWeight: FontWeight.w600)),
                onTap: _isSavingJournal
                    ? null
                    : () {
                        Get.back();
                        _deleteExercise(ex, isWarmup);
                      },
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }
}
